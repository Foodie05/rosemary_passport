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


test('every auth operation gates consent before captcha, HTTP or advancing a step', () => {
  const operations = ['submitRegisterCode', 'requestPasswordLoginCode', 'requestPasswordPhoneCode', 'selectPasswordFactor', 'prepareLogin', 'completeLogin', 'requestEmailCodeLogin', 'requestPhoneCodeLogin', 'preparePhoneCodeLogin', 'completePhoneCodeLogin', 'prepareEmailCodeLogin', 'completeEmailCodeLogin', 'selectDirectLoginStepUpFactor', 'completeDirectLoginStepUp', 'submitRegister', 'sendRecoveryCode', 'resetPasswordByCode', 'beginWebAuthnLogin', 'completeWebAuthnLogin', 'beginDirectLoginStepUpPasskey'];
  for (const name of operations) {
    const start = app.indexOf(`function ${name}(`);
    const body = app.slice(app.indexOf('{\n', start) + 2);
    assert.match(body, /^\s*(?:event(?:\?\.)?[^\n]*\n\s*)?if \(!await requestLegalAcceptance\(\)\) return null;/, name);
  }
  assert.match(auth, /if \(!options\) return;/);
  assert.match(auth, /if \(result === null\) return;\n\s*setStep\('verify'\)/);
  assert.match(auth, /if \(result === null\) return;\n\s*setStep\('done'\)/);
});


test('authentication page links ask before navigating and retain the requested route', () => {
  assert.match(auth, /function AuthActionLink/);
  assert.match(auth, /event\.preventDefault\(\);\n\s*if \(await requestLegalAcceptance\(\)\) navigate\(to\)/);
  assert.doesNotMatch(auth, /<Link\s+to=\{authNext/);
  assert.match(app, /requestLegalAcceptance=\{requestLegalAcceptance\}/);
});
