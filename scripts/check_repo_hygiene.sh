#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

git diff --check

forbidden_tracked='(^|/)(\.DS_Store|\.env|\.flutter-plugins|\.flutter-plugins-dependencies)($|/)|(^|/)output/'
if git ls-files | grep -E "$forbidden_tracked" >/dev/null; then
  echo 'Repository hygiene failed: generated, environment, or output files are tracked.' >&2
  git ls-files | grep -E "$forbidden_tracked" >&2
  exit 1
fi

if git ls-files 'packages/*/pubspec.lock' | grep -q .; then
  echo 'Repository hygiene failed: reusable Flutter/Dart package lockfile is tracked.' >&2
  exit 1
fi

required_executables=(
  run_local.sh
  stop_local.sh
  scripts/build_linux_x64.sh
  scripts/check_repo_hygiene.sh
  scripts/deploy_auth_cruty_cn.sh
  scripts/local-down.sh
  scripts/local-up.sh
  ops/deploy/auth_cruty_cn/deploy.sh
  ops/deploy/auth_cruty_cn/provision_secrets.sh
)
for path in "${required_executables[@]}"; do
  mode="$(git ls-files --stage -- "$path" | awk '{print $1}')"
  if [[ "$mode" != 100755 ]]; then
    echo "Repository hygiene failed: $path must be tracked as executable." >&2
    exit 1
  fi
done

if git grep -Il -E -- '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}' -- . >/dev/null; then
  echo 'Repository hygiene failed: a private-key signature was found.' >&2
  exit 1
fi

echo 'Repository hygiene checks passed.'
