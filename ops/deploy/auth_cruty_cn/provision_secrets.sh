#!/usr/bin/env bash
set -Eeuo pipefail

SECRETS_DIR="${1:-/etc/rosm-passport/secrets}"
LEGACY_ENV="${2:-}"
umask 077
mkdir -p "$SECRETS_DIR/jwt" "$SECRETS_DIR/data_keys"

legacy_value() {
  [[ -n "$LEGACY_ENV" && -f "$LEGACY_ENV" ]] || return 0
  sed -n "s/^$1=//p" "$LEGACY_ENV" | tail -n 1
}

write_secret() {
  local path="$1" value="$2"
  [[ -f "$path" ]] && return 0
  printf '%s' "$value" >"$path"
  chmod 0400 "$path"
}

random_secret() { openssl rand -base64 "$1" | tr -d '\n'; }
legacy_or_random() {
  local name="$1" bytes="$2" value
  value="$(legacy_value "$name")"
  if [[ -n "$value" ]]; then
    printf '%s' "$value"
  else
    random_secret "$bytes"
  fi
}

if [[ ! -s "$SECRETS_DIR/db_password" ]]; then
  db_password="$(legacy_value POSTGRES_PASSWORD || true)"
  if [[ -z "$db_password" ]]; then
    db_password="$(random_secret 32)"
  fi
  [[ ! -e "$SECRETS_DIR/db_password" ]] || \
    chmod 0600 "$SECRETS_DIR/db_password"
  printf '%s' "$db_password" >"$SECRETS_DIR/db_password"
  chmod 0400 "$SECRETS_DIR/db_password"
fi

private_b64="$(legacy_value JWT_PRIVATE_KEY_PEM_B64 || true)"
public_b64="$(legacy_value JWT_PUBLIC_KEY_PEM_B64 || true)"
if [[ ! -f "$SECRETS_DIR/jwt/signing-v1.private.pem" ]]; then
  if [[ -n "$private_b64" && -n "$public_b64" ]]; then
    printf '%s' "$private_b64" | openssl base64 -d -A \
      >"$SECRETS_DIR/jwt/signing-v1.private.pem"
    printf '%s' "$public_b64" | openssl base64 -d -A \
      >"$SECRETS_DIR/jwt/signing-v1.public.pem"
  else
    openssl genrsa -out "$SECRETS_DIR/jwt/signing-v1.private.pem" 3072
    openssl rsa -in "$SECRETS_DIR/jwt/signing-v1.private.pem" -pubout \
      -out "$SECRETS_DIR/jwt/signing-v1.public.pem"
  fi
fi

write_secret "$SECRETS_DIR/jwt_binding_key" \
  "$(legacy_or_random JWT_BINDING_KEY 64)"
write_secret "$SECRETS_DIR/email_code_hmac_key" \
  "$(legacy_or_random EMAIL_CODE_HMAC_KEY 64)"
write_secret "$SECRETS_DIR/data_keys/data-v1.key" \
  "$(legacy_or_random DATA_ENCRYPTION_KEY 32)"
write_secret "$SECRETS_DIR/smtp_password" \
  "$(legacy_value SMTP_PASSWORD || true)"
write_secret "$SECRETS_DIR/aliyun_captcha_access_key_id" \
  "$(legacy_value ALIYUN_CAPTCHA_ACCESS_KEY_ID || true)"
write_secret "$SECRETS_DIR/aliyun_captcha_access_key_secret" \
  "$(legacy_value ALIYUN_CAPTCHA_ACCESS_KEY_SECRET || true)"
write_secret "$SECRETS_DIR/local_admin_password" \
  "$(legacy_or_random LOCAL_ADMIN_PASSWORD 24)"
write_secret "$SECRETS_DIR/backup_encryption_key" "$(random_secret 48)"
write_secret "$SECRETS_DIR/helper_shared_key" "$(random_secret 48)"
write_secret "$SECRETS_DIR/s3_access_key_id" ""
write_secret "$SECRETS_DIR/s3_secret_access_key" ""

if [[ ! -f "$SECRETS_DIR/audit_signing.private.pem" ]]; then
  openssl genpkey -algorithm Ed25519 \
    -out "$SECRETS_DIR/audit_signing.private.pem"
  openssl pkey -in "$SECRETS_DIR/audit_signing.private.pem" -pubout \
    -out "$SECRETS_DIR/audit_signing.public.pem"
fi

find "$SECRETS_DIR" -type d -exec chmod 0700 {} +
find "$SECRETS_DIR" -type f -exec chmod 0400 {} +
printf 'Secrets provisioned at %s. Fill the S3 credential files before deployment.\n' \
  "$SECRETS_DIR"
