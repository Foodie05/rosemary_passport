import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const app = readFileSync(new URL('./App.jsx', import.meta.url), 'utf8');
const auth = readFileSync(new URL('./pages/AuthPages.jsx', import.meta.url), 'utf8');
const admin = readFileSync(new URL('./pages/AdminPages.jsx', import.meta.url), 'utf8');

test('every completed web authentication binds current legal versions', () => {
  const requiredFunctions = [
    'prepareLogin',
    'completeLogin',
    'completeEmailCodeLogin',
    'completePhoneCodeLogin',
    'completeDirectLoginStepUp',
    'submitRegister',
    'completeWebAuthnLogin',
  ];
  assert.match(app, /accepted_legal: true/);
  assert.match(app, /terms_version: legalDocuments\.terms\.version/);
  assert.match(app, /privacy_version: legalDocuments\.privacy\.version/);
  for (const functionName of requiredFunctions) {
    const position = app.indexOf(`function ${functionName}(`);
    assert.ok(position >= 0, `${functionName} is missing`);
    const nextFunction = app.indexOf('\n  async function ', position + 10);
    const body = app.slice(position, nextFunction >= 0 ? nextFunction : position + 2400);
    assert.match(body, /legalSubmission\(\)/, `${functionName} must bind legal versions`);
  }
});

test('login and registration expose versioned agreements in a new window', () => {
  assert.match(auth, /function LegalAgreementCheckbox/);
  assert.match(auth, /to="\/legal\/terms" target="_blank" rel="noopener noreferrer"/);
  assert.match(auth, /to="\/legal\/privacy" target="_blank" rel="noopener noreferrer"/);
  assert.ok((auth.match(/<LegalAgreementCheckbox/g) || []).length >= 2);
});

test('admin-only surfaces include dashboard, legal publishing, and account status controls', () => {
  assert.match(app, /isLoggedIn && isAdmin \? <AdminLayout/);
  assert.match(app, /path="dashboard"/);
  assert.match(app, /path="legal"/);
  assert.match(admin, /export function AdminDashboard/);
  assert.match(admin, /export function AdminLegalDocuments/);
  assert.match(admin, /updateUserStatus\(viewingUser\.id, 'banned'/);
});
