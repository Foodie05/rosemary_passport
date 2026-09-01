import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/step_up_service.dart';
import 'package:rosm_passport_server/src/services/webauthn_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockEmailCodes extends Mock implements EmailCodeService {}

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
    authenticatorSecret: null,
    hasAuthenticator: true,
    roles: ['user'],
    isEmailVerified: true,
    isPhoneVerified: true,
  );

  late _MockUsers users;
  late _MockPasswords passwords;
  late _MockEmailCodes emailCodes;
  late _MockWebAuthn webAuthn;
  late StepUpService service;

  setUp(() {
    users = _MockUsers();
    passwords = _MockPasswords();
    emailCodes = _MockEmailCodes();
    webAuthn = _MockWebAuthn();
    when(() => users.findById(any())).thenAnswer((_) async => user);
    when(() => webAuthn.hasCredentials(any())).thenAnswer((_) async => true);
    service = StepUpService(
      userRepository: users,
      passwordHasher: passwords,
      emailCodeService: emailCodes,
      webAuthnService: webAuthn,
    );
  });

  test('excludes the factor currently being changed', () async {
    expect(
      await service.availableMethods(user.id, excludedFactor: 'email'),
      isNot(contains('email_code')),
    );
    expect(
      await service.availableMethods(user.id, excludedFactor: 'passkey'),
      isNot(contains('passkey')),
    );
  });

  test('accepts any available non-excluded proof', () async {
    when(
      () => passwords.verify(user.passwordHash, 'correct'),
    ).thenAnswer((_) async => true);
    expect(
      (await service.verify(
        userId: user.id,
        excludedFactor: 'email',
        proof: const {'method': 'password', 'password': 'correct'},
      )).ok,
      isTrue,
    );

    when(
      () => emailCodes.verifyStepUpCode(user.email, '123456'),
    ).thenAnswer((_) async => true);
    expect(
      (await service.verify(
        userId: user.id,
        excludedFactor: 'password',
        proof: const {'method': 'email_code', 'code': '123456'},
      )).ok,
      isTrue,
    );
  });

  test('rejects a proof that uses the changed factor', () async {
    final result = await service.verify(
      userId: user.id,
      excludedFactor: 'password',
      proof: const {'method': 'password', 'password': 'correct'},
    );
    expect(result.code, 'invalid_factor');
    verifyNever(() => passwords.verify(any(), any()));
  });
}
