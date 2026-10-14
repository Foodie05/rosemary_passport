import assert from 'node:assert/strict';
import test from 'node:test';
import { createLegalConsent } from './legal-consent.js';

function fixture() {
  let documents = { terms: { version: 1 }, privacy: { version: 2 } };
  let open = false;
  let operations = 0;
  const gate = createLegalConsent({ getDocuments: () => documents, onPrompt: (value) => { open = value; }, onChange() {} });
  return {
    gate,
    get open() { return open; },
    get operations() { return operations; },
    documents(value) { documents = value; },
    async continue() { if (await gate.request()) operations++; },
  };
}

test('unchecked consent blocks work; accepting resumes exactly the original action', async () => {
  const f = fixture();
  const action = f.continue();
  assert.equal(f.open, true);
  assert.equal(f.operations, 0);
  await f.continue(); // Repeated clicks must not enqueue another request.
  f.gate.accept();
  f.gate.accept();
  await action;
  assert.equal(f.operations, 1);
  assert.equal(f.open, false);
  assert.equal(f.gate.isAccepted(), true);
  await f.continue();
  assert.equal(f.operations, 2);
  assert.equal(f.open, false);
});

test('decline, dismissal and route cancellation cannot replay a canceled action', async () => {
  const f = fixture();
  const first = f.continue();
  f.gate.decline();
  await first;
  f.gate.accept();
  assert.equal(f.operations, 0);
  assert.equal(f.open, false);
  assert.equal(f.gate.isAccepted(), false);
  const next = f.continue();
  f.gate.accept();
  await next;
  assert.equal(f.operations, 1);
});

test('missing or still-loading documents cannot be accepted', async () => {
  const f = fixture();
  f.documents(null);
  const action = f.continue();
  f.gate.accept();
  assert.equal(f.operations, 0);
  assert.equal(f.open, true);
  f.documents({ terms: { version: 3 }, privacy: { version: 4 } });
  f.gate.accept();
  await action;
  assert.equal(f.operations, 1);
});

test('unchecking or changing either document version requires fresh consent', async () => {
  const f = fixture();
  f.gate.setAccepted(true);
  f.documents({ terms: { version: 1 }, privacy: { version: 3 } });
  assert.equal(f.gate.isAccepted(), false);
  const action = f.continue();
  assert.equal(f.operations, 0);
  f.gate.accept();
  await action;
  f.gate.setAccepted(false);
  const canceled = f.continue();
  f.gate.decline();
  await canceled;
  assert.equal(f.operations, 1);
});
