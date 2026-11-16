export function destroyAliyunCaptcha(instance) {
  try {
    if (typeof instance?.destroyCaptcha === 'function') {
      instance.destroyCaptcha();
    } else if (typeof instance?.destroy === 'function') {
      instance.destroy();
    } else {
      instance?.hide?.();
    }
  } catch (_) {
    // Provider cleanup must not prevent the next challenge from starting.
  }
}

export function createAliyunCaptchaPopup({
  initCaptcha,
  sceneId,
  element,
  button,
  trigger,
  scheduler = globalThis,
}) {
  let settled = false;
  let instance;
  let triggerTimer;
  let timeoutTimer;
  let cancel;
  const promise = new Promise((resolve, reject) => {
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      scheduler.clearTimeout(timeoutTimer);
      scheduler.clearTimeout(triggerTimer);
      destroyAliyunCaptcha(instance);
      instance = null;
      callback(value);
    };
    cancel = () => finish(reject, new Error('人机验证已取消。'));
    timeoutTimer = scheduler.setTimeout(
      () => finish(reject, new Error('人机验证已超时，请重试。')),
      120000,
    );
    try {
      initCaptcha({
        SceneId: sceneId,
        mode: 'popup',
        element,
        button,
        slideStyle: { width: 360, height: 40 },
        success: (token) => {
          if (!token) {
            finish(reject, new Error('人机验证未生成有效凭据，请重试。'));
            return;
          }
          finish(resolve, token);
        },
        fail: () => {
          // A failed attempt (including traceless fallback) is retryable.
          // The SDK refreshes the challenge; keep waiting for success.
        },
        onError: () => finish(reject, new Error('人机验证组件加载失败，请检查网络后重试。')),
        onClose: (reason) => {
          // verifyComplete may precede the delayed success callback.
          if (!reason || reason === 'userDismiss') cancel();
        },
        getInstance: (nextInstance) => {
          if (settled) {
            destroyAliyunCaptcha(nextInstance);
            return;
          }
          instance = nextInstance;
          if (triggerTimer !== undefined) return;
          // Allow the SDK to collect device information before verification.
          triggerTimer = scheduler.setTimeout(() => {
            try {
              trigger();
            } catch (error) {
              finish(reject, error);
            }
          }, 2100);
        },
      });
    } catch (error) {
      finish(reject, error instanceof Error ? error : new Error('人机验证加载失败。'));
    }
  });
  return { promise, cancel };
}
