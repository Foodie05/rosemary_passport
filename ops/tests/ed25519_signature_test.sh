#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
signer="$repo_root/ops/deploy/auth_cruty_cn/ed25519_signature.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

openssl genpkey -algorithm Ed25519 -out "$test_dir/private.pem" >/dev/null 2>&1
openssl pkey -in "$test_dir/private.pem" -pubout -out "$test_dir/public.pem" >/dev/null 2>&1
printf 'signed audit evidence\n' >"$test_dir/evidence.json"

ROSM_ED25519_FORCE_NODE=true "$signer" sign \
  "$test_dir/private.pem" "$test_dir/evidence.json" "$test_dir/evidence.sig"
ROSM_ED25519_FORCE_NODE=true "$signer" verify \
  "$test_dir/public.pem" "$test_dir/evidence.json" "$test_dir/evidence.sig"
mode="$(stat -f '%Lp' "$test_dir/evidence.sig" 2>/dev/null || stat -c '%a' "$test_dir/evidence.sig")"
[[ "$mode" == 600 ]]

printf 'tampered\n' >>"$test_dir/evidence.json"
if ROSM_ED25519_FORCE_NODE=true "$signer" verify \
  "$test_dir/public.pem" "$test_dir/evidence.json" "$test_dir/evidence.sig"; then
  echo 'tampered evidence unexpectedly verified' >&2
  exit 1
fi
echo 'Ed25519 compatibility tests passed.'
