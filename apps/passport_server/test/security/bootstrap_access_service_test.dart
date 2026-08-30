import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/repositories/settings_repository.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/services/bootstrap_access_service.dart';
import 'package:rosm_passport_server/src/services/captcha_service.dart';
import 'package:test/test.dart';

class _MockUsers extends Mock implements UserRepository {}

class _MockPasswords extends Mock implements PasswordHasher {}

class _MockCaptcha extends Mock implements CaptchaService {}

class _MockSettings extends Mock implements SettingsRepository {}

void main() {
  const user = UserRecord(
    id: 'user-id',
    email: 'user@example.invalid',
    phoneNumber: null,
    nickname: 'User',
    passwordHash: 'user-hash',
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
    email: ' Bootstrap@ROSM.Local ',
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
  late _MockUsers users;
  late _MockPasswords passwords;
  late _MockCaptcha captcha;
  late _MockSettings settings;
  late BootstrapAccessService service;

  setUp(() {
    users = _MockUsers();
    passwords = _MockPasswords();
    captcha = _MockCaptcha();
    settings = _MockSettings();
    service = BootstrapAccessService(
      userRepository: users,
      passwordHasher: passwords,
      captchaService: captcha,
      settingsRepository: settings,
    );
  });

  test('captcha verification preserves the caller IP', () async {
    when(
      () => captcha.verifyCaptchaToken('token', remoteIp: '127.0.0.1'),
    ).thenAnswer((_) async => true);
    expect(await service.verifyCaptcha('token', ip: '127.0.0.1'), isTrue);
  });

  test('credential bypass is non-enumerating and bootstrap-only', () async {
    when(() => users.findByEmail(any())).thenAnswer((_) async => null);
    expect(
      await service.shouldBypassCaptcha(
        email: 'missing@example.invalid',
        password: 'password',
      ),
      isFalse,
    );
    when(() => users.findByEmail(any())).thenAnswer((_) async => admin);
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => false);
    expect(
      await service.shouldBypassCaptcha(email: admin.email, password: 'wrong'),
      isFalse,
    );
    when(() => passwords.verify(any(), any())).thenAnswer((_) async => true);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => true);
    expect(
      await service.shouldBypassCaptcha(
        email: admin.email,
        password: 'correct',
      ),
      isTrue,
    );
    expect(service.mustBindAdminEmail(admin), isTrue);
    expect(service.mustBindAdminEmail(user), isFalse);
  });

  test('user-id bypass requires an existing active bootstrap admin', () async {
    when(() => users.findById(any())).thenAnswer((_) async => null);
    expect(await service.shouldBypassCaptchaForUser('missing'), isFalse);
    when(() => users.findById(user.id)).thenAnswer((_) async => user);
    expect(await service.shouldBypassCaptchaForUser(user.id), isFalse);
    when(() => users.findById(admin.id)).thenAnswer((_) async => admin);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => false);
    expect(await service.shouldBypassCaptchaForUser(admin.id), isFalse);
    when(
      () => settings.isBootstrapLoginEnabled(),
    ).thenAnswer((_) async => true);
    expect(await service.shouldBypassCaptchaForUser(admin.id), isTrue);
  });
}
