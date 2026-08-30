#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
transition="$repo_root/ops/deploy/auth_cruty_cn/legacy_env_transition.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

target="$test_dir/release"
quarantine="$test_dir/quarantine"
mkdir -p "$target"

empty_result="$($transition quarantine "$target" "$quarantine" 20260830-120000)"
[[ -z "$empty_result" && ! -e "$quarantine" ]]

printf 'SECRET=value\n' >"$target/.env"
chmod 0644 "$target/.env"
set +e
$transition quarantine "$target" "$quarantine" 20260830-120000 \
  >/dev/null 2>"$test_dir/mode.err"
mode_status=$?
set -e
[[ "$mode_status" -eq 78 ]]
grep -q '0600' "$test_dir/mode.err"

chmod 0600 "$target/.env"
quarantined="$($transition quarantine "$target" "$quarantine" 20260830-120000)"
[[ "$quarantined" == "$quarantine/legacy-20260830-120000.env" ]]
[[ ! -e "$target/.env" && -f "$quarantined" ]]
[[ "$(stat -c '%a' "$quarantined" 2>/dev/null || stat -f '%Lp' "$quarantined")" == 600 ]]

$transition restore "$target" "$quarantined"
[[ -f "$target/.env" && ! -e "$quarantined" ]]
grep -qx 'SECRET=value' "$target/.env"

printf 'new=value\n' >"$target/.env"
printf 'old=value\n' >"$test_dir/old.env"
chmod 0600 "$target/.env" "$test_dir/old.env"
set +e
$transition restore "$target" "$test_dir/old.env" \
  >/dev/null 2>"$test_dir/overwrite.err"
overwrite_status=$?
set -e
[[ "$overwrite_status" -eq 78 ]]
grep -q 'refusing to overwrite' "$test_dir/overwrite.err"
grep -qx 'new=value' "$target/.env"
grep -qx 'old=value' "$test_dir/old.env"

echo 'Legacy environment transition tests passed.'
