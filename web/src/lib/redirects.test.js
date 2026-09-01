import assert from 'node:assert/strict';
import test from 'node:test';

import { normalizeInternalRedirect } from './redirects.js';

test('keeps internal OIDC authorization redirects intact', () => {
  assert.equal(
    normalizeInternalRedirect('/oidc/continue?client_id=web&state=abc#resume'),
    '/oidc/continue?client_id=web&state=abc#resume',
  );
});

test('normalizes internal path segments without changing origin', () => {
  assert.equal(normalizeInternalRedirect('/account/../admin/account'), '/admin/account');
});

test('rejects external and dangerous redirect targets', () => {
  const rejected = [
    'https://evil.example/steal',
    '//evil.example/steal',
    '/\\evil.example/steal',
    'javascript:alert(1)',
    'data:text/html,unsafe',
    'admin/account',
    '',
  ];
  for (const value of rejected) {
    assert.equal(normalizeInternalRedirect(value), '', value);
  }
});
