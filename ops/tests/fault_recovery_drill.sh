#!/usr/bin/env bash
set -Eeuo pipefail

release_dir="${1:-}"
runtime_env_file="${2:-${ROSM_RUNTIME_ENV_FILE:-/etc/rosm-passport/runtime.env}}"
secrets_dir="${3:-${ROSM_SECRETS_DIR:-/etc/rosm-passport/secrets}}"
base_url="${ROSM_FAULT_DRILL_BASE_URL:-http://127.0.0.1:8091}"
max_recovery_seconds="${ROSM_FAULT_DRILL_MAX_RECOVERY_SECONDS:-1800}"
evidence_dir="${ROSM_FAULT_DRILL_EVIDENCE_DIR:-$release_dir/.drill-evidence}"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
evidence_file="$evidence_dir/fault-recovery-$timestamp.jsonl"

die() { printf '[fault-drill] %s\n' "$1" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

[[ "$release_dir" = /* ]] || die 'release directory must be absolute'
[[ "$runtime_env_file" = /* ]] || die 'runtime env path must be absolute'
[[ "$secrets_dir" = /* ]] || die 'secrets directory must be absolute'
[[ "${ROSM_FAULT_DRILL_CONFIRM:-}" == 'restart-sla-services' ]] \
  || die 'set ROSM_FAULT_DRILL_CONFIRM=restart-sla-services to authorize service restarts'
[[ "${ROSM_FAULT_DRILL_BACKUP_CONFIRM:-}" == 'create-encrypted-backup' ]] \
  || die 'set ROSM_FAULT_DRILL_BACKUP_CONFIRM=create-encrypted-backup to authorize the S3 backup'
[[ "$max_recovery_seconds" =~ ^[1-9][0-9]*$ ]] \
  || die 'ROSM_FAULT_DRILL_MAX_RECOVERY_SECONDS must be a positive integer'
[[ -f "$release_dir/docker-compose.yml" ]] || die 'docker-compose.yml is missing'
[[ -x "$release_dir/backup_to_s3.sh" ]] || die 'backup_to_s3.sh is missing or not executable'
[[ -f "$runtime_env_file" ]] || die 'runtime env file is missing'
[[ -d "$secrets_dir" ]] || die 'secrets directory is missing'

for command in curl date docker mkdir chmod; do require_cmd "$command"; done
docker compose version >/dev/null 2>&1 || die 'docker compose is unavailable'

mkdir -p "$evidence_dir"
chmod 0700 "$evidence_dir"
: >"$evidence_file"
chmod 0600 "$evidence_file"

compose() {
  (cd "$release_dir" && docker compose --env-file "$runtime_env_file" "$@")
}

record() {
  local stage="$1"
  local result="$2"
  local elapsed="$3"
  printf '{"timestamp":"%s","stage":"%s","result":"%s","elapsed_seconds":%s}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$stage" "$result" "$elapsed" \
    >>"$evidence_file"
}

is_ready() {
  curl --fail --silent --show-error --max-time 3 \
    "$base_url/health/ready" >/dev/null 2>&1
}

wait_ready() {
  local stage="$1"
  local started="$SECONDS"
  while (( SECONDS - started <= max_recovery_seconds )); do
    if is_ready; then
      local elapsed="$((SECONDS - started))"
      record "$stage" passed "$elapsed"
      printf '[fault-drill] %s recovered in %ss\n' "$stage" "$elapsed"
      return 0
    fi
    sleep 2
  done
  record "$stage" failed "$((SECONDS - started))"
  die "$stage exceeded the ${max_recovery_seconds}s recovery objective"
}

is_ready || die 'initial readiness check failed; refusing to start the drill'

printf '[fault-drill] creating encrypted off-host backup before fault injection\n'
"$release_dir/backup_to_s3.sh" "$release_dir" "$runtime_env_file" "$secrets_dir"
record pre_drill_backup passed 0

for service in passport_server identity_helper postgres; do
  printf '[fault-drill] restarting %s\n' "$service"
  compose restart "$service"
  wait_ready "restart_$service"
done

printf '[fault-drill] completed; evidence: %s\n' "$evidence_file"
