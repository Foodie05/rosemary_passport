import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const appSource = readFileSync(new URL('./App.jsx', import.meta.url), 'utf8');

test('AppRoutes declares every step-up callback it forwards', () => {
  const signature = appSource.match(/function AppRoutes\(\{([\s\S]*?)\}\) \{/);

  assert.ok(signature, 'AppRoutes destructured props were not found');
  assert.match(signature[1], /\bsendStepUpCode\b/);
  assert.match(signature[1], /\bbeginStepUpPasskey\b/);
});

test('OIDC continuation submits parameters to a fixed authorization endpoint', () => {
  const continuation = appSource.slice(
    appSource.indexOf('function OidcContinueRedirect'),
    appSource.indexOf('function App()'),
  );

  assert.match(appSource, /path="\/oidc\/continue"/);
  assert.match(continuation, /new URL\('\/oidc\/authorize', API_BASE\)/);
  assert.match(continuation, /oidcAuthorizationParameters\(authorizationSearch\)/);
  assert.match(continuation, /<form ref=\{formRef\} method="get" action=\{authorizationEndpoint\}/);
  assert.doesNotMatch(continuation, /window\.location/);

  const postAuthContinuation = appSource.slice(
    appSource.indexOf('const continuePostAuth'),
    appSource.indexOf('useEffect(() => {', appSource.indexOf('const continuePostAuth')),
  );
  assert.match(postAuthContinuation, /parsed\.pathname !== '\/oidc\/continue'/);
  assert.match(postAuthContinuation, /navigate\('\/oidc\/continue'/);
  assert.doesNotMatch(postAuthContinuation, /navigate\(normalized/);
});
