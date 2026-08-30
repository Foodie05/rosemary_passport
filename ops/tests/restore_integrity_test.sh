#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
restore_script="$repo_root/ops/deploy/auth_cruty_cn/restore_from_s3.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

mkdir -p \
  "$test_dir/bin" "$test_dir/fixtures" "$test_dir/secrets" "$test_dir/target"
runtime_env="$test_dir/runtime.env"
cat >"$runtime_env" <<'EOF'
S3_ENDPOINT=http://object-store.invalid
S3_BUCKET=restore-test
S3_REGION=auto
POSTGRES_USER=restore_test
EOF
printf 'test-access-key\n' >"$test_dir/secrets/s3_access_key_id"
printf 'test-secret-key\n' >"$test_dir/secrets/s3_secret_access_key"
printf 'test-encryption-key\n' >"$test_dir/secrets/backup_encryption_key"

object_key='base/20260830T000000Z.dump.enc'
restore_database='rosm_restore_integrity_test'
printf 'valid encrypted fixture\n' >"$test_dir/fixtures/object"
expected_checksum="$(sha256sum "$test_dir/fixtures/object" | awk '{print $1}')"
jq -n \
  --arg object "$object_key" \
  --arg sha256 "$expected_checksum" \
  '{object:$object,sha256:$sha256}' >"$test_dir/fixtures/manifest.json"

cat >"$test_dir/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
while [[ $# -gt 0 && "$1" != cp ]]; do shift; done
[[ "${1:-}" == cp ]] || exit 2
source_object="${2:?source object missing}"
destination="${3:?destination missing}"
if [[ "$source_object" == *.manifest.json ]]; then
  cp "$RESTORE_TEST_FIXTURES/manifest.json" "$destination"
else
  cp "$RESTORE_TEST_FIXTURES/object" "$destination"
fi
EOF

cat >"$test_dir/bin/openssl" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
touch "$RESTORE_TEST_OPENSSL_MARKER"
input=''
output=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    -in) input="${2:?}"; shift 2 ;;
    -out) output="${2:?}"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$input" "$output"
EOF

cat >"$test_dir/bin/pg_restore" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$test_dir/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ " $* " == *' psql '* ]]; then
  exit 0
fi
if [[ " $* " == *' pg_restore '* ]]; then
  cat >/dev/null
fi
EOF
chmod 0700 "$test_dir/bin/"*

export PATH="$test_dir/bin:$PATH"
export RESTORE_TEST_FIXTURES="$test_dir/fixtures"
export RESTORE_TEST_OPENSSL_MARKER="$test_dir/openssl-called"
export ROSM_RESTORE_CONFIRM="$restore_database"

printf 'corrupted encrypted fixture\n' >"$test_dir/fixtures/object"
set +e
"$restore_script" "$test_dir/target" "$runtime_env" \
  "$test_dir/secrets" "$object_key" "$restore_database" \
  >"$test_dir/corrupt.stdout" 2>"$test_dir/corrupt.stderr"
corrupt_status=$?
set -e
[[ "$corrupt_status" -eq 65 ]] || {
  echo "expected corrupt backup status 65, got $corrupt_status" >&2
  exit 1
}
[[ ! -e "$RESTORE_TEST_OPENSSL_MARKER" ]] || {
  echo 'corrupt backup reached the decrypt step' >&2
  exit 1
}
grep -q 'checksum mismatch' "$test_dir/corrupt.stderr"

printf 'valid encrypted fixture\n' >"$test_dir/fixtures/object"
"$restore_script" "$test_dir/target" "$runtime_env" \
  "$test_dir/secrets" "$object_key" "$restore_database" \
  >"$test_dir/valid.stdout"
[[ -e "$RESTORE_TEST_OPENSSL_MARKER" ]]
grep -q "restored_database=$restore_database" "$test_dir/valid.stdout"

echo 'Restore integrity tests passed.'
