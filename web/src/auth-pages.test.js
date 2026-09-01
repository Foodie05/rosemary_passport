import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const source = readFileSync(new URL('./pages/AuthPages.jsx', import.meta.url), 'utf8');

test('login exposes password recovery independently of the selected login method', () => {
  const loginPage = source.slice(
    source.indexOf('export function LoginPage'),
    source.indexOf('export function RegisterPage'),
  );
  const methodPanel = loginPage.indexOf('function renderPanel');
  const persistentControls = loginPage.indexOf('<RememberMeCheckbox');
  const recoveryLink = loginPage.lastIndexOf("'/forgot-password'");

  assert.ok(methodPanel >= 0, 'login method panel was not found');
  assert.ok(persistentControls >= 0, 'persistent login controls were not found');
  assert.ok(recoveryLink > persistentControls, 'recovery link must remain visible below every login method');
});

test('password recovery uses the shared ROSM Pass authentication frame', () => {
  const recoveryPage = source.slice(
    source.indexOf('export function ForgotPasswordPage'),
    source.indexOf('export function PostRegisterPasskeyPrompt'),
  );

  assert.match(recoveryPage, /<AuthPageFrame>/);
  assert.match(recoveryPage, /<BrandSection \/>/);
  assert.match(recoveryPage, /grid min-h-dvh grid-cols-1 bg-white lg:grid-cols-2/);
});

test('administrator password is requested only in direct email-code login', () => {
  const phonePanel = source.slice(
    source.indexOf("if (view.method === 'phone_code')"),
    source.indexOf("if (view.method === 'email_code')"),
  );
  const emailPanel = source.slice(
    source.indexOf("if (view.method === 'email_code')"),
    source.indexOf("if (view.method === 'password')"),
  );

  assert.doesNotMatch(phonePanel, /管理员密码/);
  assert.match(emailPanel, /管理员密码（普通账号可留空）/);
  assert.match(emailPanel, /autoComplete="current-password"/);
});
