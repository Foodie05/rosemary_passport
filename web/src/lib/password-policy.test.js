import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { evaluatePassword, passwordContainsPersonalInfo } from './password-policy.js';
const cases = JSON.parse(readFileSync(new URL('../../../testdata/password-policy-cases.json', import.meta.url), 'utf8'));
test('new-password feedback and server use the same acceptance cases', () => {
  for (const {input: password, accepted} of cases) assert.equal(evaluatePassword(password).ok, accepted, `Mismatch for ${JSON.stringify(password)}`);
});
test('feedback updates before submission and explains the failing condition', () => {
  assert.match(evaluatePassword('orchid').message, /还需 2 个/);
  assert.match(evaluatePassword('Password!2026').message, /容易被猜/);
  assert.match(evaluatePassword('orchid willow ').message, /首尾不能有空格/);
  assert.equal(evaluatePassword('orchid-willow').message, '');
});
test('personal information prompts are advice, not an unsupported strength guarantee', () => {
  assert.equal(passwordContainsPersonalInfo('maria willows bloom', ['maria@example.com']), true);
  assert.equal(passwordContainsPersonalInfo('independent phrase', ['maria', '13800138000']), false);
  assert.equal(passwordContainsPersonalInfo('a long phrase', ['', 'a']), false);
});
