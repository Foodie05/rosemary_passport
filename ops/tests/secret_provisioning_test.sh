#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
provisioner="$repo_root/ops/deploy/auth_cruty_cn/provision_secrets.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
legacy_env="$test_dir/legacy.env"
secrets_dir="$test_dir/secrets"

cat >"$legacy_env" <<'EOF'
POSTGRES_PASSWORD=fixture-db-password
JWT_BINDING_KEY=fixture-jwt-binding
EMAIL_CODE_HMAC_KEY=fixture-email-hmac
DATA_ENCRYPTION_KEY=fixture-data-key
SMTP_PASSWORD=fixture-smtp-password
ALIYUN_ACCESS_KEY_ID=fixture-legacy-aliyun-id
ALIYUN_ACCESS_KEY_SECRET=fixture-legacy-aliyun-secret
LOCAL_ADMIN_PASSWORD=fixture-local-admin
EOF
chmod 0600 "$legacy_env"

output="$($provisioner "$secrets_dir" "$legacy_env")"
[[ "$output" == "Secrets provisioned at $secrets_dir. Fill the S3 credential files before deployment." ]]

[[ "$(<"$secrets_dir/db_password")" == fixture-db-password ]]
[[ "$(<"$secrets_dir/aliyun_captcha_access_key_id")" == fixture-legacy-aliyun-id ]]
[[ "$(<"$secrets_dir/aliyun_captcha_access_key_secret")" == fixture-legacy-aliyun-secret ]]
[[ "$(<"$secrets_dir/data_keys/data-v1.key")" == fixture-data-key ]]
[[ ! -s "$secrets_dir/s3_access_key_id" && ! -s "$secrets_dir/s3_secret_access_key" ]]
[[ "$(stat -f '%Lp' "$secrets_dir" 2>/dev/null || stat -c '%a' "$secrets_dir")" == 700 ]]
while IFS= read -r secret_file; do
  mode="$(stat -f '%Lp' "$secret_file" 2>/dev/null || stat -c '%a' "$secret_file")"
  [[ "$mode" == 400 ]]
done < <(find "$secrets_dir" -type f -print)

printf 'changed' >"$legacy_env"
$provisioner "$secrets_dir" "$legacy_env" >/dev/null
[[ "$(<"$secrets_dir/db_password")" == fixture-db-password ]]

echo 'Secret provisioning compatibility tests passed.'
