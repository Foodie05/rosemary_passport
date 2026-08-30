#!/usr/bin/env bash
set -Eeuo pipefail

RUNTIME_ENV_FILE="${1:?runtime env required}"
SECRETS_DIR="${2:?secrets directory required}"

die() {
  printf '[s3-preflight] %s\n' "$1" >&2
  exit 78
}

read_env() {
  sed -n "s/^$1=//p" "$RUNTIME_ENV_FILE" | tail -n 1
}

command -v aws >/dev/null 2>&1 || die 'aws CLI is required'
[[ -f "$RUNTIME_ENV_FILE" ]] || die "runtime env is missing: $RUNTIME_ENV_FILE"
[[ -s "$SECRETS_DIR/s3_access_key_id" ]] || die 'S3 access key file is missing or empty'
[[ -s "$SECRETS_DIR/s3_secret_access_key" ]] || die 'S3 secret key file is missing or empty'

s3_endpoint="$(read_env S3_ENDPOINT)"
s3_bucket="$(read_env S3_BUCKET)"
s3_region="$(read_env S3_REGION)"
require_object_lock="$(read_env S3_REQUIRE_OBJECT_LOCK)"
minimum_retention_days="$(read_env S3_OBJECT_LOCK_MIN_RETENTION_DAYS)"
require_object_lock="${require_object_lock:-false}"
minimum_retention_days="${minimum_retention_days:-30}"

[[ -n "$s3_endpoint" && -n "$s3_bucket" ]] || die 'S3_ENDPOINT and S3_BUCKET are required'
[[ "$require_object_lock" == true || "$require_object_lock" == false ]] \
  || die 'S3_REQUIRE_OBJECT_LOCK must be true or false'
[[ "$minimum_retention_days" =~ ^[1-9][0-9]*$ ]] \
  || die 'S3_OBJECT_LOCK_MIN_RETENTION_DAYS must be a positive integer'

AWS_ACCESS_KEY_ID="$(<"$SECRETS_DIR/s3_access_key_id")"
AWS_SECRET_ACCESS_KEY="$(<"$SECRETS_DIR/s3_secret_access_key")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${s3_region:-auto}"

versioning="$(aws --endpoint-url "$s3_endpoint" s3api get-bucket-versioning \
  --bucket "$s3_bucket" --query Status --output text)" \
  || die 'unable to query S3 bucket versioning'
[[ "$versioning" == Enabled ]] || die 'S3 bucket versioning must be enabled'

if [[ "$require_object_lock" == true ]]; then
  lock_enabled="$(aws --endpoint-url "$s3_endpoint" s3api get-object-lock-configuration \
    --bucket "$s3_bucket" --query ObjectLockConfiguration.ObjectLockEnabled --output text)" \
    || die 'Object Lock is required but its configuration cannot be queried'
  lock_mode="$(aws --endpoint-url "$s3_endpoint" s3api get-object-lock-configuration \
    --bucket "$s3_bucket" --query ObjectLockConfiguration.Rule.DefaultRetention.Mode --output text)" \
    || die 'Object Lock default retention mode cannot be queried'
  lock_days="$(aws --endpoint-url "$s3_endpoint" s3api get-object-lock-configuration \
    --bucket "$s3_bucket" --query ObjectLockConfiguration.Rule.DefaultRetention.Days --output text)" \
    || die 'Object Lock default retention days cannot be queried'
  lock_years="$(aws --endpoint-url "$s3_endpoint" s3api get-object-lock-configuration \
    --bucket "$s3_bucket" --query ObjectLockConfiguration.Rule.DefaultRetention.Years --output text)" \
    || die 'Object Lock default retention years cannot be queried'

  [[ "$lock_enabled" == Enabled ]] || die 'Object Lock must be enabled'
  [[ "$lock_mode" == GOVERNANCE || "$lock_mode" == COMPLIANCE ]] \
    || die 'Object Lock requires a GOVERNANCE or COMPLIANCE default retention rule'

  retention_days=0
  if [[ "$lock_days" =~ ^[1-9][0-9]*$ ]]; then
    retention_days="$lock_days"
  elif [[ "$lock_years" =~ ^[1-9][0-9]*$ ]]; then
    retention_days=$((lock_years * 365))
  fi
  ((retention_days >= minimum_retention_days)) \
    || die "Object Lock default retention must be at least $minimum_retention_days days"
fi

printf '[s3-preflight] versioning=Enabled object_lock_required=%s\n' "$require_object_lock"
