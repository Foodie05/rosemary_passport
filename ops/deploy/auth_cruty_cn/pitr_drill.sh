#!/usr/bin/env bash
set -Eeuo pipefail

release_dir="${1:?release directory required}"
runtime_env_file="${2:?runtime env required}"
secrets_dir="${3:?secrets directory required}"
evidence_dir="${4:-$release_dir/.drill-evidence}"
max_rpo_seconds="${ROSM_PITR_MAX_RPO_SECONDS:-300}"
max_rto_seconds="${ROSM_PITR_MAX_RTO_SECONDS:-1800}"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
marker_id="pitr-$timestamp-$(openssl rand -hex 8)"
container_name="rosm-pitr-drill-$(openssl rand -hex 6)"
work_dir="$(mktemp -d)"
evidence_file="$evidence_dir/pitr-$timestamp.json"
signature_file="$evidence_file.sig"

die() { printf '[pitr-drill] %s\n' "$1" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
read_env() { sed -n "s/^$1=//p" "$runtime_env_file" | tail -n 1; }
cleanup() {
  docker rm -f "$container_name" >/dev/null 2>&1 || true
  rm -rf "$work_dir"
}
trap cleanup EXIT

[[ "$release_dir" = /* && "$runtime_env_file" = /* && "$secrets_dir" = /* ]] \
  || die 'release, runtime env, and secrets paths must be absolute'
[[ "${ROSM_PITR_CONFIRM:-}" == 'isolated-pitr-drill' ]] \
  || die 'set ROSM_PITR_CONFIRM=isolated-pitr-drill to authorize the isolated drill'
[[ "$max_rpo_seconds" =~ ^[1-9][0-9]*$ && "$max_rto_seconds" =~ ^[1-9][0-9]*$ ]] \
  || die 'RPO and RTO limits must be positive integer seconds'
[[ -f "$release_dir/docker-compose.yml" && -f "$runtime_env_file" ]] \
  || die 'release or runtime configuration is missing'
for file in s3_access_key_id s3_secret_access_key backup_encryption_key \
  audit_signing.private.pem audit_signing.public.pem; do
  [[ -s "$secrets_dir/$file" ]] || die "missing secret: $file"
done
for command in aws cp date docker grep jq mkdir openssl sha256sum sleep tar touch chmod sed tail awk; do
  require_cmd "$command"
done
docker compose version >/dev/null 2>&1 || die 'docker compose is unavailable'

s3_endpoint="$(read_env S3_ENDPOINT)"
s3_bucket="$(read_env S3_BUCKET)"
s3_region="$(read_env S3_REGION)"
postgres_user="$(read_env POSTGRES_USER)"
postgres_db="$(read_env POSTGRES_DB)"
release_tag="$(read_env RELEASE_TAG)"
pitr_image="${ROSM_PITR_IMAGE:-rosm-passport-postgres:${release_tag:-current}}"
[[ -n "$s3_endpoint" && -n "$s3_bucket" && -n "$postgres_user" && -n "$postgres_db" ]] \
  || die 'S3 and PostgreSQL settings are required'
docker image inspect "$pitr_image" >/dev/null 2>&1 || die "PITR image is unavailable: $pitr_image"

export AWS_ACCESS_KEY_ID="$(<"$secrets_dir/s3_access_key_id")"
export AWS_SECRET_ACCESS_KEY="$(<"$secrets_dir/s3_secret_access_key")"
export AWS_DEFAULT_REGION="${s3_region:-auto}"
compose() { (cd "$release_dir" && docker compose --env-file "$runtime_env_file" "$@"); }
source_sql() {
  compose exec -T postgres psql -U "$postgres_user" -d "$postgres_db" \
    -v ON_ERROR_STOP=1 -Atc "$1"
}

mkdir -p "$evidence_dir" "$work_dir/data" "$work_dir/secrets"
chmod 0700 "$evidence_dir" "$work_dir" "$work_dir/data" "$work_dir/secrets"
for file in s3_access_key_id s3_secret_access_key backup_encryption_key; do
  cp "$secrets_dir/$file" "$work_dir/secrets/$file"
  chmod 0400 "$work_dir/secrets/$file"
done

printf '[pitr-drill] inserting recovery marker %s\n' "$marker_id"
source_sql "insert into sla_recovery_markers(marker_id) values ('$marker_id')"
source_counts_json="$(source_sql "select json_build_object(
  'users',(select count(*) from users),
  'roles',(select count(*) from roles),
  'oidc_clients',(select count(*) from oidc_clients),
  'system_settings',(select count(*) from system_settings),
  'audit_logs',(select count(*) from audit_logs),
  'schema_migrations',(select count(*) from schema_migrations)
)")"
marker_time="$(source_sql "select created_at at time zone 'UTC' from sla_recovery_markers where marker_id='$marker_id'")"
restore_point="$(source_sql "select pg_create_restore_point('$marker_id')")"
wal_name="$(source_sql "select pg_walfile_name(pg_switch_wal())")"

printf '[pitr-drill] waiting for marker WAL archive %s\n' "$wal_name"
wal_wait_started="$SECONDS"
until aws --endpoint-url "$s3_endpoint" s3api head-object \
  --bucket "$s3_bucket" --key "wal/$wal_name.enc" >/dev/null 2>&1; do
  (( SECONDS - wal_wait_started <= max_rpo_seconds )) \
    || die "marker WAL was not archived within ${max_rpo_seconds}s"
  sleep 2
done
failure_epoch="$(date -u '+%s')"

rto_started="$SECONDS"
aws --endpoint-url "$s3_endpoint" s3 cp \
  "s3://$s3_bucket/physical/latest.json" "$work_dir/manifest.json" --only-show-errors
object_key="$(jq -er '.object | strings' "$work_dir/manifest.json")"
expected_checksum="$(jq -er '.sha256 | strings' "$work_dir/manifest.json")"
[[ "$object_key" =~ ^physical/[0-9]{8}T[0-9]{6}Z/base\.tar\.enc$ ]] \
  || die 'physical backup manifest contains an unsafe object key'
[[ "$expected_checksum" =~ ^[0-9a-f]{64}$ ]] || die 'physical backup checksum is invalid'
aws --endpoint-url "$s3_endpoint" s3 cp \
  "s3://$s3_bucket/$object_key" "$work_dir/base.tar.enc" --only-show-errors
actual_checksum="$(sha256sum "$work_dir/base.tar.enc" | awk '{print $1}')"
[[ "$actual_checksum" == "$expected_checksum" ]] || die 'physical backup checksum mismatch'
openssl enc -d -aes-256-cbc -pbkdf2 \
  -pass file:"$secrets_dir/backup_encryption_key" \
  -in "$work_dir/base.tar.enc" -out "$work_dir/base.tar"
tar -tf "$work_dir/base.tar" >/dev/null
tar -xf "$work_dir/base.tar" -C "$work_dir/data"
printf "restore_command = '/usr/local/bin/restore-wal.sh %%f %%p'\n" \
  >>"$work_dir/data/postgresql.auto.conf"
printf "recovery_target_name = '%s'\nrecovery_target_action = 'promote'\n" "$marker_id" \
  >>"$work_dir/data/postgresql.auto.conf"
touch "$work_dir/data/recovery.signal"

docker run --rm --entrypoint /bin/sh \
  -v "$work_dir/data:/restore" "$pitr_image" \
  -c 'chown -R postgres:postgres /restore && chmod 0700 /restore'
docker run -d --name "$container_name" \
  --read-only --tmpfs /tmp --tmpfs /run/postgresql \
  --cap-drop ALL --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add SETGID --cap-add SETUID \
  --security-opt no-new-privileges:true \
  -e POSTGRES_USER="$postgres_user" -e POSTGRES_DB="$postgres_db" \
  -e S3_ENDPOINT="$s3_endpoint" -e S3_BUCKET="$s3_bucket" -e S3_REGION="${s3_region:-auto}" \
  -v "$work_dir/data:/var/lib/postgresql/data" \
  -v "$work_dir/secrets:/run/secrets/rosm-passport:ro" \
  "$pitr_image" postgres >/dev/null

restored=false
while (( SECONDS - rto_started <= max_rto_seconds )); do
  if docker exec "$container_name" psql -U "$postgres_user" -d "$postgres_db" -Atc \
    "select 1 from sla_recovery_markers where marker_id='$marker_id'" 2>/dev/null | grep -qx 1; then
    restored=true
    break
  fi
  sleep 2
done
[[ "$restored" == true ]] || {
  docker logs "$container_name" >&2 || true
  die "isolated recovery did not reach the marker within ${max_rto_seconds}s"
}
rto_seconds="$((SECONDS - rto_started))"
rpo_seconds="$((failure_epoch - $(date -u -d "$marker_time UTC" '+%s')))"
(( rpo_seconds >= 0 && rpo_seconds <= max_rpo_seconds )) || die "RPO exceeded: ${rpo_seconds}s"
(( rto_seconds <= max_rto_seconds )) || die "RTO exceeded: ${rto_seconds}s"

counts_json="$(docker exec "$container_name" psql -U "$postgres_user" -d "$postgres_db" -Atc \
  "select json_build_object(
    'users',(select count(*) from users),
    'roles',(select count(*) from roles),
    'oidc_clients',(select count(*) from oidc_clients),
    'system_settings',(select count(*) from system_settings),
    'audit_logs',(select count(*) from audit_logs),
    'schema_migrations',(select count(*) from schema_migrations)
  )")"
counts_consistent="$(jq -n \
  --argjson source "$source_counts_json" --argjson restored "$counts_json" \
  '($restored.users <= $source.users) and
   ($restored.audit_logs <= $source.audit_logs) and
   ($restored.roles == $source.roles) and
   ($restored.oidc_clients == $source.oidc_clients) and
   ($restored.system_settings == $source.system_settings) and
   ($restored.schema_migrations == $source.schema_migrations)')"
[[ "$counts_consistent" == true ]] || die 'restored core-table counts are inconsistent with the source'
jq -nS \
  --arg timestamp "$timestamp" --arg marker_id "$marker_id" \
  --arg marker_time "$marker_time" --arg restore_point "$restore_point" \
  --arg object "$object_key" --arg wal "$wal_name" \
  --argjson rpo_seconds "$rpo_seconds" --argjson rto_seconds "$rto_seconds" \
  --argjson source_counts "$source_counts_json" --argjson restored_counts "$counts_json" \
  '{timestamp:$timestamp,result:"passed",marker_id:$marker_id,marker_time:$marker_time,
    recovery_target_name:$marker_id,recovery_target_lsn:$restore_point,
    physical_object:$object,marker_wal:$wal,
    rpo_seconds:$rpo_seconds,rto_seconds:$rto_seconds,
    source_counts:$source_counts,restored_counts:$restored_counts}' \
  >"$evidence_file"
chmod 0600 "$evidence_file"
openssl pkeyutl -sign -rawin -inkey "$secrets_dir/audit_signing.private.pem" \
  -in "$evidence_file" -out "$signature_file"
openssl pkeyutl -verify -rawin -pubin -inkey "$secrets_dir/audit_signing.public.pem" \
  -in "$evidence_file" -sigfile "$signature_file" >/dev/null
chmod 0600 "$signature_file"
archive_prefix="drills/pitr/$timestamp"
aws --endpoint-url "$s3_endpoint" s3 cp "$evidence_file" \
  "s3://$s3_bucket/$archive_prefix/evidence.json" --only-show-errors
aws --endpoint-url "$s3_endpoint" s3 cp "$signature_file" \
  "s3://$s3_bucket/$archive_prefix/evidence.json.sig" --only-show-errors
aws --endpoint-url "$s3_endpoint" s3 cp "$secrets_dir/audit_signing.public.pem" \
  "s3://$s3_bucket/$archive_prefix/audit_signing.public.pem" --only-show-errors
printf '[pitr-drill] passed: RPO=%ss RTO=%ss evidence=%s\n' \
  "$rpo_seconds" "$rto_seconds" "$evidence_file"
