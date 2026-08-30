#!/usr/bin/env bash
set -Eeuo pipefail

minimum_bytes="${ROSM_MIN_FREE_BYTES:-5368709120}"
[[ "$minimum_bytes" =~ ^[1-9][0-9]*$ ]] || {
  echo '[disk-preflight] ROSM_MIN_FREE_BYTES must be a positive integer' >&2
  exit 64
}
(( minimum_bytes <= 9223372036854775807 )) || {
  echo '[disk-preflight] ROSM_MIN_FREE_BYTES is too large' >&2
  exit 64
}

(( $# > 0 )) || {
  echo '[disk-preflight] at least one existing path is required' >&2
  exit 64
}

minimum_kib=$(( (minimum_bytes + 1023) / 1024 ))
for path in "$@"; do
  [[ "$path" = /* && -e "$path" ]] || {
    echo "[disk-preflight] path must be absolute and exist: $path" >&2
    exit 64
  }
  available_kib="$(df -Pk "$path" | awk 'NR == 2 {print $4}')"
  [[ "$available_kib" =~ ^[0-9]+$ ]] || {
    echo "[disk-preflight] could not determine free space for: $path" >&2
    exit 69
  }
  if (( available_kib < minimum_kib )); then
    echo "[disk-preflight] insufficient free space for: $path" >&2
    exit 75
  fi
done

echo "[disk-preflight] passed for $# path(s)"
