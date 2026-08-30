import 'auth_attempts.dart';
import 'security_policy_service.dart';
import 'security_service.dart';

/// Centralizes authentication rate-limit decisions and retry calculations.
class AuthThrottleService {
  AuthThrottleService({
    SecurityService? securityService,
    SecurityPolicyService? securityPolicyService,
  }) : _security = securityService,
       _policy = securityPolicyService;

  final SecurityService? _security;
  final SecurityPolicyService? _policy;

  Future<SecurityPolicy> loadPolicy() {
    return _policy?.load() ?? Future.value(SecurityPolicyService.defaultPolicy);
  }

  Future<int?> loginRetryAfter({
    required String email,
    String? requestIp,
  }) async {
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = await loadPolicy();
    final emailRetry = policy.emailRateLimitEnabled
        ? await security.retryAfterSeconds(
            scope: 'login:email',
            subject: email.trim().toLowerCase(),
          )
        : null;
    final ipSubject = requestIp?.trim() ?? '';
    final ipRetry = ipSubject.isEmpty || !policy.ipRateLimitEnabled
        ? null
        : await security.retryAfterSeconds(
            scope: 'login:ip',
            subject: ipSubject,
          );
    return maxRetryAfter(emailRetry, ipRetry);
  }

  Future<int?> verificationCodeRetryAfter({
    required String email,
    String? requestIp,
    required String emailScope,
    required String ipScope,
    required String cooldownScope,
    required int emailLimit,
    required int ipLimit,
  }) async {
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = await loadPolicy();
    final emailRetry = policy.emailRateLimitEnabled && emailLimit > 0
        ? await security.retryAfterSeconds(
            scope: emailScope,
            subject: email.trim().toLowerCase(),
          )
        : null;
    final ipSubject = requestIp?.trim() ?? '';
    final ipRetry =
        ipSubject.isEmpty || !policy.ipRateLimitEnabled || ipLimit < 1
        ? null
        : await security.retryAfterSeconds(scope: ipScope, subject: ipSubject);
    final cooldownRetry = await verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: cooldownScope,
    );
    return maxRetryAfter(maxRetryAfter(emailRetry, ipRetry), cooldownRetry);
  }

  Future<int?> verificationCodeCooldownRetryAfter({
    required String email,
    required String cooldownScope,
  }) {
    final security = _security;
    if (security == null) {
      return Future.value();
    }
    return security.retryAfterSeconds(
      scope: cooldownScope,
      subject: email.trim().toLowerCase(),
    );
  }

  Future<int?> refreshRetryAfter({String? requestIp}) async {
    final ipSubject = requestIp?.trim() ?? '';
    final security = _security;
    if (ipSubject.isEmpty || security == null) {
      return null;
    }
    final policy = await loadPolicy();
    if (!policy.ipRateLimitEnabled) {
      return null;
    }
    return security.retryAfterSeconds(
      scope: 'refresh:first-party:ip',
      subject: ipSubject,
    );
  }

  Future<LoginAttempt?> enforceLoginGuards({
    required String email,
    String? requestIp,
    required int emailLimit,
    required int ipLimit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = await loadPolicy();
    if (policy.emailRateLimitEnabled) {
      final decision = await security.enforce(
        scope: 'login:email',
        subject: email.trim().toLowerCase(),
        limit: emailLimit,
        window: window,
        blockDuration: blockDuration,
      );
      if (!decision.allowed) {
        return const LoginAttempt.failure(
          code: 'rate_limited',
          message: '尝试次数过多，请稍后再试。',
          statusCode: 429,
        );
      }
    }
    final ipSubject = requestIp?.trim() ?? '';
    if (ipSubject.isEmpty || !policy.ipRateLimitEnabled) {
      return null;
    }
    final decision = await security.enforce(
      scope: 'login:ip',
      subject: ipSubject,
      limit: ipLimit,
      window: window,
      blockDuration: blockDuration,
    );
    return decision.allowed
        ? null
        : const LoginAttempt.failure(
            code: 'rate_limited',
            message: '尝试次数过多，请稍后再试。',
            statusCode: 429,
          );
  }

  Future<AdminLoginCodeAttempt?> enforceRequestGuards({
    required String emailScope,
    required String ipScope,
    required String email,
    String? requestIp,
    required int emailLimit,
    required int ipLimit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    final security = _security;
    if (security == null) {
      return null;
    }
    final policy = await loadPolicy();
    if (policy.emailRateLimitEnabled) {
      final decision = await security.enforce(
        scope: emailScope,
        subject: email.trim().toLowerCase(),
        limit: emailLimit,
        window: window,
        blockDuration: blockDuration,
      );
      if (!decision.allowed) {
        return const AdminLoginCodeAttempt.failure(
          code: 'rate_limited',
          message: '请求过于频繁，请稍后再试。',
          statusCode: 429,
        );
      }
    }
    final ipSubject = requestIp?.trim() ?? '';
    if (ipSubject.isEmpty || !policy.ipRateLimitEnabled) {
      return null;
    }
    final decision = await security.enforce(
      scope: ipScope,
      subject: ipSubject,
      limit: ipLimit,
      window: window,
      blockDuration: blockDuration,
    );
    return decision.allowed
        ? null
        : const AdminLoginCodeAttempt.failure(
            code: 'rate_limited',
            message: '请求过于频繁，请稍后再试。',
            statusCode: 429,
          );
  }

  Future<AdminLoginCodeAttempt?> enforceVerificationCodeSendGuards({
    required String email,
    String? requestIp,
    required SecurityPolicy policy,
    required String emailScope,
    required String ipScope,
    required String cooldownScope,
    required int emailLimit,
    required int ipLimit,
  }) async {
    final cooldownRetry = await verificationCodeCooldownRetryAfter(
      email: email,
      cooldownScope: cooldownScope,
    );
    if (cooldownRetry != null) {
      return const AdminLoginCodeAttempt.failure(
        code: 'rate_limited',
        message: '请求过于频繁，请稍后再试。',
        statusCode: 429,
      );
    }
    return enforceRequestGuards(
      emailScope: emailScope,
      ipScope: ipScope,
      email: email,
      requestIp: requestIp,
      emailLimit: emailLimit,
      ipLimit: ipLimit,
      window: Duration(seconds: policy.adminLoginCodeWindowSeconds),
      blockDuration: Duration(seconds: policy.adminLoginCodeBlockSeconds),
    );
  }

  Future<void> clearLoginGuards({required String email}) {
    final security = _security;
    return security?.clear(
          scope: 'login:email',
          subject: email.trim().toLowerCase(),
        ) ??
        Future.value();
  }

  Future<void> startVerificationCodeCooldown({
    required String email,
    required int seconds,
    required String cooldownScope,
  }) {
    final security = _security;
    return security?.startCooldown(
          scope: cooldownScope,
          subject: email.trim().toLowerCase(),
          duration: Duration(seconds: seconds),
        ) ??
        Future.value();
  }

  int? maxRetryAfter(int? left, int? right) {
    if (left == null) {
      return right;
    }
    if (right == null) {
      return left;
    }
    return left > right ? left : right;
  }
}
