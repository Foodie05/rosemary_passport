#!/usr/bin/env bash
set -Eeuo pipefail

runtime_env_file="${1:?runtime env file required}"
placeholder='PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS'
temporary_file=''

die() {
  printf '[refresh-sunset] %s\n' "$1" >&2
  exit 78
}

cleanup() {
  if [[ -n "$temporary_file" && -f "$temporary_file" ]]; then
    unlink "$temporary_file"
  fi
}
trap cleanup EXIT

[[ "$runtime_env_file" = /* ]] || die 'runtime env path must be absolute'
[[ -f "$runtime_env_file" && ! -L "$runtime_env_file" ]] \
  || die 'runtime env must be a regular non-symlink file'

setting_count="$(grep -c '^LEGACY_JSON_REFRESH_SUNSET_AT=' "$runtime_env_file" || true)"
[[ "$setting_count" -eq 1 ]] || die 'runtime env must contain exactly one refresh sunset setting'
current_value="$(sed -n 's/^LEGACY_JSON_REFRESH_SUNSET_AT=//p' "$runtime_env_file")"

if [[ "$current_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  printf '[refresh-sunset] already fixed at %s\n' "$current_value"
  exit 0
fi
[[ "$current_value" == "$placeholder" ]] \
  || die 'refresh sunset must be the first-deployment placeholder or a fixed UTC timestamp'

sunset_at="$(date -u -d '+14 days' '+%Y-%m-%dT%H:%M:%SZ')" \
  || die 'could not calculate the 14-day UTC sunset'
[[ "$sunset_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
  || die 'calculated sunset is not an RFC 3339 UTC timestamp'

runtime_directory="$(dirname "$runtime_env_file")"
temporary_file="$(mktemp "$runtime_directory/.runtime.env.XXXXXXXX")"
awk -v replacement="LEGACY_JSON_REFRESH_SUNSET_AT=$sunset_at" '
  /^LEGACY_JSON_REFRESH_SUNSET_AT=/ { print replacement; next }
  { print }
' "$runtime_env_file" >"$temporary_file"

if stat -c '%a' "$runtime_env_file" >/dev/null 2>&1; then
  original_mode="$(stat -c '%a' "$runtime_env_file")"
  original_uid="$(stat -c '%u' "$runtime_env_file")"
  original_gid="$(stat -c '%g' "$runtime_env_file")"
else
  original_mode="$(stat -f '%Lp' "$runtime_env_file")"
  original_uid="$(stat -f '%u' "$runtime_env_file")"
  original_gid="$(stat -f '%g' "$runtime_env_file")"
fi
chmod "$original_mode" "$temporary_file"
temporary_uid="$(stat -c '%u' "$temporary_file" 2>/dev/null || stat -f '%u' "$temporary_file")"
temporary_gid="$(stat -c '%g' "$temporary_file" 2>/dev/null || stat -f '%g' "$temporary_file")"
if [[ "$temporary_uid:$temporary_gid" != "$original_uid:$original_gid" ]]; then
  [[ "$(id -u)" -eq 0 ]] || die 'cannot preserve runtime env ownership without root'
  chown "$original_uid:$original_gid" "$temporary_file"
fi
[[ "$(grep -c "^LEGACY_JSON_REFRESH_SUNSET_AT=$sunset_at$" "$temporary_file")" -eq 1 ]] \
  || die 'failed to write the fixed refresh sunset'
mv -f "$temporary_file" "$runtime_env_file"
temporary_file=''
printf '[refresh-sunset] fixed at %s\n' "$sunset_at"
