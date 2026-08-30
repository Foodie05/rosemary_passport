#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
TARGET_DIR="${1:-}"
FRONTEND_TARGET_DIR="${2:-${APACHE_FRONTEND_ROOT:-}}"
RUNTIME_ENV_FILE="${3:-${ROSM_RUNTIME_ENV_FILE:-/etc/rosm-passport/runtime.env}}"
SECRETS_DIR="${4:-${ROSM_SECRETS_DIR:-/etc/rosm-passport/secrets}}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

log() { printf '[deploy][%s] %s\n' "$1" "$2"; }
info() { log INFO "$1"; }
error() { log ERROR "$1" >&2; }
die() { error "$1"; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh /absolute/path/to/current-release /absolute/path/to/apache-web-root \
    [/etc/rosm-passport/runtime.env] [/etc/rosm-passport/secrets]

The runtime env contains non-secret settings only. Secrets must be mounted from
the external secrets directory and are never copied into a release or backup.
EOF
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }
cleanup() {
  if [[ "${MAINTENANCE_ENABLED:-false}" == true && -e "$FRONTEND_TARGET_DIR/.maintenance" ]]; then
    unlink "$FRONTEND_TARGET_DIR/.maintenance" || true
  fi
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

[[ -n "$TARGET_DIR" && -n "$FRONTEND_TARGET_DIR" ]] || { usage; exit 64; }
[[ "$TARGET_DIR" = /* ]] || die "target directory must be absolute"
[[ "$FRONTEND_TARGET_DIR" = /* ]] || die "frontend directory must be absolute"

for command in docker tar rsync curl mkdir ln mv grep readlink aws openssl \
  sha256sum pg_restore sed tail awk df date; do require_cmd "$command"; done
docker compose version >/dev/null 2>&1 || die "docker compose is unavailable"

TARGET_DIR="${TARGET_DIR%/}"
FRONTEND_TARGET_DIR="${FRONTEND_TARGET_DIR%/}"
BACKUP_DIR="$TARGET_DIR/.deploy_backups"
BACKUP_ARCHIVE="$BACKUP_DIR/release-$TIMESTAMP.tar.gz"
FRONTEND_BACKUP_ARCHIVE="$BACKUP_DIR/frontend-$TIMESTAMP.tar.gz"
FRONTEND_RELEASES_DIR="${FRONTEND_TARGET_DIR}.releases"
FRONTEND_STAGE_DIR="$FRONTEND_RELEASES_DIR/$TIMESTAMP"
TMP_DIR="$(mktemp -d)"

[[ -f "$SOURCE_DIR/docker-compose.yml" ]] || die "release is missing docker-compose.yml"
[[ -f "$SOURCE_DIR/Dockerfile.backend" ]] || die "release is missing Dockerfile.backend"
[[ -d "$SOURCE_DIR/backend" ]] || die "release is missing backend/"
[[ -f "$SOURCE_DIR/frontend/dist/index.html" ]] || die "release is missing frontend/dist/index.html"
[[ -f "$SOURCE_DIR/frontend/dist/maintenance.html" ]] || die "release is missing maintenance page"
[[ -f "$RUNTIME_ENV_FILE" ]] || die "runtime env is missing: $RUNTIME_ENV_FILE"
[[ -d "$SECRETS_DIR" ]] || die "secrets directory is missing: $SECRETS_DIR"
[[ ! -f "$TARGET_DIR/.env" ]] || die "legacy .env must be migrated outside the release directory first"

required_secret_files=(
  db_password jwt_binding_key email_code_hmac_key smtp_password
  local_admin_password aliyun_captcha_access_key_id
  aliyun_captcha_access_key_secret aliyun_access_key_id
  aliyun_access_key_secret backup_encryption_key
  s3_access_key_id s3_secret_access_key helper_shared_key
)
for secret_file in "${required_secret_files[@]}"; do
  [[ -f "$SECRETS_DIR/$secret_file" ]] || die "missing secret: $SECRETS_DIR/$secret_file"
done
for secret_file in db_password jwt_binding_key email_code_hmac_key \
  local_admin_password backup_encryption_key s3_access_key_id \
  s3_secret_access_key helper_shared_key; do
  [[ -s "$SECRETS_DIR/$secret_file" ]] || die "empty required secret: $SECRETS_DIR/$secret_file"
done
[[ -s "$SECRETS_DIR/audit_signing.private.pem" ]] || die "missing audit signing private key"
[[ -s "$SECRETS_DIR/audit_signing.public.pem" ]] || die "missing audit signing public key"
[[ -d "$SECRETS_DIR/jwt" ]] || die "missing JWT keyring"
[[ -d "$SECRETS_DIR/data_keys" ]] || die "missing data keyring"
if grep -Eq 'REPLACE_WITH_VERIFIED_DIGEST|^[[:space:]]*(POSTGRES_IMAGE|NODE_IMAGE)=[^@]*$' "$RUNTIME_ENV_FILE"; then
  die "runtime images must use verified sha256 digests"
fi
legacy_json_sunset="$(sed -n 's/^LEGACY_JSON_REFRESH_SUNSET_AT=//p' \
  "$RUNTIME_ENV_FILE" | tail -n 1)"
if [[ ! "$legacy_json_sunset" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
  ! date -u -d "$legacy_json_sunset" '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
  die "legacy JSON refresh sunset must be a valid RFC 3339 UTC timestamp"
fi

info "validating host capacity"
"$SOURCE_DIR/check_host_capacity.sh"
info "validating off-host storage protection"
"$SOURCE_DIR/check_s3_storage.sh" "$RUNTIME_ENV_FILE" "$SECRETS_DIR"

compose() { docker compose --env-file "$RUNTIME_ENV_FILE" "$@"; }

mkdir -p "$TARGET_DIR" "$BACKUP_DIR" "$FRONTEND_RELEASES_DIR"
"$SOURCE_DIR/check_disk_capacity.sh" "$TARGET_DIR" "$FRONTEND_RELEASES_DIR"
previous_frontend=""
if [[ -L "$FRONTEND_TARGET_DIR" ]]; then
  previous_frontend="$(readlink "$FRONTEND_TARGET_DIR")"
fi

if [[ -f "$TARGET_DIR/docker-compose.yml" ]]; then
  info "creating credential-free code backup"
  tar --exclude='./data/postgres' --exclude='./.deploy_backups' \
    --exclude='./.env' -C "$TARGET_DIR" -czf "$BACKUP_ARCHIVE" .
fi
if [[ -e "$FRONTEND_TARGET_DIR" ]]; then
  tar -C "$FRONTEND_TARGET_DIR" -czf "$FRONTEND_BACKUP_ARCHIVE" .
fi

if [[ -f "$TARGET_DIR/docker-compose.yml" ]]; then
  info "creating encrypted off-host database backup"
  "$SOURCE_DIR/backup_to_s3.sh" "$TARGET_DIR" "$RUNTIME_ENV_FILE" "$SECRETS_DIR"
  "$SOURCE_DIR/physical_backup_to_s3.sh" "$TARGET_DIR" "$RUNTIME_ENV_FILE" "$SECRETS_DIR"
else
  info "first deployment: no existing database backup is required"
fi

info "syncing credential-free release"
tar --exclude='./.env' -C "$SOURCE_DIR" -cf - . | tar -C "$TARGET_DIR" -xf -
chmod +x "$TARGET_DIR/deploy.sh" "$TARGET_DIR/backup_to_s3.sh" \
  "$TARGET_DIR/physical_backup_to_s3.sh" \
  "$TARGET_DIR/check_s3_storage.sh" \
  "$TARGET_DIR/upload_s3_verified.sh" \
  "$TARGET_DIR/check_host_capacity.sh" \
  "$TARGET_DIR/check_disk_capacity.sh" \
  "$TARGET_DIR/archive_audit_to_s3.sh" \
  "$TARGET_DIR/restore_from_s3.sh" "$TARGET_DIR/pitr_drill.sh" \
  "$TARGET_DIR/record_sla_observation.sh" \
  "$TARGET_DIR/evaluate_sla_observation.sh" \
  "$TARGET_DIR/install_systemd_units.sh" \
  "$TARGET_DIR/provision_secrets.sh" \
  "$TARGET_DIR/backend/entrypoint.sh"

info "building containers before maintenance"
(
  cd "$TARGET_DIR"
  compose build
)

info "staging frontend"
mkdir -p "$FRONTEND_STAGE_DIR"
rsync -a --delete --exclude='.user.ini' \
  "$SOURCE_DIR/frontend/dist/" "$FRONTEND_STAGE_DIR/"
[[ -f "$FRONTEND_STAGE_DIR/index.html" ]] || die "frontend staging failed"
if [[ -d "$FRONTEND_TARGET_DIR" && ! -L "$FRONTEND_TARGET_DIR" ]]; then
  legacy_frontend="$FRONTEND_RELEASES_DIR/legacy-$TIMESTAMP"
  mv "$FRONTEND_TARGET_DIR" "$legacy_frontend"
  previous_frontend="$legacy_frontend"
  ln -s "$legacy_frontend" "$FRONTEND_TARGET_DIR"
fi

MAINTENANCE_ENABLED=false
if [[ -e "$FRONTEND_TARGET_DIR" ]]; then
  info "enabling maintenance mode"
  cp "$SOURCE_DIR/frontend/dist/maintenance.html" "$FRONTEND_TARGET_DIR/maintenance.html"
  touch "$FRONTEND_TARGET_DIR/.maintenance"
  MAINTENANCE_ENABLED=true
fi

info "starting migrated backend"
(
  cd "$TARGET_DIR"
  compose up -d --no-build
)

ready=false
for _ in {1..40}; do
  if curl --fail --silent --max-time 3 http://127.0.0.1:8091/health/ready >/dev/null; then
    ready=true
    break
  fi
  sleep 2
done

if [[ "$ready" != true ]]; then
  error "readiness failed; rolling back application files"
  if [[ -f "$BACKUP_ARCHIVE" ]]; then
    tar -C "$TARGET_DIR" -xzf "$BACKUP_ARCHIVE"
    (
      cd "$TARGET_DIR"
      compose up -d --build || true
    )
  fi
  exit 1
fi

info "atomically switching frontend and restoring traffic"
ln -sfn "$FRONTEND_STAGE_DIR" "$FRONTEND_TARGET_DIR.next"
mv -Tf "$FRONTEND_TARGET_DIR.next" "$FRONTEND_TARGET_DIR"
if [[ "$MAINTENANCE_ENABLED" == true && -n "$previous_frontend" && -e "$previous_frontend/.maintenance" ]]; then
  unlink "$previous_frontend/.maintenance"
fi
MAINTENANCE_ENABLED=false

info "deployment completed and readiness passed"
info "code backup: $BACKUP_ARCHIVE"
info "frontend backup: $FRONTEND_BACKUP_ARCHIVE"
