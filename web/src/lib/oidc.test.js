import assert from 'node:assert/strict';
import test from 'node:test';

import { oidcAuthorizationParameters } from './oidc.js';

test('preserves every authorization parameter supported by existing clients', () => {
  const expected = [
    ['client_id', 'legacy-web-client'],
    ['redirect_uri', 'https://client.example/callback?source=existing'],
    ['response_type', 'code'],
    ['scope', 'openid profile email phone accountRule'],
    ['state', 'state-value'],
    ['nonce', 'nonce-value'],
    ['code_challenge', 'pkce-challenge'],
    ['code_challenge_method', 'S256'],
    ['decision', 'approve'],
    ['consent_token', 'consent-token'],
  ];
  const search = new URLSearchParams(expected);

  assert.deepEqual(oidcAuthorizationParameters(search), expected);
});

test('does not turn unrelated query fields into authorization form controls', () => {
  assert.deepEqual(
    oidcAuthorizationParameters('?client_id=existing&submit=shadow&action=override'),
    [['client_id', 'existing']],
  );
});
