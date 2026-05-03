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
LOCAL_ADMIN_PASSWORD="${LOCAL_ADMIN_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n' | cut -c1-20)}"
LOCAL_ADMIN_NICKNAME="${LOCAL_ADMIN_NICKNAME:-Cruty Initial Admin}"
HCAPTCHA_SITEKEY="${HCAPTCHA_SITEKEY:-}"
HCAPTCHA_SECRET="${HCAPTCHA_SECRET:-}"
SMTP_HOST="${SMTP_HOST:-smtp.example.com}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-no-reply@cruty.cn}"
SMTP_PASSWORD="${SMTP_PASSWORD:-change_me}"
SMTP_FROM="${SMTP_FROM:-Cruty Auth <no-reply@cruty.cn>}"
SMTP_SECURE="${SMTP_SECURE:-true}"
TRUST_PROXY_HEADERS="${TRUST_PROXY_HEADERS:-false}"
TRUSTED_PROXY_IPS="${TRUSTED_PROXY_IPS:-127.0.0.1}"
ACCESS_TOKEN_TTL_SECONDS="${ACCESS_TOKEN_TTL_SECONDS:-900}"
REFRESH_TOKEN_TTL_SECONDS="${REFRESH_TOKEN_TTL_SECONDS:-2592000}"
ARGON2_MEMORY_KB="${ARGON2_MEMORY_KB:-65536}"
ARGON2_ITERATIONS="${ARGON2_ITERATIONS:-3}"
ARGON2_PARALLELISM="${ARGON2_PARALLELISM:-1}"
EMAIL_CODE_TTL_SECONDS="${EMAIL_CODE_TTL_SECONDS:-300}"
OIDC_REQUIRE_PKCE="${OIDC_REQUIRE_PKCE:-true}"
POSTGRES_USER="${POSTGRES_USER:-rosm_passport}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(openssl rand -base64 24 | tr -d '\n' | cut -c1-24)}"
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
require_cmd openssl
require_cmd tar
require_cmd base64

generate_rsa_keypair_b64() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  openssl genrsa -out "$tmpdir/private.pem" 2048 >/dev/null 2>&1
  openssl rsa -in "$tmpdir/private.pem" -pubout -out "$tmpdir/public.pem" >/dev/null 2>&1
  JWT_PRIVATE_KEY_PEM_B64="$(base64 <"$tmpdir/private.pem" | tr -d '\n')"
  JWT_PUBLIC_KEY_PEM_B64="$(base64 <"$tmpdir/public.pem" | tr -d '\n')"
  rm -rf "$tmpdir"
}

JWT_BINDING_KEY="${JWT_BINDING_KEY:-$(openssl rand -base64 64 | tr -d '\n')}"
EMAIL_CODE_HMAC_KEY="${EMAIL_CODE_HMAC_KEY:-$(openssl rand -base64 64 | tr -d '\n')}"
DATA_ENCRYPTION_KEY="${DATA_ENCRYPTION_KEY:-$(openssl rand -base64 64 | tr -d '\n')}"
generate_rsa_keypair_b64

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
  npm ci
  dart_frog build
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    build/bin/server.dart \
    -o "$RELEASE_DIR/backend/bin/passport_server"
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    -Ddart.vm.product=true \
    bin/seed_local_admin.dart \
    -o "$RELEASE_DIR/backend/bin/seed_local_admin"
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
  VITE_HCAPTCHA_SITE_KEY="$HCAPTCHA_SITEKEY" \
  npm run build
)
cp -R "$WEB_DIR/dist" "$RELEASE_DIR/frontend/dist"
cp "$TEMPLATE_DIR/frontend.htaccess" "$RELEASE_DIR/frontend/dist/.htaccess"
cp "$TEMPLATE_DIR/Dockerfile.backend" "$RELEASE_DIR/Dockerfile.backend"
cp "$TEMPLATE_DIR/docker-compose.yml" "$RELEASE_DIR/docker-compose.yml"
cp "$TEMPLATE_DIR/deploy.sh" "$RELEASE_DIR/deploy.sh"
cp "$TEMPLATE_DIR/README.md" "$RELEASE_DIR/README.md"
cp "$ROOT_DIR/ops/postgres/init/001_init.sql" "$RELEASE_DIR/postgres/init/001_init.sql"

cat >"$RELEASE_DIR/.env" <<EOF
SERVER_BASE_URL=$SERVER_BASE_URL
WEB_BASE_URL=$WEB_BASE_URL
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
JWT_ISSUER=$JWT_ISSUER
JWT_AUDIENCE=$JWT_AUDIENCE
JWT_PRIVATE_KEY_PEM_B64=$JWT_PRIVATE_KEY_PEM_B64
JWT_PUBLIC_KEY_PEM_B64=$JWT_PUBLIC_KEY_PEM_B64
JWT_BINDING_KEY=$JWT_BINDING_KEY
EMAIL_CODE_HMAC_KEY=$EMAIL_CODE_HMAC_KEY
DATA_ENCRYPTION_KEY=$DATA_ENCRYPTION_KEY
ACCESS_TOKEN_TTL_SECONDS=$ACCESS_TOKEN_TTL_SECONDS
REFRESH_TOKEN_TTL_SECONDS=$REFRESH_TOKEN_TTL_SECONDS
ARGON2_MEMORY_KB=$ARGON2_MEMORY_KB
ARGON2_ITERATIONS=$ARGON2_ITERATIONS
ARGON2_PARALLELISM=$ARGON2_PARALLELISM
HCAPTCHA_SECRET=$HCAPTCHA_SECRET
HCAPTCHA_SITEKEY=$HCAPTCHA_SITEKEY
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_FROM=$SMTP_FROM
SMTP_SECURE=$SMTP_SECURE
EMAIL_CODE_TTL_SECONDS=$EMAIL_CODE_TTL_SECONDS
OIDC_REQUIRE_PKCE=$OIDC_REQUIRE_PKCE
TRUST_PROXY_HEADERS=$TRUST_PROXY_HEADERS
TRUSTED_PROXY_IPS=$TRUSTED_PROXY_IPS
CORS_ALLOWED_ORIGINS=$CORS_ALLOWED_ORIGINS
LOCAL_ADMIN_EMAIL=$LOCAL_ADMIN_EMAIL
LOCAL_ADMIN_PASSWORD=$LOCAL_ADMIN_PASSWORD
LOCAL_ADMIN_NICKNAME=$LOCAL_ADMIN_NICKNAME
EOF

mkdir -p "$RELEASE_ROOT"
chmod +x "$RELEASE_DIR/deploy.sh" "$RELEASE_DIR/backend/entrypoint.sh"
tar -C "$RELEASE_DIR" -czf "$ARCHIVE_PATH" .

echo "[build_linux_x64] release ready"
echo "  directory: $RELEASE_DIR"
echo "  archive:   $ARCHIVE_PATH"
echo "  frontend:  frontend/dist -> serve with Apache at https://auth.cruty.cn"
echo "  backend:   https://apiauth.cruty.cn -> reverse proxy to 127.0.0.1:8091"
echo "  bootstrap admin email: $LOCAL_ADMIN_EMAIL"
echo "  bootstrap admin password: $LOCAL_ADMIN_PASSWORD"
