#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
checker="$repo_root/scripts/check_commit_messages.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

git -C "$test_dir" init -q
git -C "$test_dir" config user.name 'Commit Gate Test'
git -C "$test_dir" config user.email 'commit-gate@example.invalid'
touch "$test_dir/fixture"
git -C "$test_dir" add fixture
git -C "$test_dir" commit -qm 'chore: initialize fixture'
initial="$(git -C "$test_dir" rev-parse HEAD)"

(
  cd "$test_dir"
  "$checker" "$initial" "$initial" >/dev/null
)

printf 'valid\n' >"$test_dir/fixture"
git -C "$test_dir" add fixture
git -C "$test_dir" commit -qm 'test(repo): cover empty commit range'
valid="$(git -C "$test_dir" rev-parse HEAD)"
(
  cd "$test_dir"
  "$checker" "$initial" "$valid" >/dev/null
)

printf 'invalid\n' >"$test_dir/fixture"
git -C "$test_dir" add fixture
git -C "$test_dir" commit -qm 'invalid subject'
invalid="$(git -C "$test_dir" rev-parse HEAD)"
set +e
(
  cd "$test_dir"
  "$checker" "$valid" "$invalid" >/dev/null 2>&1
)
status=$?
set -e
[[ "$status" -ne 0 ]]

echo 'Commit message gate tests passed.'
