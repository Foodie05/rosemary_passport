#!/usr/bin/env bash
set -euo pipefail

cd /app

if [[ -n "${LOCAL_ADMIN_EMAIL:-}" && -n "${LOCAL_ADMIN_PASSWORD:-}" ]]; then
  echo "[passport-server] checking bootstrap admin configuration..."
  /app/bin/seed_local_admin || true
fi

exec /app/bin/passport_server
