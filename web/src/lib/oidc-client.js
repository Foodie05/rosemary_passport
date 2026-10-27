export const CONFIDENTIAL_REDIRECT_MESSAGE = '机密客户端不能使用自定义 scheme 回调。App 直连请关闭“机密客户端”；服务端交接请改用 HTTPS 回调。';

function lines(value) {
  return [...new Set(String(value || '').split('\n').map((item) => item.trim()).filter(Boolean))];
}

export function oidcClientRedirectUris(form) {
  return [...new Set([
    ...(form.enable_web ? lines(form.web_redirect_uris ?? form.redirect_uris) : []),
    ...(form.enable_app ? lines(form.app_redirect_uri) : []),
  ])];
}

function redirectError(value, isConfidential) {
  let uri;
  try { uri = new URL(value); } catch { return '回调地址格式不正确，请填写完整地址。'; }
  if (uri.hash || uri.username || uri.password) return '回调地址不能包含用户名、密码或 # 片段。';
  if (uri.protocol === 'https:' && /^https:\/\//i.test(value)) return '';
  if (uri.protocol === 'http:' && /^http:\/\//i.test(value)) {
    return ['localhost', '127.0.0.1'].includes(uri.hostname) ? '' : 'HTTP 回调仅可使用 localhost 或 127.0.0.1；线上请使用 HTTPS。';
  }
  if (['about:', 'data:', 'file:', 'ftp:', 'http:', 'https:', 'javascript:', 'mailto:', 'tel:'].includes(uri.protocol)) {
    return '回调地址须使用 HTTPS、本机回环 HTTP 或 App 自定义 scheme。';
  }
  if (isConfidential) return CONFIDENTIAL_REDIRECT_MESSAGE;
  return uri.pathname || uri.hostname ? '' : 'App 回调地址须包含路径，例如 com.example.app:/oidc/callback。';
}

export function validateOidcClient(form) {
  const errors = {};
  if (!String(form.client_id || '').trim()) errors.client_id = '请填写 Client ID。';
  if (!form.enable_web && !form.enable_app) errors.redirect_uris = '请至少启用 Web 或 App，并填写回调地址。';
  for (const [enabled, field, value, missing] of [
    [form.enable_web, 'web_redirect_uris', form.web_redirect_uris ?? form.redirect_uris, '请填写至少一个 Web 回调地址。'],
    [form.enable_app, 'app_redirect_uri', form.app_redirect_uri, '请填写 App 回调地址。'],
  ]) {
    if (!enabled) continue;
    const redirects = lines(value);
    const error = redirects.map((uri) => redirectError(uri, form.is_confidential)).find(Boolean);
    if (!redirects.length || error) errors[field] = error || missing;
  }
  return errors;
}
