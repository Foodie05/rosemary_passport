#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/apps/passport_server"
WEB_DIR="$ROOT_DIR/web"
TEMPLATE_DIR="$ROOT_DIR/ops/deploy/auth_cruty_cn"
RELEASE_ROOT="${RELEASE_ROOT:-$ROOT_DIR/.local/release}"
RELEASE_DIR="${RELEASE_DIR:-$RELEASE_ROOT/auth_cruty_cn_release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$RELEASE_ROOT/auth_cruty_cn_release.tar.gz}"

API_BASE="${API_BASE:-https://apiauth.cruty.cn}"
SERVER_BASE_URL="${SERVER_BASE_URL:-https://apiauth.cruty.cn}"
WEB_BASE_URL="${WEB_BASE_URL:-https://auth.cruty.cn}"
LOCAL_ADMIN_EMAIL="${LOCAL_ADMIN_EMAIL:-bootstrap-admin@rosm.local}"
LOCAL_ADMIN_NICKNAME="${LOCAL_ADMIN_NICKNAME:-Cruty Initial Admin}"
ALIYUN_CAPTCHA_PREFIX="${ALIYUN_CAPTCHA_PREFIX:-}"
ALIYUN_CAPTCHA_SCENE_ID="${ALIYUN_CAPTCHA_SCENE_ID:-}"
SMTP_HOST="${SMTP_HOST:-smtp.example.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-no-reply@cruty.cn}"
SMTP_FROM="${SMTP_FROM:-Cruty Auth <no-reply@cruty.cn>}"
SMTP_SECURE="${SMTP_SECURE:-true}"
TRUST_PROXY_HEADERS="${TRUST_PROXY_HEADERS:-false}"
TRUSTED_PROXY_IPS="${TRUSTED_PROXY_IPS:-127.0.0.1}"
ACCESS_TOKEN_TTL_SECONDS="${ACCESS_TOKEN_TTL_SECONDS:-900}"
FIRST_PARTY_REFRESH_TOKEN_TTL_SECONDS="${FIRST_PARTY_REFRESH_TOKEN_TTL_SECONDS:-43200}"
FIRST_PARTY_REMEMBERED_REFRESH_TOKEN_TTL_SECONDS="${FIRST_PARTY_REMEMBERED_REFRESH_TOKEN_TTL_SECONDS:-2592000}"
REFRESH_TOKEN_TTL_SECONDS="${REFRESH_TOKEN_TTL_SECONDS:-2592000}"
ARGON2_MEMORY_KB="${ARGON2_MEMORY_KB:-65536}"
ARGON2_ITERATIONS="${ARGON2_ITERATIONS:-3}"
ARGON2_PARALLELISM="${ARGON2_PARALLELISM:-1}"
EMAIL_CODE_TTL_SECONDS="${EMAIL_CODE_TTL_SECONDS:-300}"
OIDC_REQUIRE_PKCE="${OIDC_REQUIRE_PKCE:-true}"
POSTGRES_USER="${POSTGRES_USER:-rosm_passport}"
POSTGRES_DB="${POSTGRES_DB:-rosm_passport}"
JWT_ISSUER="${JWT_ISSUER:-apiauth.cruty.cn}"
JWT_AUDIENCE="${JWT_AUDIENCE:-cruty-apps}"
CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-https://auth.cruty.cn}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[build_linux_x64] missing command: $1" >&2
    exit 1
  fi
}

require_cmd dart
require_cmd dart_frog
require_cmd npm
require_cmd tar

echo "[build_linux_x64] preparing release directory: $RELEASE_DIR"
rm -rf "$RELEASE_DIR"
mkdir -p \
  "$RELEASE_DIR/backend/bin" \
  "$RELEASE_DIR/backend/scripts" \
  "$RELEASE_DIR/frontend" \
  "$RELEASE_DIR/postgres/init" \
  "$RELEASE_DIR/data/postgres"

echo "[build_linux_x64] building passport server routes"
(
  cd "$SERVER_DIR"
  dart pub get
  git diff --exit-code -- pubspec.lock
  npm ci
  dart_frog build
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    bin/server.dart \
    -o "$RELEASE_DIR/backend/bin/passport_server"
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    bin/seed_local_admin.dart \
    -o "$RELEASE_DIR/backend/bin/seed_local_admin"
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    bin/migrate.dart \
    -o "$RELEASE_DIR/backend/bin/migrate"
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    bin/verify_audit_chain.dart \
    -o "$RELEASE_DIR/backend/bin/verify_audit_chain"
)

cp -R "$SERVER_DIR/scripts/." "$RELEASE_DIR/backend/scripts/"
cp -R "$SERVER_DIR/node_modules" "$RELEASE_DIR/backend/node_modules"
cp "$SERVER_DIR/package.json" "$RELEASE_DIR/backend/package.json"
cp "$SERVER_DIR/package-lock.json" "$RELEASE_DIR/backend/package-lock.json"
cp "$TEMPLATE_DIR/backend-entrypoint.sh" "$RELEASE_DIR/backend/entrypoint.sh"

echo "[build_linux_x64] building web frontend"
(
  cd "$WEB_DIR"
  npm ci
  VITE_API_BASE="$API_BASE" \
  VITE_ALIYUN_CAPTCHA_PREFIX="$ALIYUN_CAPTCHA_PREFIX" \
  VITE_ALIYUN_CAPTCHA_SCENE_ID="$ALIYUN_CAPTCHA_SCENE_ID" \
  npm run build
)
cp -R "$WEB_DIR/dist" "$RELEASE_DIR/frontend/dist"
cp "$TEMPLATE_DIR/frontend.htaccess" "$RELEASE_DIR/frontend/dist/.htaccess"
cp "$TEMPLATE_DIR/Dockerfile.backend" "$RELEASE_DIR/Dockerfile.backend"
cp "$TEMPLATE_DIR/Dockerfile.postgres" "$RELEASE_DIR/Dockerfile.postgres"
cp "$TEMPLATE_DIR/Dockerfile.helper" "$RELEASE_DIR/Dockerfile.helper"
cp "$TEMPLATE_DIR/helper-entrypoint.sh" "$RELEASE_DIR/helper-entrypoint.sh"
cp "$TEMPLATE_DIR/gosu-setpriv.sh" "$RELEASE_DIR/gosu-setpriv.sh"
cp "$TEMPLATE_DIR/docker-compose.yml" "$RELEASE_DIR/docker-compose.yml"
cp "$TEMPLATE_DIR/deploy.sh" "$RELEASE_DIR/deploy.sh"
cp "$TEMPLATE_DIR/check_disk_capacity.sh" "$RELEASE_DIR/check_disk_capacity.sh"
cp "$TEMPLATE_DIR/check_host_capacity.sh" "$RELEASE_DIR/check_host_capacity.sh"
cp "$TEMPLATE_DIR/check_s3_storage.sh" "$RELEASE_DIR/check_s3_storage.sh"
cp "$TEMPLATE_DIR/upload_s3_verified.sh" "$RELEASE_DIR/upload_s3_verified.sh"
cp "$TEMPLATE_DIR/backup_to_s3.sh" "$RELEASE_DIR/backup_to_s3.sh"
cp "$TEMPLATE_DIR/physical_backup_to_s3.sh" "$RELEASE_DIR/physical_backup_to_s3.sh"
cp "$TEMPLATE_DIR/archive_audit_to_s3.sh" "$RELEASE_DIR/archive_audit_to_s3.sh"
cp "$TEMPLATE_DIR/restore_from_s3.sh" "$RELEASE_DIR/restore_from_s3.sh"
cp "$TEMPLATE_DIR/pitr_drill.sh" "$RELEASE_DIR/pitr_drill.sh"
cp "$TEMPLATE_DIR/record_sla_observation.sh" "$RELEASE_DIR/record_sla_observation.sh"
cp "$TEMPLATE_DIR/evaluate_sla_observation.sh" "$RELEASE_DIR/evaluate_sla_observation.sh"
cp "$TEMPLATE_DIR/install_systemd_units.sh" "$RELEASE_DIR/install_systemd_units.sh"
cp -R "$TEMPLATE_DIR/systemd" "$RELEASE_DIR/systemd"
cp "$TEMPLATE_DIR/provision_secrets.sh" "$RELEASE_DIR/provision_secrets.sh"
cp "$TEMPLATE_DIR/postgres/archive-wal.sh" "$RELEASE_DIR/postgres/archive-wal.sh"
cp "$TEMPLATE_DIR/postgres/restore-wal.sh" "$RELEASE_DIR/postgres/restore-wal.sh"
cp "$TEMPLATE_DIR/postgres/postgres-entrypoint.sh" "$RELEASE_DIR/postgres/postgres-entrypoint.sh"
cp "$TEMPLATE_DIR/README.md" "$RELEASE_DIR/README.md"
cp "$TEMPLATE_DIR/runtime.env.example" "$RELEASE_DIR/runtime.env.example"
cp "$ROOT_DIR/ops/postgres/init/001_init.sql" "$RELEASE_DIR/postgres/init/001_init.sql"

mkdir -p "$RELEASE_ROOT"
chmod +x "$RELEASE_DIR/deploy.sh" "$RELEASE_DIR/backup_to_s3.sh" \
  "$RELEASE_DIR/check_disk_capacity.sh" \
  "$RELEASE_DIR/check_host_capacity.sh" \
  "$RELEASE_DIR/check_s3_storage.sh" \
  "$RELEASE_DIR/upload_s3_verified.sh" \
  "$RELEASE_DIR/physical_backup_to_s3.sh" \
  "$RELEASE_DIR/archive_audit_to_s3.sh" \
  "$RELEASE_DIR/restore_from_s3.sh" "$RELEASE_DIR/postgres/archive-wal.sh" \
  "$RELEASE_DIR/pitr_drill.sh" "$RELEASE_DIR/postgres/restore-wal.sh" \
  "$RELEASE_DIR/record_sla_observation.sh" \
  "$RELEASE_DIR/evaluate_sla_observation.sh" \
  "$RELEASE_DIR/install_systemd_units.sh" \
  "$RELEASE_DIR/postgres/postgres-entrypoint.sh" \
  "$RELEASE_DIR/provision_secrets.sh" \
  "$RELEASE_DIR/helper-entrypoint.sh" \
  "$RELEASE_DIR/backend/entrypoint.sh"
tar -C "$RELEASE_DIR" -czf "$ARCHIVE_PATH" .

echo "[build_linux_x64] release ready"
echo "  directory: $RELEASE_DIR"
echo "  archive:   $ARCHIVE_PATH"
echo "  frontend:  frontend/dist -> serve with Apache at https://auth.cruty.cn"
echo "  backend:   https://apiauth.cruty.cn -> reverse proxy to 127.0.0.1:8091"
echo "  secrets:   provision /etc/rosm-passport/secrets before deployment"
