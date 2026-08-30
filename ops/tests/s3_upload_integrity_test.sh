#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
uploader="$repo_root/ops/deploy/auth_cruty_cn/upload_s3_verified.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin"
printf 'encrypted backup fixture\n' >"$test_dir/source.enc"

cat >"$test_dir/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ " $* " == *' s3 cp '* ]]; then
  while [[ $# -gt 0 && "$1" != cp ]]; do shift; done
  source_file="${2:?}"
  while [[ $# -gt 0 && "$1" != --metadata ]]; do shift; done
  metadata="${2:?}"
  printf '%s\n' "${metadata#sha256=}" >"$UPLOAD_TEST_STATE/sha"
  if stat -c '%s' "$source_file" >/dev/null 2>&1; then
    stat -c '%s' "$source_file" >"$UPLOAD_TEST_STATE/size"
  else
    stat -f '%z' "$source_file" >"$UPLOAD_TEST_STATE/size"
  fi
  exit 0
fi
if [[ " $* " == *' s3api head-object '* && " $* " == *' Metadata.sha256 '* ]]; then
  if [[ -n "${UPLOAD_TEST_SHA_OVERRIDE:-}" ]]; then
    printf '%s\n' "$UPLOAD_TEST_SHA_OVERRIDE"
  else
    cat "$UPLOAD_TEST_STATE/sha"
  fi
  exit 0
fi
if [[ " $* " == *' s3api head-object '* && " $* " == *' ContentLength '* ]]; then
  cat "$UPLOAD_TEST_STATE/size"
  exit 0
fi
exit 2
EOF
chmod 0700 "$test_dir/bin/aws"
export PATH="$test_dir/bin:$PATH"
export UPLOAD_TEST_STATE="$test_dir"

"$uploader" "$test_dir/source.enc" https://s3.invalid backups \
  base/fixture.dump.enc >/dev/null

set +e
UPLOAD_TEST_SHA_OVERRIDE="$(printf '0%.0s' {1..64})" \
  "$uploader" "$test_dir/source.enc" https://s3.invalid backups \
    base/fixture.dump.enc >"$test_dir/bad.stdout" 2>"$test_dir/bad.stderr"
bad_status=$?
set -e
[[ "$bad_status" -eq 74 ]]
grep -q 'checksum metadata mismatch' "$test_dir/bad.stderr"

echo 'S3 upload integrity tests passed.'
