const AUTHORIZATION_PARAMETER_NAMES = new Set([
  'client_id',
  'redirect_uri',
  'response_type',
  'scope',
  'state',
  'nonce',
  'code_challenge',
  'code_challenge_method',
  'decision',
  'consent_token',
]);

export function oidcAuthorizationParameters(search) {
  return Array.from(new URLSearchParams(search).entries())
    .filter(([name]) => AUTHORIZATION_PARAMETER_NAMES.has(name));
}
