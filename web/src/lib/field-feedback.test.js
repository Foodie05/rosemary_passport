import test from 'node:test';
import assert from 'node:assert/strict';
import { rememberField, fieldFeedbackTarget, publishFieldFeedback, rememberActionField } from './field-feedback.js';

class Field extends EventTarget {
  id = 'test-field';
  isConnected = true;
}
test('an async verification result stays with the initiating field', () => {
  const email = new Field(), code = new Field();
  const messages = [];
  email.addEventListener('epass-field-feedback', event => messages.push(['email', event.detail]));
  code.addEventListener('epass-field-feedback', event => messages.push(['code', event.detail]));
  rememberField(email);
  const complete = fieldFeedbackTarget();
  rememberField(code);
  assert.equal(complete('验证已完成', 'success'), true);
  assert.equal(publishFieldFeedback('正在发送', 'info'), true);
  assert.deepEqual(messages, [['email', {message:'验证已完成', tone:'success'}], ['code', {message:'正在发送', tone:'info'}]]);
});
test('a detached field receives no stale feedback after route changes', () => {
  const field = new Field();
  let dispatched = false;
  field.addEventListener('epass-field-feedback', () => { dispatched = true; });
  rememberField(field);
  const complete = fieldFeedbackTarget();
  field.isConnected = false;
  assert.equal(complete('过期结果', 'error'), false);
  assert.equal(dispatched, false);
});

test('autofill-only submission still anchors feedback to a form field', () => {
  const field = new Field();
  const received = [];
  field.addEventListener('epass-field-feedback', event => received.push(event.detail.message));
  rememberActionField({form:{contains:()=>false,querySelector:selector => selector.includes('password') ? field : null}});
  publishFieldFeedback('请完成安全验证');
  assert.deepEqual(received, ['请完成安全验证']);
});
