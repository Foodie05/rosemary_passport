#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=/run/secrets/rosm-passport
runtime_dir=/tmp/pg-backup-secrets
mkdir -p "$runtime_dir"
for name in s3_access_key_id s3_secret_access_key backup_encryption_key; do
  [[ -s "$source_dir/$name" ]] || { echo "missing backup secret: $name" >&2; exit 78; }
  cp "$source_dir/$name" "$runtime_dir/$name"
done
chmod 0700 "$runtime_dir"
chmod 0400 "$runtime_dir"/*
chown -R postgres:postgres "$runtime_dir"
export PG_BACKUP_SECRETS_DIR="$runtime_dir"
exec docker-entrypoint.sh "$@"
