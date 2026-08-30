#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
preflight="$repo_root/ops/deploy/auth_cruty_cn/check_disk_capacity.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

ROSM_MIN_FREE_BYTES=1 "$preflight" "$test_dir" >/dev/null

available_kib="$(df -Pk "$test_dir" | awk 'NR == 2 {print $4}')"
# Leave enough headroom for concurrent runner cleanup. A one-KiB margin made
# this assertion race with package caches and other jobs freeing disk blocks.
too_large_bytes=$(( (available_kib + 1048576) * 1024 ))
set +e
ROSM_MIN_FREE_BYTES="$too_large_bytes" "$preflight" "$test_dir" \
  >"$test_dir/stdout" 2>"$test_dir/stderr"
status=$?
set -e
[[ "$status" -eq 75 ]]
grep -q 'insufficient free space' "$test_dir/stderr"

echo 'Disk capacity preflight tests passed.'
