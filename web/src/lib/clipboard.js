export async function copyText(text, {clipboard = globalThis.navigator?.clipboard, document = globalThis.document, secure = globalThis.isSecureContext} = {}) {
  if (secure && clipboard?.writeText) {
    try { await clipboard.writeText(text); return; } catch { /* Use the browser's user-activated fallback. */ }
  }
  const active = document.activeElement;
  const field = document.createElement('textarea');
  field.value = text;
  field.setAttribute('readonly', '');
  field.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0';
  document.body.append(field);
  try {
    field.select();
    if (!document.execCommand('copy')) throw new Error('复制失败，请手动选择代码复制。');
  } finally {
    field.remove();
    active?.focus({preventScroll:true});
  }
}
