import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/services/helper_client.dart';
import 'package:rosm_passport_server/src/services/phone_verification_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/security_service.dart';
import 'package:test/test.dart';

class _MockSecurity extends Mock implements SecurityService {}

class _MockPolicy extends Mock implements SecurityPolicyService {}

class _MockHelper extends Mock implements HelperClient {}

void main() {
  late _MockSecurity security;
  late _MockPolicy policy;
  late _MockHelper helper;
  late PhoneVerificationService service;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    security = _MockSecurity();
    policy = _MockPolicy();
    helper = _MockHelper();
    when(
      () => policy.load(),
    ).thenAnswer((_) async => SecurityPolicyService.defaultPolicy);
    when(() => helper.enabled).thenReturn(true);
    when(
      () => security.retryAfterSeconds(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => const ThrottleDecision(allowed: true));
    when(
      () => security.startCooldown(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => security.clear(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async {});
    service = PhoneVerificationService(
      config: AppConfig.forTesting(const {
        'ALIYUN_ACCESS_KEY_ID': 'access-id',
        'ALIYUN_ACCESS_KEY_SECRET': 'access-secret',
        'ALIYUN_SMS_SIGN_NAME': 'ROSM',
        'ALIYUN_SMS_TEMPLATE_CODE': 'SMS_123',
        'ALIYUN_SMS_SCHEME_NAME': 'scheme',
      }),
      securityService: security,
      securityPolicyService: policy,
      helperClient: helper,
    );
  });

  test('phone normalization accepts mainland representations only', () {
    expect(service.normalizePhone('138 0000-0000'), '13800000000');
    expect(service.normalizePhone('+86 (138) 0000-0000'), '13800000000');
    expect(service.normalizePhone('8613800000000'), '13800000000');
    expect(service.normalizePhone('23800000000'), isNull);
    expect(service.normalizePhone('13800000000', countryCode: '1'), isNull);
  });

  test(
    'unconfigured provider and invalid inputs fail before helper calls',
    () async {
      final disabled = PhoneVerificationService(
        config: AppConfig.forTesting(const {}),
        helperClient: helper,
      );
      expect(
        (await disabled.sendCode(
          phoneNumber: '13800000000',
          requestIp: 'ip',
        )).code,
        'phone_verification_not_configured',
      );
      expect(
        (await disabled.verifyCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
          requestIp: 'ip',
        )).code,
        'phone_verification_not_configured',
      );
      expect(
        (await service.sendCode(
          phoneNumber: '13800000000',
          requestIp: 'ip',
          countryCode: '1',
        )).code,
        'unsupported_country_code',
      );
      expect(
        (await service.sendCode(phoneNumber: 'bad', requestIp: 'ip')).code,
        'invalid_phone_number',
      );
      expect(
        (await service.verifyCode(
          phoneNumber: '13800000000',
          verifyCode: '123456',
          requestIp: 'ip',
          countryCode: '1',
        )).code,
        'unsupported_country_code',
      );
      expect(
        (await service.verifyCode(
          phoneNumber: 'bad',
          verifyCode: '123456',
          requestIp: 'ip',
        )).code,
        'invalid_phone_number',
      );
      expect(
        (await service.verifyCode(
          phoneNumber: '13800000000',
          verifyCode: 'bad',
          requestIp: 'ip',
        )).code,
        'invalid_verify_code',
      );
    },
  );

  test('send throttles cooldown, phone, and IP independently', () async {
    when(
      () => security.retryAfterSeconds(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async => 10);
    expect(
      (await service.sendCode(
        phoneNumber: '13800000000',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );

    when(
      () => security.retryAfterSeconds(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async => null);
    var call = 0;
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async {
      call++;
      return ThrottleDecision(allowed: call != 1);
    });
    expect(
      (await service.sendCode(
        phoneNumber: '13800000000',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );

    call = 0;
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async {
      call++;
      return ThrottleDecision(allowed: call != 2);
    });
    expect(
      (await service.sendCode(
        phoneNumber: '13800000000',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );
  });

  test('send maps provider responses and starts cooldown on success', () async {
    when(
      () => helper.execute('sms-send-verify-code.mjs', any()),
    ).thenAnswer((_) async => {'success': false, 'code': 'FREQUENCY_FAIL'});
    expect(
      (await service.sendCode(
        phoneNumber: '13800000000',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );
    when(
      () => helper.execute('sms-send-verify-code.mjs', any()),
    ).thenAnswer((_) async => {'success': false, 'code': 'PROVIDER_DOWN'});
    expect(
      (await service.sendCode(
        phoneNumber: '13800000000',
        requestIp: 'ip',
      )).code,
      'temporary_issue',
    );
    when(
      () => helper.execute('sms-send-verify-code.mjs', any()),
    ).thenAnswer((_) async => {'success': true, 'code': 'OK'});
    final result = await service.sendCode(
      phoneNumber: '13800000000',
      requestIp: 'ip',
    );
    expect(result.ok, isTrue);
    expect(result.retryAfterSeconds, greaterThan(0));
    verify(
      () => security.startCooldown(
        scope: any(named: 'scope'),
        subject: '13800000000',
        duration: any(named: 'duration'),
      ),
    ).called(1);
  });

  test('verify maps throttles and provider failures', () async {
    var call = 0;
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async {
      call++;
      return ThrottleDecision(allowed: call != 1);
    });
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );
    call = 0;
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async {
      call++;
      return ThrottleDecision(allowed: call != 2);
    });
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'rate_limited',
    );

    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => const ThrottleDecision(allowed: true));
    when(
      () => helper.execute('sms-check-verify-code.mjs', any()),
    ).thenThrow(StateError('Invalid Verify Code'));
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'invalid_verify_code',
    );
    when(() => helper.execute('sms-check-verify-code.mjs', any())).thenAnswer(
      (_) async => {'success': false, 'code': 'VALIDATEFAIL', 'message': ''},
    );
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'invalid_verify_code',
    );
    when(
      () => helper.execute('sms-check-verify-code.mjs', any()),
    ).thenAnswer((_) async => {'success': false, 'code': 'DOWN'});
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'temporary_issue',
    );
    when(() => helper.execute('sms-check-verify-code.mjs', any())).thenAnswer(
      (_) async => {'success': true, 'code': 'OK', 'verifyResult': 'FAIL'},
    );
    expect(
      (await service.verifyCode(
        phoneNumber: '13800000000',
        verifyCode: '123456',
        requestIp: 'ip',
      )).code,
      'invalid_verify_code',
    );
  });

  test('valid provider verification clears both throttles', () async {
    when(() => helper.execute('sms-check-verify-code.mjs', any())).thenAnswer(
      (_) async => {'success': true, 'code': 'OK', 'verifyResult': 'pass'},
    );
    final result = await service.verifyCode(
      phoneNumber: '13800000000',
      verifyCode: '123456',
      requestIp: 'ip',
    );
    expect(result.ok, isTrue);
    verify(
      () => security.clear(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).called(2);
  });
}
