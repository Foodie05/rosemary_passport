import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/repositories/email_code_repository.dart';
import 'package:rosm_passport_server/src/services/email_code_service.dart';
import 'package:rosm_passport_server/src/services/email_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:test/test.dart';

class _MockRepository extends Mock implements EmailCodeRepository {}

class _MockEmail extends Mock implements EmailService {}

class _MockPolicy extends Mock implements SecurityPolicyService {}

void main() {
  const address = 'User@Example.Invalid';
  late _MockRepository repository;
  late _MockEmail email;
  late EmailCodeService service;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    repository = _MockRepository();
    email = _MockEmail();
    service = EmailCodeService(
      AppConfig.forTesting(const {
        'EMAIL_CODE_HMAC_KEY':
            'test-email-code-hmac-key-with-at-least-thirty-two-bytes',
        'EMAIL_CODE_TTL_SECONDS': '420',
      }),
      repository,
      email,
      null,
    );
    when(
      () => repository.storeCode(
        email: any(named: 'email'),
        codeHash: any(named: 'codeHash'),
        expiresAt: any(named: 'expiresAt'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer((_) async => 'code-id');
    when(
      () => email.sendVerificationCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
        templateName: any(named: 'templateName'),
      ),
    ).thenAnswer((_) async {});
  });

  test('issues every supported purpose with six-digit random codes', () async {
    await service.issueRegisterCode(address);
    await service.issueBindEmailCode(address);
    await service.issuePasswordResetCode(address);
    await service.issueAdminLoginCode(address);
    await service.issueLoginCode(address, templateName: 'custom_login');

    final stored = verify(
      () => repository.storeCode(
        email: address,
        codeHash: captureAny(named: 'codeHash'),
        expiresAt: captureAny(named: 'expiresAt'),
        purpose: captureAny(named: 'purpose'),
      ),
    ).captured;
    expect(
      stored.whereType<String>().where((value) => value.length == 64),
      hasLength(5),
    );
    expect(stored.whereType<DateTime>(), everyElement(isA<DateTime>()));
    final purposes = stored
        .whereType<String>()
        .where((value) => value.length != 64)
        .toList();
    expect(purposes, [
      'register',
      'bind_email',
      'password_reset',
      'login',
      'login',
    ]);
    final codes =
        verify(
          () => email.sendVerificationCode(
            email: address,
            code: captureAny(named: 'code'),
            templateName: captureAny(named: 'templateName'),
          ),
        ).captured.whereType<String>().where(
          (value) => RegExp(r'^\d{6}$').hasMatch(value),
        );
    expect(codes, hasLength(5));
  });

  test(
    'validation rejects missing, used, expired, and exhausted codes',
    () async {
      when(
        () => repository.findLatestCode(
          email: any(named: 'email'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => null);
      expect(await service.verifyRegisterCode(address, '123456'), isFalse);

      Future<bool> verifyItem(Map<String, dynamic> item) async {
        when(
          () => repository.findLatestCode(
            email: any(named: 'email'),
            purpose: any(named: 'purpose'),
          ),
        ).thenAnswer((_) async => item);
        return service.verifyBindEmailCode(address, '123456');
      }

      final future = DateTime.now().toUtc().add(const Duration(minutes: 5));
      expect(
        await verifyItem({
          'id': 'used',
          'code_hash': 'hash',
          'expires_at': future,
          'used_at': DateTime.now().toUtc(),
          'failed_attempts': 0,
        }),
        isFalse,
      );
      expect(
        await verifyItem({
          'id': 'expired',
          'code_hash': 'hash',
          'expires_at': DateTime.now().toUtc().subtract(
            const Duration(seconds: 1),
          ),
          'used_at': null,
          'failed_attempts': 0,
        }),
        isFalse,
      );
      expect(
        await verifyItem({
          'id': 'exhausted',
          'code_hash': 'hash',
          'expires_at': future,
          'used_at': null,
          'failed_attempts':
              SecurityPolicyService.defaultPolicy.emailCodeMaxAttempts,
        }),
        isFalse,
      );
    },
  );

  test('wrong codes increment attempts and valid codes consume once', () async {
    String? code;
    String? digest;
    when(
      () => repository.storeCode(
        email: any(named: 'email'),
        codeHash: any(named: 'codeHash'),
        expiresAt: any(named: 'expiresAt'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer((invocation) async {
      digest = invocation.namedArguments[#codeHash] as String;
      return 'code-id';
    });
    when(
      () => email.sendVerificationCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
        templateName: any(named: 'templateName'),
      ),
    ).thenAnswer((invocation) async {
      code = invocation.namedArguments[#code] as String;
    });
    await service.issueLoginCode(address);

    when(
      () => repository.findLatestCode(
        email: any(named: 'email'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer(
      (_) async => {
        'id': 'code-id',
        'code_hash': digest,
        'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)),
        'used_at': null,
        'failed_attempts': 0,
      },
    );
    when(() => repository.markFailed('code-id')).thenAnswer((_) async {});
    expect(await service.verifyAdminLoginCode(address, '000000'), isFalse);
    verify(() => repository.markFailed('code-id')).called(1);

    when(
      () => repository.markUsedIfAvailable('code-id'),
    ).thenAnswer((_) async => true);
    expect(await service.verifyLoginCode(address, code!), isTrue);
    expect(await service.validateLoginCode(address, code!), 'code-id');
    expect(await service.consumeCode('code-id'), isTrue);
  });

  test('failed SMTP delivery invalidates the newly stored code', () async {
    when(() => repository.markUsed('code-id')).thenAnswer((_) async {});
    when(
      () => email.sendVerificationCode(
        email: any(named: 'email'),
        code: any(named: 'code'),
        templateName: any(named: 'templateName'),
      ),
    ).thenThrow(StateError('smtp unavailable'));

    await expectLater(service.issueLoginCode(address), throwsStateError);
    verify(() => repository.markUsed('code-id')).called(1);
  });

  test('loads the dynamic attempt policy when configured', () async {
    final policy = _MockPolicy();
    when(
      () => policy.load(),
    ).thenAnswer((_) async => SecurityPolicyService.defaultPolicy);
    service = EmailCodeService(
      AppConfig.forTesting(const {
        'EMAIL_CODE_HMAC_KEY':
            'test-email-code-hmac-key-with-at-least-thirty-two-bytes',
      }),
      repository,
      email,
      policy,
    );
    when(
      () => repository.findLatestCode(
        email: any(named: 'email'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer(
      (_) async => {
        'id': 'code-id',
        'code_hash': 'wrong',
        'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 5)),
        'used_at': null,
        'failed_attempts': 0,
      },
    );
    when(() => repository.markFailed('code-id')).thenAnswer((_) async {});
    expect(await service.verifyPasswordResetCode(address, '123456'), isFalse);
    verify(() => policy.load()).called(1);
  });
}
