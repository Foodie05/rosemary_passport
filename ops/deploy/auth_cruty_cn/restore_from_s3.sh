#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_DIR="${1:?target directory required}"
RUNTIME_ENV_FILE="${2:?runtime env required}"
SECRETS_DIR="${3:?secrets directory required}"
OBJECT_KEY="${4:?S3 object key required}"
RESTORE_DATABASE="${5:-rosm_passport_restore_$(date -u '+%Y%m%d%H%M%S')}"
[[ "${ROSM_RESTORE_CONFIRM:-}" == "$RESTORE_DATABASE" ]] || {
  echo "Set ROSM_RESTORE_CONFIRM=$RESTORE_DATABASE to authorize restore." >&2
  exit 64
}
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

read_env() { sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1; }
S3_ENDPOINT="$(read_env S3_ENDPOINT)"
S3_BUCKET="$(read_env S3_BUCKET)"
S3_REGION="$(read_env S3_REGION)"
POSTGRES_USER="$(read_env POSTGRES_USER)"
export AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"

aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://$S3_BUCKET/$OBJECT_KEY" "$TMP_DIR/database.dump.enc" --only-show-errors
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
