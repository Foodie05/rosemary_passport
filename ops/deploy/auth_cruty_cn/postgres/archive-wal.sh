#!/usr/bin/env bash
set -Eeuo pipefail

wal_path="${1:?wal path required}"
wal_name="${2:?wal name required}"
secret_dir="${PG_BACKUP_SECRETS_DIR:-/tmp/pg-backup-secrets}"
tmp_file="$(mktemp "/tmp/$wal_name.XXXXXXXX.enc")"
trap 'rm -f "$tmp_file"' EXIT
umask 077

AWS_ACCESS_KEY_ID="$(<"$secret_dir/s3_access_key_id")"
AWS_SECRET_ACCESS_KEY="$(<"$secret_dir/s3_secret_access_key")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${S3_REGION:-auto}"

openssl enc -aes-256-cbc -pbkdf2 -salt \
  -pass file:"$secret_dir/backup_encryption_key" \
  -in "$wal_path" -out "$tmp_file"
/usr/local/bin/upload-s3-verified.sh "$tmp_file" "$S3_ENDPOINT" \
  "$S3_BUCKET" "wal/$wal_name.enc"
