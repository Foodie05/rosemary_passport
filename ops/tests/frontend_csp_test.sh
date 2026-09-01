#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
csp_file="$repo_root/ops/deploy/auth_cruty_cn/frontend.htaccess"

required_sources=(
  'https://g.alicdn.com'
  'https://o.alicdn.com'
  'https://x.alicdn.com'
  'https://static-captcha.aliyuncs.com'
  'https://cloudauth-device.aliyuncs.com'
  'https://cn-shanghai.device.saf.aliyuncs.com'
  'https://upload.captcha-open.aliyuncs.com'
  'https://*.captcha-open.aliyuncs.com'
)

for source in "${required_sources[@]}"; do
  if ! grep -Fq "$source" "$csp_file"; then
    echo "Frontend CSP is missing required Aliyun Captcha source: $source" >&2
    exit 1
  fi
done

if grep -Fq 'https://*.aliyuncs.com' "$csp_file"; then
  echo 'Frontend CSP must not grant every aliyuncs.com service access.' >&2
  exit 1
fi

echo 'Frontend CSP includes the bounded Aliyun Captcha source set.'
