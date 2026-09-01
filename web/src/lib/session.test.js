import assert from 'node:assert/strict';
import test from 'node:test';

import { createSingleFlightRefresh, requestWithSessionRefresh } from './session.js';

test('concurrent access-token failures share one refresh rotation', async () => {
  let releaseRefresh;
  let refreshCalls = 0;
  const refreshSession = createSingleFlightRefresh(() => {
    refreshCalls += 1;
    if (refreshCalls > 1) {
      return true;
    }
    return new Promise((resolve) => {
      releaseRefresh = resolve;
    });
  });

  const first = refreshSession();
  const second = refreshSession();
  await Promise.resolve();
  assert.equal(refreshCalls, 1);

  releaseRefresh(true);
  assert.deepEqual(await Promise.all([first, second]), [true, true]);

  assert.equal(await refreshSession(), true);
  assert.equal(refreshCalls, 2);
});

test('authenticated requests retry once after a successful refresh', async () => {
  let requests = 0;
  let refreshes = 0;
  const response = await requestWithSessionRefresh(
    async () => ({ status: ++requests === 1 ? 401 : 200 }),
    {
      auth: true,
      refreshSession: async () => {
        refreshes += 1;
        return true;
      },
    },
  );

  assert.equal(response.status, 200);
  assert.equal(requests, 2);
  assert.equal(refreshes, 1);
});

test('failed refresh preserves the original unauthorized response without retrying', async () => {
  let requests = 0;
  const original = { status: 401 };
  const response = await requestWithSessionRefresh(
    async () => {
      requests += 1;
      return original;
    },
    { auth: true, refreshSession: async () => false },
  );

  assert.equal(response, original);
  assert.equal(requests, 1);
});

test('public requests never attempt session refresh', async () => {
  let refreshes = 0;
  const response = await requestWithSessionRefresh(
    async () => ({ status: 401 }),
    {
      auth: false,
      refreshSession: async () => {
        refreshes += 1;
        return true;
      },
    },
  );

  assert.equal(response.status, 401);
  assert.equal(refreshes, 0);
});
