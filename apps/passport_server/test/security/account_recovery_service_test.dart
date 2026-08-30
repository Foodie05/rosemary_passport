import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:rosm_passport_server/src/services/account_recovery_service.dart';
import 'package:rosm_passport_server/src/services/auth_attempts.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/phone_verification_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/session_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

class _MockThrottles extends Mock implements AuthThrottleService {}

class _MockSessions extends Mock implements SessionService {}

class _MockPhones extends Mock implements PhoneVerificationService {}

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

  late _MockUsers users;
  late _MockPasswords passwords;
  late _MockEmailCodes emailCodes;
  late _MockThrottles throttles;
  late _MockSessions sessions;
  late _MockPhones phones;
  late AccountRecoveryService service;

  setUpAll(() {
    registerFallbackValue(SecurityPolicyService.defaultPolicy);
  });

  setUp(() {
    users = _MockUsers();
    passwords = _MockPasswords();
    emailCodes = _MockEmailCodes();
    throttles = _MockThrottles();
    sessions = _MockSessions();
    phones = _MockPhones();
    service = AccountRecoveryService(
      userRepository: users,
      passwordHasher: passwords,
      passwordPolicy: PasswordPolicy(),
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
      phoneVerificationService: phones,
    );
  });

  void stubEmailDelivery({AdminLoginCodeAttempt? limited}) {
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

  test(
    'email recovery send remains non-enumerating and rate limited',
    () async {
      stubEmailDelivery();
      when(
        () => throttles.startVerificationCodeCooldown(
          email: any(named: 'email'),
          seconds: any(named: 'seconds'),
          cooldownScope: any(named: 'cooldownScope'),
        ),
      ).thenAnswer((_) async {});
      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        (await service.sendCode(
          account: 'missing@example.invalid',
          method: 'email',
        )).ok,
        isTrue,
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      stubEmailDelivery(
        limited: const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: 'limited',
          statusCode: 429,
        ),
      );
      expect(
        (await service.sendCode(
          account: user.email,
          method: 'email',
        )).statusCode,
        429,
      );

      stubEmailDelivery();
      when(
        () => emailCodes.issuePasswordResetCode(user.email),
      ).thenAnswer((_) async => 'code-id');
      expect(
        (await service.sendCode(
          account: ' USER@EXAMPLE.INVALID ',
          method: 'email',
        )).ok,
        isTrue,
      );
      verify(() => emailCodes.issuePasswordResetCode(user.email)).called(1);
    },
  );

  test('phone recovery send validates configuration and delivery', () async {
    final disabled = AccountRecoveryService(
      userRepository: users,
      passwordHasher: passwords,
      passwordPolicy: PasswordPolicy(),
      emailCodeService: emailCodes,
      throttleService: throttles,
      sessionService: sessions,
    );
    expect(
      (await disabled.sendCode(account: '13800000000', method: 'phone')).code,
      'phone_verification_not_configured',
    );

    when(() => phones.normalizePhone(any())).thenReturn(null);
    expect(
      (await service.sendCode(account: 'bad', method: 'phone')).code,
      'invalid_phone_number',
    );

    when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
    stubEmailDelivery();
    when(
      () => throttles.startVerificationCodeCooldown(
        email: any(named: 'email'),
        seconds: any(named: 'seconds'),
        cooldownScope: any(named: 'cooldownScope'),
      ),
    ).thenAnswer((_) async {});
    when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
    expect(
      (await service.sendCode(account: '13800000000', method: 'phone')).ok,
      isTrue,
    );

    when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => user);
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
      (await service.sendCode(account: '13800000000', method: 'phone')).ok,
      isTrue,
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
      (await service.sendCode(account: '13800000000', method: 'phone')).ok,
      isTrue,
    );
    expect(
      (await service.sendCode(account: 'x', method: 'unknown')).code,
      'invalid_request',
    );
  });

  test(
    'email password recovery validates policy, code, and revokes sessions',
    () async {
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'email',
          code: '123456',
          newPassword: '',
        )).code,
        'invalid_request',
      );
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'email',
          code: '123456',
          newPassword: 'password',
        )).code,
        'password_policy_violation',
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => null);
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'email',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).code,
        'invalid_code',
      );

      when(() => users.findByEmail(any())).thenAnswer((_) async => user);
      when(
        () => emailCodes.verifyPasswordResetCode(any(), any()),
      ).thenAnswer((_) async => false);
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'email',
          code: 'wrong',
          newPassword: 'A secure historical-compatible passphrase',
        )).code,
        'invalid_code',
      );

      when(
        () => emailCodes.verifyPasswordResetCode(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => passwords.hash(any())).thenAnswer((_) async => 'new-hash');
      when(
        () => users.updatePasswordHash(
          userId: any(named: 'userId'),
          passwordHash: any(named: 'passwordHash'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sessions.revokeAllUserSessions(
          any(),
          preservedAccessTokenId: any(named: 'preservedAccessTokenId'),
        ),
      ).thenAnswer((_) async {});
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'email',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).ok,
        isTrue,
      );
      verify(
        () =>
            users.updatePasswordHash(userId: user.id, passwordHash: 'new-hash'),
      ).called(1);
      verify(
        () => sessions.revokeAllUserSessions(
          user.id,
          preservedAccessTokenId: any(named: 'preservedAccessTokenId'),
        ),
      ).called(1);
    },
  );

  test(
    'phone password recovery rejects invalid and accepts valid codes',
    () async {
      when(() => phones.normalizePhone(any())).thenReturn(null);
      expect(
        (await service.recoverPassword(
          account: 'bad',
          method: 'phone',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).code,
        'invalid_phone_number',
      );

      when(() => phones.normalizePhone(any())).thenReturn('+8613800000000');
      when(() => users.findByPhoneNumber(any())).thenAnswer((_) async => null);
      expect(
        (await service.recoverPassword(
          account: '13800000000',
          method: 'phone',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).code,
        'invalid_code',
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
        (await service.recoverPassword(
          account: '13800000000',
          method: 'phone',
          code: 'wrong',
          newPassword: 'A secure historical-compatible passphrase',
        )).statusCode,
        401,
      );

      when(
        () => phones.verifyCode(
          phoneNumber: any(named: 'phoneNumber'),
          verifyCode: any(named: 'verifyCode'),
          requestIp: any(named: 'requestIp'),
        ),
      ).thenAnswer((_) async => const PhoneVerifyCheckAttempt.success());
      when(() => passwords.hash(any())).thenAnswer((_) async => 'new-hash');
      when(
        () => users.updatePasswordHash(
          userId: any(named: 'userId'),
          passwordHash: any(named: 'passwordHash'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => sessions.revokeAllUserSessions(
          any(),
          preservedAccessTokenId: any(named: 'preservedAccessTokenId'),
        ),
      ).thenAnswer((_) async {});
      expect(
        (await service.recoverPassword(
          account: '13800000000',
          method: 'phone',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).ok,
        isTrue,
      );
      expect(
        (await service.recoverPassword(
          account: user.email,
          method: 'unknown',
          code: '123456',
          newPassword: 'A secure historical-compatible passphrase',
        )).code,
        'invalid_request',
      );
    },
  );
}
