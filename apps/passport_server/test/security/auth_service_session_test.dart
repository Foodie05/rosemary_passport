import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/repositories/oidc_repository.dart';
import 'package:rosm_passport_server/src/repositories/settings_repository.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_service.dart';
import 'package:rosm_passport_server/src/services/captcha_service.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/security_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswordHasher extends Mock implements PasswordHasher {}

class _MockTokenService extends Mock implements TokenService {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

class _MockCaptcha extends Mock implements CaptchaService {}

class _MockOidcRepository extends Mock implements OidcRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockAudit extends Mock implements AuditService {}

class _MockWebAuthn extends Mock implements WebAuthnService {}

class _MockSecurity extends Mock implements SecurityService {}

class _MockSecurityPolicy extends Mock implements SecurityPolicyService {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: '+8613800000000',
    nickname: 'User',
    passwordHash: 'password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: true,
  );
  const bootstrapAdmin = UserRecord(
    id: 'admin-id',
    email: 'bootstrap@rosm.local',
    phoneNumber: null,
    nickname: 'Admin',
    passwordHash: 'admin-password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['admin'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  const pair = TokenPair(
    accessToken: 'new-access-token',
    refreshToken: 'new-refresh-token',
    expiresIn: 900,
    tokenType: 'Bearer',
    accessTokenId: 'new-access-id',
    refreshTokenId: 'new-refresh-id',
    familyId: 'family-id',
    refreshExpiresIn: 1200,
  );

  late _MockUsers users;
  late _MockPasswordHasher passwordHasher;
  late _MockTokenService tokens;
  late _MockEmailCodes emailCodes;
  late _MockCaptcha captcha;
  late _MockOidcRepository oidc;
  late _MockSettings settings;
  late _MockAudit audit;
  late _MockWebAuthn webAuthn;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(
      const AuthenticatedUser(
        id: 'fallback',
        email: 'fallback@example.invalid',
        nickname: 'Fallback',
        roles: ['user'],
      ),
    );
    registerFallbackValue(DateTime.utc(2026));
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    users = _MockUsers();
    passwordHasher = _MockPasswordHasher();
    tokens = _MockTokenService();
    emailCodes = _MockEmailCodes();
    captcha = _MockCaptcha();
    oidc = _MockOidcRepository();
    settings = _MockSettings();
    audit = _MockAudit();
    webAuthn = _MockWebAuthn();
    service = AuthService(
      userRepository: users,
      passwordHasher: passwordHasher,
      passwordPolicy: PasswordPolicy(),
      tokenService: tokens,
      emailCodeService: emailCodes,
      captchaService: captcha,
      oidcRepository: oidc,
      settingsRepository: settings,
      auditService: audit,
      webAuthnService: webAuthn,
    );
  });

  test(
    'bootstrap bypass requires an existing user and a valid password',
    () async {
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        await service.shouldBypassBootstrapCaptcha(
          email: 'missing@example.invalid',
          password: 'password',
        ),
        isFalse,
      );

      when(
        () => users.findByEmail(any()),
      ).thenAnswer((_) async => bootstrapAdmin);
      when(
        () => passwordHasher.verify(any(), any()),
      ).thenAnswer((_) async => false);
      expect(
        await service.shouldBypassBootstrapCaptcha(
          email: bootstrapAdmin.email,
          password: 'wrong',
        ),
        isFalse,
      );

      when(
        () => passwordHasher.verify(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => settings.isBootstrapLoginEnabled(),
      ).thenAnswer((_) async => true);
      expect(
        await service.shouldBypassBootstrapCaptcha(
          email: bootstrapAdmin.email,
          password: 'correct',
        ),
        isTrue,
      );
      expect(service.mustBindAdminEmail(bootstrapAdmin), isTrue);
      expect(service.mustBindAdminEmail(user), isFalse);
    },
  );

  test(
    'security state is non-enumerating and includes configured factors',
    () async {
      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(await service.getSecurityState(userId: 'missing'), const {
        'has_passkey': false,
        'has_authenticator': false,
        'has_phone': false,
      });

      when(() => users.findById(any())).thenAnswer((_) async => user);
      when(
        () => webAuthn.hasCredentials(user.id),
      ).thenAnswer((_) async => true);
      expect(await service.getSecurityState(userId: user.id), const {
        'has_passkey': true,
        'has_authenticator': false,
        'has_phone': true,
      });
    },
  );

  test(
    'session issuance stores short-lived first-party token metadata',
    () async {
      final sessions = SessionService(
        userRepository: users,
        tokenService: tokens,
        oidcRepository: oidc,
        auditService: audit,
      );
      when(
        () => tokens.firstPartyRefreshTokenTtlSeconds(
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenReturn(1200);
      when(
        () => tokens.issueTokenPair(
          any(),
          clientId: any(named: 'clientId'),
          scopes: any(named: 'scopes'),
          nonce: any(named: 'nonce'),
          familyId: any(named: 'familyId'),
          refreshTokenTtlSeconds: any(named: 'refreshTokenTtlSeconds'),
          rememberSession: any(named: 'rememberSession'),
          additionalAccessClaims: any(named: 'additionalAccessClaims'),
        ),
      ).thenReturn(pair);
      when(() => tokens.accessTokenTtlSeconds).thenReturn(900);
      when(
        () => oidc.storeTokenPair(
          accessTokenId: any(named: 'accessTokenId'),
          refreshTokenId: any(named: 'refreshTokenId'),
          familyId: any(named: 'familyId'),
          userId: any(named: 'userId'),
          clientId: any(named: 'clientId'),
          accessExpiresAt: any(named: 'accessExpiresAt'),
          refreshExpiresAt: any(named: 'refreshExpiresAt'),
        ),
      ).thenAnswer((_) async {});

      final standard = await sessions.issueFirstPartyAuthResult(user);
      expect(standard.postRegistrationPasskeyBootstrap, isFalse);
      final bootstrap = await sessions.issueFirstPartyAuthResult(
        user,
        postRegistrationPasskeyBootstrap: true,
        rememberMe: true,
      );
      expect(bootstrap.postRegistrationPasskeyBootstrap, isTrue);
      final captured =
          verify(
                () => tokens.issueTokenPair(
                  any(),
                  clientId: any(named: 'clientId'),
                  scopes: any(named: 'scopes'),
                  nonce: any(named: 'nonce'),
                  familyId: any(named: 'familyId'),
                  refreshTokenTtlSeconds: any(named: 'refreshTokenTtlSeconds'),
                  rememberSession: true,
                  additionalAccessClaims: captureAny(
                    named: 'additionalAccessClaims',
                  ),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['post_register_passkey_bootstrap_until'], isA<int>());
      verify(
        () => oidc.storeTokenPair(
          accessTokenId: pair.accessTokenId,
          refreshTokenId: pair.refreshTokenId,
          familyId: pair.familyId,
          userId: user.id,
          clientId: 'first_party_web',
          accessExpiresAt: any(named: 'accessExpiresAt'),
          refreshExpiresAt: any(named: 'refreshExpiresAt'),
        ),
      ).called(2);
    },
  );

  test(
    'user-wide revocation can preserve the newly issued access token',
    () async {
      final sessions = SessionService(
        userRepository: users,
        tokenService: tokens,
        oidcRepository: oidc,
        auditService: audit,
      );
      when(
        () => oidc.revokeRefreshTokensForUser(user.id),
      ).thenAnswer((_) async {});
      when(
        () => oidc.revokeAccessTokensForUser(user.id),
      ).thenAnswer((_) async {});
      when(
        () => oidc.revokeAccessTokensForUserExcept(user.id, 'preserved-id'),
      ).thenAnswer((_) async {});

      await sessions.revokeAllUserSessions(user.id);
      await sessions.revokeAllUserSessions(
        user.id,
        preservedAccessTokenId: 'preserved-id',
      );
      verify(() => oidc.revokeAccessTokensForUser(user.id)).called(1);
      verify(
        () => oidc.revokeAccessTokensForUserExcept(user.id, 'preserved-id'),
      ).called(1);
    },
  );

  test(
    'refresh enforces configured IP throttling before token validation',
    () async {
      final security = _MockSecurity();
      final policy = _MockSecurityPolicy();
      final sessions = SessionService(
        userRepository: users,
        tokenService: tokens,
        oidcRepository: oidc,
        auditService: audit,
        securityService: security,
        securityPolicyService: policy,
      );
      when(
        () => policy.load(),
      ).thenAnswer((_) async => SecurityPolicyService.defaultPolicy);
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
        await sessions.refreshForClient(
          'token',
          clientId: 'first_party_web',
          requestIp: ' 192.0.2.1 ',
        ),
        isNull,
      );
      verify(
        () => security.enforce(
          scope: 'refresh:first_party_web:ip',
          subject: '192.0.2.1',
          limit: any(named: 'limit'),
          window: any(named: 'window'),
          blockDuration: any(named: 'blockDuration'),
        ),
      ).called(1);
      verifyNever(
        () => tokens.verify(any(), expectedType: any(named: 'expectedType')),
      );
    },
  );

  test(
    'refresh rejects invalid binding, client, family, and user states',
    () async {
      when(
        () => tokens.verify(any(), expectedType: 'refresh'),
      ).thenReturn(null);
      expect(await service.refresh('invalid'), isNull);

      when(() => tokens.verify(any(), expectedType: 'refresh')).thenReturn(
        const VerifiedToken(
          payload: {
            'jti': 'old-refresh-id',
            'sub': 'user-id',
            'client_id': 'other-client',
            'remember': false,
          },
        ),
      );
      expect(
        await service.refreshForClient('token', clientId: 'first_party_web'),
        isNull,
      );

      when(() => tokens.verify(any(), expectedType: 'refresh')).thenReturn(
        const VerifiedToken(
          payload: {
            'jti': 'old-refresh-id',
            'sub': 'user-id',
            'client_id': 'first_party_web',
            'remember': false,
          },
        ),
      );
      when(() => oidc.findRefreshToken(any())).thenAnswer((_) async => null);
      expect(await service.refresh('token'), isNull);

      when(() => oidc.findRefreshToken(any())).thenAnswer(
        (_) async => {'client_id': 'first_party_web', 'family_id': ''},
      );
      expect(await service.refresh('token'), isNull);

      when(() => oidc.findRefreshToken(any())).thenAnswer(
        (_) async => {'client_id': 'first_party_web', 'family_id': 'family-id'},
      );
      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(await service.refresh('token'), isNull);
    },
  );

  test(
    'refresh rotates once and audits reuse without returning a token',
    () async {
      when(() => tokens.verify(any(), expectedType: 'refresh')).thenReturn(
        const VerifiedToken(
          payload: {
            'jti': 'old-refresh-id',
            'sub': 'user-id',
            'client_id': 'first_party_web',
            'remember': false,
          },
        ),
      );
      when(() => oidc.findRefreshToken(any())).thenAnswer(
        (_) async => {'client_id': 'first_party_web', 'family_id': 'family-id'},
      );
      when(() => users.findById(user.id)).thenAnswer((_) async => user);
      when(
        () => tokens.firstPartyRefreshTokenTtlSeconds(rememberMe: false),
      ).thenReturn(1200);
      when(
        () => tokens.issueTokenPair(
          any(),
          clientId: 'first_party_web',
          familyId: 'family-id',
          refreshTokenTtlSeconds: 1200,
          rememberSession: false,
        ),
      ).thenReturn(pair);
      when(() => tokens.accessTokenTtlSeconds).thenReturn(900);
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
      expect(await service.refresh('token'), same(pair));

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
      ).thenAnswer((_) async => RefreshRotationStatus.reused);
      when(
        () => audit.log(
          action: any(named: 'action'),
          actorId: any(named: 'actorId'),
          actorType: any(named: 'actorType'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          metadata: any(named: 'metadata'),
          ip: any(named: 'ip'),
        ),
      ).thenAnswer((_) async {});
      expect(
        await service.refreshForClient(
          'token',
          clientId: 'first_party_web',
          requestIp: '127.0.0.1',
        ),
        isNull,
      );
      verify(
        () => audit.log(
          action: 'session.refresh_reuse_detected',
          actorId: user.id,
          actorType: 'user',
          resourceType: 'token_family',
          resourceId: 'family-id',
          metadata: {'client_id': 'first_party_web'},
          ip: '127.0.0.1',
        ),
      ).called(1);
    },
  );

  test(
    'logout revokes a family or falls back to the access token id',
    () async {
      when(() => tokens.verify('access', expectedType: 'access')).thenReturn(
        const VerifiedToken(
          payload: {'jti': 'access-id', 'sub': 'user-id', 'sid': 'family-id'},
        ),
      );
      when(() => tokens.verify('refresh', expectedType: 'refresh')).thenReturn(
        const VerifiedToken(
          payload: {'jti': 'refresh-id', 'sub': 'user-id', 'sid': 'family-id'},
        ),
      );
      when(() => oidc.revokeTokenFamily(any())).thenAnswer((_) async {});
      when(
        () => audit.log(
          action: any(named: 'action'),
          actorId: any(named: 'actorId'),
          actorType: any(named: 'actorType'),
          resourceType: any(named: 'resourceType'),
          resourceId: any(named: 'resourceId'),
          metadata: any(named: 'metadata'),
          ip: any(named: 'ip'),
        ),
      ).thenAnswer((_) async {});
      await service.logoutFirstPartySession(
        accessToken: 'access',
        refreshToken: 'refresh',
        requestIp: '127.0.0.1',
      );
      verify(() => oidc.revokeTokenFamily('family-id')).called(1);

      reset(tokens);
      when(
        () => tokens.verify('access-only', expectedType: 'access'),
      ).thenReturn(const VerifiedToken(payload: {'jti': 'access-only-id'}));
      when(() => oidc.revokeAccessToken(any())).thenAnswer((_) async {});
      await service.logoutFirstPartySession(accessToken: 'access-only');
      verify(() => oidc.revokeAccessToken('access-only-id')).called(1);
    },
  );
}
