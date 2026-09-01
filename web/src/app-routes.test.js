import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const appSource = readFileSync(new URL('./App.jsx', import.meta.url), 'utf8');

test('AppRoutes declares every step-up callback it forwards', () => {
  const signature = appSource.match(/function AppRoutes\(\{([\s\S]*?)\}\) \{/);

  assert.ok(signature, 'AppRoutes destructured props were not found');
  assert.match(signature[1], /\bsendStepUpCode\b/);
  assert.match(signature[1], /\bbeginStepUpPasskey\b/);
});
