#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR"
TARGET_DIR="${1:-}"
FRONTEND_TARGET_DIR="${2:-${APACHE_FRONTEND_ROOT:-}}"
CLEAR_DATABASE_ONCE="${CLEAR_DATABASE_ONCE:-false}"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

log() {
  printf '[deploy][%s] %s\n' "$1" "$2"
}

info() {
  log INFO "$1"
}

warn() {
  log WARN "$1"
}

error() {
  log ERROR "$1" >&2
}

die() {
  error "$1"
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh /absolute/path/to/current-release /absolute/path/to/apache-web-root

Behavior:
  - Backs up the current deployment (excluding postgres data) into .deploy_backups
  - Preserves an existing .env if present
  - Syncs the new release files into the target directory
  - Publishes frontend/dist into the Apache web root with stale files removed
  - Optionally clears postgres data once when CLEAR_DATABASE_ONCE=true
  - Rebuilds and restarts containers with docker compose
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

[[ -n "$TARGET_DIR" ]] || {
  usage
  exit 64
}

case "$TARGET_DIR" in
  /*) ;;
  *) die "target directory must be an absolute path: $TARGET_DIR" ;;
esac

[[ -n "$FRONTEND_TARGET_DIR" ]] || die "apache frontend directory is required as arg #2 or APACHE_FRONTEND_ROOT"

case "$FRONTEND_TARGET_DIR" in
  /*) ;;
  *) die "apache frontend directory must be an absolute path: $FRONTEND_TARGET_DIR" ;;
esac

require_cmd docker
require_cmd tar
require_cmd cp
require_cmd mkdir
require_cmd rsync

if ! docker compose version >/dev/null 2>&1; then
  die "docker compose is not available on this server"
fi

TMP_DIR="$(mktemp -d)"
TARGET_DIR="${TARGET_DIR%/}"
FRONTEND_TARGET_DIR="${FRONTEND_TARGET_DIR%/}"
BACKUP_DIR="$TARGET_DIR/.deploy_backups"
BACKUP_ARCHIVE="$BACKUP_DIR/release-$TIMESTAMP.tar.gz"
FRONTEND_BACKUP_ARCHIVE="$BACKUP_DIR/frontend-$TIMESTAMP.tar.gz"
ENV_SOURCE="$SOURCE_DIR/.env"
ENV_TARGET="$TARGET_DIR/.env"

info "source package: $SOURCE_DIR"
info "target directory: $TARGET_DIR"
info "apache frontend root: $FRONTEND_TARGET_DIR"
info "clear database once: $CLEAR_DATABASE_ONCE"

[[ -f "$SOURCE_DIR/docker-compose.yml" ]] || die "source package is incomplete: missing docker-compose.yml"
[[ -f "$SOURCE_DIR/Dockerfile.backend" ]] || die "source package is incomplete: missing Dockerfile.backend"
[[ -d "$SOURCE_DIR/backend" ]] || die "source package is incomplete: missing backend/"
[[ -d "$SOURCE_DIR/frontend/dist" ]] || die "source package is incomplete: missing frontend/dist/"

mkdir -p "$TARGET_DIR" "$BACKUP_DIR" "$FRONTEND_TARGET_DIR"

if [[ -f "$ENV_TARGET" ]]; then
  info "preserving existing .env from target"
  cp "$ENV_TARGET" "$TMP_DIR/target.env"
  warn "existing .env preserved; bootstrap admin credentials printed during a new build do not overwrite an existing deployment"
else
  warn "target has no .env yet; generated .env from package will be used"
  [[ -f "$ENV_SOURCE" ]] || die "package does not include a generated .env"
fi

if [[ -f "$TARGET_DIR/docker-compose.yml" ]]; then
  info "creating backup archive: $BACKUP_ARCHIVE"
  tar \
    --exclude='./data/postgres' \
    --exclude='./.deploy_backups' \
    -C "$TARGET_DIR" \
    -czf "$BACKUP_ARCHIVE" \
    .
else
  info "target looks empty; skipping deployment backup"
fi

if find "$FRONTEND_TARGET_DIR" -mindepth 1 -maxdepth 1 | read -r _; then
  info "creating frontend backup archive: $FRONTEND_BACKUP_ARCHIVE"
  tar -C "$FRONTEND_TARGET_DIR" -czf "$FRONTEND_BACKUP_ARCHIVE" .
else
  info "apache frontend root looks empty; skipping frontend backup"
fi

info "syncing new release into target"
tar \
  --exclude='./.env' \
  -C "$SOURCE_DIR" \
  -cf - \
  . | tar -C "$TARGET_DIR" -xf -

if [[ -f "$TMP_DIR/target.env" ]]; then
  cp "$TMP_DIR/target.env" "$ENV_TARGET"
else
  cp "$ENV_SOURCE" "$ENV_TARGET"
fi

chmod +x "$TARGET_DIR/deploy.sh" "$TARGET_DIR/backend/entrypoint.sh" || true

if [[ -f "$TARGET_DIR/.env" ]]; then
  info "active .env: $TARGET_DIR/.env"
fi

info "publishing frontend assets to apache web root"
rsync -a --delete \
  --exclude='.user.ini' \
  "$SOURCE_DIR/frontend/dist/" \
  "$FRONTEND_TARGET_DIR/"

if [[ ! -f "$FRONTEND_TARGET_DIR/index.html" ]]; then
  die "frontend publish failed: index.html not found in $FRONTEND_TARGET_DIR"
fi

if [[ "$CLEAR_DATABASE_ONCE" == "true" ]]; then
  warn "CLEAR_DATABASE_ONCE=true, removing postgres volume data before restart"
  (
    cd "$TARGET_DIR"
    docker compose down -v || true
  )
  rm -rf "$TARGET_DIR/data/postgres"
  mkdir -p "$TARGET_DIR/data/postgres"
fi

info "building and starting containers"
(
  cd "$TARGET_DIR"
  docker compose up -d --build
)

info "deployment completed successfully"
info "backup archive: $BACKUP_ARCHIVE"
info "frontend backup archive: $FRONTEND_BACKUP_ARCHIVE"
info "check status with: cd $TARGET_DIR && docker compose ps"
info "tail server logs with: cd $TARGET_DIR && docker compose logs -f passport_server"
