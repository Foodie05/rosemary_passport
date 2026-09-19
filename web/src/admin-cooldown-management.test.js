import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const app = readFileSync(new URL('./App.jsx', import.meta.url), 'utf8');
const layouts = readFileSync(new URL('./components/Layouts.jsx', import.meta.url), 'utf8');
const admin = readFileSync(new URL('./pages/AdminPages.jsx', import.meta.url), 'utf8');

test('admin navigation and route expose status management', () => {
  assert.match(layouts, /label: '状态管理', to: '\/admin\/status'/);
  assert.match(app, /path="status" element=\{<AdminStatusManagement/);
  assert.match(app, /\/api\/v1\/admin\/status\/cooldowns/);
});

test('cooldown management shows operational context and live remaining time', () => {
  for (const label of [
    '冷却管理',
    '尝试次数',
    '计数窗口开始',
    '最后更新',
    '冷却截止',
    '剩余时间',
    'IP 地址',
  ]) {
    assert.match(admin, new RegExp(label));
  }
  assert.match(admin, /window\.setInterval/);
  assert.match(admin, /Asia\/Shanghai/);
  assert.match(admin, /subject_type/);
});

test('reset uses the Rosemary dialog and a single-flight destructive action', () => {
  assert.match(admin, /useRosemaryDialog\(\)/);
  assert.match(admin, /const approved = await confirm\(/);
  assert.match(admin, /resetting === key/);
  assert.match(app, /method: 'DELETE'/);
});
