#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
umask 077
ENV_FILE="$test_dir/server.env"
log() { :; }

# Exercise the actual setup function without starting containers or opening UI.
sed -n '/^create_env_if_needed() {$/,/^create_admin_credential_if_needed() {$/p' \
  "$repo_root/scripts/local-up.sh" | sed '$d' >"$test_dir/setup.sh"
# shellcheck disable=SC1091
source "$test_dir/setup.sh"
create_env_if_needed
first_password="$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE")"
[[ "$first_password" =~ ^[0-9a-f]{64}$ ]]
create_env_if_needed
[[ "$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE")" == "$first_password" ]]
rm "$ENV_FILE"
create_env_if_needed
[[ "$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE")" != "$first_password" ]]

# Regenerating legacy PEM configuration must preserve the volume's password.
printf 'JWT_PRIVATE_KEY_PEM=legacy\nDB_PASSWORD=existing-volume-password\n' >"$ENV_FILE"
create_env_if_needed
[[ "$(sed -n 's/^DB_PASSWORD=//p' "$ENV_FILE")" == existing-volume-password ]]
grep -Fq '127.0.0.1:5432:5432' "$repo_root/docker-compose.yml"
if grep -Fq 'POSTGRES_PASSWORD: rosm_passport_dev' "$repo_root/docker-compose.yml"; then
  echo 'shared database password remains in Compose' >&2
  exit 1
fi
echo 'Local database configuration tests passed.'
