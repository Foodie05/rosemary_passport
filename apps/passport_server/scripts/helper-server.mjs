import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { timingSafeEqual } from 'node:crypto';

const port = Number.parseInt(process.env.HELPER_PORT || '8092', 10);
const maxConcurrency = Number.parseInt(process.env.HELPER_MAX_CONCURRENCY || '8', 10);
const timeoutMs = Number.parseInt(process.env.HELPER_EXEC_TIMEOUT_MS || '2800', 10);
const sharedKey = readFileSync(process.env.HELPER_SHARED_KEY_FILE, 'utf8').trim();
const allowedScripts = new Set([
  'webauthn-register-options.mjs',
  'webauthn-verify-registration.mjs',
  'webauthn-auth-options.mjs',
  'webauthn-verify-authentication.mjs',
  'sms-send-verify-code.mjs',
  'sms-check-verify-code.mjs',
  'captcha-verify.mjs',
]);
let active = 0;

const send = (response, status, body) => {
  response.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(body));
};

const authorized = (request) => {
  const value = request.headers.authorization || '';
  const received = Buffer.from(value.startsWith('Bearer ') ? value.slice(7) : '');
  const expected = Buffer.from(sharedKey);
  return received.length === expected.length && timingSafeEqual(received, expected);
};

const readBody = async (request) => {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 65536) throw new Error('body_too_large');
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
};

const execute = (script, payload) => new Promise((resolve, reject) => {
  const child = spawn(process.execPath, [`scripts/${script}`], {
    cwd: '/app',
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  const stdout = [];
  let stdoutSize = 0;
  child.stdout.on('data', (chunk) => {
    stdoutSize += chunk.length;
    if (stdoutSize <= 262144) stdout.push(chunk);
  });
  child.stderr.resume();
  const timer = setTimeout(() => {
    child.kill('SIGKILL');
    reject(new Error('helper_timeout'));
  }, timeoutMs);
  child.once('error', reject);
  child.once('exit', (code) => {
    clearTimeout(timer);
    if (code !== 0) return reject(new Error('helper_failed'));
    try {
      resolve(JSON.parse(Buffer.concat(stdout).toString('utf8')));
    } catch {
      reject(new Error('invalid_helper_response'));
    }
  });
  child.stdin.end(JSON.stringify(payload));
});

const server = createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    return send(response, 200, { ok: true, active, maxConcurrency });
  }
  if (request.method !== 'POST' || request.url !== '/v1/execute') {
    return send(response, 404, { error: 'not_found' });
  }
  if (!authorized(request)) return send(response, 401, { error: 'unauthorized' });
  if (active >= maxConcurrency) return send(response, 503, { error: 'busy' });
  let acquired = false;
  try {
    const body = await readBody(request);
    if (!allowedScripts.has(body.script) || typeof body.payload !== 'object') {
      return send(response, 400, { error: 'invalid_request' });
    }
    active += 1;
    acquired = true;
    const result = await execute(body.script, body.payload);
    return send(response, 200, result);
  } catch (error) {
    const status = error?.message === 'body_too_large' ? 413 : 502;
    return send(response, status, { error: error?.message || 'helper_error' });
  } finally {
    if (acquired) active -= 1;
  }
});

server.requestTimeout = 3500;
server.headersTimeout = 4000;
server.listen(port, '0.0.0.0');
