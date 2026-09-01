#!/usr/bin/env bash
set -Eeuo pipefail
set +x

runtime_env="${1:?runtime env required}"
secrets_dir="${2:?secrets directory required}"
s3_endpoint="${3:?S3 endpoint required}"
s3_bucket="${4:?S3 bucket required}"
s3_region="${5:?S3 region required}"
s3_prefix="${6:?S3 prefix required}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/deploy/auth_cruty_cn/s3_key.sh
source "$script_dir/s3_key.sh"

die() { printf '[s3-config] %s\n' "$1" >&2; exit 78; }
file_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
file_uid() { stat -c '%u' "$1" 2>/dev/null || stat -f '%u' "$1"; }

[[ -f "$runtime_env" && ! -L "$runtime_env" ]] || die 'runtime env is missing or unsafe'
[[ -d "$secrets_dir" && ! -L "$secrets_dir" ]] || die 'secrets directory is missing or unsafe'
[[ "$(file_uid "$runtime_env")" == "$(id -u)" ]] || die 'runtime env has the wrong owner'
[[ "$(file_uid "$secrets_dir")" == "$(id -u)" ]] || die 'secrets directory has the wrong owner'
case "$(file_mode "$runtime_env")" in 600|640) ;; *) die 'runtime env mode must be 0600 or 0640' ;; esac
[[ "$(file_mode "$secrets_dir")" == 700 ]] || die 'secrets directory mode must be 0700'
[[ "$s3_endpoint" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || die 'S3 endpoint must be HTTPS'
[[ "$s3_bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || die 'S3 bucket name is invalid'
[[ "$s3_region" =~ ^[A-Za-z0-9-]+$ ]] || die 'S3 region is invalid'
validate_s3_prefix "$s3_prefix" || die 'S3 prefix is invalid'

IFS= read -r access_key_id || die 'missing AccessKey ID on standard input'
IFS= read -r secret_access_key || die 'missing Secret AccessKey on standard input'
[[ -n "$access_key_id" && -n "$secret_access_key" ]] || die 'S3 credentials must not be empty'
[[ "$access_key_id" != *[[:space:]]* && "$secret_access_key" != *[[:space:]]* ]] \
  || die 'S3 credentials must not contain whitespace'

umask 077
ak_tmp="$(mktemp "$secrets_dir/.s3_access_key_id.XXXXXX")"
sk_tmp="$(mktemp "$secrets_dir/.s3_secret_access_key.XXXXXX")"
env_tmp="$(mktemp "$(dirname "$runtime_env")/.runtime.env.s3.XXXXXX")"
cleanup() {
  rm -f "${ak_tmp:-}" "${sk_tmp:-}" "${env_tmp:-}"
  access_key_id=''
  secret_access_key=''
}
trap cleanup EXIT

printf '%s' "$access_key_id" >"$ak_tmp"
printf '%s' "$secret_access_key" >"$sk_tmp"
chmod 0400 "$ak_tmp" "$sk_tmp"

awk -v endpoint="$s3_endpoint" -v bucket="$s3_bucket" \
  -v region="$s3_region" -v prefix="$s3_prefix" '
  BEGIN {
    values["S3_ENDPOINT"] = endpoint
    values["S3_BUCKET"] = bucket
    values["S3_REGION"] = region
    values["S3_PREFIX"] = prefix
  }
  /^[A-Za-z_][A-Za-z0-9_]*=/ {
    key = substr($0, 1, index($0, "=") - 1)
    if (key in values) {
      if (!seen[key]++) print key "=" values[key]
      next
    }
  }
  { print }
  END {
    order[1] = "S3_ENDPOINT"; order[2] = "S3_BUCKET"
    order[3] = "S3_REGION"; order[4] = "S3_PREFIX"
    for (i = 1; i <= 4; i++) if (!seen[order[i]]) print order[i] "=" values[order[i]]
  }
' "$runtime_env" >"$env_tmp"
chmod "$(file_mode "$runtime_env")" "$env_tmp"

mv -f "$ak_tmp" "$secrets_dir/s3_access_key_id"
ak_tmp=''
mv -f "$sk_tmp" "$secrets_dir/s3_secret_access_key"
sk_tmp=''
mv -f "$env_tmp" "$runtime_env"
env_tmp=''

printf '[s3-config] configured endpoint=%s bucket=%s region=%s prefix=%s\n' \
  "$s3_endpoint" "$s3_bucket" "$s3_region" "$s3_prefix"
