import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/phone_verification_service.dart';
import 'package:rosm_passport_server/src/services/registration_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

class _MockThrottles extends Mock implements AuthThrottleService {}

class _MockSessions extends Mock implements SessionService {}

class _MockAudit extends Mock implements AuditService {}

class _MockPolicyService extends Mock implements SecurityPolicyService {}

class _MockPhones extends Mock implements PhoneVerificationService {}

class _MockUuid extends Mock implements Uuid {}

void main() {
  const user = UserRecord(
    id: 'new-user-id',
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
  const tokens = TokenPair(
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
      id: 'new-user-id',
      email: 'user@example.invalid',
      nickname: 'User',
      roles: ['user'],
    ),
    tokens: tokens,
    postRegistrationPasskeyBootstrap: true,
  );

  late _MockUsers users;
  late _MockPasswords passwords;
  late _MockEmailCodes emailCodes;
  late _MockThrottles throttles;
  late _MockSessions sessions;
  late _MockAudit audit;
  late _MockPolicyService policies;
  late _MockPhones phones;
  late _MockUuid uuid;
  late RegistrationService service;

  setUpAll(() {
    registerFallbackValue(SecurityPolicyService.defaultPolicy);
  });

  setUp(() {
    users = _MockUsers();
    passwords = _MockPasswords();
    emailCodes = _MockEmailCodes();
    throttles = _MockThrottles();
    sessions = _MockSessions();
    audit = _MockAudit();
    policies = _MockPolicyService();
    phones = _MockPhones();
    uuid = _MockUuid();
    service = RegistrationService(
      userRepository: users,
      passwordHasher: passwords,
      passwordPolicy: PasswordPolicy(),
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      auditService: audit,
      securityPolicyService: policies,
      phoneVerificationService: phones,
      uuid: uuid,
    );
  });

  void allowEmailProvider() {
    when(() => policies.loadRegistrationEmailProviderPolicy()).thenAnswer(
      (_) async => const RegistrationEmailProviderPolicy(
        mode: SecurityPolicyService.blacklistMode,
        blacklist: [],
        whitelist: [],
      ),
    );
  }

  void stubThrottle({AdminLoginCodeAttempt? limited}) {
    when(
      () => throttles.loadPolicy(),
    ).thenAnswer((_) async => SecurityPolicyService.defaultPolicy);
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
    ).thenAnswer((_) async => limited);
  }

  void stubCreatedUser({UserRecord? result = user}) {
    when(() => uuid.v4()).thenReturn(user.id);
    when(() => passwords.hash(any())).thenAnswer((_) async => 'new-hash');
    when(
      () => users.createUser(
        userId: any(named: 'userId'),
        email: any(named: 'email'),
        nickname: any(named: 'nickname'),
        passwordHash: any(named: 'passwordHash'),
        roles: any(named: 'roles'),
        isEmailVerified: any(named: 'isEmailVerified'),
      ),
    ).thenAnswer((_) async {});
    when(() => users.findById(user.id)).thenAnswer((_) async => result);
  }

  test('email code send applies provider and throttle policy', () async {
    when(() => policies.loadRegistrationEmailProviderPolicy()).thenAnswer(
      (_) async => const RegistrationEmailProviderPolicy(
        mode: SecurityPolicyService.whitelistMode,
        blacklist: [],
        whitelist: ['allowed.example'],
      ),
    );
    expect(
      (await service.sendEmailCode(email: 'user@blocked.example')).statusCode,
      403,
    );

    allowEmailProvider();
    stubThrottle(
      limited: const AdminLoginCodeAttempt.failure(
        code: 'rate_limited',
        message: 'limited',
        statusCode: 429,
      ),
    );
    expect((await service.sendEmailCode(email: user.email)).statusCode, 429);

    stubThrottle();
    when(
      () => emailCodes.issueRegisterCode(user.email),
    ).thenAnswer((_) async => 'code-id');
    when(
      () => throttles.startVerificationCodeCooldown(
        email: any(named: 'email'),
        seconds: any(named: 'seconds'),
        cooldownScope: any(named: 'cooldownScope'),
      ),
    ).thenAnswer((_) async {});
    expect((await service.sendEmailCode(email: user.email)).ok, isTrue);
  });

  test('email registration validates policy, uniqueness, and code', () async {
    expect(
      (await service.registerWithEmail(
        email: user.email,
        nickname: user.nickname,
        password: 'password',
        emailCode: '123456',
      )).code,
      'password_policy_violation',
    );
    when(() => policies.loadRegistrationEmailProviderPolicy()).thenAnswer(
      (_) async => const RegistrationEmailProviderPolicy(
        mode: SecurityPolicyService.whitelistMode,
        blacklist: [],
        whitelist: ['allowed.example'],
      ),
    );
    expect(
      (await service.registerWithEmail(
        email: user.email,
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        emailCode: '123456',
      )).code,
      'registration_email_not_allowed',
    );

    allowEmailProvider();
    when(() => users.findByEmail(any())).thenAnswer((_) async => user);
    expect(
      (await service.registerWithEmail(
        email: user.email,
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        emailCode: '123456',
      )).code,
      'email_already_registered',
    );
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    when(
      () => emailCodes.verifyRegisterCode(any(), any()),
    ).thenAnswer((_) async => false);
    expect(
      (await service.registerWithEmail(
        email: user.email,
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        emailCode: 'wrong',
      )).code,
      'invalid_email_code',
    );
  });

  test(
    'successful email registration issues bootstrap session and audit',
    () async {
      allowEmailProvider();
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      when(
        () => emailCodes.verifyRegisterCode(any(), any()),
      ).thenAnswer((_) async => true);
      stubCreatedUser();
      when(
        () => sessions.issueFirstPartyAuthResult(
          user,
          postRegistrationPasskeyBootstrap: true,
          rememberMe: any(named: 'rememberMe'),
        ),
      ).thenAnswer((_) async => auth);
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
      final result = await service.registerWithEmail(
        email: user.email,
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        emailCode: '123456',
        requestIp: '192.0.2.1',
      );
      expect(result.ok, isTrue);
      verify(
        () => audit.log(
          action: 'user.register',
          actorId: user.id,
          actorType: 'user',
          resourceType: 'user',
          resourceId: user.id,
          metadata: any(named: 'metadata'),
          ip: '192.0.2.1',
        ),
      ).called(1);
    },
  );

  test(
    'phone code send validates provider, number, uniqueness, and send',
    () async {
      final disabled = RegistrationService(
        userRepository: users,
        passwordHasher: passwords,
        passwordPolicy: PasswordPolicy(),
        emailCodeService: emailCodes,
        throttleService: throttles,
        sessionService: sessions,
        auditService: audit,
      );
      expect(
        (await disabled.sendPhoneCode(phoneNumber: '13800000000')).code,
        'phone_verification_not_configured',
      );
      when(() => phones.normalizePhone(any())).thenReturn(null);
      expect(
        (await service.sendPhoneCode(phoneNumber: 'bad')).code,
        'invalid_phone_number',
      );
      when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => user);
      expect(
        (await service.sendPhoneCode(phoneNumber: '13800000000')).code,
        'phone_already_registered',
      );
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
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
        (await service.sendPhoneCode(phoneNumber: '13800000000')).code,
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
        (await service.sendPhoneCode(phoneNumber: '13800000000')).ok,
        isTrue,
      );
    },
  );

  test('phone registration validates code and issues a session', () async {
    expect(
      (await service.registerWithPhone(
        phoneNumber: '13800000000',
        nickname: user.nickname,
        password: 'password',
        verifyCode: '123456',
      )).code,
      'password_policy_violation',
    );
    final disabled = RegistrationService(
      userRepository: users,
      passwordHasher: passwords,
      passwordPolicy: PasswordPolicy(),
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      auditService: audit,
    );
    expect(
      (await disabled.registerWithPhone(
        phoneNumber: '13800000000',
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        verifyCode: '123456',
      )).code,
      'phone_verification_not_configured',
    );
    when(() => phones.normalizePhone(any())).thenReturn(null);
    expect(
      (await service.registerWithPhone(
        phoneNumber: 'bad',
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        verifyCode: '123456',
      )).code,
      'invalid_phone_number',
    );
    when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
    when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => user);
    expect(
      (await service.registerWithPhone(
        phoneNumber: '13800000000',
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        verifyCode: '123456',
      )).code,
      'phone_already_registered',
    );
    when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
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
      (await service.registerWithPhone(
        phoneNumber: '13800000000',
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
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
    stubCreatedUser();
    when(
      () => users.updatePhoneNumber(
        userId: user.id,
        phoneNumber: any(named: 'phoneNumber'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => sessions.issueFirstPartyAuthResult(
        user,
        postRegistrationPasskeyBootstrap: true,
        rememberMe: any(named: 'rememberMe'),
      ),
    ).thenAnswer((_) async => auth);
    expect(
      (await service.registerWithPhone(
        phoneNumber: '13800000000',
        nickname: user.nickname,
        password: 'A secure historical-compatible passphrase',
        verifyCode: '123456',
      )).ok,
      isTrue,
    );
  });
}
