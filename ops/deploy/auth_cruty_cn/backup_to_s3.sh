#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/deploy/auth_cruty_cn/s3_key.sh
source "$script_dir/s3_key.sh"

TARGET_DIR="${1:?target directory required}"
RUNTIME_ENV_FILE="${2:?runtime env required}"
SECRETS_DIR="${3:?secrets directory required}"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

read_env() {
  sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1
}

S3_ENDPOINT="$(read_env S3_ENDPOINT)"
S3_BUCKET="$(read_env S3_BUCKET)"
S3_REGION="$(read_env S3_REGION)"
S3_PREFIX="$(read_env S3_PREFIX)"
POSTGRES_DB="$(read_env POSTGRES_DB)"
POSTGRES_USER="$(read_env POSTGRES_USER)"
[[ -n "$S3_ENDPOINT" && -n "$S3_BUCKET" ]] || {
  echo "S3_ENDPOINT and S3_BUCKET are required" >&2
  exit 78
}

AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"
"$(dirname "${BASH_SOURCE[0]}")/check_s3_storage.sh" "$RUNTIME_ENV_FILE" "$SECRETS_DIR"

dump_path="$TMP_DIR/database.dump"
encrypted_path="$TMP_DIR/database.dump.enc"
validate_s3_prefix "$S3_PREFIX" || { echo 'S3_PREFIX is invalid' >&2; exit 78; }
object_key="$(s3_key "$S3_PREFIX" "base/$TIMESTAMP.dump.enc")"
compose_env_file="$RUNTIME_ENV_FILE"
if [[ -e "$TARGET_DIR/.env" ]]; then
  [[ -f "$TARGET_DIR/.env" && ! -L "$TARGET_DIR/.env" ]] || {
    echo "legacy .env must be a regular non-symlink file" >&2
    exit 78
  }
  legacy_mode="$(stat -c '%a' "$TARGET_DIR/.env" 2>/dev/null || stat -f '%Lp' "$TARGET_DIR/.env")"
  legacy_uid="$(stat -c '%u' "$TARGET_DIR/.env" 2>/dev/null || stat -f '%u' "$TARGET_DIR/.env")"
  [[ "$legacy_mode" == 600 && "$legacy_uid" == "$(id -u)" ]] || {
    echo "legacy .env must be mode 0600 and owned by the backup user" >&2
    exit 78
  }
  compose_env_file="$TARGET_DIR/.env"
fi
project_name="$(basename "$TARGET_DIR")"
[[ "$project_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || {
  echo "target directory name is not a safe Compose project" >&2
  exit 78
}

(
  cd "$TARGET_DIR"
  docker compose --project-name "$project_name" --env-file "$compose_env_file" \
    exec -T postgres \
    pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      --format=custom --no-owner --no-acl >"$dump_path"
)
pg_restore --list "$dump_path" >/dev/null
openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass file:"$SECRETS_DIR/backup_encryption_key" \
  -in "$dump_path" -out "$encrypted_path"
checksum="$(sha256sum "$encrypted_path" | awk '{print $1}')"
"$(dirname "${BASH_SOURCE[0]}")/upload_s3_verified.sh" \
  "$encrypted_path" "$S3_ENDPOINT" "$S3_BUCKET" "$object_key"
printf '{"created_at":"%s","object":"%s","sha256":"%s"}\n' \
  "$TIMESTAMP" "$object_key" "$checksum" >"$TMP_DIR/manifest.json"
"$(dirname "${BASH_SOURCE[0]}")/upload_s3_verified.sh" \
  "$TMP_DIR/manifest.json" "$S3_ENDPOINT" "$S3_BUCKET" \
  "$(s3_key "$S3_PREFIX" "base/$TIMESTAMP.manifest.json")"
printf 'backup_object=%s\n' "$object_key"
