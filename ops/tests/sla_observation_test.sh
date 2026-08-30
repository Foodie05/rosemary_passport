#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
recorder="$repo_root/ops/deploy/auth_cruty_cn/record_sla_observation.sh"
evaluator="$repo_root/ops/deploy/auth_cruty_cn/evaluate_sla_observation.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/release" "$test_dir/secrets" "$test_dir/evidence"
touch "$test_dir/release/docker-compose.yml"
cat >"$test_dir/runtime.env" <<'EOF'
S3_ENDPOINT=https://object-store.invalid
S3_BUCKET=sla-test
S3_REGION=auto
EOF
printf 'test-access' >"$test_dir/secrets/s3_access_key_id"
printf 'test-secret' >"$test_dir/secrets/s3_secret_access_key"
openssl genpkey -algorithm Ed25519 -out "$test_dir/secrets/audit_signing.private.pem" >/dev/null 2>&1
openssl pkey -in "$test_dir/secrets/audit_signing.private.pem" -pubout \
  -out "$test_dir/secrets/audit_signing.public.pem" >/dev/null 2>&1

cat >"$test_dir/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
cat >"$test_dir/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
  *' compose version '*) exit 0 ;;
  *' compose '*' ps --status running --services '*)
    printf 'postgres\npassport_server\nidentity_helper\n'
    ;;
  *' compose '*' ps -q '*) printf 'container-a\ncontainer-b\ncontainer-c\n' ;;
  *' compose '*' exec -T passport_server /app/bin/verify_audit_chain '*) exit 0 ;;
  *' inspect --format '*) printf '0\n' ;;
  *) printf 'unexpected docker invocation: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
cat >"$test_dir/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
  *' s3api head-object '*) date -u '+%Y-%m-%dT%H:%M:%SZ' ;;
  *' s3api list-objects-v2 '*)
    now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf '{"Key":"wal/000000010000000000000001.enc","LastModified":"%s"}\n' "$now"
    ;;
  *' s3 cp '*) exit 0 ;;
  *) printf 'unexpected aws invocation: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
chmod 0700 "$test_dir/bin/"*

export PATH="$test_dir/bin:$PATH"
export ROSM_OBSERVATION_CONFIRM=record-production-sla-evidence
export ROSM_OBSERVATION_MIN_FREE_MB=0
dates=(
  2026-08-01 2026-08-02 2026-08-03 2026-08-04 2026-08-05 2026-08-06 2026-08-07
  2026-08-08 2026-08-09 2026-08-10 2026-08-11 2026-08-12 2026-08-13 2026-08-14
)
for observation_date in "${dates[@]}"; do
  ROSM_OBSERVATION_DATE_OVERRIDE="$observation_date" \
    "$recorder" "$test_dir/release" "$test_dir/runtime.env" \
      "$test_dir/secrets" "$test_dir/evidence" >/dev/null
done
summary="$($evaluator "$test_dir/evidence" 14)"
[[ "$(jq -r '.result' <<<"$summary")" == passed ]]
[[ "$(jq -r '.observed_days' <<<"$summary")" == 14 ]]

set +e
ROSM_OBSERVATION_DATE_OVERRIDE=2026-08-14 \
  "$recorder" "$test_dir/release" "$test_dir/runtime.env" \
    "$test_dir/secrets" "$test_dir/evidence" >/dev/null 2>&1
duplicate_status=$?
set -e
[[ "$duplicate_status" -ne 0 ]]

jq '.result="failed"' "$test_dir/evidence/records/2026-08-14.json" \
  >"$test_dir/tampered.json"
mv "$test_dir/tampered.json" "$test_dir/evidence/records/2026-08-14.json"
set +e
"$evaluator" "$test_dir/evidence" 14 >/dev/null 2>&1
tamper_status=$?
set -e
[[ "$tamper_status" -ne 0 ]]
echo 'SLA observation evidence tests passed.'
