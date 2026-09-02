import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const auth = readFileSync(new URL('./pages/AuthPages.jsx', import.meta.url), 'utf8');
const admin = readFileSync(new URL('./pages/AdminPages.jsx', import.meta.url), 'utf8');
const user = readFileSync(new URL('./pages/UserPages.jsx', import.meta.url), 'utf8');
const ui = readFileSync(new URL('./components/ui.jsx', import.meta.url), 'utf8');
const main = readFileSync(new URL('./main.jsx', import.meta.url), 'utf8');
const activePages = `${auth}\n${admin}\n${user}`;

test('active pages use Rosemary controls instead of browser-native widgets', () => {
  assert.doesNotMatch(activePages, /window\.(alert|confirm|prompt)\s*\(/);
  assert.doesNotMatch(activePages, /<select(?:\s|>)/);
  assert.doesNotMatch(activePages, /type=["']checkbox["']/);
  assert.match(activePages, /RosemaryCheckbox/);
  assert.match(activePages, /RosemarySelect/);
});

test('confirmation and alert flows use the shared Rosemary dialog provider', () => {
  assert.match(main, /<RosemaryDialogProvider>/);
  assert.match(ui, /role="alertdialog"/);
  assert.match(ui, /aria-modal="true"/);
  assert.match(ui, /useRosemaryDialog/);
});

test('login legal and recovery actions use lightweight text layout', () => {
  const legalStart = auth.indexOf('function LegalAgreementCheckbox');
  const legalEnd = auth.indexOf('function AccountCenterLink');
  const legal = auth.slice(legalStart, legalEnd);
  assert.match(legal, /px-1 text-sm/);
  assert.doesNotMatch(legal, /rounded-2xl|border-sage|bg-sage/);

  const loginStart = auth.indexOf('export function LoginPage');
  const loginEnd = auth.indexOf('export function RegisterPage');
  const login = auth.slice(loginStart, loginEnd);
  assert.match(login, /忘记密码？/);
  assert.doesNotMatch(login, /忘记密码[\s\S]{0,500}rounded-2xl border/);
});
