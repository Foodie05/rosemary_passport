#!/usr/bin/env bash
set -euo pipefail

cd /app

SOURCE_SECRETS=/run/secrets/rosm-passport
RUNTIME_SECRETS=/tmp/rosm-passport-secrets
[[ -d "$SOURCE_SECRETS" ]] || {
  echo "[passport-server] secret mount is missing" >&2
  exit 78
}
mkdir -p "$RUNTIME_SECRETS"
cp -R "$SOURCE_SECRETS/." "$RUNTIME_SECRETS/"
find "$RUNTIME_SECRETS" -type d -exec chmod 700 {} +
find "$RUNTIME_SECRETS" -type f -exec chmod 400 {} +
chown -R node:node "$RUNTIME_SECRETS"

export DB_PASSWORD_FILE="$RUNTIME_SECRETS/db_password"
export JWT_SIGNING_KEYS_DIR="$RUNTIME_SECRETS/jwt"
export JWT_BINDING_KEY_FILE="$RUNTIME_SECRETS/jwt_binding_key"
export EMAIL_CODE_HMAC_KEY_FILE="$RUNTIME_SECRETS/email_code_hmac_key"
export DATA_ENCRYPTION_KEYS_DIR="$RUNTIME_SECRETS/data_keys"
export DATA_ENCRYPTION_KEY_FILE="$RUNTIME_SECRETS/data_keys/${DATA_ENCRYPTION_ACTIVE_KID:-data-v1}.key"
export LEGAL_INITIAL_TERMS_FILE="$RUNTIME_SECRETS/legal/terms-v1.md"
export LEGAL_INITIAL_PRIVACY_FILE="$RUNTIME_SECRETS/legal/privacy-v1.md"
export ALIYUN_CAPTCHA_ACCESS_KEY_ID_FILE="$RUNTIME_SECRETS/aliyun_captcha_access_key_id"
export ALIYUN_CAPTCHA_ACCESS_KEY_SECRET_FILE="$RUNTIME_SECRETS/aliyun_captcha_access_key_secret"
export ALIYUN_ACCESS_KEY_ID_FILE="$RUNTIME_SECRETS/aliyun_access_key_id"
export ALIYUN_ACCESS_KEY_SECRET_FILE="$RUNTIME_SECRETS/aliyun_access_key_secret"
export SMTP_PASSWORD_FILE="$RUNTIME_SECRETS/smtp_password"
export LOCAL_ADMIN_PASSWORD_FILE="$RUNTIME_SECRETS/local_admin_password"
export HELPER_SHARED_KEY_FILE="$RUNTIME_SECRETS/helper_shared_key"

echo "[passport-server] applying backward-compatible database migrations..."
gosu node:node /app/bin/migrate

if [[ -n "${LOCAL_ADMIN_EMAIL:-}" && -n "${LOCAL_ADMIN_PASSWORD_FILE:-}" ]]; then
  echo "[passport-server] checking bootstrap admin configuration..."
  gosu node:node /app/bin/seed_local_admin || true
fi

exec gosu node:node /app/bin/passport_server
