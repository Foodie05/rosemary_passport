#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/.local/release/auth_cruty_cn_release.tar.gz}"
LOCAL_LEGAL_DIR="${ROSM_LOCAL_LEGAL_DIR:-$ROOT_DIR/.local/legal}"

SSH_TARGET="${1:-${SSH_TARGET:-root@cruty.cn}}"
REMOTE_RELEASE_DIR="${2:-${REMOTE_RELEASE_DIR:-/www/wwwroot/auth/auth_cruty_cn_release}}"
REMOTE_FRONTEND_DIR="${3:-${REMOTE_FRONTEND_DIR:-/www/wwwroot/auth.cruty.cn}}"
REMOTE_RUNTIME_ENV="${4:-${REMOTE_RUNTIME_ENV:-/etc/rosm-passport/runtime.env}}"
REMOTE_SECRETS_DIR="${5:-${REMOTE_SECRETS_DIR:-/etc/rosm-passport/secrets}}"
REMOTE_STAGE_ROOT="${REMOTE_STAGE_ROOT:-/var/tmp}"

log() { printf '[remote-deploy][%s] %s\n' "$1" "$2"; }
info() { log INFO "$1"; }
error() { log ERROR "$1" >&2; }
die() { error "$1"; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }
validate_path() {
  [[ "$1" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "unsafe or non-absolute remote path: $1"
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/deploy_auth_cruty_cn.sh [ssh_target] [release_dir] [frontend_dir] \
    [runtime_env] [secrets_dir]

Defaults:
  ssh_target    root@cruty.cn
  release_dir   /www/wwwroot/auth/auth_cruty_cn_release
  frontend_dir  /www/wwwroot/auth.cruty.cn
  runtime_env   /etc/rosm-passport/runtime.env
  secrets_dir   /etc/rosm-passport/secrets

The remote runtime configuration and secrets must already exist outside the
release directory. This command never creates, downloads, or prints secrets,
and it has no database deletion mode. Initial legal documents are read from
.local/legal by default and installed outside the release as root-only files.
EOF
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi

for command in ssh scp tar; do require_cmd "$command"; done
[[ "$SSH_TARGET" =~ ^[A-Za-z0-9._@:-]+$ ]] || die 'unsafe SSH target'
for path in "$REMOTE_RELEASE_DIR" "$REMOTE_FRONTEND_DIR" \
  "$REMOTE_RUNTIME_ENV" "$REMOTE_SECRETS_DIR" "$REMOTE_STAGE_ROOT"; do
  validate_path "$path"
done
for legal_file in terms-v1.md privacy-v1.md; do
  [[ -f "$LOCAL_LEGAL_DIR/$legal_file" && \
    ! -L "$LOCAL_LEGAL_DIR/$legal_file" && \
    -s "$LOCAL_LEGAL_DIR/$legal_file" ]] \
    || die "local legal document is missing, empty, or unsafe: $LOCAL_LEGAL_DIR/$legal_file"
done

info 'building credential-free release package'
"$ROOT_DIR/scripts/build_linux_x64.sh"
[[ -f "$ARCHIVE_PATH" ]] || die "release archive not found: $ARCHIVE_PATH"
archive_listing="$(tar -tzf "$ARCHIVE_PATH")"
if grep -Eq '(^|/)(\.env|secrets)(/|$)' <<<"$archive_listing"; then
  die 'release archive contains a forbidden environment or secrets path'
fi
if grep -Eq '(^/|(^|/)\.\.(/|$))' <<<"$archive_listing"; then
  die 'release archive contains an unsafe path'
fi

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10)

info 'validating root-owned remote configuration without reading its contents'
ssh "${ssh_options[@]}" "$SSH_TARGET" /bin/bash -s -- \
  "$REMOTE_RUNTIME_ENV" "$REMOTE_SECRETS_DIR" <<'REMOTE_PREFLIGHT'
set -Eeuo pipefail
runtime_env="$1"
secrets_dir="$2"
die() { printf '[remote-preflight] %s\n' "$1" >&2; exit 78; }

[[ "$(id -u)" == 0 ]] || die 'deployment must run as root on the target host'
[[ -f "$runtime_env" && ! -L "$runtime_env" ]] || die 'runtime env is missing or is a symlink'
[[ -d "$secrets_dir" && ! -L "$secrets_dir" ]] || die 'secrets directory is missing or is a symlink'
[[ "$(stat -c '%U' "$runtime_env")" == root ]] || die 'runtime env must be owned by root'
[[ "$(stat -c '%U' "$secrets_dir")" == root ]] || die 'secrets directory must be owned by root'
case "$(stat -c '%a' "$runtime_env")" in
  600|640) ;;
  *) die 'runtime env mode must be 0600 or 0640' ;;
esac
[[ "$(stat -c '%a' "$secrets_dir")" == 700 ]] || die 'secrets directory mode must be 0700'

while IFS= read -r secret_directory; do
  [[ ! -L "$secret_directory" ]] || die 'secret directories must not be symlinks'
  [[ "$(stat -c '%U' "$secret_directory")" == root ]] || die 'every secret directory must be owned by root'
  [[ "$(stat -c '%a' "$secret_directory")" == 700 ]] || die 'every secret directory mode must be 0700'
done < <(find "$secrets_dir" -type d -print)
while IFS= read -r secret_file; do
  [[ ! -L "$secret_file" ]] || die 'secret files must not be symlinks'
  [[ "$(stat -c '%U' "$secret_file")" == root ]] || die 'every secret file must be owned by root'
  [[ "$(stat -c '%a' "$secret_file")" == 400 ]] || die 'every secret file mode must be 0400'
done < <(find "$secrets_dir" -type f -print)
REMOTE_PREFLIGHT

info 'creating an unpredictable private remote staging directory'
REMOTE_STAGE_DIR="$(ssh "${ssh_options[@]}" "$SSH_TARGET" \
  mktemp -d "$REMOTE_STAGE_ROOT/rosm-passport-deploy.XXXXXXXX")"
validate_path "$REMOTE_STAGE_DIR"
cleanup_remote_stage() {
  if [[ -n "${REMOTE_STAGE_DIR:-}" ]]; then
    ssh "${ssh_options[@]}" "$SSH_TARGET" /bin/bash -s -- \
      "$REMOTE_STAGE_DIR" <<'REMOTE_CLEANUP' >/dev/null 2>&1 || true
set -Eeuo pipefail
stage_dir="$1"
if [[ -d "$stage_dir" ]]; then
  find "$stage_dir" -depth -mindepth 1 -delete
  rmdir "$stage_dir"
fi
REMOTE_CLEANUP
  fi
}
trap cleanup_remote_stage EXIT

info 'uploading credential-free release archive'
scp "${ssh_options[@]}" "$ARCHIVE_PATH" \
  "$SSH_TARGET:$REMOTE_STAGE_DIR/release.tar.gz"
info 'uploading private initial legal documents outside the release archive'
scp "${ssh_options[@]}" "$LOCAL_LEGAL_DIR/terms-v1.md" \
  "$SSH_TARGET:$REMOTE_STAGE_DIR/legal-terms-v1.md"
scp "${ssh_options[@]}" "$LOCAL_LEGAL_DIR/privacy-v1.md" \
  "$SSH_TARGET:$REMOTE_STAGE_DIR/legal-privacy-v1.md"

info 'running guarded remote deployment'
ssh "${ssh_options[@]}" "$SSH_TARGET" /bin/bash -s -- \
  "$REMOTE_STAGE_DIR" "$REMOTE_RELEASE_DIR" "$REMOTE_FRONTEND_DIR" \
  "$REMOTE_RUNTIME_ENV" "$REMOTE_SECRETS_DIR" <<'REMOTE_DEPLOY'
set -Eeuo pipefail
umask 077
stage_dir="$1"
release_dir="$2"
frontend_dir="$3"
runtime_env="$4"
secrets_dir="$5"
cleanup() {
  if [[ -d "$stage_dir" ]]; then
    find "$stage_dir" -depth -mindepth 1 -delete || true
    rmdir "$stage_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT

legal_dir="$secrets_dir/legal"
mkdir -p "$legal_dir"
chown root:root "$legal_dir"
chmod 0700 "$legal_dir"
for legal_name in terms privacy; do
  source_file="$stage_dir/legal-$legal_name-v1.md"
  target_file="$legal_dir/$legal_name-v1.md"
  [[ -f "$source_file" && ! -L "$source_file" && -s "$source_file" ]] \
    || { printf '[remote-deploy] invalid staged legal document: %s\n' "$legal_name" >&2; exit 78; }
  temporary_file="$(mktemp "$legal_dir/.$legal_name-v1.XXXXXXXX")"
  cp "$source_file" "$temporary_file"
  chown root:root "$temporary_file"
  chmod 0400 "$temporary_file"
  mv -f "$temporary_file" "$target_file"
done

mkdir -p "$stage_dir/release"
tar --no-same-owner -xzf "$stage_dir/release.tar.gz" -C "$stage_dir/release"
chmod 0755 "$stage_dir/release/deploy.sh"
"$stage_dir/release/deploy.sh" \
  "$release_dir" "$frontend_dir" "$runtime_env" "$secrets_dir"
REMOTE_DEPLOY

info 'deployment completed; no credentials were read or printed'
info "server: $SSH_TARGET"
info "release directory: $REMOTE_RELEASE_DIR"
info "frontend directory: $REMOTE_FRONTEND_DIR"
