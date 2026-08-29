#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${1:?target directory required}"
RUNTIME_ENV_FILE="${2:?runtime env required}"
SECRETS_DIR="${3:?secrets directory required}"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

read_env() {
  sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1
}

S3_ENDPOINT="$(read_env S3_ENDPOINT)"
S3_BUCKET="$(read_env S3_BUCKET)"
S3_REGION="$(read_env S3_REGION)"
POSTGRES_DB="$(read_env POSTGRES_DB)"
POSTGRES_USER="$(read_env POSTGRES_USER)"
[[ -n "$S3_ENDPOINT" && -n "$S3_BUCKET" ]] || {
  echo "S3_ENDPOINT and S3_BUCKET are required" >&2
  exit 78
}

export AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"
versioning="$(aws --endpoint-url "$S3_ENDPOINT" s3api get-bucket-versioning \
  --bucket "$S3_BUCKET" --query Status --output text)"
[[ "$versioning" == "Enabled" ]] || {
  echo "S3 bucket versioning must be enabled" >&2
  exit 78
}

dump_path="$TMP_DIR/database.dump"
encrypted_path="$TMP_DIR/database.dump.enc"
object_key="base/$TIMESTAMP.dump.enc"

(
  cd "$TARGET_DIR"
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T postgres \
    pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
      --format=custom --no-owner --no-acl >"$dump_path"
)
pg_restore --list "$dump_path" >/dev/null
openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass file:"$SECRETS_DIR/backup_encryption_key" \
  -in "$dump_path" -out "$encrypted_path"
checksum="$(sha256sum "$encrypted_path" | awk '{print $1}')"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$encrypted_path" \
  "s3://$S3_BUCKET/$object_key" --only-show-errors
printf '{"created_at":"%s","object":"%s","sha256":"%s"}\n' \
  "$TIMESTAMP" "$object_key" "$checksum" >"$TMP_DIR/manifest.json"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$TMP_DIR/manifest.json" \
  "s3://$S3_BUCKET/base/$TIMESTAMP.manifest.json" --only-show-errors
printf 'backup_object=%s\n' "$object_key"
