#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${1:?target directory required}"
RUNTIME_ENV_FILE="${2:?runtime env required}"
SECRETS_DIR="${3:?secrets directory required}"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

read_env() { sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1; }
S3_ENDPOINT="$(read_env S3_ENDPOINT)"
S3_BUCKET="$(read_env S3_BUCKET)"
S3_REGION="$(read_env S3_REGION)"
POSTGRES_USER="$(read_env POSTGRES_USER)"
POSTGRES_DB="$(read_env POSTGRES_DB)"
export AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"
versioning="$(aws --endpoint-url "$S3_ENDPOINT" s3api get-bucket-versioning \
  --bucket "$S3_BUCKET" --query Status --output text)"
[[ "$versioning" == "Enabled" ]] || {
  echo "S3 bucket versioning must be enabled" >&2
  exit 78
}

archive="$TMP_DIR/audit-$TIMESTAMP.jsonl"
(
  cd "$TARGET_DIR"
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T passport_server \
    /app/bin/verify_audit_chain >&2
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T postgres \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -Atc \
      "select jsonb_build_object(
        'id', id, 'action', action, 'actor_id', actor_id,
        'actor_type', actor_type, 'resource_type', resource_type,
        'resource_id', resource_id, 'metadata', metadata,
        'ip_address', ip_address, 'created_at', created_at,
        'previous_hash', previous_hash, 'entry_hash', entry_hash,
        'chain_position', chain_position
      ) from audit_logs order by chain_position"
) >"$archive"

(
  cd "$TARGET_DIR"
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T passport_server \
    /app/bin/verify_audit_chain --stdin <"$archive"
)

openssl pkeyutl -sign -rawin \
  -inkey "$SECRETS_DIR/audit_signing.private.pem" \
  -in "$archive" -out "$archive.sig"
openssl pkeyutl -verify -rawin \
  -pubin -inkey "$SECRETS_DIR/audit_signing.public.pem" \
  -in "$archive" -sigfile "$archive.sig" >/dev/null
object_prefix="audit/$TIMESTAMP"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$archive" \
  "s3://$S3_BUCKET/$object_prefix/audit.jsonl" --only-show-errors
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$archive.sig" \
  "s3://$S3_BUCKET/$object_prefix/audit.jsonl.sig" --only-show-errors
aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "$SECRETS_DIR/audit_signing.public.pem" \
  "s3://$S3_BUCKET/$object_prefix/audit_signing.public.pem" --only-show-errors
printf 'audit_archive=s3://%s/%s\n' "$S3_BUCKET" "$object_prefix"
