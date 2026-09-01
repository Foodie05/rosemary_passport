#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
preflight="$repo_root/ops/deploy/auth_cruty_cn/check_s3_storage.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/secrets"
printf 'fixture-access' >"$test_dir/secrets/s3_access_key_id"
printf 'fixture-secret' >"$test_dir/secrets/s3_secret_access_key"

cat >"$test_dir/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
query=''
while (($#)); do
  if [[ "$1" == --query ]]; then
    query="$2"
    break
  fi
  shift
done
case "$query" in
  Status) printf '%s\n' "${FAKE_VERSIONING:-Enabled}" ;;
  ObjectLockConfiguration.ObjectLockEnabled)
    [[ "${FAKE_OBJECT_LOCK_QUERY_FAIL:-false}" != true ]] || exit 2
    printf '%s\n' "${FAKE_OBJECT_LOCK_ENABLED:-Enabled}"
    ;;
  ObjectLockConfiguration.Rule.DefaultRetention.Mode) printf '%s\n' "${FAKE_LOCK_MODE:-COMPLIANCE}" ;;
  ObjectLockConfiguration.Rule.DefaultRetention.Days) printf '%s\n' "${FAKE_LOCK_DAYS:-30}" ;;
  ObjectLockConfiguration.Rule.DefaultRetention.Years) printf '%s\n' "${FAKE_LOCK_YEARS:-None}" ;;
  *) printf 'unexpected query: %s\n' "$query" >&2; exit 2 ;;
esac
EOF
chmod 0700 "$test_dir/bin/aws"
export PATH="$test_dir/bin:$PATH"

write_env() {
  cat >"$test_dir/runtime.env" <<EOF
S3_ENDPOINT=https://object-store.invalid
S3_BUCKET=backup-test
S3_REGION=auto
S3_REQUIRE_VERSIONING=$1
S3_REQUIRE_OBJECT_LOCK=$2
S3_OBJECT_LOCK_MIN_RETENTION_DAYS=30
EOF
}

expect_failure() {
  local expected="$1"
  shift
  set +e
  "$preflight" "$test_dir/runtime.env" "$test_dir/secrets" \
    >"$test_dir/out" 2>"$test_dir/err"
  status=$?
  set -e
  [[ "$status" -eq 78 ]]
  grep -q "$expected" "$test_dir/err"
}

write_env true true
FAKE_VERSIONING=Suspended expect_failure 'versioning must be enabled'
FAKE_OBJECT_LOCK_QUERY_FAIL=true expect_failure 'configuration cannot be queried'
FAKE_LOCK_DAYS=7 expect_failure 'at least 30 days'

FAKE_VERSIONING=Enabled FAKE_OBJECT_LOCK_ENABLED=Enabled \
  FAKE_LOCK_MODE=COMPLIANCE FAKE_LOCK_DAYS=30 \
  "$preflight" "$test_dir/runtime.env" "$test_dir/secrets" >/dev/null

write_env true false
FAKE_OBJECT_LOCK_QUERY_FAIL=true \
  "$preflight" "$test_dir/runtime.env" "$test_dir/secrets" >/dev/null

write_env false false
FAKE_VERSIONING=None FAKE_OBJECT_LOCK_QUERY_FAIL=true \
  "$preflight" "$test_dir/runtime.env" "$test_dir/secrets" >/dev/null

echo 'S3 storage preflight tests passed.'
