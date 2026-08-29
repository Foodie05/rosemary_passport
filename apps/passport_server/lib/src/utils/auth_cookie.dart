import '../config/app_config.dart';

const kAccessTokenCookieName = 'rosm_access_token';
const kLegacyRefreshTokenCookieName = 'rosm_refresh_token';
const kSecureRefreshTokenCookieName = '__Host-rosm_refresh_token';

String buildAccessTokenCookie(
  String accessToken, {
  required AppConfig config,
  int? maxAgeSeconds,
}) {
  final attributes = <String>[
    '$kAccessTokenCookieName=$accessToken',
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    if (maxAgeSeconds != null && maxAgeSeconds > 0) 'Max-Age=$maxAgeSeconds',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String buildRefreshTokenCookie(
  String refreshToken, {
  required AppConfig config,
  required int maxAgeSeconds,
}) {
  final attributes = <String>[
    '${refreshTokenCookieName(config)}=$refreshToken',
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=$maxAgeSeconds',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String refreshTokenCookieName(AppConfig config) => _isSecureCookie(config)
    ? kSecureRefreshTokenCookieName
    : kLegacyRefreshTokenCookieName;

String? readRefreshTokenCookie(String? header, AppConfig config) {
  return readCookieValue(header, refreshTokenCookieName(config)) ??
      readCookieValue(header, kLegacyRefreshTokenCookieName);
}

String buildOidcConsentCookie(String token, {required AppConfig config}) {
  final attributes = <String>[
    'rosm_oidc_consent=$token',
    'Path=/oidc/authorize',
    'HttpOnly',
    'SameSite=Strict',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String buildExpiredAccessTokenCookie({required AppConfig config}) {
  final attributes = <String>[
    '$kAccessTokenCookieName=',
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=0',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String buildExpiredRefreshTokenCookie({required AppConfig config}) {
  final attributes = <String>[
    '${refreshTokenCookieName(config)}=',
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=0',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String buildExpiredOidcConsentCookie({required AppConfig config}) {
  final attributes = <String>[
    'rosm_oidc_consent=',
    'Path=/oidc/authorize',
    'HttpOnly',
    'SameSite=Strict',
    'Max-Age=0',
    if (_isSecureCookie(config)) 'Secure',
  ];
  return attributes.join('; ');
}

String? readCookieValue(String? header, String name) {
  if (header == null || header.trim().isEmpty) {
    return null;
  }

  for (final segment in header.split(';')) {
    final index = segment.indexOf('=');
    if (index <= 0) {
      continue;
    }
    final key = segment.substring(0, index).trim();
    if (key != name) {
      continue;
    }
    final value = segment.substring(index + 1).trim();
    return value.isEmpty ? null : Uri.decodeComponent(value);
  }
  return null;
}

bool _isSecureCookie(AppConfig config) {
  try {
    return Uri.parse(config.serverBaseUrl).scheme == 'https';
  } catch (_) {
    return false;
  }
}
