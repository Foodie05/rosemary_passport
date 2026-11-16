// Run against Vite with Playwright installed; all API requests are intercepted.
// PLAYWRIGHT_PACKAGE can point to a shared Playwright installation.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir, mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_PACKAGE || 'playwright');
const base = process.env.EPASS_TEST_URL || 'http://127.0.0.1:5188';
const output = process.env.EPASS_TEST_OUTPUT || await mkdtemp(path.join(tmpdir(), 'epass-oidc-feedback-'));
await mkdir(output, { recursive: true });
const client = { client_id: 'com.cruty.stockme', display_name: 'Stockme', redirect_uris: ['https://api.example.com/callback'], scopes: ['openid'], grant_types: ['authorization_code'], is_confidential: true, is_active: true };
const results = [];

for (const engine of (process.env.EPASS_TEST_BROWSERS || 'chromium,webkit').split(',')) {
  const executablePath = process.env[`EPASS_TEST_${engine.toUpperCase()}_EXECUTABLE`];
  const browser = await playwright[engine].launch(executablePath ? { executablePath } : {});
  try {
    for (const width of (process.env.EPASS_TEST_WIDTHS || '1440,320').split(',').map(Number)) {
      const page = await browser.newPage({ viewport: { width, height: 1000 }, colorScheme: width === 320 ? 'dark' : 'light', reducedMotion: width === 320 ? 'reduce' : 'no-preference' });
      page.setDefaultTimeout(10000);
      const crashes = [];
      const writes = [];
      let rejectSave = true;
      page.on('pageerror', (error) => crashes.push(error.message));
      await page.route('**/*', async (route) => {
        const url = new URL(route.request().url());
        // This test never sends traffic or mutations to a real backend.
        const pathname = url.pathname;
        if (!pathname.startsWith('/api/v1/') && pathname !== '/.well-known/openid-configuration') {
          return url.origin === new URL(base).origin ? route.continue() : route.abort();
        }
        let data = {};
        let status = 200;
        if (pathname === '/api/v1/me') data = { user: { id: 'preview-admin', email: 'admin@example.com', nickname: '管理员', roles: ['admin'] }, security: { must_bind_email: false } };
        else if (pathname === '/api/v1/admin/settings') data = { settings: {} };
        else if (pathname === '/api/v1/admin/oidc/clients') data = { clients: [client] };
        else if (pathname === '/.well-known/openid-configuration') data = { issuer: 'https://api.example.com' };
        else if (pathname.startsWith('/api/v1/admin/oidc/clients/') && route.request().method() === 'PUT') {
          writes.push(route.request().postDataJSON());
          status = rejectSave ? 400 : 200;
          data = rejectSave ? { error: 'invalid_request', message: 'Client ID 已被其他应用使用，请换一个。' } : { updated: true };
        }
        return route.fulfill({ status, json: data, headers: { 'access-control-allow-origin': base, 'access-control-allow-credentials': 'true', 'access-control-allow-methods': 'GET, PUT, POST, PATCH, DELETE, OPTIONS', 'access-control-allow-headers': 'content-type' } });
      });
      await page.goto(`${base}/admin/oidc`);
      // Session bootstrap can initially redirect protected deep links.
      await page.waitForSelector('.epass-shell');
      if (width < 1024) await page.getByRole('button', { name: '打开导航', exact: true }).click();
      await page.getByRole('link', { name: '应用接入', exact: true }).click();
      await page.waitForFunction(() => !document.querySelector('dialog[open]'));
      const edit = page.getByRole('button', { name: `编辑 ${client.client_id}`, exact: true });
      await edit.click().catch(async (error) => {
        console.error({ body: await page.locator('body').innerText(), crashes });
        throw error;
      });
      const dialog = page.locator('dialog[open]');
      await dialog.getByRole('checkbox', { name: '启用 App', exact: true }).check();
      const callback = page.getByRole('textbox', { name: 'App 回调地址', exact: true });
      await callback.fill('com.cruty.stockme:/oidc/callback');
      await page.waitForFunction(() => document.querySelector('[aria-label="App 回调地址"]').getAttribute('aria-invalid') === 'true');
      const inline = dialog.locator('[role="alert"]').filter({ hasText: '机密客户端不能使用自定义 scheme' });
      assert.equal(await inline.count(), 1);
      assert.equal(writes.length, 0);
      await dialog.getByRole('button', { name: '保存应用', exact: true }).click();
      await page.waitForFunction(() => document.querySelector('.epass-notice')?.matches(':popover-open'));
      assert.equal(writes.length, 0, 'client validation must precede HTTP');
      assert.equal(await callback.inputValue(), 'com.cruty.stockme:/oidc/callback');
      assert.match(await page.locator('.epass-notice').innerText(), /App 直连请关闭/);
      const layer = await page.locator('.epass-notice').evaluate((notice) => {
        const rect = notice.getBoundingClientRect();
        const active = document.activeElement;
        const focusRetained = !!active.closest('dialog[open]') && !notice.contains(active);
        notice.style.pointerEvents = 'auto';
        const paintedAboveDialog = notice.contains(document.elementFromPoint(rect.x + rect.width / 2, rect.y + rect.height / 2));
        notice.style.pointerEvents = '';
        return { popover: notice.matches(':popover-open'), insideActiveDialog: !!notice.closest('dialog[open]'), paintedAboveDialog, focusRetained, withinViewport: rect.left >= 0 && rect.right <= innerWidth && rect.top >= 0 && rect.bottom <= innerHeight };
      });
      for (const [name, passed] of Object.entries(layer)) assert.equal(passed, true, `${engine}/${width}: ${name}`);
      await page.waitForFunction(() => Number(getComputedStyle(document.querySelector('.epass-notice')).opacity) >= 0.99);
      await page.screenshot({ path: path.join(output, `${engine}-${width}-conflict.png`) });

      // The correction clears field feedback immediately; an independent server
      // validation failure must still show its actual reason above the dialog.
      await callback.fill('https://api.example.com/app/callback');
      await inline.waitFor({ state: 'detached' });
      assert.equal(await inline.count(), 0);
      await dialog.getByRole('button', { name: '保存应用', exact: true }).click();
      await page.waitForFunction(() => document.querySelector('.epass-notice')?.textContent === 'Client ID 已被其他应用使用，请换一个。');
      assert.equal(writes.length, 1);
      assert.equal(await callback.inputValue(), 'https://api.example.com/app/callback');
      assert.equal(await dialog.count(), 1, 'failed save keeps the editor open');
      assert.equal(await page.locator('.epass-notice').evaluate((n) => n.matches(':popover-open') && !!n.closest('dialog[open]')), true);

      // Existing feedback survives closing and reopening a native modal.
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => !!document.activeElement.closest('dialog[open]')), true);
      await page.keyboard.press('Escape');
      await page.waitForFunction(() => !document.querySelector('dialog[open]') && document.querySelector('.epass-notice')?.parentElement === document.body);
      await edit.click();
      await page.waitForFunction(() => !!document.querySelector('.epass-notice')?.closest('dialog[open]'));
      await dialog.getByRole('checkbox', { name: '机密客户端', exact: true }).uncheck();
      rejectSave = false;
      await dialog.getByRole('button', { name: '保存应用', exact: true }).click();
      await page.waitForFunction(() => !document.querySelector('dialog[open]'));
      assert.equal(writes.length, 2);
      assert.equal(writes[1].is_confidential, false);
      assert.equal(writes[1].generate_client_secret, false);
      await page.waitForFunction(() => !document.querySelector('.epass-notice'), null, { timeout: 5000 }).catch(async (error) => {
        console.error(await page.locator('.epass-notice').evaluateAll((nodes) => nodes.map((node) => ({ text: node.textContent, parent: node.parentElement.tagName, state: node.dataset.motionState, open: node.matches(':popover-open') }))));
        console.error(crashes);
        throw error;
      });
      assert.deepEqual(crashes, []);
      results.push({ engine, width, immediateConflict: true, blockedInvalidRequest: true, layer, specificServerReason: true, retainedInput: true, keyboard: true, modalRehosting: true, validSave: true, cleanExit: true });
      await page.close();
    }
  } finally { await browser.close(); }
}
console.log(JSON.stringify({ output, results }, null, 2));
