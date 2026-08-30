#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
drill="$repo_root/ops/deploy/auth_cruty_cn/pitr_drill.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/release" "$test_dir/secrets" "$test_dir/evidence"
touch "$test_dir/release/docker-compose.yml"
cat >"$test_dir/runtime.env" <<'EOF'
S3_ENDPOINT=https://object-store.invalid
S3_BUCKET=pitr-test
S3_REGION=auto
S3_REQUIRE_OBJECT_LOCK=false
POSTGRES_USER=postgres
POSTGRES_DB=rosm_passport
EOF
for name in s3_access_key_id s3_secret_access_key backup_encryption_key; do
  printf 'fixture' >"$test_dir/secrets/$name"
done
openssl genpkey -algorithm Ed25519 -out "$test_dir/secrets/audit_signing.private.pem" >/dev/null 2>&1
openssl pkey -in "$test_dir/secrets/audit_signing.private.pem" -pubout \
  -out "$test_dir/secrets/audit_signing.public.pem" >/dev/null 2>&1

set +e
"$drill" "$test_dir/release" "$test_dir/runtime.env" \
  "$test_dir/secrets" "$test_dir/evidence" >/dev/null 2>"$test_dir/no-confirm.err"
no_confirm_status=$?
set -e
[[ "$no_confirm_status" -ne 0 ]]
grep -q 'ROSM_PITR_CONFIRM' "$test_dir/no-confirm.err"

cat >"$test_dir/bin/docker" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
  *' rm -f '*) exit 0 ;;
  *' compose version '*) exit 0 ;;
  *' image inspect '*) exit 0 ;;
  *' compose '*' exec -T postgres psql '*)
    sql="${*: -1}"
    case "$sql" in
      *'insert into sla_recovery_markers'*) exit 0 ;;
      *'select json_build_object'*) printf '{"users":0,"roles":0,"oidc_clients":0,"system_settings":0,"audit_logs":0,"schema_migrations":5}\n' ;;
      *'select created_at'*) printf '2026-08-30 09:00:00\n' ;;
      *'pg_create_restore_point'*) printf '0/12345678\n' ;;
      *'pg_walfile_name'*) printf '000000010000000000000001\n' ;;
      *) printf 'unexpected SQL: %s\n' "$sql" >&2; exit 2 ;;
    esac
    ;;
  *) printf 'unexpected docker invocation: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
cat >"$test_dir/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case " $* " in
  *' s3api get-bucket-versioning '*) printf 'Enabled\n' ;;
  *' s3api head-object '*) exit 0 ;;
  *' s3 cp '*'physical/latest.json'*)
    destination="${*: -2:1}"
    printf '{"object":"../../unsafe","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}\n' \
      >"$destination"
    ;;
  *) printf 'unexpected aws invocation: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
chmod 0700 "$test_dir/bin/"*
export PATH="$test_dir/bin:$PATH"
export ROSM_PITR_CONFIRM=isolated-pitr-drill
set +e
"$drill" "$test_dir/release" "$test_dir/runtime.env" \
  "$test_dir/secrets" "$test_dir/evidence" >/dev/null 2>"$test_dir/unsafe.err"
unsafe_status=$?
set -e
[[ "$unsafe_status" -ne 0 ]]
grep -q 'unsafe object key' "$test_dir/unsafe.err"
echo 'PITR drill safety tests passed.'
