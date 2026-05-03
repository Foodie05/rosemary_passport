#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$ROOT_DIR/apps/passport_server"
LOCAL_DIR="$ROOT_DIR/.local"
ENV_FILE="$SERVER_DIR/.env"
BOOTSTRAP_LOG="$LOCAL_DIR/bootstrap.log"
ADMIN_CRED_FILE="$LOCAL_DIR/admin_credentials.env"
FIRST_ADMIN_BOOTSTRAP=0

mkdir -p "$LOCAL_DIR"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[local-up] 缺少命令: $1"
    exit 1
  fi
}

require_cmd docker
require_cmd openssl
require_cmd dart
require_cmd npm
require_cmd lsof
require_cmd osascript

log() {
  echo "[local-up] $1"
}

kill_port_if_needed() {
  local port="$1"
  local pids
  pids="$(lsof -ti tcp:"$port" || true)"
  if [[ -n "$pids" ]]; then
    echo "[local-up] 检测到端口 $port 已被占用，正在终止旧进程..."
    # shellcheck disable=SC2086
    kill $pids >/dev/null 2>&1 || true
    sleep 1
    pids="$(lsof -ti tcp:"$port" || true)"
    if [[ -n "$pids" ]]; then
      # shellcheck disable=SC2086
      kill -9 $pids >/dev/null 2>&1 || true
    fi
  fi
}

ensure_docker_ready() {
  if ! docker info >/dev/null 2>&1; then
    log "Docker Desktop 未启动或 Docker daemon 不可用。"
    log "请先启动 Docker Desktop，然后重新执行 ./run_local.sh"
    exit 1
  fi
}

create_env_if_needed() {
  if [[ -f "$ENV_FILE" ]]; then
    if grep -q '^JWT_PRIVATE_KEY_PEM_B64=' "$ENV_FILE" &&
      grep -q '^JWT_PUBLIC_KEY_PEM_B64=' "$ENV_FILE"; then
      local updated=0
      if ! grep -q '^EMAIL_CODE_HMAC_KEY=' "$ENV_FILE"; then
        echo "EMAIL_CODE_HMAC_KEY=$(openssl rand -base64 64 | tr -d '\n')" >>"$ENV_FILE"
        updated=1
      fi
      if ! grep -q '^DATA_ENCRYPTION_KEY=' "$ENV_FILE"; then
        echo "DATA_ENCRYPTION_KEY=$(openssl rand -base64 64 | tr -d '\n')" >>"$ENV_FILE"
        updated=1
      fi
      if ! grep -q '^TRUST_PROXY_HEADERS=' "$ENV_FILE"; then
        echo "TRUST_PROXY_HEADERS=false" >>"$ENV_FILE"
        updated=1
      fi
      if ! grep -q '^CORS_ALLOWED_ORIGINS=' "$ENV_FILE"; then
        echo "CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173" >>"$ENV_FILE"
        updated=1
      fi
      if [[ "$updated" -eq 1 ]]; then
        log "已补齐本地环境中的新增安全配置。"
      fi
      return
    fi
    if grep -q '^JWT_PRIVATE_KEY_PEM=' "$ENV_FILE" ||
      grep -q '^JWT_PUBLIC_KEY_PEM=' "$ENV_FILE"; then
      echo "[local-up] 检测到旧版 PEM 环境变量，自动迁移为 base64 格式..."
      rm -f "$ENV_FILE"
    else
      return
    fi
  fi

  local tmpdir private_b64 public_b64 binding_key
  tmpdir="$(mktemp -d)"
  openssl genrsa -out "$tmpdir/jwt_private.pem" 2048 >/dev/null 2>&1
  openssl rsa -in "$tmpdir/jwt_private.pem" -pubout -out "$tmpdir/jwt_public.pem" >/dev/null 2>&1
  private_b64="$(base64 <"$tmpdir/jwt_private.pem" | tr -d '\n')"
  public_b64="$(base64 <"$tmpdir/jwt_public.pem" | tr -d '\n')"
  binding_key="$(openssl rand -base64 64 | tr -d '\n')"

  cat >"$ENV_FILE" <<ENVVARS
SERVER_BASE_URL=http://localhost:8080
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=rosm_passport
DB_PASSWORD=rosm_passport_dev
DB_NAME=rosm_passport
DB_SSL_MODE=disable
JWT_ISSUER=rosm-passport
JWT_AUDIENCE=rosm-apps
JWT_PRIVATE_KEY_PEM_B64=$private_b64
JWT_PUBLIC_KEY_PEM_B64=$public_b64
JWT_BINDING_KEY=$binding_key
ACCESS_TOKEN_TTL_SECONDS=900
REFRESH_TOKEN_TTL_SECONDS=2592000
ARGON2_MEMORY_KB=8192
ARGON2_ITERATIONS=2
ARGON2_PARALLELISM=1
HCAPTCHA_SECRET=
HCAPTCHA_SITEKEY=
SMTP_HOST=localhost
SMTP_PORT=1025
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=ROSM Passport <no-reply@localhost>
SMTP_SECURE=false
EMAIL_CODE_TTL_SECONDS=300
OIDC_REQUIRE_PKCE=true
ENVVARS

  rm -rf "$tmpdir"
  log "已生成本地环境文件: $ENV_FILE"
}

create_admin_credential_if_needed() {
  local admin_email admin_password admin_nickname
  admin_email=""
  admin_password=""
  admin_nickname=""

  if [[ -f "$ADMIN_CRED_FILE" ]]; then
    local cred_size
    cred_size="$(wc -c <"$ADMIN_CRED_FILE" | tr -d ' ')"
    if [[ "$cred_size" -gt 4096 ]]; then
      log "检测到损坏的管理员凭证文件（体积异常：${cred_size} bytes），将自动重建。"
      rm -f "$ADMIN_CRED_FILE"
    else
      return 0
    fi
  fi

  [[ -n "$admin_email" ]] || admin_email="admin@rosm.local"
  [[ -n "$admin_password" ]] || admin_password="$(openssl rand -base64 18 | tr -d '\n' | cut -c1-16)"
  [[ -n "$admin_nickname" ]] || admin_nickname="ROSM Super Admin"

  {
    printf 'LOCAL_ADMIN_EMAIL=%q\n' "$admin_email"
    printf 'LOCAL_ADMIN_PASSWORD=%q\n' "$admin_password"
    printf 'LOCAL_ADMIN_NICKNAME=%q\n' "$admin_nickname"
  } >"$ADMIN_CRED_FILE"
  FIRST_ADMIN_BOOTSTRAP=1
}

escape_for_osascript() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

create_env_if_needed
create_admin_credential_if_needed
ensure_docker_ready

log "清理旧端口占用..."
kill_port_if_needed 8080
kill_port_if_needed 5173

cd "$ROOT_DIR"
log "启动 PostgreSQL 容器..."
docker compose up -d postgres

log "等待 PostgreSQL 启动..."
for _ in {1..30}; do
  if docker compose exec -T postgres pg_isready -U rosm_passport -d rosm_passport >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker compose exec -T postgres pg_isready -U rosm_passport -d rosm_passport >/dev/null 2>&1; then
  log "PostgreSQL 启动超时，请检查 Docker 状态与容器日志。"
  exit 1
fi

docker compose exec -T -e PGOPTIONS='-c client_min_messages=warning' postgres \
  psql -v ON_ERROR_STOP=1 -U rosm_passport -d rosm_passport \
  -f /docker-entrypoint-initdb.d/001_init.sql >/dev/null

log "安装后端依赖..."
(cd "$SERVER_DIR" && dart pub get >/dev/null)

log "安装前端依赖..."
(cd "$ROOT_DIR/web" && npm install >/dev/null)

if [[ "$FIRST_ADMIN_BOOTSTRAP" -eq 1 ]]; then
  # shellcheck disable=SC1090
  source "$ADMIN_CRED_FILE"
  log "首次初始化本地管理员账号..."
  (
    cd "$SERVER_DIR"
    LOCAL_ADMIN_EMAIL="$LOCAL_ADMIN_EMAIL" \
      LOCAL_ADMIN_PASSWORD="$LOCAL_ADMIN_PASSWORD" \
      LOCAL_ADMIN_NICKNAME="$LOCAL_ADMIN_NICKNAME" \
      ARGON2_MEMORY_KB=8192 \
      ARGON2_ITERATIONS=2 \
      ARGON2_PARALLELISM=1 \
      dart run bin/seed_local_admin.dart
  ) | tee -a "$BOOTSTRAP_LOG"

  echo ""
  log "默认管理员账号（仅首次初始化时输出）"
  echo "  email: $LOCAL_ADMIN_EMAIL"
  echo "  password: $LOCAL_ADMIN_PASSWORD"
  echo "  账号文件: $ADMIN_CRED_FILE"
else
  log "检测到已有管理员初始化记录，跳过自动创建超级管理员。"
  log "如需重新初始化，请手动删除 $ADMIN_CRED_FILE 并清理本地数据库。"
fi

BACKEND_CMD="cd \"$SERVER_DIR\" && dart run dart_frog_cli:dart_frog dev --port 8080"
FRONTEND_CMD="cd \"$ROOT_DIR/web\" && npm run dev -- --host 0.0.0.0 --port 5173"

BACKEND_CMD_ESCAPED="$(escape_for_osascript "$BACKEND_CMD")"
FRONTEND_CMD_ESCAPED="$(escape_for_osascript "$FRONTEND_CMD")"

log "正在打开两个终端窗口运行服务..."
osascript <<OSA
tell application "Terminal"
  activate
  do script "$BACKEND_CMD_ESCAPED"
  delay 0.2
  do script "$FRONTEND_CMD_ESCAPED"
end tell
OSA

echo ""
log "已启动（前台窗口）"
echo "  前端: http://localhost:5173"
echo "  后端: http://localhost:8080"
echo "  OIDC Discovery: http://localhost:8080/.well-known/openid-configuration"
echo ""
log "如需停止，请执行: $ROOT_DIR/scripts/local-down.sh"
