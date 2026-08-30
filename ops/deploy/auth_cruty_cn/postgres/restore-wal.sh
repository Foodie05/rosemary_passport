#!/usr/bin/env bash
set -Eeuo pipefail

wal_name="${1:?WAL name required}"
destination="${2:?destination path required}"
secret_dir="${PG_BACKUP_SECRETS_DIR:-/tmp/pg-backup-secrets}"
temporary="${destination}.encrypted.$$"
trap 'unlink "$temporary" 2>/dev/null || true' EXIT

AWS_ACCESS_KEY_ID="$(<"$secret_dir/s3_access_key_id")"
AWS_SECRET_ACCESS_KEY="$(<"$secret_dir/s3_secret_access_key")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"

aws --endpoint-url "$S3_ENDPOINT" s3 cp \
  "s3://$S3_BUCKET/wal/$wal_name.enc" "$temporary" --only-show-errors
openssl enc -d -aes-256-cbc -pbkdf2 \
  -pass file:"$secret_dir/backup_encryption_key" \
  -in "$temporary" -out "$destination"
