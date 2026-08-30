#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
deploy_script="$repo_root/scripts/deploy_auth_cruty_cn.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

bash -n "$deploy_script"
help_text="$($deploy_script --help)"
grep -q 'has no database deletion mode' <<<"$help_text"
grep -q 'never creates, downloads, or prints secrets' <<<"$help_text"

for forbidden in CLEAR_DATABASE_ONCE LOCAL_ADMIN_PASSWORD REMOTE_BOOTSTRAP_INFO; do
  if grep -q "$forbidden" "$deploy_script"; then
    printf 'forbidden legacy deployment behavior remains: %s\n' "$forbidden" >&2
    exit 1
  fi
done

mkdir -p "$test_dir/bin"
for command in ssh scp tar; do
  cat >"$test_dir/bin/$command" <<'EOF'
#!/usr/bin/env bash
printf 'external command must not run for rejected input\n' >&2
exit 99
EOF
  chmod 0700 "$test_dir/bin/$command"
done

set +e
PATH="$test_dir/bin:$PATH" "$deploy_script" 'root@host;touch-bad' \
  >/dev/null 2>"$test_dir/invalid-target.err"
invalid_target_status=$?
PATH="$test_dir/bin:$PATH" "$deploy_script" root@example.invalid '../unsafe' \
  >/dev/null 2>"$test_dir/invalid-path.err"
invalid_path_status=$?
set -e
[[ "$invalid_target_status" -ne 0 && "$invalid_target_status" -ne 99 ]]
[[ "$invalid_path_status" -ne 0 && "$invalid_path_status" -ne 99 ]]
grep -q 'unsafe SSH target' "$test_dir/invalid-target.err"
grep -q 'unsafe or non-absolute remote path' "$test_dir/invalid-path.err"

grep -q 'BatchMode=yes' "$deploy_script"
grep -q 'runtime env is missing or is a symlink' "$deploy_script"
grep -q 'every secret file mode must be 0400' "$deploy_script"
grep -q 'release archive contains a forbidden environment or secrets path' "$deploy_script"
grep -q 'mktemp -d' "$deploy_script"
grep -q -- '--no-same-owner' "$deploy_script"

compose_file="$repo_root/ops/deploy/auth_cruty_cn/docker-compose.yml"
runtime_example="$repo_root/ops/deploy/auth_cruty_cn/runtime.env.example"
for setting in ALIYUN_ACCESS_KEY_ID_FILE ALIYUN_ACCESS_KEY_SECRET_FILE \
  ALIYUN_SMS_SIGN_NAME ALIYUN_SMS_TEMPLATE_CODE WEBAUTHN_ANDROID_ORIGINS; do
  grep -q "$setting" "$compose_file"
done
for setting in ALIYUN_SMS_SIGN_NAME ALIYUN_SMS_TEMPLATE_CODE \
  WEBAUTHN_ANDROID_ORIGINS; do
  grep -q "^$setting=" "$runtime_example"
done

echo 'Remote deployment safety tests passed.'
