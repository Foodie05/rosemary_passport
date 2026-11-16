import assert from 'node:assert/strict';
import test from 'node:test';
import { createAliyunCaptchaPopup } from './aliyun-captcha.js';

function popup(t, init) {
  let callbacks;
  const trigger = t.mock.fn();
  const instance = { destroyCaptcha: t.mock.fn() };
  const challenge = createAliyunCaptchaPopup({
    sceneId: 'test-scene',
    element: '#captcha',
    button: '#trigger',
    trigger,
    initCaptcha: (options) => {
      callbacks = options;
      if (init) init(options);
      else options.getInstance(instance);
    },
  });
  return { ...challenge, callbacks, trigger, instance };
}

test('early failure and failed slider attempts keep login waiting until a valid token arrives', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  const submitLogin = t.mock.fn();
  let rejected = false;
  const login = challenge.promise.then(submitLogin, () => { rejected = true; });

  // The SDK can fail its automatic check before the user touches the slider.
  challenge.callbacks.fail('retryable');
  await Promise.resolve();
  assert.equal(rejected, false);
  assert.equal(submitLogin.mock.callCount(), 0);
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 0);

  t.mock.timers.tick(2100);
  assert.equal(challenge.trigger.mock.callCount(), 1);
  challenge.callbacks.fail('retryable');
  challenge.callbacks.fail('retryable');
  await Promise.resolve();
  assert.equal(rejected, false);
  assert.equal(submitLogin.mock.callCount(), 0);

  challenge.callbacks.success('signed-token');
  await login;
  assert.equal(submitLogin.mock.callCount(), 1);
  assert.deepEqual(submitLogin.mock.calls[0].arguments, ['signed-token']);
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 1);
  t.mock.timers.tick(120000);
  assert.equal(submitLogin.mock.callCount(), 1);
});

test('SDK automatic close can precede delayed success without cancelling login', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  challenge.callbacks.onClose('verifyComplete');
  challenge.callbacks.success('signed-token');
  assert.equal(await challenge.promise, 'signed-token');
});

test('user dismissal cancels verification and removes the delayed trigger', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  const rejected = assert.rejects(challenge.promise, /人机验证已取消/);
  challenge.callbacks.onClose('userDismiss');
  await rejected;
  t.mock.timers.tick(120000);
  assert.equal(challenge.trigger.mock.callCount(), 0);
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 1);
});

test('callbacks from a cancelled challenge cannot complete a new request', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const previous = popup(t);
  const cancelled = assert.rejects(previous.promise, /已取消/);
  previous.cancel();
  await cancelled;
  const current = popup(t);
  let completed = false;
  const result = current.promise.then((token) => { completed = true; return token; });
  previous.callbacks.success('stale-token');
  previous.callbacks.onError();
  previous.callbacks.onClose('userDismiss');
  await Promise.resolve();
  assert.equal(completed, false);
  current.callbacks.success('new-token');
  assert.equal(await result, 'new-token');
});

test('repeated failures still expire and clean up the widget at the deadline', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  const rejected = assert.rejects(challenge.promise, /已超时/);
  t.mock.timers.tick(119999);
  challenge.callbacks.fail('retryable');
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 0);
  t.mock.timers.tick(1);
  await rejected;
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 1);
});

test('resource loading errors reject without reporting a failed human verification', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  const rejected = assert.rejects(challenge.promise, /组件加载失败/);
  challenge.callbacks.onError({ code: 'network' });
  await rejected;
  t.mock.timers.tick(2100);
  assert.equal(challenge.trigger.mock.callCount(), 0);
});

test('an empty success token never proceeds with login', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t);
  const rejected = assert.rejects(challenge.promise, /未生成有效凭据/);
  challenge.callbacks.success('');
  await rejected;
});

test('an instance delivered after timeout is disposed without opening a popup', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t, () => {});
  const rejected = assert.rejects(challenge.promise, /已超时/);
  t.mock.timers.tick(120000);
  await rejected;
  challenge.callbacks.getInstance(challenge.instance);
  t.mock.timers.tick(2100);
  assert.equal(challenge.trigger.mock.callCount(), 0);
  assert.equal(challenge.instance.destroyCaptcha.mock.callCount(), 1);
});

test('cleanup using a legacy hide method cannot turn success into cancellation', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t, (options) => {
    options.getInstance({ hide: () => options.onClose('userDismiss') });
  });
  challenge.callbacks.success('signed-token');
  assert.equal(await challenge.promise, 'signed-token');
});

test('synchronous SDK initialization errors reject and clear the deadline', async (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] });
  const challenge = popup(t, () => { throw new Error('SDK unavailable'); });
  await assert.rejects(challenge.promise, /SDK unavailable/);
  t.mock.timers.tick(120000);
  assert.equal(challenge.trigger.mock.callCount(), 0);
});
