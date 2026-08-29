import '@simplewebauthn/server';

process.stdin.resume();
for await (const _ of process.stdin) {
  // Drain the request payload before responding.
}
process.stdout.write(JSON.stringify({ ok: true }));
