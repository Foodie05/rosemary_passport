import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/repositories/oidc_repository.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_service.dart';
import 'package:rosm_passport_server/src/services/oidc_service.dart';
import 'package:rosm_passport_server/src/services/security_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:rosm_passport_server/src/services/token_validation_service.dart';
import 'package:test/test.dart';

class _Users extends Mock implements UserRepository {}

class _Oidc extends Mock implements OidcRepository {}

class _Tokens extends Mock implements TokenService {}

class _Validation extends Mock implements TokenValidationService {}

class _Passwords extends Mock implements PasswordHasher {}

class _Security extends Mock implements SecurityService {}

class _Auth extends Mock implements AuthService {}

class _Audit extends Mock implements AuditService {}

const _admin = UserRecord(
  id: 'admin-id',
  email: 'admin@example.invalid',
  phoneNumber: null,
  nickname: 'Admin',
  passwordHash: 'hash',
  passkeyHash: null,
  securityCodeHash: null,
  authenticatorSecret: null,
  hasAuthenticator: true,
  roles: ['admin'],
  isEmailVerified: true,
  isPhoneVerified: false,
);
const _pair = TokenPair(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresIn: 900,
  tokenType: 'Bearer',
  accessTokenId: 'access-id',
  refreshTokenId: 'refresh-id',
  familyId: 'family-id',
  refreshExpiresIn: 3600,
);

void main() {
  late _Users users;
  late _Oidc oidc;
  late _Tokens tokens;
  late _Validation validation;
  late _Passwords passwords;
  late _Security security;
  late OidcService service;
  final config = AppConfig.forTesting({'OIDC_REQUIRE_PKCE': 'false'});

  setUpAll(() {
    registerFallbackValue(_admin.toAuthenticatedUser());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DateTime.utc(2026));
  });
  setUp(() {
    users = _Users();
    oidc = _Oidc();
    tokens = _Tokens();
    validation = _Validation();
    passwords = _Passwords();
    security = _Security();
    when(() => users.findById(any())).thenAnswer((_) async => _admin);
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => const ThrottleDecision(allowed: true));
    service = OidcService(
      config: config,
      oidcRepository: oidc,
      userRepository: users,
      tokenService: tokens,
      tokenValidationService: validation,
      passwordHasher: passwords,
      authService: _Auth(),
      securityService: security,
    );
  });

  test('the first-party client identifier cannot be issued by OIDC', () async {
    expect(await service.findClient('first_party_web'), isNull);
    expect(
      await service.authorize(
        clientId: 'first_party_web',
        redirectUri: 'https://rp.invalid',
        responseType: 'code',
        scope: 'openid',
        user: _admin.toAuthenticatedUser(),
        nonce: 'nonce',
      ),
      isNull,
    );
    expect(
      await service.exchangeCode(
        code: 'code',
        clientId: 'first_party_web',
        redirectUri: 'https://rp.invalid',
        clientSecret: 'secret',
        codeVerifier: null,
      ),
      isNull,
    );
    verifyNever(() => oidc.findClient(any()));
    verifyNever(() => passwords.verify(any(), any()));
  });

  test(
    'all client-secret entry points reject before hashing when admission is denied',
    () async {
      when(
        () => security.enforce(
          scope: any(named: 'scope'),
          subject: any(named: 'subject'),
          limit: any(named: 'limit'),
          window: any(named: 'window'),
          blockDuration: any(named: 'blockDuration'),
        ),
      ).thenAnswer((_) async => const ThrottleDecision(allowed: false));
      expect(
        await service.exchangeCode(
          code: 'code',
          clientId: 'rp',
          redirectUri: 'https://rp.invalid',
          clientSecret: 'bad',
          codeVerifier: null,
        ),
        isNull,
      );
      expect(
        await service.refreshTokenGrant(
          refreshToken: 'refresh',
          clientId: 'rp',
          clientSecret: 'bad',
        ),
        isNull,
      );
      expect(
        await service.introspect(
          token: 'token',
          clientId: 'rp',
          clientSecret: 'bad',
        ),
        isNull,
      );
      expect(
        await service.revoke(
          token: 'token',
          clientId: 'rp',
          clientSecret: 'bad',
        ),
        isNull,
      );
      expect(
        await service.authenticateControlClient(
          clientId: 'rp',
          clientSecret: 'bad',
        ),
        isFalse,
      );
      expect(
        await service.authenticateRevocationClient(
          clientId: 'rp',
          clientSecret: 'bad',
        ),
        isFalse,
      );
      verifyNever(() => passwords.verify(any(), any()));
      verifyNever(() => oidc.consumeAuthCode(any()));
    },
  );

  test(
    'valid client revocation authenticates once and preserves unknown-token semantics',
    () async {
      when(() => oidc.findClient('rp')).thenAnswer(
        (_) async => {'is_confidential': true, 'client_secret_hash': 'hash'},
      );
      when(
        () => passwords.verify('hash', 'secret'),
      ).thenAnswer((_) async => true);
      when(
        () => validation.verifyActiveAccessToken('unknown'),
      ).thenAnswer((_) async => null);
      when(
        () => validation.verifyActiveRefreshToken('unknown'),
      ).thenAnswer((_) async => null);
      expect(
        await service.revoke(
          token: 'unknown',
          clientId: 'rp',
          clientSecret: 'secret',
        ),
        isFalse,
      );
      verify(() => passwords.verify('hash', 'secret')).called(1);
    },
  );

  test(
    'invalid secrets cannot exhaust the same application budget for another IP',
    () async {
      final hits = <String, int>{};
      when(
        () => security.enforce(
          scope: any(named: 'scope'),
          subject: any(named: 'subject'),
          limit: any(named: 'limit'),
          window: any(named: 'window'),
          blockDuration: any(named: 'blockDuration'),
        ),
      ).thenAnswer((invocation) async {
        final subject = invocation.namedArguments[#subject] as String;
        final count = hits.update(subject, (old) => old + 1, ifAbsent: () => 1);
        return ThrottleDecision(
          allowed: count <= (invocation.namedArguments[#limit] as int),
        );
      });
      when(() => oidc.findClient('rp')).thenAnswer(
        (_) async => {'is_confidential': true, 'client_secret_hash': 'hash'},
      );
      when(
        () => passwords.verify('hash', 'secret'),
      ).thenAnswer((_) async => true);
      when(
        () => validation.verifyActiveAccessToken('unknown'),
      ).thenAnswer((_) async => null);
      when(
        () => validation.verifyActiveRefreshToken('unknown'),
      ).thenAnswer((_) async => null);
      for (var attempt = 0; attempt < 31; attempt++) {
        expect(
          await service.revoke(
            token: 'unknown',
            clientId: 'rp',
            clientSecret: null,
            requestIp: '192.0.2.1',
          ),
          isNull,
        );
      }
      expect(
        await service.revoke(
          token: 'unknown',
          clientId: 'rp',
          clientSecret: 'secret',
          requestIp: '192.0.2.2',
        ),
        isFalse,
      );
      expect(hits, containsPair(jsonEncode(['rp', '192.0.2.2']), 1));
      verify(() => passwords.verify('hash', 'secret')).called(1);
    },
  );

  test(
    'refresh retains or narrows scopes and rejects unknown legacy delegated grants',
    () async {
      final sessions = SessionService(
        userRepository: users,
        tokenService: tokens,
        oidcRepository: oidc,
        auditService: _Audit(),
      );
      when(() => tokens.accessTokenTtlSeconds).thenReturn(900);
      when(() => tokens.refreshTokenTtlSeconds).thenReturn(3600);
      when(
        () => tokens.firstPartyRefreshTokenTtlSeconds(
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenReturn(3600);
      when(
        () => oidc.findRefreshToken(any()),
      ).thenAnswer((_) async => {'client_id': 'rp', 'family_id': 'family-id'});
      when(() => oidc.findClient('rp')).thenAnswer(
        (_) async => {
          'scopes': ['openid', 'profile', 'email'],
          'grant_types': ['refresh_token'],
        },
      );
      when(
        () => tokens.issueTokenPair(
          any(),
          scopes: any(named: 'scopes'),
          clientId: any(named: 'clientId'),
          familyId: any(named: 'familyId'),
          refreshTokenTtlSeconds: any(named: 'refreshTokenTtlSeconds'),
          rememberSession: any(named: 'rememberSession'),
        ),
      ).thenReturn(_pair);
      when(
        () => oidc.rotateRefreshToken(
          oldTokenId: any(named: 'oldTokenId'),
          newAccessTokenId: any(named: 'newAccessTokenId'),
          newRefreshTokenId: any(named: 'newRefreshTokenId'),
          familyId: any(named: 'familyId'),
          userId: any(named: 'userId'),
          clientId: any(named: 'clientId'),
          accessExpiresAt: any(named: 'accessExpiresAt'),
          refreshExpiresAt: any(named: 'refreshExpiresAt'),
        ),
      ).thenAnswer((_) async => RefreshRotationStatus.success);
      for (final scope in [
        'openid',
        'openid phone',
        '',
        null,
        ['openid'],
      ]) {
        when(
          () => tokens.verify('refresh', expectedType: 'refresh'),
        ).thenReturn(
          VerifiedToken(
            payload: {
              'jti': 'old',
              'sub': _admin.id,
              'client_id': 'rp',
              if (scope != null) 'scope': scope,
            },
          ),
        );
        final pair = await sessions.refreshForClient('refresh', clientId: 'rp');
        if (scope is! String) {
          expect(pair, isNull);
          continue;
        }
        expect(pair, _pair);
        final granted = verify(
          () => tokens.issueTokenPair(
            any(),
            scopes: captureAny(named: 'scopes'),
            clientId: 'rp',
            familyId: 'family-id',
            refreshTokenTtlSeconds: 3600,
            rememberSession: false,
          ),
        ).captured.single;
        expect(granted, scope.isEmpty ? isEmpty : ['openid']);
      }
      when(() => oidc.findClient('rp')).thenAnswer(
        (_) async => {
          'scopes': ['openid'],
          'grant_types': ['authorization_code'],
        },
      );
      when(() => tokens.verify('refresh', expectedType: 'refresh')).thenReturn(
        const VerifiedToken(
          payload: {
            'jti': 'old',
            'sub': 'admin-id',
            'client_id': 'rp',
            'scope': 'openid',
          },
        ),
      );
      expect(
        await sessions.refreshForClient('refresh', clientId: 'rp'),
        isNull,
      );
    },
  );
}
