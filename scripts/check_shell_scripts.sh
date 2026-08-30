#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo 'ShellCheck is required to validate repository shell scripts.' >&2
  exit 69
fi

git ls-files -z -- '*.sh' | \
  xargs -0 shellcheck --external-sources --severity=warning

echo 'Shell script static analysis passed.'
