#!/usr/bin/env bash
set -Eeuo pipefail

base_revision="${1:-}"
head_revision="${2:-HEAD}"
pattern='^(feat|fix|security|refactor|perf|test|docs|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: .{1,72}$'

git rev-parse --verify "${head_revision}^{commit}" >/dev/null

if [[ -z "$base_revision" || "$base_revision" =~ ^0+$ ]] \
  || ! git rev-parse --verify "${base_revision}^{commit}" >/dev/null 2>&1; then
  revisions=("$head_revision")
else
  revisions=()
  while IFS= read -r revision; do
    revisions+=("$revision")
  done < <(git rev-list --reverse "${base_revision}..${head_revision}")
fi

failed=false
for revision in "${revisions[@]}"; do
  parent_count="$(git show -s --format='%P' "$revision" | awk '{print NF}')"
  if (( parent_count > 1 )); then
    continue
  fi
  subject="$(git show -s --format='%s' "$revision")"
  if [[ ! "$subject" =~ $pattern ]]; then
    printf 'Invalid commit subject %s: %s\n' "${revision:0:12}" "$subject" >&2
    failed=true
  fi
done

if [[ "$failed" == true ]]; then
  echo 'Use Conventional Commits with an allowed type and a 1-72 character subject.' >&2
  exit 1
fi

echo 'Commit message checks passed.'
