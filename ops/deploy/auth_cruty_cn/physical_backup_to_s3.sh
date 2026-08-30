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
[[ -n "$S3_ENDPOINT" && -n "$S3_BUCKET" && -n "$POSTGRES_USER" ]] || {
  echo "S3 and PostgreSQL settings are required" >&2
  exit 78
}

export AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"
"$(dirname "${BASH_SOURCE[0]}")/check_s3_storage.sh" "$RUNTIME_ENV_FILE" "$SECRETS_DIR"

base_path="$TMP_DIR/base.tar"
encrypted_path="$TMP_DIR/base.tar.enc"
object_key="physical/$TIMESTAMP/base.tar.enc"
compose_env_file="$RUNTIME_ENV_FILE"
if [[ -e "$TARGET_DIR/.env" ]]; then
  [[ -f "$TARGET_DIR/.env" && ! -L "$TARGET_DIR/.env" ]] || {
    echo "legacy .env must be a regular non-symlink file" >&2
    exit 78
  }
  legacy_mode="$(stat -c '%a' "$TARGET_DIR/.env" 2>/dev/null || stat -f '%Lp' "$TARGET_DIR/.env")"
  legacy_uid="$(stat -c '%u' "$TARGET_DIR/.env" 2>/dev/null || stat -f '%u' "$TARGET_DIR/.env")"
  [[ "$legacy_mode" == 600 && "$legacy_uid" == "$(id -u)" ]] || {
    echo "legacy .env must be mode 0600 and owned by the backup user" >&2
    exit 78
  }
  compose_env_file="$TARGET_DIR/.env"
fi
project_name="$(basename "$TARGET_DIR")"
[[ "$project_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || {
  echo "target directory name is not a safe Compose project" >&2
  exit 78
}
(
  cd "$TARGET_DIR"
  docker compose --project-name "$project_name" --env-file "$compose_env_file" \
    exec -T postgres \
    pg_basebackup -U "$POSTGRES_USER" -D - --format=tar --wal-method=fetch \
      --checkpoint=fast >"$base_path"
)
tar -tf "$base_path" >/dev/null
openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass file:"$SECRETS_DIR/backup_encryption_key" \
  -in "$base_path" -out "$encrypted_path"
checksum="$(sha256sum "$encrypted_path" | awk '{print $1}')"
uploader="$(dirname "${BASH_SOURCE[0]}")/upload_s3_verified.sh"
"$uploader" "$encrypted_path" "$S3_ENDPOINT" "$S3_BUCKET" "$object_key"
printf '{"created_at":"%s","object":"%s","sha256":"%s","wal_prefix":"wal/"}\n' \
  "$TIMESTAMP" "$object_key" "$checksum" >"$TMP_DIR/manifest.json"
"$uploader" "$TMP_DIR/manifest.json" "$S3_ENDPOINT" "$S3_BUCKET" \
  "physical/$TIMESTAMP/manifest.json"
"$uploader" "$TMP_DIR/manifest.json" "$S3_ENDPOINT" "$S3_BUCKET" \
  "physical/latest.json"
printf 'physical_backup_object=%s\n' "$object_key"
