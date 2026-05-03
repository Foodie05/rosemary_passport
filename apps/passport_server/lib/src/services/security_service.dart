import '../repositories/security_repository.dart';

class ThrottleDecision {
  const ThrottleDecision({
    required this.allowed,
    this.retryAfterSeconds,
  });

  final bool allowed;
  final int? retryAfterSeconds;
}

class SecurityService {
  SecurityService(this._repository);

  final SecurityRepository _repository;

  Future<ThrottleDecision> enforce({
    required String scope,
    required String subject,
    required int limit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    final state = await _repository.recordHit(
      scope: scope,
      subject: subject,
      limit: limit,
      window: window,
      blockDuration: blockDuration,
    );

    if (!state.isBlocked) {
      return const ThrottleDecision(allowed: true);
    }

    final now = DateTime.now().toUtc();
    final retryAfter = state.blockedUntil!.difference(now).inSeconds;
    return ThrottleDecision(
      allowed: false,
      retryAfterSeconds: retryAfter < 1 ? 1 : retryAfter,
    );
  }

  Future<bool> isBlocked({
    required String scope,
    required String subject,
  }) async {
    final state = await _repository.findThrottle(
      scope: scope,
      subject: subject,
    );
    return state?.isBlocked ?? false;
  }

  Future<int?> retryAfterSeconds({
    required String scope,
    required String subject,
  }) async {
    final state = await _repository.findThrottle(
      scope: scope,
      subject: subject,
    );
    if (state == null || !state.isBlocked) {
      return null;
    }

    final seconds =
        state.blockedUntil!.difference(DateTime.now().toUtc()).inSeconds;
    return seconds < 1 ? 1 : seconds;
  }

  Future<void> clear({
    required String scope,
    required String subject,
  }) {
    return _repository.clearThrottle(scope: scope, subject: subject);
  }

  Future<void> startCooldown({
    required String scope,
    required String subject,
    required Duration duration,
  }) {
    return _repository.setBlockedUntil(
      scope: scope,
      subject: subject,
      blockedUntil: DateTime.now().toUtc().add(duration),
    );
  }
}
