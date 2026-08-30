#!/usr/bin/env bash
set -Eeuo pipefail

evidence_dir="${1:?evidence directory required}"
expected_days="${2:-14}"
die() { printf '[sla-evaluation] %s\n' "$1" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
to_epoch() {
  if date --version >/dev/null 2>&1; then
    date -u -d "$1" '+%s'
  else
    date -j -u -f '%Y-%m-%d' "$1" '+%s'
  fi
}
[[ "$evidence_dir" = /* ]] || die 'evidence directory must be absolute'
[[ "$expected_days" =~ ^[1-9][0-9]*$ ]] || die 'expected days must be positive'
for command in awk date find jq openssl sha256sum sort tail; do require_cmd "$command"; done
[[ -s "$evidence_dir/audit_signing.public.pem" ]] || die 'observation public key is missing'
records=()
while IFS= read -r record; do
  records+=("$record")
done < <(find "$evidence_dir/records" -maxdepth 1 -type f -name '*.json' | sort | tail -n "$expected_days")
(( ${#records[@]} == expected_days )) \
  || die "expected $expected_days daily records, found ${#records[@]}"

previous_hash='GENESIS'
previous_epoch=''
for record_file in "${records[@]}"; do
  signature_file="$record_file.sig"
  [[ -s "$signature_file" ]] || die "signature missing: $record_file"
  openssl pkeyutl -verify -rawin -pubin \
    -inkey "$evidence_dir/audit_signing.public.pem" \
    -in "$record_file" -sigfile "$signature_file" >/dev/null \
    || die "signature verification failed: $record_file"
  result="$(jq -er '.result' "$record_file")"
  date_value="$(jq -er '.date' "$record_file")"
  recorded_previous="$(jq -er '.previous_hash' "$record_file")"
  entry_hash="$(jq -er '.entry_hash' "$record_file")"
  payload="$(jq -cS 'del(.entry_hash)' "$record_file")"
  calculated_hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
  [[ "$result" == passed ]] || die "failed observation: $date_value"
  [[ "$recorded_previous" == "$previous_hash" ]] || die "hash chain mismatch: $date_value"
  [[ "$entry_hash" == "$calculated_hash" ]] || die "entry hash mismatch: $date_value"
  current_epoch="$(to_epoch "$date_value")"
  if [[ -n "$previous_epoch" ]]; then
    (( current_epoch - previous_epoch == 86400 )) || die "dates are not consecutive: $date_value"
  fi
  previous_hash="$entry_hash"
  previous_epoch="$current_epoch"
done
printf '{"result":"passed","observed_days":%s,"first_date":"%s","last_date":"%s","final_hash":"%s"}\n' \
  "$expected_days" "$(jq -r '.date' "${records[0]}")" \
  "$(jq -r '.date' "${records[expected_days-1]}")" "$previous_hash"
