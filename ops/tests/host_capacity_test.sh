#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
preflight="$repo_root/ops/deploy/auth_cruty_cn/check_host_capacity.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

write_meminfo() {
  cat >"$test_dir/meminfo" <<EOF
MemTotal:       $1 kB
MemAvailable:   $2 kB
SwapTotal:      $3 kB
SwapFree:       $4 kB
EOF
}

write_meminfo 8388608 2097152 2097152 1048576
ROSM_MEMINFO_PATH="$test_dir/meminfo" ROSM_CPU_COUNT_OVERRIDE=4 \
  "$preflight" >/dev/null

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
  ROSM_MEMINFO_PATH="$test_dir/meminfo" ROSM_CPU_COUNT_OVERRIDE=1 "$preflight"

# Physical memory is intentionally not a fixed deployment gate. Small hosts may
# deploy when they have enough immediately available RAM and free swap.
write_meminfo 1933828 1048576 1048576 1048576
ROSM_MEMINFO_PATH="$test_dir/meminfo" ROSM_CPU_COUNT_OVERRIDE=2 \
  "$preflight" >/dev/null

write_meminfo 8388608 262144 1048576 262144
assert_capacity_failure 'insufficient memory headroom' env \
  ROSM_MEMINFO_PATH="$test_dir/meminfo" ROSM_CPU_COUNT_OVERRIDE=2 "$preflight"

echo 'Host capacity preflight tests passed.'
