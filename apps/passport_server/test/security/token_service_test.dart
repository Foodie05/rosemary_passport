import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory keyDirectory;

  AppConfig config({String kid = 'active'}) => AppConfig.forTesting({
    'SERVER_BASE_URL': 'http://localhost:8080',
    'JWT_ISSUER': 'issuer',
    'JWT_AUDIENCE': 'audience',
    'JWT_ACTIVE_KID': kid,
    'JWT_SIGNING_KEYS_DIR': keyDirectory.path,
    'JWT_BINDING_KEY': 'binding-key-material-with-more-than-32-characters',
    'FIRST_PARTY_REFRESH_TOKEN_TTL_SECONDS': '1200',
    'FIRST_PARTY_REMEMBERED_REFRESH_TOKEN_TTL_SECONDS': '86400',
    'REFRESH_TOKEN_TTL_SECONDS': '3600',
  });

  const user = AuthenticatedUser(
    id: 'user-1',
    email: 'user@example.com',
    phoneNumber: '+8613800000000',
    isPhoneVerified: true,
    nickname: 'User',
    roles: ['user'],
  );

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
    final service = TokenService(config());
    final pair = service.issueTokenPair(
      user,
      rememberSession: true,
      nonce: ' nonce-value ',
    );

    expect(pair.expiresIn, 900);
    expect(pair.refreshExpiresIn, 3600);
    expect(service.verify(pair.accessToken)?.payload['sid'], pair.familyId);
    expect(
      service.verify(pair.refreshToken, expectedType: 'refresh'),
      isNotNull,
    );
    expect(service.jwkSet()['keys'], hasLength(2));
    expect(pair.toJson(), containsPair('id_token', pair.idToken));
    final idPayload = Map<String, dynamic>.from(
      JWT.decode(pair.idToken!).payload as Map,
    );
    expect(idPayload['nonce'], 'nonce-value');
    expect(idPayload['phone_number'], user.phoneNumber);
    expect(idPayload['phone_number_verified'], isTrue);
    expect(service.firstPartyRefreshTokenTtlSeconds(rememberMe: false), 1200);
    expect(service.firstPartyRefreshTokenTtlSeconds(rememberMe: true), 86400);
  });

  test('active keyring verifies a token issued by the retiring key', () {
    const user = AuthenticatedUser(
      id: 'user-legacy',
      email: 'legacy@example.com',
      nickname: 'Legacy',
      roles: ['user'],
    );
    final oldPair = TokenService(config(kid: 'previous')).issueTokenPair(user);
    final current = TokenService(config());
    expect(current.verify(oldPair.accessToken), isNotNull);
    expect(
      current.verify(oldPair.refreshToken, expectedType: 'refresh'),
      isNotNull,
    );
  });

  test('omits optional identity claims and id token without OIDC scope', () {
    final service = TokenService(config());
    const minimalUser = AuthenticatedUser(
      id: 'minimal-user',
      email: 'minimal@example.com',
      nickname: 'Minimal',
      roles: ['user'],
    );
    final pair = service.issueTokenPair(
      minimalUser,
      scopes: const [],
      nonce: '   ',
      familyId: 'fixed-family',
      refreshTokenTtlSeconds: 42,
    );
    expect(pair.familyId, 'fixed-family');
    expect(pair.refreshExpiresIn, 42);
    expect(pair.idToken, isNull);
    expect(pair.toJson(), isNot(contains('id_token')));
  });

  test('rejects malformed, mistyped, and incorrectly signed tokens', () {
    final service = TokenService(config());
    final privateKey = RSAPrivateKey(
      File('${keyDirectory.path}/active.private.pem').readAsStringSync(),
    );

    String sign(
      Map<String, dynamic> payload, {
      String kid = 'active',
      String issuer = 'issuer',
      String audience = 'audience',
    }) => JWT(
      payload,
      issuer: issuer,
      audience: Audience([audience]),
      header: {'kid': kid},
    ).sign(privateKey, algorithm: JWTAlgorithm.RS256);

    expect(service.verify('not-a-jwt'), isNull);
    expect(
      service.verify(
        service.issueTokenPair(user).accessToken,
        expectedType: 'refresh',
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({
          'sub': user.id,
          'jti': 'unknown-key-token',
          'typ': 'access',
          'sig2': 'invalid',
        }, kid: 'unknown'),
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({'sub': user.id, 'jti': 'missing-fields', 'typ': 'access'}),
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({
          'sub': user.id,
          'jti': 'bad-binding-short',
          'typ': 'access',
          'sig2': 'short',
        }),
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({
          'sub': user.id,
          'jti': 'bad-binding-same-length',
          'typ': 'access',
          'sig2': 'x' * 44,
        }),
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({
          'sub': user.id,
          'jti': 'wrong-audience',
          'typ': 'access',
          'sig2': 'invalid',
        }, audience: 'other-audience'),
      ),
      isNull,
    );
    expect(
      service.verify(
        sign({
          'sub': user.id,
          'jti': 'wrong-issuer',
          'typ': 'access',
          'sig2': 'invalid',
        }, issuer: 'other-issuer'),
      ),
      isNull,
    );
    final symmetric = JWT(
      {'sub': user.id},
      header: {'kid': 'active'},
    ).sign(SecretKey('symmetric-secret'), algorithm: JWTAlgorithm.HS256);
    expect(service.verify(symmetric), isNull);
  });
}
