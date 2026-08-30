#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
finalizer="$repo_root/ops/deploy/auth_cruty_cn/finalize_legacy_refresh_sunset.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin"
cat >"$test_dir/bin/date" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_DATE_OUTPUT:?}"
EOF
chmod 0700 "$test_dir/bin/date"

runtime_env="$test_dir/runtime.env"
cat >"$runtime_env" <<'EOF'
SERVER_BASE_URL=https://apiauth.cruty.cn
LEGACY_JSON_REFRESH_SUNSET_AT=PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS
S3_BUCKET=fixture
EOF
chmod 0640 "$runtime_env"

FAKE_DATE_OUTPUT=2026-09-13T12:00:00Z PATH="$test_dir/bin:$PATH" \
  "$finalizer" "$runtime_env" >/dev/null
grep -qx 'LEGACY_JSON_REFRESH_SUNSET_AT=2026-09-13T12:00:00Z' "$runtime_env"
[[ "$(stat -c '%a' "$runtime_env" 2>/dev/null || stat -f '%Lp' "$runtime_env")" == 640 ]]

first_hash="$(shasum -a 256 "$runtime_env" | awk '{print $1}')"
FAKE_DATE_OUTPUT=2027-01-01T00:00:00Z PATH="$test_dir/bin:$PATH" \
  "$finalizer" "$runtime_env" >/dev/null
[[ "$(shasum -a 256 "$runtime_env" | awk '{print $1}')" == "$first_hash" ]]

printf 'LEGACY_JSON_REFRESH_SUNSET_AT=invalid\n' >"$runtime_env"
invalid_hash="$(shasum -a 256 "$runtime_env" | awk '{print $1}')"
set +e
FAKE_DATE_OUTPUT=2026-09-13T12:00:00Z PATH="$test_dir/bin:$PATH" \
  "$finalizer" "$runtime_env" >/dev/null 2>"$test_dir/invalid.err"
invalid_status=$?
set -e
[[ "$invalid_status" -eq 78 ]]
[[ "$(shasum -a 256 "$runtime_env" | awk '{print $1}')" == "$invalid_hash" ]]
grep -q 'placeholder or a fixed UTC timestamp' "$test_dir/invalid.err"

printf '%s\n%s\n' \
  'LEGACY_JSON_REFRESH_SUNSET_AT=PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS' \
  'LEGACY_JSON_REFRESH_SUNSET_AT=PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS' \
  >"$runtime_env"
set +e
FAKE_DATE_OUTPUT=2026-09-13T12:00:00Z PATH="$test_dir/bin:$PATH" \
  "$finalizer" "$runtime_env" >/dev/null 2>"$test_dir/duplicate.err"
duplicate_status=$?
set -e
[[ "$duplicate_status" -eq 78 ]]
grep -q 'exactly one' "$test_dir/duplicate.err"

printf 'LEGACY_JSON_REFRESH_SUNSET_AT=2026-09-13T12:00:00Z\n' >"$runtime_env"
ln -s "$runtime_env" "$test_dir/runtime-link.env"
set +e
"$finalizer" "$test_dir/runtime-link.env" >/dev/null 2>"$test_dir/symlink.err"
symlink_status=$?
set -e
[[ "$symlink_status" -eq 78 ]]
grep -q 'non-symlink' "$test_dir/symlink.err"

echo 'Legacy refresh sunset finalization tests passed.'
