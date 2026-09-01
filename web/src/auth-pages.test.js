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

test('direct code login uses a dedicated factor-choice step-up page', () => {
  const loginPage = source.slice(
    source.indexOf('export function LoginPage'),
    source.indexOf('export function RegisterPage'),
  );

  assert.doesNotMatch(loginPage, /管理员密码（普通账号可留空）/);
  assert.match(loginPage, /使用当前账户密码完成二次验证/);
  assert.match(loginPage, /selectedPasswordFactor === 'password'/);
  assert.match(loginPage, /返回验证方式/);
});
