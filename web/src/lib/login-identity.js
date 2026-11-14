import { normalizeInternalRedirect } from './redirects.js';

// Match the server's supported email and mainland mobile formats. This only
// selects the existing code flow; it never queries whether an account exists.
export function resolveCodeLoginIdentifier(raw) {
  const identifier = `${raw || ''}`.trim();
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(identifier)) {
    return { method: 'email_code', identifier };
  }
  let phone = identifier.replace(/[\s\-()]/g, '');
  if (phone.startsWith('+86')) phone = phone.slice(3);
  else if (phone.startsWith('86') && phone.length === 13) phone = phone.slice(2);
  return /^1\d{10}$/.test(phone) ? { method: 'phone_code', identifier: phone } : null;
}

export function isAuthorizationLogin(next) {
  const internal = normalizeInternalRedirect(next);
  if (!internal) return false;
  const parsed = new URL(internal, 'https://passport.invalid');
  return parsed.pathname === '/oidc/continue' && Boolean(parsed.searchParams.get('client_id'));
}
