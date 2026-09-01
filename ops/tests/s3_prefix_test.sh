#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=ops/deploy/auth_cruty_cn/s3_key.sh
source "$repo_root/ops/deploy/auth_cruty_cn/s3_key.sh"
configurator="$repo_root/ops/deploy/auth_cruty_cn/configure_s3_credentials.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

[[ "$(s3_key 'rosemary-passport/production' 'base/fixture.dump.enc')" \
  == 'rosemary-passport/production/base/fixture.dump.enc' ]]
[[ "$(s3_relative_key 'rosemary-passport/production' \
  'rosemary-passport/production/wal/0001.enc')" == 'wal/0001.enc' ]]
for invalid in /leading trailing/ double//slash path/../escape path/./dot; do
  if validate_s3_prefix "$invalid"; then
    printf 'unsafe prefix accepted: %s\n' "$invalid" >&2
    exit 1
  fi
done

mkdir -m 0700 "$test_dir/secrets"
runtime_env="$test_dir/runtime.env"
printf '%s\n' \
  'SERVER_BASE_URL=https://example.invalid' \
  'S3_ENDPOINT=https://old.invalid' \
  'S3_BUCKET=old-bucket' \
  'S3_REGION=old-region' >"$runtime_env"
chmod 0600 "$runtime_env"

stdout="$test_dir/stdout"
stderr="$test_dir/stderr"
printf '%s\n%s\n' 'fixture-access-key' 'fixture-secret-key' | \
  "$configurator" "$runtime_env" "$test_dir/secrets" \
    'https://s3.bitiful.net' 'serverbak' 'cn-east-1' \
    'rosemary-passport/production' >"$stdout" 2>"$stderr"

grep -qx 'S3_ENDPOINT=https://s3.bitiful.net' "$runtime_env"
grep -qx 'S3_BUCKET=serverbak' "$runtime_env"
grep -qx 'S3_REGION=cn-east-1' "$runtime_env"
grep -qx 'S3_PREFIX=rosemary-passport/production' "$runtime_env"
[[ "$(grep -c '^S3_' "$runtime_env")" -eq 4 ]]
[[ "$(cat "$test_dir/secrets/s3_access_key_id")" == 'fixture-access-key' ]]
[[ "$(cat "$test_dir/secrets/s3_secret_access_key")" == 'fixture-secret-key' ]]
[[ "$(stat -c '%a' "$test_dir/secrets/s3_access_key_id" 2>/dev/null \
  || stat -f '%Lp' "$test_dir/secrets/s3_access_key_id")" == 400 ]]
! grep -q 'fixture-access-key\|fixture-secret-key' "$stdout" "$stderr"

echo 'S3 prefix and credential configuration tests passed.'
