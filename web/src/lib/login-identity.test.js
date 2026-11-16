import assert from 'node:assert/strict';
import test from 'node:test';
import { resolveCodeLoginIdentifier, isAuthorizationLogin } from './login-identity.js';

test('code login routes email and all server-supported mobile formats', () => {
  for (const raw of ['13800138000', '+86 138-0013-8000', '86(138)00138000']) {
    assert.deepEqual(resolveCodeLoginIdentifier(raw), {method:'phone_code',identifier:'13800138000'});
  }
  assert.deepEqual(resolveCodeLoginIdentifier('  example+login@example.com  '), {method:'email_code',identifier:'example+login@example.com'});
  for (const raw of ['', 'name@', 'a b@example.com', '+1 13800138000', '1380013800', '13800138000junk', 'https://example.com']) {
    assert.equal(resolveCodeLoginIdentifier(raw), null, raw);
  }
});

test('account centre is offered only for an internal OIDC authorization login', () => {
  assert.equal(isAuthorizationLogin('/oidc/continue?client_id=example&state=local'), true);
  for (const next of ['', '/account', '/oidc/continue', '/oidc/continue?client_id=', '//elsewhere/oidc/continue?client_id=x', 'https://elsewhere/oidc/continue?client_id=x', '/oidc/continue-other?client_id=x']) {
    assert.equal(isAuthorizationLogin(next), false, next);
  }
});
