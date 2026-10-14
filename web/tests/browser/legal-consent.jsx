import React from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter } from 'react-router-dom';
import { ThemeProvider } from '../../src/theme';
import { MotionPreferences } from '../../src/design/MotionPreferences';
import { RosemaryDialogProvider } from '../../src/components/ui';
import App from '../../src/App';
import '../../src/styles.css';

// Synthetic, non-binding documents. No request is sent to a real service.
const requests = [];
const json = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
window.fetch = async (url, options = {}) => {
  const path = new URL(url, location.origin).pathname;
  requests.push({ path, method: options.method || 'GET' });
  document.querySelector('#requests').textContent = JSON.stringify(requests, null, 2);
  if (path === '/api/v1/public/config') return json({});
  if (path === '/api/v1/legal/documents') return json({terms:{version:11,title:'验收示例条款（无效力）',content:'仅用于测试'},privacy:{version:12,title:'验收示例政策（无效力）',content:'仅用于测试'}});
  if (path === '/api/v1/auth/password-factors') return json({ factors: ['authenticator', 'email_code'], direct_login: false });
  if (path.includes('/send-')) return json({ sent: true, retry_after: 0 });
  if (path === '/api/v1/auth/webauthn/options') return json({ error:'fixture_passkey_stop',message:'确认后到达测试通行密钥入口，验收环境不调用设备。' }, 400);
  return json({ error: 'fixture_no_session', message: '验收环境无登录会话' }, 401);
};
const params = new URLSearchParams(location.search);
const route = params.get('view') === 'recovery' ? '/forgot-password' : '/login';
const info = document.createElement('aside');
info.style = 'position:fixed;bottom:0;left:0;z-index:60;max-width:300px;max-height:140px;overflow:auto;background:#fff;color:#242e29;padding:8px;font-size:11px';
info.innerHTML = '<strong>本地验收 · 所有协议及请求均为模拟</strong><pre id="requests"></pre>';
document.body.append(info);
createRoot(document.getElementById('root')).render(<MotionPreferences><ThemeProvider><RosemaryDialogProvider><MemoryRouter initialEntries={[route]}><App /></MemoryRouter></RosemaryDialogProvider></ThemeProvider></MotionPreferences>);
