import assert from 'node:assert/strict';
import test from 'node:test';

import { getPasskeyErrorMessage } from './errors.js';

test('uses a passkey-specific message for non-enumerating login failures', () => {
  const message = getPasskeyErrorMessage({ code: 'login_failed' });

  assert.match(message, /通行密钥验证失败/);
  assert.match(message, /PIN、Touch ID 或 Face ID/);
  assert.doesNotMatch(message, /账号或密码错误/);
});

test('keeps browser cancellation distinct from credential rejection', () => {
  assert.equal(
    getPasskeyErrorMessage({ name: 'NotAllowedError' }),
    '你已取消本次通行密钥验证，或验证已超时。',
  );
});
