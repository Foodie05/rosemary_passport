import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const admin = readFileSync(new URL('./pages/AdminPages.jsx', import.meta.url), 'utf8');
const analytics = readFileSync(
  new URL('../../apps/passport_server/lib/src/repositories/admin_analytics_repository.dart', import.meta.url),
  'utf8',
);

test('dashboard offers explicit time ranges and Beijing calendar labels', () => {
  for (const days of [7, 30, 90, 180]) {
    assert.match(admin, new RegExp(`days: ${days},`));
  }
  assert.match(admin, /formatBeijingDate/);
  assert.match(admin, /北京时间（UTC\+8）/);
  assert.match(admin, /aria-label="统计时间范围"/);
});

test('line charts expose every series value at the selected point', () => {
  assert.match(admin, /onPointerMove=\{selectPointerPosition\}/);
  assert.match(admin, /series\.map\(\(item\) => \(/);
  assert.match(admin, /hoveredRow\[item\.key\]/);
  assert.match(admin, /strokeDasharray="5 5"/);
  assert.match(admin, /onKeyDown=\{moveKeyboardPosition\}/);
});

test('server aggregates dashboard days in Asia Shanghai and returns date-only labels', () => {
  assert.ok((analytics.match(/at time zone 'Asia\/Shanghai'/g) || []).length >= 12);
  assert.ok((analytics.match(/to_char\(d\.day, 'YYYY-MM-DD'\)/g) || []).length >= 3);
  assert.doesNotMatch(analytics, /created_at::date/);
});
