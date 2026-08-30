#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
entrypoint="$repo_root/ops/deploy/auth_cruty_cn/backend-entrypoint.sh"

bash -n "$entrypoint"
grep -Fq 'exec gosu node:node /app/bin/passport_server' "$entrypoint"

required_runtime_files=(
  'DB_PASSWORD_FILE:$RUNTIME_SECRETS/db_password'
  'JWT_BINDING_KEY_FILE:$RUNTIME_SECRETS/jwt_binding_key'
  'EMAIL_CODE_HMAC_KEY_FILE:$RUNTIME_SECRETS/email_code_hmac_key'
  'ALIYUN_CAPTCHA_ACCESS_KEY_ID_FILE:$RUNTIME_SECRETS/aliyun_captcha_access_key_id'
  'ALIYUN_CAPTCHA_ACCESS_KEY_SECRET_FILE:$RUNTIME_SECRETS/aliyun_captcha_access_key_secret'
  'ALIYUN_ACCESS_KEY_ID_FILE:$RUNTIME_SECRETS/aliyun_access_key_id'
  'ALIYUN_ACCESS_KEY_SECRET_FILE:$RUNTIME_SECRETS/aliyun_access_key_secret'
  'SMTP_PASSWORD_FILE:$RUNTIME_SECRETS/smtp_password'
  'LOCAL_ADMIN_PASSWORD_FILE:$RUNTIME_SECRETS/local_admin_password'
  'HELPER_SHARED_KEY_FILE:$RUNTIME_SECRETS/helper_shared_key'
)
for mapping in "${required_runtime_files[@]}"; do
  variable="${mapping%%:*}"
  path="${mapping#*:}"
  grep -Fq "export $variable=\"$path\"" "$entrypoint" || {
    echo "missing non-root runtime secret mapping: $variable" >&2
    exit 1
  }
done

echo 'Backend entrypoint secret-path tests passed.'
