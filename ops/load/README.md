# SLA capacity gate

`sla_capacity.js` runs three isolated scenarios in sequence:

- 50 RPS for 30 minutes;
- 100 RPS for 5 minutes;
- 500 concurrent sessions after a 30-second ramp, held for 5 minutes.

Each scenario receives a separate refresh-token pool. The default run therefore
requires 1,500 session records. Generate them only against a local database:

```sh
cd apps/passport_server
ALLOW_LOAD_SESSION_MANAGEMENT=true \
LOAD_TEST_ACTION=generate \
LOAD_TEST_SESSION_FILE=/tmp/rosm-sla-sessions.json \
LOAD_TEST_SESSION_COUNT=1500 \
LOAD_TEST_USER_EMAIL='load-test-user@example.invalid' \
dart bin/manage_load_sessions.dart
```

The generator refuses non-loopback server/database hosts, restricts output to
mode `0600`, and will not overwrite a file without
`LOAD_TEST_OVERWRITE=true`. Run the gate with a native k6 process so the load
generator does not share the target's container runtime:

The target must trust only the load generator's direct proxy address when the
script's per-session `X-Forwarded-For` values are used. For a macOS loopback
run, Dart may report IPv4 as `::ffff:127.0.0.1`:

```sh
TRUST_PROXY_HEADERS=true \
TRUSTED_PROXY_IPS='127.0.0.1,::1,::ffff:127.0.0.1' \
dart bin/server.dart
```

Never copy this list blindly to production; configure the exact address of the
real reverse proxy there.

```sh
BASE_URL=http://127.0.0.1:8080 \
BROWSER_ORIGIN=http://localhost:5173 \
SESSION_FILE=/tmp/rosm-sla-sessions.json \
k6 run --summary-export=/tmp/rosm-sla-summary.json ops/load/sla_capacity.js
```

Always revoke the generated token families before deleting the fixture:

```sh
cd apps/passport_server
ALLOW_LOAD_SESSION_MANAGEMENT=true \
LOAD_TEST_ACTION=revoke \
LOAD_TEST_SESSION_FILE=/tmp/rosm-sla-sessions.json \
dart bin/manage_load_sessions.dart
rm /tmp/rosm-sla-sessions.json
```

The committed thresholds are `5xx/HTTP failure < 0.1%`, P95 below 300 ms and
P99 below 800 ms. A failed threshold makes k6 exit non-zero.
