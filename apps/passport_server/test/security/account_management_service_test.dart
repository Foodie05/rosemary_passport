import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/settings_repository.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:rosm_passport_server/src/services/account_management_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/phone_verification_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockSettings extends Mock implements SettingsRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

class _MockThrottles extends Mock implements AuthThrottleService {}

class _MockSessions extends Mock implements SessionService {}

class _MockPhones extends Mock implements PhoneVerificationService {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: null,
    nickname: 'User',
    passwordHash: 'password-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: false,
  );
  const admin = UserRecord(
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
  const other = UserRecord(
    id: 'other-id',
    email: 'other@example.invalid',
    phoneNumber: '+8613900000000',
    nickname: 'Other',
    passwordHash: 'other-hash',
    passkeyHash: null,
    securityCodeHash: null,
    authenticatorSecret: null,
    hasAuthenticator: false,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: true,
  );

  late _MockUsers users;
  late _MockSettings settings;
  late _MockPasswords passwords;
  late _MockEmailCodes emailCodes;
  late _MockThrottles throttles;
  late _MockSessions sessions;
  late _MockPhones phones;
  late AccountManagementService service;

  setUpAll(() {
    registerFallbackValue(SecurityPolicyService.defaultPolicy);
  });

  setUp(() {
    users = _MockUsers();
    settings = _MockSettings();
    passwords = _MockPasswords();
    emailCodes = _MockEmailCodes();
    throttles = _MockThrottles();
    sessions = _MockSessions();
    phones = _MockPhones();
    service = AccountManagementService(
      userRepository: users,
      settingsRepository: settings,
      passwordHasher: passwords,
      passwordPolicy: PasswordPolicy(),
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      phoneVerificationService: phones,
    );
  });

  void stubSessionRevocation() {
    when(
      () => sessions.revokeAllUserSessions(
        any(),
        preservedAccessTokenId: any(named: 'preservedAccessTokenId'),
      ),
    ).thenAnswer((_) async {});
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

  test('profile updates require step-up only for sensitive changes', () async {
    when(() => users.findById(any())).thenAnswer((_) async => null);
    expect(
      (await service.updateAccount(
        userId: 'missing',
        currentPassword: '',
      )).code,
      'not_found',
    );

    when(() => users.findById(any())).thenAnswer((_) async => user);
    when(
      () => users.updateNickname(
        userId: user.id,
        nickname: any(named: 'nickname'),
      ),
    ).thenAnswer((_) async {});
    final nickname = await service.updateAccount(
      userId: user.id,
      currentPassword: '',
      nickname: ' New name ',
    );
    expect(nickname.updatedNickname, isTrue);

    expect(
      (await service.updateAccount(
        userId: user.id,
        currentPassword: '',
        newEmail: 'new@example.invalid',
      )).code,
      'invalid_request',
    );
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
    expect(
      (await service.updateAccount(
        userId: user.id,
        currentPassword: 'wrong',
        newPassword: 'A secure historical-compatible passphrase',
      )).code,
      'invalid_password',
    );
  });

  test(
    'sensitive profile changes validate conflicts and revoke sessions',
    () async {
      when(() => users.findById(any())).thenAnswer((_) async => admin);
      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      expect(
        (await service.updateAccount(
          userId: admin.id,
          currentPassword: 'password',
          newEmail: 'reserved@rosm.local',
        )).code,
        'invalid_email',
      );

      when(() => users.findById(any())).thenAnswer((_) async => user);
      when(() => users.findByEmail(any())).thenAnswer((_) async => other);
      expect(
        (await service.updateAccount(
          userId: user.id,
          currentPassword: 'password',
          newEmail: other.email,
        )).code,
        'email_exists',
      );
      expect(
        (await service.updateAccount(
          userId: user.id,
          currentPassword: 'password',
          newPassword: 'password',
        )).code,
        'password_policy_violation',
      );

      when(() => users.findById(any())).thenAnswer((_) async => admin);
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      when(
        () => users.updateEmail(
          userId: admin.id,
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => users.updatePasswordHash(
          userId: admin.id,
          passwordHash: any(named: 'passwordHash'),
        ),
      ).thenAnswer((_) async {});
      when(() => passwords.hash(any())).thenAnswer((_) async => 'new-hash');
      when(
        () => settings.isBootstrapLoginEnabled(),
      ).thenAnswer((_) async => true);
      when(
        () =>
            settings.closeBootstrapLogin(boundEmail: any(named: 'boundEmail')),
      ).thenAnswer((_) async {});
      stubSessionRevocation();
      final result = await service.updateAccount(
        userId: admin.id,
        currentPassword: 'password',
        newEmail: 'ADMIN@EXAMPLE.INVALID',
        newPassword: 'A secure historical-compatible passphrase',
      );
      expect(result.updatedEmail, isTrue);
      expect(result.updatedPassword, isTrue);
      verify(
        () => settings.closeBootstrapLogin(boundEmail: 'admin@example.invalid'),
      ).called(1);
    },
  );

  test(
    'email binding validates password, target, throttle, and code',
    () async {
      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(
        (await service.sendBindEmailCode(
          userId: 'missing',
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
        )).code,
        'not_found',
      );
      expect(
        (await service.bindEmail(
          userId: 'missing',
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
          emailCode: '123456',
        )).code,
        'not_found',
      );

      when(() => users.findById(any())).thenAnswer((_) async => user);
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: '',
        )).code,
        'invalid_request',
      );
      when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'wrong',
        )).code,
        'invalid_password',
      );
      expect(
        (await service.bindEmail(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'wrong',
          emailCode: '123456',
        )).code,
        'invalid_password',
      );

      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: '',
          currentPassword: 'password',
        )).code,
        'invalid_request',
      );
      when(() => users.findByEmail(any())).thenAnswer((_) async => other);
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: other.email,
          currentPassword: 'password',
        )).code,
        'email_exists',
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      stubThrottle(
        limited: const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: 'limited',
          statusCode: 429,
        ),
      );
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
        )).statusCode,
        429,
      );

      stubThrottle();
      when(
        () => emailCodes.issueBindEmailCode(any()),
      ).thenAnswer((_) async => 'code-id');
      when(
        () => throttles.startVerificationCodeCooldown(
          email: any(named: 'email'),
          seconds: any(named: 'seconds'),
          cooldownScope: any(named: 'cooldownScope'),
        ),
      ).thenAnswer((_) async {});
      expect(
        (await service.sendBindEmailCode(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
        )).ok,
        isTrue,
      );

      expect(
        (await service.bindEmail(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
          emailCode: '',
        )).code,
        'invalid_request',
      );
      when(
        () => emailCodes.verifyBindEmailCode(any(), any()),
      ).thenAnswer((_) async => false);
      expect(
        (await service.bindEmail(
          userId: user.id,
          newEmail: 'new@example.invalid',
          currentPassword: 'password',
          emailCode: 'wrong',
        )).code,
        'invalid_code',
      );
    },
  );

  test('valid email binding preserves the current access token', () async {
    when(() => users.findById(any())).thenAnswer((_) async => admin);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    when(
      () => emailCodes.verifyBindEmailCode(any(), any()),
    ).thenAnswer((_) async => true);
    when(
      () => users.updateEmail(
        userId: admin.id,
        email: any(named: 'email'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => true);
    when(
      () => settings.closeBootstrapLogin(boundEmail: any(named: 'boundEmail')),
    ).thenAnswer((_) async {});
    stubSessionRevocation();
    final result = await service.bindEmail(
      userId: admin.id,
      newEmail: 'admin@example.invalid',
      currentPassword: 'password',
      emailCode: '123456',
      preservedAccessTokenId: 'access-id',
    );
    expect(result.ok, isTrue);
    verify(
      () => sessions.revokeAllUserSessions(
        admin.id,
        preservedAccessTokenId: 'access-id',
      ),
    ).called(1);
  });

  test(
    'phone binding validates provider, number, conflict, and codes',
    () async {
      final disabled = AccountManagementService(
        userRepository: users,
        settingsRepository: settings,
        passwordHasher: passwords,
        passwordPolicy: PasswordPolicy(),
        emailCodeService: emailCodes,
        throttleService: throttles,
        sessionService: sessions,
      );
      when(() => users.findById(any())).thenAnswer((_) async => user);
      when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
      expect(
        (await disabled.sendBindPhoneCode(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
        )).code,
        'phone_verification_not_configured',
      );

      when(() => phones.normalizePhone(any())).thenReturn(null);
      expect(
        (await service.sendBindPhoneCode(
          userId: user.id,
          phoneNumber: 'bad',
          currentPassword: 'password',
        )).code,
        'invalid_phone_number',
      );
      when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => other);
      expect(
        (await service.sendBindPhoneCode(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
        )).code,
        'phone_exists',
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
        (await service.sendBindPhoneCode(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
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
        (await service.sendBindPhoneCode(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
        )).ok,
        isTrue,
      );

      expect(
        (await service.bindPhone(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
          verifyCode: '',
        )).code,
        'invalid_request',
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
        (await service.bindPhone(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
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
      when(
        () => users.updatePhoneNumber(
          userId: user.id,
          phoneNumber: any(named: 'phoneNumber'),
        ),
      ).thenAnswer((_) async {});
      stubSessionRevocation();
      expect(
        (await service.bindPhone(
          userId: user.id,
          phoneNumber: '13800000000',
          currentPassword: 'password',
          verifyCode: '123456',
          preservedAccessTokenId: 'access-id',
        )).ok,
        isTrue,
      );
    },
  );

  test(
    'authenticated password reset is throttled and revokes sessions',
    () async {
      when(() => users.findById(any())).thenAnswer((_) async => null);
      expect(
        (await service.sendPasswordResetCode(userId: 'missing')).code,
        'not_found',
      );
      expect(
        (await service.resetPassword(
          userId: 'missing',
          newPassword: 'A secure historical-compatible passphrase',
          emailCode: '123456',
        )).code,
        'not_found',
      );
      when(() => users.findById(any())).thenAnswer((_) async => user);
      stubThrottle(
        limited: const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: 'limited',
          statusCode: 429,
        ),
      );
      expect(
        (await service.sendPasswordResetCode(userId: user.id)).statusCode,
        429,
      );
      stubThrottle();
      when(
        () => emailCodes.issuePasswordResetCode(user.email),
      ).thenAnswer((_) async => 'code-id');
      when(
        () => throttles.startVerificationCodeCooldown(
          email: any(named: 'email'),
          seconds: any(named: 'seconds'),
          cooldownScope: any(named: 'cooldownScope'),
        ),
      ).thenAnswer((_) async {});
      expect((await service.sendPasswordResetCode(userId: user.id)).ok, isTrue);

      expect(
        (await service.resetPassword(
          userId: user.id,
          newPassword: '',
          emailCode: '',
        )).code,
        'invalid_request',
      );
      expect(
        (await service.resetPassword(
          userId: user.id,
          newPassword: 'password',
          emailCode: '123456',
        )).code,
        'password_policy_violation',
      );
      when(
        () => emailCodes.verifyPasswordResetCode(any(), any()),
      ).thenAnswer((_) async => false);
      expect(
        (await service.resetPassword(
          userId: user.id,
          newPassword: 'A secure historical-compatible passphrase',
          emailCode: 'wrong',
        )).code,
        'invalid_code',
      );
      when(
        () => emailCodes.verifyPasswordResetCode(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => passwords.hash(any())).thenAnswer((_) async => 'new-hash');
      when(
        () => users.updatePasswordHash(
          userId: user.id,
          passwordHash: any(named: 'passwordHash'),
        ),
      ).thenAnswer((_) async {});
      stubSessionRevocation();
      expect(
        (await service.resetPassword(
          userId: user.id,
          newPassword: 'A secure historical-compatible passphrase',
          emailCode: '123456',
        )).ok,
        isTrue,
      );
    },
  );
}
