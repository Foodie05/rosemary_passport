#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${1:?target directory required}"
RUNTIME_ENV_FILE="${2:?runtime env required}"
SECRETS_DIR="${3:?secrets directory required}"
OBJECT_KEY="${4:?S3 object key required}"
RESTORE_DATABASE="${5:-rosm_passport_restore_$(date -u '+%Y%m%d%H%M%S')}"
[[ "$OBJECT_KEY" =~ ^base/[0-9]{8}T[0-9]{6}Z\.dump\.enc$ ]] || {
  echo "object key must match base/YYYYMMDDTHHMMSSZ.dump.enc" >&2
  exit 64
}
[[ "$RESTORE_DATABASE" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || {
  echo "restore database must be a safe lowercase PostgreSQL identifier" >&2
  exit 64
}
[[ "${ROSM_RESTORE_CONFIRM:-}" == "$RESTORE_DATABASE" ]] || {
  echo "Set ROSM_RESTORE_CONFIRM=$RESTORE_DATABASE to authorize restore." >&2
  exit 64
}
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for command in aws jq openssl pg_restore sha256sum awk docker; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "missing required command: $command" >&2
    exit 69
  }
done

read_env() { sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1; }
S3_ENDPOINT="$(read_env S3_ENDPOINT)"
S3_BUCKET="$(read_env S3_BUCKET)"
S3_REGION="$(read_env S3_REGION)"
POSTGRES_USER="$(read_env POSTGRES_USER)"
export AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"

manifest_key="${OBJECT_KEY%.dump.enc}.manifest.json"
aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://$S3_BUCKET/$OBJECT_KEY" "$TMP_DIR/database.dump.enc" --only-show-errors
aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://$S3_BUCKET/$manifest_key" "$TMP_DIR/manifest.json" --only-show-errors
manifest_object="$(jq -er '.object | strings' "$TMP_DIR/manifest.json")"
expected_checksum="$(jq -er '.sha256 | strings' "$TMP_DIR/manifest.json")"
[[ "$manifest_object" == "$OBJECT_KEY" ]] || {
  echo "backup manifest does not refer to the requested object" >&2
  exit 65
}
[[ "$expected_checksum" =~ ^[0-9a-f]{64}$ ]] || {
  echo "backup manifest contains an invalid checksum" >&2
  exit 65
}
actual_checksum="$(sha256sum "$TMP_DIR/database.dump.enc" | awk '{print $1}')"
[[ "$actual_checksum" == "$expected_checksum" ]] || {
  echo "encrypted backup checksum mismatch" >&2
  exit 65
}
openssl enc -d -aes-256-cbc -pbkdf2 \
  -pass file:"$SECRETS_DIR/backup_encryption_key" \
  -in "$TMP_DIR/database.dump.enc" -out "$TMP_DIR/database.dump"
pg_restore --list "$TMP_DIR/database.dump" >/dev/null

(
  cd "$TARGET_DIR"
  exists="$(docker compose --env-file "$RUNTIME_ENV_FILE" exec -T postgres \
    psql -U "$POSTGRES_USER" -d postgres -tAc \
      "select 1 from pg_database where datname = '$RESTORE_DATABASE'")"
  [[ -z "$exists" ]] || { echo "restore database already exists" >&2; exit 1; }
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T postgres \
    createdb -U "$POSTGRES_USER" "$RESTORE_DATABASE"
  docker compose --env-file "$RUNTIME_ENV_FILE" exec -T postgres \
    pg_restore -U "$POSTGRES_USER" -d "$RESTORE_DATABASE" \
      --no-owner --no-acl <"$TMP_DIR/database.dump"
)
printf 'restored_database=%s\n' "$RESTORE_DATABASE"
