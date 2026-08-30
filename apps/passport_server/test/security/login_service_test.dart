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

  test(
    'email-code send returns a uniform response for missing accounts',
    () async {
      stubAllowedGuards();
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      when(
        () => throttles.startVerificationCodeCooldown(
          email: any(named: 'email'),
          seconds: any(named: 'seconds'),
          cooldownScope: any(named: 'cooldownScope'),
        ),
      ).thenAnswer((_) async {});
      expect((await service.sendEmailCode(email: user.email)).ok, isTrue);
      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      when(
        () => emailCodes.issueLoginCode(
          user.email,
          templateName: any(named: 'templateName'),
        ),
      ).thenAnswer((_) async => 'code-id');
      expect((await service.sendEmailCode(email: user.email)).ok, isTrue);
    },
  );

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

  test('direct email-code login rejects admins and consumes once', () async {
    stubAllowedGuards();
    when(() => users.findByEmail(any())).thenAnswer((_) async => bootstrap);
    expect(
      (await service.loginWithEmailCode(
        email: bootstrap.email,
        emailCode: '123456',
      )).code,
      'login_failed',
    );
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    when(
      () => emailCodes.validateLoginCode(any(), any()),
    ).thenAnswer((_) async => 'code-id');
    when(() => emailCodes.consumeCode('code-id')).thenAnswer((_) async => true);
    stubLoginCompletion();
    expect(
      (await service.loginWithEmailCode(
        email: user.email,
        emailCode: '123456',
      )).ok,
      isTrue,
    );
  });

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
    'phone login remains non-enumerating and verifies valid codes',
    () async {
      final disabled = LoginService(
        userRepository: users,
        settingsRepository: settings,
        passwordHasher: passwords,
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
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
      expect(
        (await service.sendPhoneCode(phoneNumber: '13800000000')).ok,
        isTrue,
      );
      expect(
        (await service.loginWithPhoneCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
        )).code,
        'login_failed',
      );
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => user);
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
