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

test('password bootstrap login preserves the remember-me choice', () => {
  const prepareLogin = appSource.slice(
    appSource.indexOf('async function prepareLogin'),
    appSource.indexOf('async function completeLogin'),
  );

  assert.match(prepareLogin, /if \(data\.direct_login\)[\s\S]*remember_me: rememberMe/);
});

test('direct email-code login forwards an optional administrator password', () => {
  const completeEmailLogin = appSource.slice(
    appSource.indexOf('async function completeEmailCodeLogin'),
    appSource.indexOf('const loadLoginCodeCooldown'),
  );

  assert.match(completeEmailLogin, /loginForm\.password \? \{ password: loginForm\.password \} : \{\}/);
  assert.match(completeEmailLogin, /remember_me: rememberMe/);
});
