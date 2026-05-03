#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

kill_port_if_needed() {
  local port="$1"
  local pids
  pids="$(lsof -ti tcp:"$port" || true)"
  if [[ -n "$pids" ]]; then
    echo "[local-down] 终止端口 $port 进程..."
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

kill_port_if_needed 8080
kill_port_if_needed 5173

cd "$ROOT_DIR"
docker compose stop postgres >/dev/null || true

echo "[local-down] 本地服务已停止"
