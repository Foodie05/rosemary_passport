#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ops/deploy/auth_cruty_cn/s3_key.sh
source "$script_dir/s3_key.sh"
release_dir="${1:?release directory required}"
runtime_env_file="${2:?runtime env required}"
secrets_dir="${3:?secrets directory required}"
evidence_dir="${4:-/var/lib/rosm-passport/sla-observation}"
base_url="${ROSM_OBSERVATION_BASE_URL:-http://127.0.0.1:8091}"
max_physical_age="${ROSM_OBSERVATION_MAX_PHYSICAL_AGE_SECONDS:-90000}"
max_wal_age="${ROSM_OBSERVATION_MAX_WAL_AGE_SECONDS:-600}"
max_restart_count="${ROSM_OBSERVATION_MAX_RESTART_COUNT:-3}"
minimum_free_mb="${ROSM_OBSERVATION_MIN_FREE_MB:-2048}"
observed_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
observation_date="${ROSM_OBSERVATION_DATE_OVERRIDE:-${observed_at%%T*}}"

die() { printf '[sla-observation] %s\n' "$1" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
read_env() { sed -n "s/^$1=//p" "$runtime_env_file" | tail -n 1; }
to_epoch() {
  if date --version >/dev/null 2>&1; then
    date -u -d "$1" '+%s'
  else
    date -j -u -f '%Y-%m-%dT%H:%M:%S%z' "${1/Z/+0000}" '+%s'
  fi
}

[[ "$release_dir" = /* && "$runtime_env_file" = /* && "$secrets_dir" = /* && "$evidence_dir" = /* ]] \
  || die 'all paths must be absolute'
[[ "${ROSM_OBSERVATION_CONFIRM:-}" == 'record-production-sla-evidence' ]] \
  || die 'set ROSM_OBSERVATION_CONFIRM=record-production-sla-evidence'
[[ "$observation_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die 'observation date is invalid'
for value in "$max_physical_age" "$max_wal_age" "$max_restart_count" "$minimum_free_mb"; do
  [[ "$value" =~ ^[0-9]+$ ]] || die 'numeric thresholds must be non-negative integers'
done
for file in s3_access_key_id s3_secret_access_key audit_signing.private.pem audit_signing.public.pem; do
  [[ -s "$secrets_dir/$file" ]] || die "missing secret: $file"
done
for command in aws awk chmod cmp cp curl date df docker jq mkdir openssl sed sha256sum sort tail tr; do
  require_cmd "$command"
done
docker compose version >/dev/null 2>&1 || die 'docker compose is unavailable'

s3_endpoint="$(read_env S3_ENDPOINT)"
s3_bucket="$(read_env S3_BUCKET)"
s3_region="$(read_env S3_REGION)"
s3_prefix="$(read_env S3_PREFIX)"
[[ -n "$s3_endpoint" && -n "$s3_bucket" ]] || die 'S3 settings are required'
validate_s3_prefix "$s3_prefix" || die 'S3_PREFIX is invalid'
AWS_ACCESS_KEY_ID="$(<"$secrets_dir/s3_access_key_id")"
AWS_SECRET_ACCESS_KEY="$(<"$secrets_dir/s3_secret_access_key")"
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${s3_region:-auto}"
"$script_dir/check_s3_storage.sh" "$runtime_env_file" "$secrets_dir"

mkdir -p "$evidence_dir/records"
chmod 0700 "$evidence_dir" "$evidence_dir/records"
record_file="$evidence_dir/records/$observation_date.json"
signature_file="$record_file.sig"
[[ ! -e "$record_file" && ! -e "$signature_file" ]] \
  || die "an observation already exists for $observation_date"
compose() { (cd "$release_dir" && docker compose --env-file "$runtime_env_file" "$@"); }

live_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --max-time 5 "$base_url/health/live" || true)"
ready_status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --max-time 5 "$base_url/health/ready" || true)"
running_services="$(compose ps --status running --services | sort | tr '\n' ',' | sed 's/,$//')"
required_services='identity_helper,passport_server,postgres'
restart_count=0
while IFS= read -r container_id; do
  [[ -n "$container_id" ]] || continue
  count="$(docker inspect --format '{{.RestartCount}}' "$container_id")"
  (( count > restart_count )) && restart_count="$count"
done < <(compose ps -q)

audit_chain_valid=false
if compose exec -T passport_server /app/bin/verify_audit_chain >/dev/null 2>&1; then
  audit_chain_valid=true
fi

physical_modified="$(aws --endpoint-url "$s3_endpoint" s3api head-object \
  --bucket "$s3_bucket" --key "$(s3_key "$s3_prefix" 'physical/latest.json')" \
  --query LastModified --output text)"
wal_json="$(aws --endpoint-url "$s3_endpoint" s3api list-objects-v2 \
  --bucket "$s3_bucket" --prefix "$(s3_key "$s3_prefix" 'wal/')" \
  --query 'sort_by(Contents,&LastModified)[-1]' --output json)"
wal_key="$(jq -er '.Key | strings' <<<"$wal_json")"
wal_modified="$(jq -er '.LastModified | strings' <<<"$wal_json")"
now_epoch="$(date -u '+%s')"
physical_age="$((now_epoch - $(to_epoch "$physical_modified")))"
wal_age="$((now_epoch - $(to_epoch "$wal_modified")))"
free_mb="$(df -Pm "$release_dir" | awk 'NR==2 {print $4}')"

result=passed
failure_reasons=()
[[ "$live_status" == 200 ]] || { result=failed; failure_reasons+=("live_status"); }
[[ "$ready_status" == 200 ]] || { result=failed; failure_reasons+=("ready_status"); }
[[ "$running_services" == "$required_services" ]] \
  || { result=failed; failure_reasons+=("running_services"); }
[[ "$audit_chain_valid" == true ]] || { result=failed; failure_reasons+=("audit_chain"); }
(( restart_count <= max_restart_count )) || { result=failed; failure_reasons+=("restart_count"); }
(( physical_age >= 0 && physical_age <= max_physical_age )) \
  || { result=failed; failure_reasons+=("physical_backup_age"); }
(( wal_age >= 0 && wal_age <= max_wal_age )) || { result=failed; failure_reasons+=("wal_age"); }
(( free_mb >= minimum_free_mb )) || { result=failed; failure_reasons+=("free_disk"); }
failure_json="$(printf '%s\n' "${failure_reasons[@]:-}" | jq -Rsc 'split("\n") | map(select(length>0))')"

previous_hash='GENESIS'
if [[ -s "$evidence_dir/latest_hash" ]]; then
  previous_hash="$(<"$evidence_dir/latest_hash")"
  [[ "$previous_hash" =~ ^[0-9a-f]{64}$ ]] || die 'latest observation hash is invalid'
fi
payload="$(jq -ncS \
  --arg date "$observation_date" --arg observed_at "$observed_at" --arg result "$result" \
  --arg previous_hash "$previous_hash" --arg running_services "$running_services" \
  --arg physical_modified "$physical_modified" --arg wal_key "$wal_key" \
  --arg wal_modified "$wal_modified" --argjson live_status "${live_status:-0}" \
  --argjson ready_status "${ready_status:-0}" --argjson restart_count "$restart_count" \
  --argjson audit_chain_valid "$audit_chain_valid" --argjson physical_age_seconds "$physical_age" \
  --argjson wal_age_seconds "$wal_age" --argjson free_disk_mb "$free_mb" \
  --argjson failure_reasons "$failure_json" \
  '{date:$date,observed_at:$observed_at,result:$result,previous_hash:$previous_hash,
    checks:{live_status:$live_status,ready_status:$ready_status,running_services:$running_services,
      restart_count:$restart_count,audit_chain_valid:$audit_chain_valid,
      physical_backup:{last_modified:$physical_modified,age_seconds:$physical_age_seconds},
      wal_archive:{key:$wal_key,last_modified:$wal_modified,age_seconds:$wal_age_seconds},
      free_disk_mb:$free_disk_mb},failure_reasons:$failure_reasons}')"
entry_hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
record="$(jq -cS --arg entry_hash "$entry_hash" '. + {entry_hash:$entry_hash}' <<<"$payload")"
printf '%s\n' "$record" >"$record_file"
chmod 0600 "$record_file"
openssl pkeyutl -sign -rawin -inkey "$secrets_dir/audit_signing.private.pem" \
  -in "$record_file" -out "$signature_file"
openssl pkeyutl -verify -rawin -pubin -inkey "$secrets_dir/audit_signing.public.pem" \
  -in "$record_file" -sigfile "$signature_file" >/dev/null
chmod 0600 "$signature_file"
printf '%s\n' "$entry_hash" >"$evidence_dir/latest_hash"
chmod 0600 "$evidence_dir/latest_hash"
if [[ -e "$evidence_dir/audit_signing.public.pem" ]]; then
  cmp -s "$secrets_dir/audit_signing.public.pem" "$evidence_dir/audit_signing.public.pem" \
    || die 'observation signing key changed during the evidence window'
else
  cp "$secrets_dir/audit_signing.public.pem" "$evidence_dir/audit_signing.public.pem"
  chmod 0444 "$evidence_dir/audit_signing.public.pem"
fi

archive_prefix="observation/$observation_date"
uploader="$script_dir/upload_s3_verified.sh"
"$uploader" "$record_file" "$s3_endpoint" "$s3_bucket" \
  "$archive_prefix/evidence.json"
"$uploader" "$signature_file" "$s3_endpoint" "$s3_bucket" \
  "$archive_prefix/evidence.json.sig"
"$uploader" "$secrets_dir/audit_signing.public.pem" \
  "$s3_endpoint" "$s3_bucket" "$archive_prefix/audit_signing.public.pem"
printf '[sla-observation] %s: %s hash=%s\n' "$observation_date" "$result" "$entry_hash"
[[ "$result" == passed ]]
