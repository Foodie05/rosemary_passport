#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
deploy_script="$repo_root/scripts/deploy_auth_cruty_cn.sh"
interactive_script="$repo_root/scripts/configure_s3_and_deploy_auth_cruty_cn.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

bash -n "$deploy_script"
bash -n "$interactive_script"
interactive_help="$($interactive_script --help)"
grep -q 'Credentials never enter argv' <<<"$interactive_help"
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
grep -q "read -r -s -p 'AccessKey ID: '" "$interactive_script"
grep -q "read -r -s -p 'Secret AccessKey: '" "$interactive_script"
grep -Fq 'printf '\''%s\n%s\n'\'' "$access_key_id" "$secret_access_key" |' \
  "$interactive_script"
if grep -Eq 'export (AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY)|--access-key|--secret-key' \
  "$interactive_script"; then
  echo 'interactive deployment must not expose S3 credentials through argv or environment' >&2
  exit 1
fi
grep -q 'runtime env is missing or is a symlink' "$deploy_script"
grep -q 'every secret file mode must be 0400' "$deploy_script"
grep -q 'release archive contains a forbidden environment or secrets path' "$deploy_script"
grep -q 'mktemp -d' "$deploy_script"
grep -q -- '--no-same-owner' "$deploy_script"
grep -q 'valid RFC 3339 UTC timestamp' \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q 'finalize_legacy_refresh_sunset.sh' \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q 'legacy_env_transition.sh' \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q "rsync -a --checksum --delete" \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q "up -d --no-build --remove-orphans" \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q 'compose_source build' "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q 'NEW_RELEASE_TAG="release-\$TIMESTAMP"' \
  "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"
grep -q 'restore_cutover' "$repo_root/ops/deploy/auth_cruty_cn/deploy.sh"

grep -q '^    image: rosm-passport-backend:' \
  "$repo_root/ops/deploy/auth_cruty_cn/docker-compose.yml"

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
