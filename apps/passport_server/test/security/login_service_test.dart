import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/repositories/settings_repository.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/authenticator_service.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/login_service.dart';
import 'package:rosm_passport_server/src/services/phone_verification_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockTokens extends Mock implements TokenService {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

class _MockThrottles extends Mock implements AuthThrottleService {}

class _MockSessions extends Mock implements SessionService {}

class _MockAudit extends Mock implements AuditService {}

class _MockAuthenticator extends Mock implements AuthenticatorService {}

class _MockPhones extends Mock implements PhoneVerificationService {}

class _MockWebAuthn extends Mock implements WebAuthnService {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: '+8613800000000',
    nickname: 'User',
    passwordHash: 'password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: 'encrypted-secret',
    hasAuthenticator: true,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: true,
  );
  const bootstrap = UserRecord(
    id: 'admin-id',
    email: 'bootstrap@rosm.local',
    phoneNumber: null,
    nickname: 'Admin',
    passwordHash: 'admin-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['admin'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  const boundAdmin = UserRecord(
    id: 'bound-admin-id',
    email: 'admin@example.invalid',
    phoneNumber: null,
    nickname: 'Bound Admin',
    passwordHash: 'bound-admin-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['admin'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  const tokenPair = TokenPair(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresIn: 900,
    tokenType: 'Bearer',
    accessTokenId: 'access-id',
    refreshTokenId: 'refresh-id',
    familyId: 'family-id',
    refreshExpiresIn: 1200,
  );
  const auth = AuthResult(
    user: AuthenticatedUser(
      id: 'user-id',
      email: 'user@example.invalid',
      nickname: 'User',
      roles: ['user'],
    ),
    tokens: tokenPair,
  );

  late _MockUsers users;
  late _MockSettings settings;
  late _MockPasswords passwords;
  late _MockTokens tokens;
  late _MockEmailCodes emailCodes;
  late _MockThrottles throttles;
  late _MockSessions sessions;
  late _MockAudit audit;
  late _MockAuthenticator authenticator;
  late _MockPhones phones;
  late _MockWebAuthn webAuthn;
  late LoginService service;

  setUpAll(() {
    registerFallbackValue(SecurityPolicyService.defaultPolicy);
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    users = _MockUsers();
    settings = _MockSettings();
    passwords = _MockPasswords();
    tokens = _MockTokens();
    emailCodes = _MockEmailCodes();
    throttles = _MockThrottles();
    sessions = _MockSessions();
    audit = _MockAudit();
    authenticator = _MockAuthenticator();
    phones = _MockPhones();
    webAuthn = _MockWebAuthn();
    service = LoginService(
      userRepository: users,
      settingsRepository: settings,
      passwordHasher: passwords,
      tokenService: tokens,
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      auditService: audit,
      authenticatorService: authenticator,
      phoneVerificationService: phones,
      webAuthnService: webAuthn,
    );
  });

  void stubPolicy() {
    when(
      () => throttles.loadPolicy(),
    ).thenAnswer((_) async => SecurityPolicyService.defaultPolicy);
  }

  void stubAllowedGuards() {
    stubPolicy();
    when(
      () => throttles.enforceLoginGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => throttles.enforceVerificationCodeSendGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        policy: any(named: 'policy'),
        emailScope: any(named: 'emailScope'),
        ipScope: any(named: 'ipScope'),
        cooldownScope: any(named: 'cooldownScope'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
      ),
    ).thenAnswer((_) async => null);
  }

  void stubLoginCompletion([UserRecord target = user]) {
    when(
      () => sessions.issueFirstPartyAuthResult(
        target,
        postRegistrationPasskeyBootstrap: any(
          named: 'postRegistrationPasskeyBootstrap',
        ),
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => auth);
    when(
      () => throttles.clearLoginGuards(email: any(named: 'email')),
    ).thenAnswer((_) async {});
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
  }

  test(
    'password email-code send is rate limited and non-enumerating',
    () async {
      stubPolicy();
      when(
        () => throttles.enforceVerificationCodeSendGuards(
          email: any(named: 'email'),
          requestIp: any(named: 'requestIp'),
          policy: any(named: 'policy'),
          emailScope: any(named: 'emailScope'),
          ipScope: any(named: 'ipScope'),
          cooldownScope: any(named: 'cooldownScope'),
          emailLimit: any(named: 'emailLimit'),
          ipLimit: any(named: 'ipLimit'),
        ),
      ).thenAnswer(
        (_) async => const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: 'limited',
          statusCode: 429,
        ),
      );
      expect(
        (await service.sendPasswordEmailCode(
          email: user.email,
          password: 'password',
        )).statusCode,
        429,
      );

      stubAllowedGuards();
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        (await service.sendPasswordEmailCode(
          email: user.email,
          password: 'password',
        )).code,
        'login_failed',
      );
      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      when(
        () => emailCodes.issueLoginCode(
          user.email,
          templateName: any(named: 'templateName'),
        ),
      ).thenAnswer((_) async => 'code-id');
      when(
        () => throttles.startVerificationCodeCooldown(
          email: any(named: 'email'),
          seconds: any(named: 'seconds'),
          cooldownScope: any(named: 'cooldownScope'),
        ),
      ).thenAnswer((_) async {});
      expect(
        (await service.sendPasswordEmailCode(
          email: user.email,
          password: 'password',
        )).ok,
        isTrue,
      );
    },
  );

  test('password phone-code send validates account and provider', () async {
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
    expect(
      (await service.sendPasswordPhoneCode(
        email: user.email,
        password: 'wrong',
      )).code,
      'login_failed',
    );
    final disabled = LoginService(
      userRepository: users,
      settingsRepository: settings,
      passwordHasher: passwords,
      tokenService: tokens,
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      auditService: audit,
    );
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    expect(
      (await disabled.sendPasswordPhoneCode(
        email: user.email,
        password: 'password',
      )).code,
      'mfa_not_available',
    );
    when(
      () => phones.sendCode(
        phoneNumber: any(named: 'phoneNumber'),
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer(
      (_) async => const PhoneVerificationAttempt.failure(
        code: 'provider_failed',
        message: 'failed',
        statusCode: 503,
      ),
    );
    expect(
      (await service.sendPasswordPhoneCode(
        email: user.email,
        password: 'password',
      )).code,
      'provider_failed',
    );
    when(
      () => phones.sendCode(
        phoneNumber: any(named: 'phoneNumber'),
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer(
      (_) async =>
          const PhoneVerificationAttempt.success(retryAfterSeconds: 45),
    );
    expect(
      (await service.sendPasswordPhoneCode(
        email: user.email,
        password: 'password',
      )).ok,
      isTrue,
    );
  });

  test(
    'password preparation returns available factors or bootstrap bypass',
    () async {
      stubAllowedGuards();
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        (await service.preparePasswordLogin(
          email: user.email,
          password: 'password',
        )).code,
        'login_failed',
      );
      when(() => users.findByEmail(any())).thenAnswer((_) async => bootstrap);
      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      when(
        () => settings.isBootstrapLoginEnabled(),
      ).thenAnswer((_) async => true);
      expect(
        (await service.preparePasswordLogin(
          email: bootstrap.email,
          password: 'password',
        )).directLogin,
        isTrue,
      );
      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      when(
        () => webAuthn.hasCredentials(user.id),
      ).thenAnswer((_) async => true);
      final prepared = await service.preparePasswordLogin(
        email: user.email,
        password: 'password',
      );
      expect(prepared.factors, [
        'phone_code',
        'email_code',
        'authenticator',
        'webauthn',
      ]);
    },
  );

  test('password preparation propagates login throttling', () async {
    stubPolicy();
    when(
      () => throttles.enforceLoginGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer(
      (_) async => const LoginAttempt.failure(
        code: 'rate_limited',
        message: 'limited',
        statusCode: 429,
      ),
    );
    expect(
      (await service.preparePasswordLogin(
        email: user.email,
        password: 'password',
      )).statusCode,
      429,
    );
  });

  test('email-code send delivers for every account state', () async {
    stubAllowedGuards();
    when(
      () => emailCodes.issueLoginCode(
        any(),
        templateName: any(named: 'templateName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => throttles.startVerificationCodeCooldown(
        email: any(named: 'email'),
        seconds: any(named: 'seconds'),
        cooldownScope: any(named: 'cooldownScope'),
      ),
    ).thenAnswer((_) async {});
    final missing = await service.sendEmailCode(email: user.email);
    expect(missing.ok, isTrue);
    when(
      () => emailCodes.issueLoginCode(
        user.email,
        templateName: any(named: 'templateName'),
      ),
    ).thenAnswer((_) async => 'code-id');
    final existing = await service.sendEmailCode(email: user.email);
    expect(existing.ok, isTrue);
    expect(existing.message, missing.message);
    when(
      () => emailCodes.issueLoginCode(
        boundAdmin.email,
        templateName: any(named: 'templateName'),
      ),
    ).thenAnswer((_) async => 'admin-code-id');
    final admin = await service.sendEmailCode(email: boundAdmin.email);
    expect(admin.ok, isTrue);
    verify(
      () => emailCodes.issueLoginCode(
        boundAdmin.email,
        templateName: 'login_verification',
      ),
    ).called(1);
    when(
      () => emailCodes.issueLoginCode(
        user.email,
        templateName: any(named: 'templateName'),
      ),
    ).thenThrow(StateError('provider unavailable'));
    final unavailable = await service.sendEmailCode(email: user.email);
    expect(unavailable.ok, isFalse);
    expect(unavailable.statusCode, 503);
    verifyNever(() => users.findByEmail(any()));
  });

  test('email-code send propagates throttling', () async {
    stubPolicy();
    when(
      () => throttles.enforceVerificationCodeSendGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        policy: any(named: 'policy'),
        emailScope: any(named: 'emailScope'),
        ipScope: any(named: 'ipScope'),
        cooldownScope: any(named: 'cooldownScope'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
      ),
    ).thenAnswer(
      (_) async => const AdminLoginCodeAttempt.failure(
        code: 'rate_limited',
        message: 'limited',
        statusCode: 429,
      ),
    );
    expect((await service.sendEmailCode(email: user.email)).statusCode, 429);
  });

  test(
    'direct email-code login propagates throttling before validation',
    () async {
      stubPolicy();
      when(
        () => throttles.enforceLoginGuards(
          email: any(named: 'email'),
          requestIp: any(named: 'requestIp'),
          emailLimit: any(named: 'emailLimit'),
          ipLimit: any(named: 'ipLimit'),
          window: any(named: 'window'),
          blockDuration: any(named: 'blockDuration'),
        ),
      ).thenAnswer(
        (_) async => const LoginAttempt.failure(
          code: 'rate_limited',
          message: 'limited',
          statusCode: 429,
        ),
      );

      final result = await service.loginWithEmailCode(
        email: user.email,
        emailCode: '123456',
      );

      expect(result.code, 'rate_limited');
      verifyNever(() => emailCodes.validateLoginCode(any(), any()));
    },
  );

  test('password login validates email-code single use', () async {
    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => false);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
      )).code,
      'mfa_required',
    );
    when(
      () => emailCodes.validateLoginCode(any(), any()),
    ).thenAnswer((_) async => null);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        emailCode: 'wrong',
      )).code,
      'mfa_required',
    );
    when(
      () => emailCodes.validateLoginCode(any(), any()),
    ).thenAnswer((_) async => 'code-id');
    stubLoginCompletion();
    when(
      () => emailCodes.consumeCode('code-id'),
    ).thenAnswer((_) async => false);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        emailCode: '123456',
      )).code,
      'mfa_required',
    );
    when(() => emailCodes.consumeCode('code-id')).thenAnswer((_) async => true);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        emailCode: '123456',
      )).ok,
      isTrue,
    );
  });

  test('password login handles guards, missing users, and bootstrap', () async {
    stubPolicy();
    when(
      () => throttles.enforceLoginGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer(
      (_) async => const LoginAttempt.failure(
        code: 'rate_limited',
        message: 'limited',
        statusCode: 429,
      ),
    );
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
      )).statusCode,
      429,
    );

    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
      )).code,
      'login_failed',
    );

    when(() => users.findByEmail(any())).thenAnswer((_) async => bootstrap);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => true);
    stubLoginCompletion(bootstrap);
    expect(
      (await service.loginWithPassword(
        email: bootstrap.email,
        password: 'password',
      )).ok,
      isTrue,
    );
  });

  test('password login rejects unavailable configured factors', () async {
    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => false);
    when(
      () => users.findAuthenticatorSecretByUserId(user.id),
    ).thenAnswer((_) async => null);
    final withoutFactors = LoginService(
      userRepository: users,
      settingsRepository: settings,
      passwordHasher: passwords,
      tokenService: tokens,
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      auditService: audit,
    );
    expect(
      (await withoutFactors.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'phone_code',
        phoneCode: '123456',
      )).code,
      'mfa_not_available',
    );
    expect(
      (await withoutFactors.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'authenticator',
        authenticatorCode: '123456',
      )).code,
      'mfa_not_available',
    );
  });

  test('password login supports phone and authenticator factors', () async {
    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => false);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'phone_code',
      )).code,
      'mfa_required',
    );
    when(
      () => phones.verifyCode(
        phoneNumber: any(named: 'phoneNumber'),
        verifyCode: any(named: 'verifyCode'),
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer(
      (_) async => const PhoneVerifyCheckAttempt.failure(
        code: 'invalid_code',
        message: 'bad code',
        statusCode: 401,
      ),
    );
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'phone_code',
        phoneCode: 'wrong',
      )).code,
      'invalid_code',
    );
    when(
      () => phones.verifyCode(
        phoneNumber: any(named: 'phoneNumber'),
        verifyCode: any(named: 'verifyCode'),
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer((_) async => const PhoneVerifyCheckAttempt.success());
    stubLoginCompletion();
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'phone_code',
        phoneCode: '123456',
      )).ok,
      isTrue,
    );

    when(
      () => users.findAuthenticatorSecretByUserId(user.id),
    ).thenAnswer((_) async => 'SECRET');
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'authenticator',
      )).code,
      'mfa_required',
    );
    when(
      () => authenticator.verifyCode(
        secret: any(named: 'secret'),
        code: any(named: 'code'),
      ),
    ).thenReturn(false);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'authenticator',
        authenticatorCode: '000000',
      )).code,
      'mfa_required',
    );
    when(
      () => authenticator.verifyCode(
        secret: any(named: 'secret'),
        code: any(named: 'code'),
      ),
    ).thenReturn(true);
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'authenticator',
        authenticatorCode: '123456',
      )).ok,
      isTrue,
    );
    expect(
      (await service.loginWithPassword(
        email: user.email,
        password: 'password',
        factorType: 'unknown',
      )).code,
      'invalid_factor',
    );
  });

  test(
    'direct email-code login guides registration and requires admin step-up',
    () async {
      stubAllowedGuards();
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      when(
        () => emailCodes.validateLoginCode(any(), any()),
      ).thenAnswer((_) async => 'new-code-id');
      when(
        () => emailCodes.consumeCode('new-code-id'),
      ).thenAnswer((_) async => false);
      expect(
        (await service.loginWithEmailCode(
          email: 'new@example.invalid',
          emailCode: '123456',
        )).code,
        'mfa_required',
      );
      when(
        () => emailCodes.consumeCode('new-code-id'),
      ).thenAnswer((_) async => true);
      when(
        () => tokens.issueRegistrationHandoff(
          method: 'email',
          subject: 'new@example.invalid',
        ),
      ).thenReturn('registration-handoff');
      expect(
        (await service.loginWithEmailCode(
          email: 'new@example.invalid',
          emailCode: '123456',
        )).registrationToken,
        'registration-handoff',
      );

      when(
        () => settings.isBootstrapLoginEnabled(),
      ).thenAnswer((_) async => true);
      when(() => users.findByEmail(any())).thenAnswer((_) async => bootstrap);
      when(
        () => emailCodes.validateLoginCode(any(), any()),
      ).thenAnswer((_) async => 'bootstrap-code-id');
      expect(
        (await service.loginWithEmailCode(
          email: bootstrap.email,
          emailCode: '123456',
        )).code,
        'login_failed',
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => boundAdmin);
      when(
        () => settings.isBootstrapLoginEnabled(),
      ).thenAnswer((_) async => false);
      when(() => passwords.verify(boundAdmin.passwordHash, any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments[1] == 'correct-password',
      );
      when(
        () => emailCodes.validateLoginCode(boundAdmin.email, any()),
      ).thenAnswer((_) async => 'admin-code-id');
      when(
        () => emailCodes.consumeCode('admin-code-id'),
      ).thenAnswer((_) async => true);
      when(
        () => webAuthn.hasCredentials(boundAdmin.id),
      ).thenAnswer((_) async => false);
      when(
        () => tokens.issueLoginStepUpChallenge(
          userId: boundAdmin.id,
          primaryMethod: 'email_code',
        ),
      ).thenReturn('step-up-challenge');
      expect(
        (await service.loginWithEmailCode(
          email: boundAdmin.email,
          emailCode: '123456',
        )).code,
        'mfa_required',
      );
      expect(
        (await service.loginWithEmailCode(
          email: boundAdmin.email,
          emailCode: '123456',
          password: 'wrong-password',
        )).code,
        'login_failed',
      );
      stubLoginCompletion(boundAdmin);
      expect(
        (await service.loginWithEmailCode(
          email: boundAdmin.email,
          emailCode: '123456',
          password: 'correct-password',
        )).ok,
        isTrue,
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      when(
        () => emailCodes.validateLoginCode(any(), any()),
      ).thenAnswer((_) async => 'code-id');
      when(
        () => emailCodes.consumeCode('code-id'),
      ).thenAnswer((_) async => true);
      stubLoginCompletion();
      expect(
        (await service.loginWithEmailCode(
          email: user.email,
          emailCode: '123456',
        )).ok,
        isTrue,
      );
    },
  );

  test('direct email-code login rejects invalid or reused codes', () async {
    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(
      () => emailCodes.validateLoginCode(any(), any()),
    ).thenAnswer((_) async => null);
    expect(
      (await service.loginWithEmailCode(
        email: user.email,
        emailCode: 'wrong',
      )).code,
      'mfa_required',
    );
    when(
      () => emailCodes.validateLoginCode(any(), any()),
    ).thenAnswer((_) async => 'code-id');
    when(
      () => emailCodes.consumeCode('code-id'),
    ).thenAnswer((_) async => false);
    when(
      () => sessions.issueFirstPartyAuthResult(
        user,
        postRegistrationPasskeyBootstrap: any(
          named: 'postRegistrationPasskeyBootstrap',
        ),
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => auth);
    expect(
      (await service.loginWithEmailCode(
        email: user.email,
        emailCode: '123456',
      )).code,
      'mfa_required',
    );
  });

  test(
    'direct login step-up excludes the primary factor and is one-time',
    () async {
      when(
        () => tokens.verifyLoginStepUpChallenge('step-up-challenge'),
      ).thenReturn(
        const VerifiedToken(
          payload: {
            'sub': 'bound-admin-id',
            'primary_method': 'email_code',
            'jti': 'step-up-id',
          },
        ),
      );
      when(
        () => users.findById(boundAdmin.id),
      ).thenAnswer((_) async => boundAdmin);
      when(
        () => webAuthn.hasCredentials(boundAdmin.id),
      ).thenAnswer((_) async => false);
      when(
        () => passwords.verify(boundAdmin.passwordHash, 'correct-password'),
      ).thenAnswer((_) async => true);
      var proofConsumed = false;
      when(() => throttles.consumeOneTimeProof('step-up-id')).thenAnswer((
        _,
      ) async {
        if (proofConsumed) return false;
        proofConsumed = true;
        return true;
      });
      stubLoginCompletion(boundAdmin);

      expect(
        (await service.completeLoginStepUp(
          challenge: 'step-up-challenge',
          factor: 'email_code',
          proof: const {'code': '123456'},
        )).ok,
        isFalse,
      );
      expect(
        (await service.completeLoginStepUp(
          challenge: 'step-up-challenge',
          factor: 'password',
          proof: const {'password': 'correct-password'},
        )).ok,
        isTrue,
      );
      expect(
        (await service.completeLoginStepUp(
          challenge: 'step-up-challenge',
          factor: 'password',
          proof: const {'password': 'correct-password'},
        )).code,
        'verification_failed',
      );
      verify(() => throttles.consumeOneTimeProof('step-up-id')).called(2);
    },
  );

  test('direct login step-up supports every bound secondary factor', () async {
    when(() => tokens.verifyLoginStepUpChallenge('invalid')).thenReturn(null);
    expect(
      (await service.sendLoginStepUpCode(
        challenge: 'invalid',
        factor: 'email_code',
      )).code,
      'invalid_challenge',
    );
    expect(
      await service.beginLoginStepUpPasskey(
        challenge: 'invalid',
        origin: 'https://passport.example.invalid',
      ),
      isNull,
    );

    when(() => tokens.verifyLoginStepUpChallenge('all-factors')).thenReturn(
      const VerifiedToken(
        payload: {
          'sub': 'user-id',
          'primary_method': 'password',
          'jti': 'all-factors-id',
        },
      ),
    );
    when(() => users.findById(user.id)).thenAnswer((_) async => user);
    when(() => webAuthn.hasCredentials(user.id)).thenAnswer((_) async => true);
    stubPolicy();
    when(
      () => throttles.enforceVerificationCodeSendGuards(
        email: any(named: 'email'),
        requestIp: any(named: 'requestIp'),
        policy: any(named: 'policy'),
        emailScope: any(named: 'emailScope'),
        ipScope: any(named: 'ipScope'),
        cooldownScope: any(named: 'cooldownScope'),
        emailLimit: any(named: 'emailLimit'),
        ipLimit: any(named: 'ipLimit'),
      ),
    ).thenAnswer((_) async => null);
    when(() => emailCodes.issueStepUpCode(user.email)).thenAnswer((_) async {});
    when(
      () => throttles.startVerificationCodeCooldown(
        email: any(named: 'email'),
        seconds: any(named: 'seconds'),
        cooldownScope: any(named: 'cooldownScope'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => phones.sendCode(
        phoneNumber: user.phoneNumber!,
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer(
      (_) async =>
          const PhoneVerificationAttempt.success(retryAfterSeconds: 60),
    );
    expect(
      (await service.sendLoginStepUpCode(
        challenge: 'all-factors',
        factor: 'email_code',
      )).ok,
      isTrue,
    );
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
    when(
      () => emailCodes.issueStepUpCode(user.email),
    ).thenThrow(StateError('provider unavailable'));
    expect(
      (await service.sendLoginStepUpCode(
        challenge: 'all-factors',
        factor: 'email_code',
      )).code,
      'temporary_issue',
    );
    verify(
      () => audit.log(
        action: 'user.login_code.delivery_failed',
        actorId: user.id,
        actorType: 'user',
        resourceType: 'user',
        resourceId: user.id,
        metadata: {'channel': 'email'},
        ip: null,
      ),
    ).called(1);
    expect(
      (await service.sendLoginStepUpCode(
        challenge: 'all-factors',
        factor: 'phone_code',
      )).ok,
      isTrue,
    );
    expect(
      (await service.sendLoginStepUpCode(
        challenge: 'all-factors',
        factor: 'password',
      )).code,
      'invalid_factor',
    );

    when(
      () => webAuthn.generateAuthenticationOptions(
        email: user.email,
        userId: user.id,
        origin: 'https://passport.example.invalid',
        requireUserVerification: true,
      ),
    ).thenAnswer((_) async => {'challenge': 'webauthn-challenge'});
    expect(
      await service.beginLoginStepUpPasskey(
        challenge: 'all-factors',
        origin: 'https://passport.example.invalid',
      ),
      containsPair('challenge', 'webauthn-challenge'),
    );

    when(
      () => throttles.consumeOneTimeProof('all-factors-id'),
    ).thenAnswer((_) async => true);
    when(
      () => emailCodes.verifyStepUpCode(user.email, '123456'),
    ).thenAnswer((_) async => true);
    when(
      () => phones.verifyCode(
        phoneNumber: user.phoneNumber!,
        verifyCode: '123456',
        requestIp: any(named: 'requestIp'),
      ),
    ).thenAnswer((_) async => const PhoneVerifyCheckAttempt.success());
    when(
      () => users.findAuthenticatorSecretByUserId(user.id),
    ).thenAnswer((_) async => user.authenticatorSecret);
    when(
      () => authenticator.verifyCode(
        secret: user.authenticatorSecret!,
        code: '123456',
      ),
    ).thenReturn(true);
    when(
      () => webAuthn.verifyAuthentication(
        userId: user.id,
        email: user.email,
        response: any(named: 'response'),
        forceUserVerification: true,
      ),
    ).thenAnswer((_) async => true);
    stubLoginCompletion();

    for (final factor in ['email_code', 'phone_code', 'authenticator']) {
      expect(
        (await service.completeLoginStepUp(
          challenge: 'all-factors',
          factor: factor,
          proof: const {'code': '123456'},
        )).ok,
        isTrue,
      );
    }
    expect(
      (await service.completeLoginStepUp(
        challenge: 'all-factors',
        factor: 'webauthn',
        proof: const {
          'response': {'id': 'credential'},
        },
      )).ok,
      isTrue,
    );
  });

  test(
    'phone login remains non-enumerating and verifies valid codes',
    () async {
      final disabled = LoginService(
        userRepository: users,
        settingsRepository: settings,
        passwordHasher: passwords,
        tokenService: tokens,
        emailCodeService: emailCodes,
        throttleService: throttles,
        sessionService: sessions,
        auditService: audit,
      );
      expect(
        (await disabled.sendPhoneCode(phoneNumber: '13800000000')).code,
        'phone_verification_not_configured',
      );
      expect(
        (await disabled.loginWithPhoneCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
        )).code,
        'phone_verification_not_configured',
      );
      when(() => phones.normalizePhone(any())).thenReturn(null);
      expect(
        (await service.sendPhoneCode(phoneNumber: 'bad')).code,
        'invalid_phone_number',
      );
      expect(
        (await service.loginWithPhoneCode(
          phoneNumber: 'bad',
          verifyCode: '123456',
        )).code,
        'invalid_phone_number',
      );
      when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
      when(
        () => phones.sendCode(
          phoneNumber: any(named: 'phoneNumber'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer(
        (_) async =>
            const PhoneVerificationAttempt.success(retryAfterSeconds: 60),
      );
      final missingPhone = await service.sendPhoneCode(
        phoneNumber: '13800000000',
      );
      expect(missingPhone.ok, isTrue);
      when(
        () => phones.verifyCode(
          phoneNumber: any(named: 'phoneNumber'),
          verifyCode: any(named: 'verifyCode'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer((_) async => const PhoneVerifyCheckAttempt.success());
      when(
        () => tokens.issueRegistrationHandoff(
          method: 'phone',
          subject: '+8613800000000',
        ),
      ).thenReturn('registration-handoff');
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
      expect(
        (await service.loginWithPhoneCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
        )).registrationToken,
        'registration-handoff',
      );
      clearInteractions(users);
      when(
        () => phones.sendCode(
          phoneNumber: any(named: 'phoneNumber'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer(
        (_) async => const PhoneVerificationAttempt.failure(
          code: 'temporary_issue',
          message: 'provider failed',
          statusCode: 503,
        ),
      );
      final unavailablePhone = await service.sendPhoneCode(
        phoneNumber: '13800000000',
      );
      expect(unavailablePhone.ok, isFalse);
      expect(unavailablePhone.statusCode, 503);
      verifyNever(() => users.findByPhoneNumber(any()));
      when(
        () => phones.sendCode(
          phoneNumber: any(named: 'phoneNumber'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenThrow(StateError('provider unavailable'));
      expect(
        (await service.sendPhoneCode(phoneNumber: '13800000000')).statusCode,
        503,
      );
      verifyNever(() => users.findByPhoneNumber(any()));
      when(
        () => phones.verifyCode(
          phoneNumber: any(named: 'phoneNumber'),
          verifyCode: any(named: 'verifyCode'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer(
        (_) async => const PhoneVerifyCheckAttempt.failure(
          code: 'invalid_code',
          message: 'bad code',
          statusCode: 401,
        ),
      );
      expect(
        (await service.loginWithPhoneCode(
          phoneNumber: '13800000000',
          verifyCode: 'wrong',
        )).code,
        'invalid_code',
      );
      when(
        () => phones.verifyCode(
          phoneNumber: any(named: 'phoneNumber'),
          verifyCode: any(named: 'verifyCode'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer((_) async => const PhoneVerifyCheckAttempt.success());
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => user);
      stubLoginCompletion();
      expect(
        (await service.loginWithPhoneCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
        )).ok,
        isTrue,
      );
    },
  );
}
