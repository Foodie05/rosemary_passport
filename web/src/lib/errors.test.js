import assert from 'node:assert/strict';
import test from 'node:test';

import { getPasskeyErrorMessage, getUserErrorMessage } from './errors.js';

test('keeps actionable validation reasons instead of hiding them behind invalid_request', () => {
  assert.equal(getUserErrorMessage({ code: 'invalid_request', serverMessage: '封禁原因至少需要 3 个字。' }), '封禁原因至少需要 3 个字。');
  const message = getUserErrorMessage({ code: 'invalid_request', serverMessage: 'confidential redirect_uris must use https or loopback http origins.' });
  assert.match(message, /机密客户端/);
  assert.match(message, /HTTPS/);
  assert.match(message, /不能使用自定义 scheme/);
});

test('keeps generic fallbacks for technical validation errors and private authentication failures', () => {
  for (const serverMessage of ['Request body must be a JSON object.', 'TypeError: 无法读取 undefined', '__proto__']) {
    assert.match(getUserErrorMessage({ code: 'invalid_request', serverMessage }), /信息不完整或格式不正确/);
  }
  assert.equal(getUserErrorMessage({ code: 'login_failed', serverMessage: '该邮箱尚未注册。' }), '账号或密码错误。');
  assert.equal(getUserErrorMessage({ code: 'server_error', serverMessage: '数据库密码无效。' }), '服务暂时不可用，请稍后重试。');
});

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
