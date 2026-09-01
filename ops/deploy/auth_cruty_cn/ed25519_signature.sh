#!/usr/bin/env bash
set -Eeuo pipefail

operation="${1:?operation (sign or verify) required}"
key_file="${2:?key file required}"
input_file="${3:?input file required}"
signature_file="${4:?signature file required}"

die() { printf '[ed25519] %s\n' "$1" >&2; exit 1; }
[[ "$operation" == sign || "$operation" == verify ]] || die 'operation must be sign or verify'
[[ -s "$key_file" ]] || die 'key file is missing or empty'
[[ -f "$input_file" ]] || die 'input file is missing'
if [[ "$operation" == verify ]]; then
  [[ -s "$signature_file" ]] || die 'signature file is missing or empty'
fi

# OpenSSL 1.1.1 exposes Ed25519 keys but cannot perform the required one-shot
# pkeyutl operation. Prefer OpenSSL 3 when available and use Node's standards-
# based Ed25519 implementation on older production hosts.
if [[ "${ROSM_ED25519_FORCE_NODE:-false}" != true ]] \
  && command -v openssl >/dev/null 2>&1 \
  && openssl pkeyutl -help 2>&1 | grep -q -- '-rawin'; then
  if [[ "$operation" == sign ]]; then
    openssl pkeyutl -sign -rawin -inkey "$key_file" \
      -in "$input_file" -out "$signature_file"
    chmod 0600 "$signature_file"
  else
    openssl pkeyutl -verify -rawin -pubin -inkey "$key_file" \
      -in "$input_file" -sigfile "$signature_file" >/dev/null
  fi
  exit 0
fi

command -v node >/dev/null 2>&1 \
  || die 'Ed25519 requires OpenSSL 3 pkeyutl or Node.js on this host'
ED25519_OPERATION="$operation" ED25519_KEY_FILE="$key_file" \
ED25519_INPUT_FILE="$input_file" ED25519_SIGNATURE_FILE="$signature_file" \
  node <<'NODE'
const crypto = require('node:crypto');
const fs = require('node:fs');

const operation = process.env.ED25519_OPERATION;
const key = fs.readFileSync(process.env.ED25519_KEY_FILE);
const input = fs.readFileSync(process.env.ED25519_INPUT_FILE);
const signaturePath = process.env.ED25519_SIGNATURE_FILE;
if (operation === 'sign') {
  fs.writeFileSync(signaturePath, crypto.sign(null, input, key), { mode: 0o600 });
  fs.chmodSync(signaturePath, 0o600);
} else if (!crypto.verify(null, input, key, fs.readFileSync(signaturePath))) {
  process.exit(1);
}
NODE
