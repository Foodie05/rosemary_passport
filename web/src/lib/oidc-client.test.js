import assert from 'node:assert/strict';
import test from 'node:test';
import { CONFIDENTIAL_REDIRECT_MESSAGE, oidcClientRedirectUris, validateOidcClient } from './oidc-client.js';

const app = { client_id: 'com.cruty.stockme', enable_web: false, enable_app: true, app_redirect_uri: 'com.cruty.stockme:/oidc/callback', is_confidential: false };

test('explains the confidential/custom-scheme conflict before submission', () => {
  assert.deepEqual(validateOidcClient({ ...app, is_confidential: true }), { app_redirect_uri: CONFIDENTIAL_REDIRECT_MESSAGE });
  assert.deepEqual(validateOidcClient({ ...app, is_confidential: true, app_redirect_uri: 'com.cruty.stockme://callback' }), { app_redirect_uri: CONFIDENTIAL_REDIRECT_MESSAGE });
  assert.deepEqual(validateOidcClient(app), {});
});

test('allows server handoff and development loopback without disabling confidential mode', () => {
  for (const uri of ['https://api.example.com/auth/callback', 'http://localhost:8080/callback', 'http://127.0.0.1:8080/callback']) {
    assert.deepEqual(validateOidcClient({ ...app, is_confidential: true, app_redirect_uri: uri }), {});
  }
  assert.deepEqual(validateOidcClient({ ...app, is_confidential: true, enable_web: true, web_redirect_uris: 'https://api.example.com/callback', enable_app: false }), {});
});

test('keeps every redirect validated in combined Web/App mode', () => {
  const form = { ...app, is_confidential: true, enable_web: true, web_redirect_uris: 'https://api.example.com/callback' };
  assert.equal(validateOidcClient(form).app_redirect_uri, CONFIDENTIAL_REDIRECT_MESSAGE);
  for (const uri of ['http://example.com/callback', 'https://example.com/cb#secret', 'https://name:password@example.com/cb', 'javascript:alert(1)', 'vbscript:msgbox(1)', 'VbScRiPt:msgbox(1)', 'not a URI']) {
    assert.ok(validateOidcClient({ ...app, app_redirect_uri: uri }).app_redirect_uri, uri);
  }
});

test('cleared or disabled callbacks cannot silently restore an old redirect', () => {
  const form = { ...app, enable_web: true, web_redirect_uris: '', redirect_uris: 'https://old.example.com/callback', enable_app: false };
  assert.deepEqual(oidcClientRedirectUris(form), []);
  assert.ok(validateOidcClient(form).web_redirect_uris);
  assert.ok(validateOidcClient({ ...app, enable_app: false }).redirect_uris);
  assert.ok(validateOidcClient({ ...app, client_id: '' }).client_id);
});

test('preserves unique callbacks, including legacy forms without split Web fields', () => {
  assert.deepEqual(oidcClientRedirectUris({ ...app, enable_web: true, redirect_uris: 'https://example.com/cb\nhttps://example.com/cb' }), ['https://example.com/cb', app.app_redirect_uri]);
});
