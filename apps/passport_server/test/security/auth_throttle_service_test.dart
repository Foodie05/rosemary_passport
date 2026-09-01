import 'package:mocktail/mocktail.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/security_policy_service.dart';
import 'package:rosm_passport_server/src/services/security_service.dart';
import 'package:test/test.dart';

class _MockSecurity extends Mock implements SecurityService {}

class _MockPolicyService extends Mock implements SecurityPolicyService {}

class _MockPolicy extends Mock implements SecurityPolicy {}

void main() {
  late _MockSecurity security;
  late _MockPolicyService policies;
  late _MockPolicy policy;
  late AuthThrottleService service;

  setUpAll(() {
    registerFallbackValue(const Duration(seconds: 1));
  });

  setUp(() {
    security = _MockSecurity();
    policies = _MockPolicyService();
    policy = _MockPolicy();
    service = AuthThrottleService(
      securityService: security,
      securityPolicyService: policies,
    );
    when(() => policies.load()).thenAnswer((_) async => policy);
    when(() => policy.emailRateLimitEnabled).thenReturn(true);
    when(() => policy.ipRateLimitEnabled).thenReturn(true);
    when(() => policy.adminLoginCodeWindowSeconds).thenReturn(60);
    when(() => policy.adminLoginCodeBlockSeconds).thenReturn(120);
  });

  test('disabled throttling is a safe no-op', () async {
    final disabled = AuthThrottleService();
    expect(
      await disabled.loginRetryAfter(email: 'user@example.invalid'),
      isNull,
    );
    expect(
      await disabled.verificationCodeRetryAfter(
        email: 'user@example.invalid',
        emailScope: 'email',
        ipScope: 'ip',
        cooldownScope: 'cooldown',
        emailLimit: 1,
        ipLimit: 1,
      ),
      isNull,
    );
    expect(
      await disabled.verificationCodeCooldownRetryAfter(
        email: 'user@example.invalid',
        cooldownScope: 'cooldown',
      ),
      isNull,
    );
    expect(await disabled.refreshRetryAfter(requestIp: ' '), isNull);
    expect(
      await disabled.enforceLoginGuards(
        email: 'user@example.invalid',
        emailLimit: 1,
        ipLimit: 1,
        window: const Duration(seconds: 1),
        blockDuration: const Duration(seconds: 1),
      ),
      isNull,
    );
    expect(
      await disabled.enforceRequestGuards(
        emailScope: 'email',
        ipScope: 'ip',
        email: 'user@example.invalid',
        emailLimit: 1,
        ipLimit: 1,
        window: const Duration(seconds: 1),
        blockDuration: const Duration(seconds: 1),
      ),
      isNull,
    );
    await disabled.clearLoginGuards(email: 'user@example.invalid');
    await disabled.startVerificationCodeCooldown(
      email: 'user@example.invalid',
      seconds: 1,
      cooldownScope: 'cooldown',
    );
    expect(await disabled.consumeOneTimeProof('proof-id'), isTrue);
    expect(disabled.maxRetryAfter(null, 2), 2);
    expect(disabled.maxRetryAfter(3, null), 3);
    expect(disabled.maxRetryAfter(3, 2), 3);
    expect(disabled.maxRetryAfter(1, 2), 2);
    expect(await disabled.loadPolicy(), SecurityPolicyService.defaultPolicy);
  });

  test('retry calculations return the longest active block', () async {
    when(
      () => security.retryAfterSeconds(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((invocation) async {
      final scope = invocation.namedArguments[#scope] as String;
      return switch (scope) {
        'login:email' => 3,
        'login:ip' => 7,
        'email' => 2,
        'ip' => 4,
        'cooldown' => 6,
        'refresh:first-party:ip' => 5,
        _ => null,
      };
    });
    expect(
      await service.loginRetryAfter(
        email: ' USER@EXAMPLE.INVALID ',
        requestIp: ' 192.0.2.1 ',
      ),
      7,
    );
    expect(
      await service.verificationCodeRetryAfter(
        email: 'USER@EXAMPLE.INVALID',
        requestIp: '192.0.2.1',
        emailScope: 'email',
        ipScope: 'ip',
        cooldownScope: 'cooldown',
        emailLimit: 1,
        ipLimit: 1,
      ),
      6,
    );
    expect(await service.refreshRetryAfter(requestIp: '192.0.2.1'), 5);
    when(() => policy.ipRateLimitEnabled).thenReturn(false);
    expect(await service.refreshRetryAfter(requestIp: '192.0.2.1'), isNull);
  });

  test('login guards reject blocked email or IP subjects', () async {
    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((invocation) async {
      final scope = invocation.namedArguments[#scope] as String;
      return ThrottleDecision(allowed: scope != 'login:email');
    });
    final emailBlocked = await service.enforceLoginGuards(
      email: 'user@example.invalid',
      requestIp: '192.0.2.1',
      emailLimit: 1,
      ipLimit: 1,
      window: const Duration(seconds: 1),
      blockDuration: const Duration(seconds: 1),
    );
    expect(emailBlocked?.statusCode, 429);

    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((invocation) async {
      final scope = invocation.namedArguments[#scope] as String;
      return ThrottleDecision(allowed: scope != 'login:ip');
    });
    final ipBlocked = await service.enforceLoginGuards(
      email: 'user@example.invalid',
      requestIp: '192.0.2.1',
      emailLimit: 1,
      ipLimit: 1,
      window: const Duration(seconds: 1),
      blockDuration: const Duration(seconds: 1),
    );
    expect(ipBlocked?.statusCode, 429);

    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => const ThrottleDecision(allowed: true));
    expect(
      await service.enforceLoginGuards(
        email: 'user@example.invalid',
        requestIp: '192.0.2.1',
        emailLimit: 1,
        ipLimit: 1,
        window: const Duration(seconds: 1),
        blockDuration: const Duration(seconds: 1),
      ),
      isNull,
    );
  });

  test('verification guards honor cooldown, email, and IP limits', () async {
    when(
      () => security.retryAfterSeconds(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async => 30);
    final cooldown = await service.enforceVerificationCodeSendGuards(
      email: 'user@example.invalid',
      requestIp: '192.0.2.1',
      policy: policy,
      emailScope: 'email',
      ipScope: 'ip',
      cooldownScope: 'cooldown',
      emailLimit: 1,
      ipLimit: 1,
    );
    expect(cooldown?.statusCode, 429);

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
    ).thenAnswer((invocation) async {
      final scope = invocation.namedArguments[#scope] as String;
      return ThrottleDecision(allowed: scope != 'email');
    });
    final emailBlocked = await service.enforceVerificationCodeSendGuards(
      email: 'user@example.invalid',
      requestIp: '192.0.2.1',
      policy: policy,
      emailScope: 'email',
      ipScope: 'ip',
      cooldownScope: 'cooldown',
      emailLimit: 1,
      ipLimit: 1,
    );
    expect(emailBlocked?.statusCode, 429);

    when(
      () => security.enforce(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        limit: any(named: 'limit'),
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((invocation) async {
      final scope = invocation.namedArguments[#scope] as String;
      return ThrottleDecision(allowed: scope != 'ip');
    });
    final ipBlocked = await service.enforceRequestGuards(
      emailScope: 'email',
      ipScope: 'ip',
      email: 'user@example.invalid',
      requestIp: '192.0.2.1',
      emailLimit: 1,
      ipLimit: 1,
      window: const Duration(seconds: 1),
      blockDuration: const Duration(seconds: 1),
    );
    expect(ipBlocked?.statusCode, 429);
  });

  test('guard state can be cleared and cooldown started', () async {
    when(
      () => security.clear(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => security.startCooldown(
        scope: any(named: 'scope'),
        subject: any(named: 'subject'),
        duration: any(named: 'duration'),
      ),
    ).thenAnswer((_) async {});
    await service.clearLoginGuards(email: ' USER@EXAMPLE.INVALID ');
    await service.startVerificationCodeCooldown(
      email: ' USER@EXAMPLE.INVALID ',
      seconds: 45,
      cooldownScope: 'cooldown',
    );
    when(
      () => security.enforce(
        scope: 'auth:one-time-proof',
        subject: 'proof-id',
        limit: 1,
        window: any(named: 'window'),
        blockDuration: any(named: 'blockDuration'),
      ),
    ).thenAnswer((_) async => const ThrottleDecision(allowed: true));
    expect(await service.consumeOneTimeProof('proof-id'), isTrue);
    verify(
      () =>
          security.clear(scope: 'login:email', subject: 'user@example.invalid'),
    ).called(1);
    verify(
      () => security.startCooldown(
        scope: 'cooldown',
        subject: 'user@example.invalid',
        duration: const Duration(seconds: 45),
      ),
    ).called(1);
  });
}
