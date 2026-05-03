#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/.local/release/auth_cruty_cn_release.tar.gz}"

SSH_TARGET="${1:-${SSH_TARGET:-root@cruty.cn}}"
REMOTE_WORKDIR="${2:-${REMOTE_WORKDIR:-/www/wwwroot/auth}}"
REMOTE_RELEASE_DIR="${3:-${REMOTE_RELEASE_DIR:-/www/wwwroot/auth/auth_cruty_cn_release}}"
REMOTE_FRONTEND_DIR="${4:-${REMOTE_FRONTEND_DIR:-/www/wwwroot/auth.cruty.cn}}"
CLEAR_DATABASE_ONCE="${CLEAR_DATABASE_ONCE:-false}"
REMOTE_ARCHIVE_NAME="auth_cruty_cn_release.tar.gz"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
REMOTE_UPDATE_DIR="$REMOTE_WORKDIR/update-$TIMESTAMP"

log() {
  printf '[remote-deploy][%s] %s\n' "$1" "$2"
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
  ./scripts/deploy_auth_cruty_cn.sh [ssh_target] [remote_workdir] [remote_release_dir] [remote_frontend_dir]

Defaults:
  ssh_target          root@cruty.cn
  remote_workdir      /www/wwwroot/auth
  remote_release_dir  /www/wwwroot/auth/auth_cruty_cn_release
  remote_frontend_dir /www/wwwroot/auth.cruty.cn

What it does:
  1. Builds the local release archive
  2. Uploads it to the server
  3. Extracts it into a timestamped remote update directory
  4. Runs the packaged deploy.sh to update backend containers and Apache frontend files
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

require_cmd ssh
require_cmd scp
require_cmd tar

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

info "building latest release package"
"$ROOT_DIR/scripts/build_linux_x64.sh"

[[ -f "$ARCHIVE_PATH" ]] || die "release archive not found: $ARCHIVE_PATH"

warn "if this is an update deployment, the remote .env will be preserved"
warn "that means the bootstrap admin password printed during this build does not overwrite an existing deployment"
if [[ "$CLEAR_DATABASE_ONCE" == "true" ]]; then
  warn "CLEAR_DATABASE_ONCE=true, this deployment will wipe postgres data once and restart from a clean state"
fi

info "ensuring remote work directory exists: $REMOTE_WORKDIR"
ssh "$SSH_TARGET" "mkdir -p '$REMOTE_WORKDIR'"

info "uploading archive to $SSH_TARGET:$REMOTE_WORKDIR/$REMOTE_ARCHIVE_NAME"
scp "$ARCHIVE_PATH" "$SSH_TARGET:$REMOTE_WORKDIR/$REMOTE_ARCHIVE_NAME"

info "running remote deployment"
ssh "$SSH_TARGET" /bin/bash <<EOF
set -Eeuo pipefail

REMOTE_WORKDIR='$REMOTE_WORKDIR'
REMOTE_RELEASE_DIR='$REMOTE_RELEASE_DIR'
REMOTE_FRONTEND_DIR='$REMOTE_FRONTEND_DIR'
REMOTE_ARCHIVE_PATH='$REMOTE_WORKDIR/$REMOTE_ARCHIVE_NAME'
REMOTE_UPDATE_DIR='$REMOTE_UPDATE_DIR'
CLEAR_DATABASE_ONCE='$CLEAR_DATABASE_ONCE'

printf '[remote-deploy][INFO] remote workdir: %s\n' "\$REMOTE_WORKDIR"
printf '[remote-deploy][INFO] release dir: %s\n' "\$REMOTE_RELEASE_DIR"
printf '[remote-deploy][INFO] frontend dir: %s\n' "\$REMOTE_FRONTEND_DIR"
printf '[remote-deploy][INFO] update dir: %s\n' "\$REMOTE_UPDATE_DIR"
printf '[remote-deploy][INFO] clear database once: %s\n' "\$CLEAR_DATABASE_ONCE"

rm -rf "\$REMOTE_UPDATE_DIR"
mkdir -p "\$REMOTE_UPDATE_DIR"
tar -xzf "\$REMOTE_ARCHIVE_PATH" -C "\$REMOTE_UPDATE_DIR"
chmod +x "\$REMOTE_UPDATE_DIR/deploy.sh"
CLEAR_DATABASE_ONCE="\$CLEAR_DATABASE_ONCE" "\$REMOTE_UPDATE_DIR/deploy.sh" "\$REMOTE_RELEASE_DIR" "\$REMOTE_FRONTEND_DIR"
rm -f "\$REMOTE_ARCHIVE_PATH"
rm -rf "\$REMOTE_UPDATE_DIR"
printf '[remote-deploy][INFO] remote deployment finished successfully\n'
EOF

info "reading active bootstrap admin credentials from remote .env"
REMOTE_BOOTSTRAP_INFO="$(ssh "$SSH_TARGET" /bin/bash <<EOF
set -Eeuo pipefail
ENV_PATH='$REMOTE_RELEASE_DIR/.env'
if [[ ! -f "\$ENV_PATH" ]]; then
  exit 0
fi
awk -F= '
  \$1 == "LOCAL_ADMIN_EMAIL" { print "LOCAL_ADMIN_EMAIL=" substr(\$0, index(\$0, "=") + 1) }
  \$1 == "LOCAL_ADMIN_PASSWORD" { print "LOCAL_ADMIN_PASSWORD=" substr(\$0, index(\$0, "=") + 1) }
  \$1 == "LOCAL_ADMIN_NICKNAME" { print "LOCAL_ADMIN_NICKNAME=" substr(\$0, index(\$0, "=") + 1) }
' "\$ENV_PATH"
EOF
)"

info "deployment finished"
info "server: $SSH_TARGET"
info "release dir: $REMOTE_RELEASE_DIR"
info "frontend dir: $REMOTE_FRONTEND_DIR"
if [[ -n "$REMOTE_BOOTSTRAP_INFO" ]]; then
  printf '%s\n' "$REMOTE_BOOTSTRAP_INFO"
fi
warn "the credentials above are the current bootstrap admin values from the server .env"
warn "once the first admin finishes formal email binding, bootstrap login is closed and these credentials become invalid"
