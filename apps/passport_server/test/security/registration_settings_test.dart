import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/repositories/settings_repository.dart';
import 'package:rosm_passport_server/src/services/admin_settings_service.dart';
import 'package:rosm_passport_server/src/services/captcha_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:test/test.dart';

class _Settings extends Mock implements SettingsRepository {}

class _Captcha extends Mock implements CaptchaService {}

class _Policy extends Mock implements SecurityPolicyService {}

void main() {
  late _Settings repository;
  late AdminSettingsService service;

  setUp(() {
    repository = _Settings();
    final policy = _Policy();
    when(() => repository.getJson(any())).thenAnswer((_) async => {});
    when(() => repository.upsertJson(any(), any())).thenAnswer((_) async {});
    when(() => policy.mergedSecuritySettings()).thenAnswer((_) async => {});
    service = AdminSettingsService(
      repository,
      AppConfig.forTesting({}),
      _Captcha(),
      policy,
    );
  });

  test(
    'legacy false flag cannot advertise unverified email registration',
    () async {
      when(() => repository.getJson('registration')).thenAnswer(
        (_) async => {'require_email_verification': false, 'enabled': true},
      );
      final settings = await service.getSystemSettings();
      expect(settings['registration'], {
        'require_email_verification': true,
        'enabled': true,
      });
    },
  );

  test('legacy client cannot persist a false verification flag', () async {
    when(() => repository.getJson('registration')).thenAnswer(
      (_) async => {'require_email_verification': false, 'enabled': true},
    );
    await service.updateSystemSettings({
      'registration': {'require_email_verification': false},
    });
    verify(
      () => repository.upsertJson('registration', {
        'require_email_verification': true,
        'enabled': true,
      }),
    ).called(1);
  });
}
