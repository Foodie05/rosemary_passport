#!/usr/bin/env bash
set -Eeuo pipefail

source_file="${1:?source file required}"
s3_endpoint="${2:?S3 endpoint required}"
s3_bucket="${3:?S3 bucket required}"
object_key="${4:?object key required}"
umask 077

die() { printf '[s3-upload] %s\n' "$1" >&2; exit 74; }
[[ -f "$source_file" && ! -L "$source_file" ]] || die 'source must be a regular non-symlink file'
[[ "$object_key" =~ ^[A-Za-z0-9._/-]+$ ]] || die 'object key contains unsafe characters'
[[ ! "$object_key" =~ (^|/)\.\.(/|$) && "$object_key" != /* ]] || die 'object key is unsafe'
command -v aws >/dev/null 2>&1 || die 'aws CLI is required'
command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required'

file_size() {
  if stat -c '%s' "$1" >/dev/null 2>&1; then
    stat -c '%s' "$1"
  else
    stat -f '%z' "$1"
  fi
}

expected_sha="$(sha256sum "$source_file" | awk '{print $1}')"
expected_size="$(file_size "$source_file")"
[[ "$expected_sha" =~ ^[0-9a-f]{64}$ && "$expected_size" =~ ^[0-9]+$ ]] \
  || die 'unable to calculate local object integrity'

aws --endpoint-url "$s3_endpoint" s3 cp "$source_file" \
  "s3://$s3_bucket/$object_key" --metadata "sha256=$expected_sha" \
  --only-show-errors || die 'object upload failed'
remote_sha="$(aws --endpoint-url "$s3_endpoint" s3api head-object \
  --bucket "$s3_bucket" --key "$object_key" \
  --query Metadata.sha256 --output text)" || die 'unable to read uploaded object metadata'
remote_size="$(aws --endpoint-url "$s3_endpoint" s3api head-object \
  --bucket "$s3_bucket" --key "$object_key" \
  --query ContentLength --output text)" || die 'unable to read uploaded object length'
[[ "$remote_sha" == "$expected_sha" ]] || die 'uploaded object checksum metadata mismatch'
[[ "$remote_size" == "$expected_size" ]] || die 'uploaded object length mismatch'

printf '[s3-upload] verified object=%s sha256=%s bytes=%s\n' \
  "$object_key" "$expected_sha" "$expected_size"
