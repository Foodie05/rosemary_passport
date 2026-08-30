#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
transition="$repo_root/ops/deploy/auth_cruty_cn/legacy_env_transition.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

source_dir="$test_dir/source"
target_dir="$test_dir/release"
rollback_dir="$test_dir/rollback"
quarantine_dir="$test_dir/quarantine"
mkdir -p "$source_dir" "$target_dir/data/postgres" \
  "$target_dir/.deploy_backups" "$rollback_dir"

printf 'new-compose\n' >"$source_dir/docker-compose.yml"
printf 'new-code\n' >"$source_dir/new.txt"
printf 'old-compose\n' >"$target_dir/docker-compose.yml"
printf 'old-code\n' >"$target_dir/old.txt"
printf 'DATABASE_SENTINEL\n' >"$target_dir/data/postgres/sentinel"
printf 'BACKUP_SENTINEL\n' >"$target_dir/.deploy_backups/sentinel"
printf 'SECRET_SENTINEL\n' >"$target_dir/.env"
chmod 0600 "$target_dir/.env"

tar --exclude='./data' --exclude='./.deploy_backups' \
  --exclude='./.env' -C "$target_dir" -czf "$test_dir/old-release.tar.gz" .
quarantined="$($transition quarantine "$target_dir" "$quarantine_dir" 20260830-120000)"

rsync -a --checksum --delete --exclude='.env' --exclude='data/' \
  --exclude='.deploy_backups/' "$source_dir/" "$target_dir/"
printf 'release-20260830-120000\n' >"$target_dir/.release_tag"

[[ ! -e "$target_dir/.env" && ! -e "$target_dir/old.txt" ]]
grep -qx 'new-compose' "$target_dir/docker-compose.yml"
grep -qx 'new-code' "$target_dir/new.txt"
grep -qx 'DATABASE_SENTINEL' "$target_dir/data/postgres/sentinel"
grep -qx 'BACKUP_SENTINEL' "$target_dir/.deploy_backups/sentinel"

tar -C "$rollback_dir" -xzf "$test_dir/old-release.tar.gz"
rsync -a --checksum --delete --exclude='.env' --exclude='data/' \
  --exclude='.deploy_backups/' "$rollback_dir/" "$target_dir/"
$transition restore "$target_dir" "$quarantined"

[[ ! -e "$target_dir/new.txt" && ! -e "$target_dir/.release_tag" ]]
grep -qx 'old-compose' "$target_dir/docker-compose.yml"
grep -qx 'old-code' "$target_dir/old.txt"
grep -qx 'SECRET_SENTINEL' "$target_dir/.env"
grep -qx 'DATABASE_SENTINEL' "$target_dir/data/postgres/sentinel"
grep -qx 'BACKUP_SENTINEL' "$target_dir/.deploy_backups/sentinel"

echo 'Legacy cutover layout tests passed.'
