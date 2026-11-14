import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { ThemeProvider } from '../../src/theme';
import { MotionPreferences } from '../../src/design/MotionPreferences';
import { RosemaryDialogProvider } from '../../src/components/ui';
import { AdminStatusManagement } from '../../src/pages/AdminPages';
import '../../src/styles.css';

let calls = 0;
function Fixture() {
  const [cooldowns, setCooldowns] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, total_pages: 0, total: 0 });
  async function loadCooldowns() {
    calls += 1;
    if (calls === 1 || calls === 3) throw new Error('模拟读取失败');
    setCooldowns([{scope: 'verification-code:login:email', subject: 'fixture@example.invalid', subject_type: 'email', hits: 1, window_started_at: new Date().toISOString(), updated_at: new Date().toISOString(), blocked_until: null, remaining_seconds: 0}]);
    setPagination({page: 1, total_pages: 1, total: 1});
  }
  async function safely(action) { try { await action(); } catch (_) {} }
  return <main style={{padding: 24}}><p>本地测试 · 所有数据均为合成，无生产请求</p><AdminStatusManagement cooldowns={cooldowns} pagination={pagination} loadCooldowns={loadCooldowns} safely={safely} resetCooldown={() => { throw new Error('测试禁止修改记录'); }} /></main>;
}
const fixtureRoot = import.meta.hot?.data.root ?? createRoot(document.getElementById('root'));
if (import.meta.hot) import.meta.hot.data.root = fixtureRoot;
fixtureRoot.render(<MotionPreferences><ThemeProvider><RosemaryDialogProvider><MemoryRouter><Fixture /></MemoryRouter></RosemaryDialogProvider></ThemeProvider></MotionPreferences>);
