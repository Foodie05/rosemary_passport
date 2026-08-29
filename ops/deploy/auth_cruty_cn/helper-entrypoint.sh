#!/usr/bin/env bash
set -Eeuo pipefail

source_key=/run/secrets/rosm-passport/helper_shared_key
runtime_key=/tmp/helper_shared_key
[[ -s "$source_key" ]] || { echo "helper shared key is missing" >&2; exit 78; }
cp "$source_key" "$runtime_key"
chmod 0400 "$runtime_key"
chown node:node "$runtime_key"
export HELPER_SHARED_KEY_FILE="$runtime_key"
exec gosu node:node node /app/scripts/helper-server.mjs
