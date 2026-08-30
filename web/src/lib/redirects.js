const REDIRECT_BASE_ORIGIN = 'https://passport.invalid';

export function normalizeInternalRedirect(value) {
  const candidate = `${value || ''}`.trim();
  if (
    !candidate.startsWith('/') ||
    candidate.startsWith('//') ||
    candidate.includes('\\')
  ) {
    return '';
  }

  try {
    const parsed = new URL(candidate, REDIRECT_BASE_ORIGIN);
    if (parsed.origin !== REDIRECT_BASE_ORIGIN) {
      return '';
    }
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch (_) {
    return '';
  }
}
