#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
preflight="$repo_root/ops/deploy/auth_cruty_cn/check_host_capacity.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

ROSM_CPU_COUNT_OVERRIDE=4 "$preflight" >/dev/null

assert_capacity_failure() {
  local expected="$1"
  shift
  set +e
  "$@" >"$test_dir/stdout" 2>"$test_dir/stderr"
  status=$?
  set -e
  [[ "$status" -eq 75 ]]
  grep -q "$expected" "$test_dir/stderr"
}

assert_capacity_failure 'insufficient CPUs' env \
  ROSM_CPU_COUNT_OVERRIDE=1 "$preflight"

# Memory-related environment variables are deliberately ignored. Deployments on
# small hosts are governed by runtime health checks instead of a RAM gate.
ROSM_MIN_MEMORY_HEADROOM_BYTES=999999999999 \
  ROSM_MEMINFO_PATH="$test_dir/does-not-exist" \
  ROSM_CPU_COUNT_OVERRIDE=2 "$preflight" >/dev/null

echo 'Host capacity preflight tests passed.'
