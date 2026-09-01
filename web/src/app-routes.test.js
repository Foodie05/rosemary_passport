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

test('direct code login continues to registration or a separate step-up challenge', () => {
  const completeEmailLogin = appSource.slice(
    appSource.indexOf('async function completeEmailCodeLogin'),
    appSource.indexOf('const loadLoginCodeCooldown'),
  );

  assert.doesNotMatch(completeEmailLogin, /password: loginForm\.password/);
  assert.match(completeEmailLogin, /remember_me: rememberMe/);
  assert.match(completeEmailLogin, /error\?\.code === 'registration_required'/);
  assert.match(completeEmailLogin, /registration_handoff: details\.registration_handoff/);
  assert.match(completeEmailLogin, /error\?\.code === 'mfa_required'/);
  assert.match(completeEmailLogin, /setLoginStep\('step_up'\)/);
  assert.match(completeEmailLogin, /navigate\(next \? `\/register\?next=/);
});

test('sending login codes never branches on account existence', () => {
  const sendEmailCode = appSource.slice(
    appSource.indexOf('async function requestEmailCodeLogin'),
    appSource.indexOf('async function requestPhoneCodeLogin'),
  );
  assert.doesNotMatch(sendEmailCode, /registration_required/);
  assert.match(sendEmailCode, /setLoginStep\('code'\)/);
});
