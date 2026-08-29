import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/utils/auth_cookie.dart';
import 'package:test/test.dart';

void main() {
  test('uses a __Host refresh cookie for HTTPS production origins', () {
    final config = AppConfig.forTesting({
      'SERVER_BASE_URL': 'https://passport.example.com',
    });
    final cookie = buildRefreshTokenCookie(
      'refresh-value',
      config: config,
      maxAgeSeconds: 3600,
    );
    expect(cookie, startsWith('__Host-rosm_refresh_token='));
    expect(cookie, contains('HttpOnly'));
    expect(cookie, contains('Secure'));
    expect(cookie, contains('SameSite=Lax'));
  });

  test('keeps a localhost-compatible cookie name in development', () {
    final config = AppConfig.forTesting({
      'SERVER_BASE_URL': 'http://localhost:8080',
    });
    final cookie = buildRefreshTokenCookie(
      'refresh-value',
      config: config,
      maxAgeSeconds: 3600,
    );
    expect(cookie, startsWith('rosm_refresh_token='));
    expect(readRefreshTokenCookie(cookie, config), 'refresh-value');
  });
}
