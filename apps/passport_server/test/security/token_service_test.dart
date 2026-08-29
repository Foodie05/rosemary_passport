import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory keyDirectory;

  setUpAll(() async {
    keyDirectory = await Directory.systemTemp.createTemp('rosm-jwt-test-');
    final privatePath = '${keyDirectory.path}/active.private.pem';
    final publicPath = '${keyDirectory.path}/active.public.pem';
    final generated = await Process.run('openssl', [
      'genrsa',
      '-out',
      privatePath,
      '2048',
    ]);
    expect(generated.exitCode, 0);
    final derived = await Process.run('openssl', [
      'rsa',
      '-in',
      privatePath,
      '-pubout',
      '-out',
      publicPath,
    ]);
    expect(derived.exitCode, 0);
    for (final kid in ['previous']) {
      final previousPrivatePath = '${keyDirectory.path}/$kid.private.pem';
      final previousPublicPath = '${keyDirectory.path}/$kid.public.pem';
      expect(
        (await Process.run('openssl', [
          'genrsa',
          '-out',
          previousPrivatePath,
          '2048',
        ])).exitCode,
        0,
      );
      expect(
        (await Process.run('openssl', [
          'rsa',
          '-in',
          previousPrivatePath,
          '-pubout',
          '-out',
          previousPublicPath,
        ])).exitCode,
        0,
      );
    }
  });

  tearDownAll(() => keyDirectory.delete(recursive: true));

  test('issues fixed short access tokens and verifies by kid', () {
    final service = TokenService(
      AppConfig.forTesting({
        'SERVER_BASE_URL': 'http://localhost:8080',
        'JWT_ISSUER': 'issuer',
        'JWT_AUDIENCE': 'audience',
        'JWT_ACTIVE_KID': 'active',
        'JWT_SIGNING_KEYS_DIR': keyDirectory.path,
        'JWT_BINDING_KEY': 'binding-key-material-with-more-than-32-characters',
        'ACCESS_TOKEN_TTL_SECONDS': '43200',
        'REFRESH_TOKEN_TTL_SECONDS': '3600',
      }),
    );
    const user = AuthenticatedUser(
      id: 'user-1',
      email: 'user@example.com',
      nickname: 'User',
      roles: ['user'],
    );
    final pair = service.issueTokenPair(user, rememberSession: true);

    expect(pair.expiresIn, 900);
    expect(pair.refreshExpiresIn, 3600);
    expect(service.verify(pair.accessToken)?.payload['sid'], pair.familyId);
    expect(
      service.verify(pair.refreshToken, expectedType: 'refresh'),
      isNotNull,
    );
    expect(service.jwkSet()['keys'], hasLength(2));
  });

  test('active keyring verifies a token issued by the retiring key', () {
    AppConfig config(String kid) => AppConfig.forTesting({
      'SERVER_BASE_URL': 'http://localhost:8080',
      'JWT_ISSUER': 'issuer',
      'JWT_AUDIENCE': 'audience',
      'JWT_ACTIVE_KID': kid,
      'JWT_SIGNING_KEYS_DIR': keyDirectory.path,
      'JWT_BINDING_KEY': 'binding-key-material-with-more-than-32-characters',
    });
    const user = AuthenticatedUser(
      id: 'user-legacy',
      email: 'legacy@example.com',
      nickname: 'Legacy',
      roles: ['user'],
    );
    final oldPair = TokenService(config('previous')).issueTokenPair(user);
    final current = TokenService(config('active'));
    expect(current.verify(oldPair.accessToken), isNotNull);
    expect(
      current.verify(oldPair.refreshToken, expectedType: 'refresh'),
      isNotNull,
    );
  });
}
