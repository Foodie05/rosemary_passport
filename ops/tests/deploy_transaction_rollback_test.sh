#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
deploy_template="$repo_root/ops/deploy/auth_cruty_cn"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

make_executable_stub() {
  local path="$1"
  shift
  {
    printf '%s\n' '#!/usr/bin/env bash' 'set -Eeuo pipefail'
    printf '%s\n' "$@"
  } >"$path"
  chmod 0700 "$path"
}

fake_bin="$test_root/fake-bin"
mkdir -p "$fake_bin"
make_executable_stub "$fake_bin/aws" 'exit 0'
make_executable_stub "$fake_bin/pg_restore" 'exit 0'
make_executable_stub "$fake_bin/sleep" 'exit 0'
make_executable_stub "$fake_bin/curl" \
  '[[ "${FAKE_CURL_SUCCESS:-false}" == true ]] && exit 0' \
  'exit 22'
make_executable_stub "$fake_bin/mv" \
  'if [[ "${1:-}" == -Tf ]]; then' \
  '  /bin/rm -f "$3"' \
  '  exec /bin/mv -f "$2" "$3"' \
  'fi' \
  'exec /bin/mv "$@"'
make_executable_stub "$fake_bin/date" \
  'if [[ "$*" == *"+%Y%m%d-%H%M%S"* ]]; then' \
  '  printf "%s\n" 20260830-120000' \
  'elif [[ "$*" == *"+%Y-%m-%dT%H:%M:%SZ"* ]]; then' \
  '  printf "%s\n" 2026-09-13T12:00:00Z' \
  'else' \
  '  exec /bin/date "$@"' \
  'fi'
make_executable_stub "$fake_bin/docker" \
  'printf "%s\n" "$*" >>"${FAKE_DOCKER_LOG:?}"' \
  '[[ "$*" != *" compose version"* && "$*" != "compose version" ]] || exit 0' \
  '[[ "$*" != *" build"* ]] || exit 0' \
  'if [[ "$*" == *" up "* ]]; then' \
  '  compose_file=""' \
  '  previous=""' \
  '  for argument in "$@"; do' \
  '    if [[ "$previous" == -f ]]; then compose_file="$argument"; break; fi' \
  '    previous="$argument"' \
  '  done' \
  '  [[ -n "$compose_file" && -f "$compose_file" ]] || exit 97' \
  '  if grep -q "new-release-compose" "$compose_file"; then' \
  '    printf "%s\n" up:new >>"${FAKE_DOCKER_LOG:?}"' \
  '  else' \
  '    printf "%s\n" up:old >>"${FAKE_DOCKER_LOG:?}"' \
  '  fi' \
  'fi' \
  'exit 0'

required_release_scripts=(
  check_host_capacity.sh check_s3_storage.sh check_disk_capacity.sh
  backup_to_s3.sh physical_backup_to_s3.sh upload_s3_verified.sh
  archive_audit_to_s3.sh restore_from_s3.sh pitr_drill.sh
  record_sla_observation.sh evaluate_sla_observation.sh
  install_systemd_units.sh provision_secrets.sh
)

prepare_case() {
  local case_name="$1"
  case_dir="$test_root/$case_name"
  source_dir="$case_dir/source"
  target_dir="$case_dir/current-release"
  frontend_dir="$case_dir/frontend"
  runtime_env="$case_dir/runtime.env"
  secrets_dir="$case_dir/secrets"
  docker_log="$case_dir/docker.log"
  mkdir -p "$source_dir/frontend/dist" "$source_dir/backend" \
    "$target_dir/data/postgres" "$target_dir/.deploy_backups" \
    "$frontend_dir" "$secrets_dir/jwt" "$secrets_dir/data_keys"

  cp "$deploy_template/deploy.sh" "$source_dir/deploy.sh"
  cp "$deploy_template/legacy_env_transition.sh" \
    "$source_dir/legacy_env_transition.sh"
  cp "$deploy_template/finalize_legacy_refresh_sunset.sh" \
    "$source_dir/finalize_legacy_refresh_sunset.sh"
  chmod 0700 "$source_dir/deploy.sh" \
    "$source_dir/legacy_env_transition.sh" \
    "$source_dir/finalize_legacy_refresh_sunset.sh"

  printf '%s\n' 'new-release-compose' >"$source_dir/docker-compose.yml"
  printf '%s\n' 'new dockerfile' >"$source_dir/Dockerfile.backend"
  printf '%s\n' 'new code' >"$source_dir/new-code.txt"
  printf '%s\n' 'new backend entrypoint' >"$source_dir/backend/entrypoint.sh"
  printf '%s\n' '<html>new frontend</html>' >"$source_dir/frontend/dist/index.html"
  printf '%s\n' '<html>maintenance</html>' >"$source_dir/frontend/dist/maintenance.html"
  chmod 0700 "$source_dir/backend/entrypoint.sh"

  for script_name in "${required_release_scripts[@]}"; do
    make_executable_stub "$source_dir/$script_name" 'exit 0'
  done

  printf '%s\n' 'old-release-compose' >"$target_dir/docker-compose.yml"
  printf '%s\n' 'old code' >"$target_dir/old-code.txt"
  printf '%s\n' 'release-20260829-120000' >"$target_dir/.release_tag"
  printf '%s\n' 'DATABASE_SENTINEL' >"$target_dir/data/postgres/sentinel"
  printf '%s\n' 'BACKUP_SENTINEL' >"$target_dir/.deploy_backups/sentinel"
  printf '%s\n' '<html>old frontend</html>' >"$frontend_dir/index.html"

  {
    printf '%s\n' \
      "POSTGRES_IMAGE=postgres@sha256:$(printf 'a%.0s' {1..64})" \
      "NODE_IMAGE=node@sha256:$(printf 'b%.0s' {1..64})" \
      'POSTGRES_USER=fixture' \
      'POSTGRES_DB=fixture' \
      'LEGACY_JSON_REFRESH_SUNSET_AT=PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS'
  } >"$runtime_env"
  chmod 0600 "$runtime_env"

  for secret_name in \
    db_password jwt_binding_key email_code_hmac_key smtp_password \
    local_admin_password aliyun_captcha_access_key_id \
    aliyun_captcha_access_key_secret aliyun_access_key_id \
    aliyun_access_key_secret backup_encryption_key s3_access_key_id \
    s3_secret_access_key helper_shared_key; do
    printf '%s\n' 'fixture-value' >"$secrets_dir/$secret_name"
  done
  printf '%s\n' 'fixture-private-key' >"$secrets_dir/audit_signing.private.pem"
  printf '%s\n' 'fixture-public-key' >"$secrets_dir/audit_signing.public.pem"
  printf '%s\n' 'fixture-jwt-key' >"$secrets_dir/jwt/signing-v1.private.pem"
  printf '%s\n' 'fixture-data-key' >"$secrets_dir/data_keys/data-v1.key"
  chmod -R u=rwX,go= "$secrets_dir"
  : >"$docker_log"
}

assert_predeployment_state_restored() {
  grep -qx 'old-release-compose' "$target_dir/docker-compose.yml"
  grep -qx 'old code' "$target_dir/old-code.txt"
  grep -qx 'release-20260829-120000' "$target_dir/.release_tag"
  [[ ! -e "$target_dir/new-code.txt" ]]
  grep -qx 'DATABASE_SENTINEL' "$target_dir/data/postgres/sentinel"
  grep -qx 'BACKUP_SENTINEL' "$target_dir/.deploy_backups/sentinel"
  grep -qx \
    'LEGACY_JSON_REFRESH_SUNSET_AT=PENDING_FIRST_HARDENED_DEPLOYMENT_PLUS_14_DAYS' \
    "$runtime_env"
  grep -qx '<html>old frontend</html>' "$frontend_dir/index.html"
  [[ ! -e "$frontend_dir/.maintenance" ]]
}

prepare_case before_start_failure
make_executable_stub "$source_dir/finalize_legacy_refresh_sunset.sh" 'exit 91'
set +e
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" \
  "$source_dir/deploy.sh" "$target_dir" "$frontend_dir" \
    "$runtime_env" "$secrets_dir" >"$case_dir/output.log" 2>&1
before_start_status=$?
set -e
[[ "$before_start_status" -eq 91 ]]
assert_predeployment_state_restored
! grep -qx 'up:new' "$docker_log"
! grep -qx 'up:old' "$docker_log"

prepare_case readiness_failure
set +e
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" \
  "$source_dir/deploy.sh" "$target_dir" "$frontend_dir" \
    "$runtime_env" "$secrets_dir" >"$case_dir/output.log" 2>&1
readiness_status=$?
set -e
[[ "$readiness_status" -eq 1 ]]
assert_predeployment_state_restored
grep -qx 'up:new' "$docker_log"
grep -qx 'up:old' "$docker_log"
grep -q 'restoring the pre-deployment application state' "$case_dir/output.log"

prepare_case successful_cutover
PATH="$fake_bin:$PATH" FAKE_DOCKER_LOG="$docker_log" FAKE_CURL_SUCCESS=true \
  "$source_dir/deploy.sh" "$target_dir" "$frontend_dir" \
    "$runtime_env" "$secrets_dir" >"$case_dir/output.log" 2>&1
grep -qx 'new-release-compose' "$target_dir/docker-compose.yml"
grep -qx 'new code' "$target_dir/new-code.txt"
[[ ! -e "$target_dir/old-code.txt" ]]
grep -qx 'release-20260830-120000' "$target_dir/.release_tag"
grep -qx 'DATABASE_SENTINEL' "$target_dir/data/postgres/sentinel"
grep -qx 'BACKUP_SENTINEL' "$target_dir/.deploy_backups/sentinel"
grep -qx 'LEGACY_JSON_REFRESH_SUNSET_AT=2026-09-13T12:00:00Z' "$runtime_env"
grep -qx '<html>new frontend</html>' "$frontend_dir/index.html"
[[ ! -e "$frontend_dir/.maintenance" ]]
grep -qx 'up:new' "$docker_log"
! grep -qx 'up:old' "$docker_log"
grep -q 'deployment completed and readiness passed' "$case_dir/output.log"

echo 'Deployment transaction success and rollback tests passed.'
