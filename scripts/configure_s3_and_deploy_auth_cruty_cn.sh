#!/usr/bin/env bash
set -Eeuo pipefail
set +x

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ssh_target="${1:-${SSH_TARGET:-root@cruty.cn}}"
remote_runtime_env="${REMOTE_RUNTIME_ENV:-/etc/rosm-passport/runtime.env}"
remote_secrets_dir="${REMOTE_SECRETS_DIR:-/etc/rosm-passport/secrets}"
s3_endpoint="${S3_ENDPOINT:-https://s3.bitiful.net}"
s3_bucket="${S3_BUCKET:-serverbak}"
s3_region="${S3_REGION:-cn-east-1}"
s3_prefix="${S3_PREFIX:-rosemary-passport/production}"

die() { printf '[interactive-deploy] %s\n' "$1" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
usage() {
  cat <<'EOF'
Usage:
  ./scripts/configure_s3_and_deploy_auth_cruty_cn.sh [ssh_target]

The script prompts for the S3 AccessKey ID and Secret AccessKey without echoing
them, writes them directly to root-only files over SSH standard input, configures
the Bitiful bucket under rosemary-passport/production/, and then runs the guarded
production deployment. Credentials never enter argv, environment variables,
shell history, Git, the release archive, or deployment logs.
EOF
}
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  usage
  exit 0
fi
[[ "$ssh_target" =~ ^[A-Za-z0-9._@:-]+$ ]] || die 'unsafe SSH target'
[[ "$remote_runtime_env" =~ ^/[A-Za-z0-9._/-]+$ ]] || die 'unsafe runtime env path'
[[ "$remote_secrets_dir" =~ ^/[A-Za-z0-9._/-]+$ ]] || die 'unsafe secrets path'
[[ "$s3_endpoint" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || die 'unsafe S3 endpoint'
[[ "$s3_bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || die 'unsafe S3 bucket'
[[ "$s3_region" =~ ^[A-Za-z0-9-]+$ ]] || die 'unsafe S3 region'
if [[ ! "$s3_prefix" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*[A-Za-z0-9]$ ]] \
  || [[ "$s3_prefix" == *//* || "/$s3_prefix/" == */../* || "/$s3_prefix/" == */./* ]]; then
  die 'unsafe S3 prefix'
fi
for command in ssh scp; do require_cmd "$command"; done

printf 'S3 endpoint: %s\nBucket: %s\nRegion: %s\nPrefix: %s\n' \
  "$s3_endpoint" "$s3_bucket" "$s3_region" "$s3_prefix"
IFS= read -r -s -p 'AccessKey ID: ' access_key_id </dev/tty
printf '\n' >/dev/tty
IFS= read -r -s -p 'Secret AccessKey: ' secret_access_key </dev/tty
printf '\n' >/dev/tty
[[ -n "$access_key_id" && -n "$secret_access_key" ]] || die 'credentials must not be empty'

ssh_options=(-o BatchMode=yes -o ConnectTimeout=10)
remote_stage="$(ssh "${ssh_options[@]}" "$ssh_target" mktemp -d /var/tmp/rosm-s3-config.XXXXXXXX)"
[[ "$remote_stage" =~ ^/var/tmp/rosm-s3-config\.[A-Za-z0-9]+$ ]] || die 'unsafe remote staging path'
cleanup() {
  access_key_id=''
  secret_access_key=''
  if [[ -n "${remote_stage:-}" ]]; then
    ssh "${ssh_options[@]}" "$ssh_target" /bin/bash -s -- "$remote_stage" \
      <<'REMOTE_CLEANUP' >/dev/null 2>&1 || true
set -Eeuo pipefail
stage="$1"
[[ "$stage" =~ ^/var/tmp/rosm-s3-config\.[A-Za-z0-9]+$ ]] || exit 1
find "$stage" -depth -mindepth 1 -delete
rmdir "$stage"
REMOTE_CLEANUP
  fi
}
trap cleanup EXIT

scp "${ssh_options[@]}" \
  "$root_dir/ops/deploy/auth_cruty_cn/configure_s3_credentials.sh" \
  "$root_dir/ops/deploy/auth_cruty_cn/s3_key.sh" \
  "$ssh_target:$remote_stage/"

printf '%s\n%s\n' "$access_key_id" "$secret_access_key" | \
  ssh "${ssh_options[@]}" "$ssh_target" /bin/bash \
    "$remote_stage/configure_s3_credentials.sh" \
    "$remote_runtime_env" "$remote_secrets_dir" \
    "$s3_endpoint" "$s3_bucket" "$s3_region" "$s3_prefix" false false
access_key_id=''
secret_access_key=''

"$root_dir/scripts/deploy_auth_cruty_cn.sh" "$ssh_target"
