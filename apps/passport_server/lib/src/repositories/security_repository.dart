import 'package:postgres/postgres.dart';

import '../db/database.dart';

class ThrottleState {
  const ThrottleState({
    required this.hits,
    required this.windowStartedAt,
    this.blockedUntil,
  });

  final int hits;
  final DateTime windowStartedAt;
  final DateTime? blockedUntil;

  bool get isBlocked =>
      blockedUntil != null && blockedUntil!.isAfter(DateTime.now().toUtc());
}

class SecurityRepository {
  SecurityRepository(this._db);

  final Database _db;

  Future<ThrottleState?> findThrottle({
    required String scope,
    required String subject,
  }) async {
    final result = await _db.execute(
      '''
      select hits, window_started_at, blocked_until
      from security_throttles
      where scope = @scope and subject = @subject
      ''',
      params: {
        'scope': scope,
        'subject': subject,
      },
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return ThrottleState(
      hits: row[0] as int,
      windowStartedAt: row[1] as DateTime,
      blockedUntil: row[2] as DateTime?,
    );
  }

  Future<ThrottleState> recordHit({
    required String scope,
    required String subject,
    required int limit,
    required Duration window,
    required Duration blockDuration,
  }) async {
    return _db.runTx((tx) async {
      final result = await tx.execute(
        Sql.named(
          '''
          select hits, window_started_at, blocked_until
          from security_throttles
          where scope = @scope and subject = @subject
          for update
          ''',
        ),
        parameters: {
          'scope': scope,
          'subject': subject,
        },
      );

      final now = DateTime.now().toUtc();
      if (result.isEmpty) {
        await tx.execute(
          Sql.named(
            '''
            insert into security_throttles(scope, subject, hits, window_started_at, blocked_until, updated_at)
            values (@scope, @subject, 1, @now, null, @now)
            ''',
          ),
          parameters: {
            'scope': scope,
            'subject': subject,
            'now': now,
          },
        );

        return ThrottleState(hits: 1, windowStartedAt: now);
      }

      final row = result.first;
      final previousHits = row[0] as int;
      final windowStartedAt = row[1] as DateTime;
      final blockedUntil = row[2] as DateTime?;

      if (blockedUntil != null && blockedUntil.isAfter(now)) {
        return ThrottleState(
          hits: previousHits,
          windowStartedAt: windowStartedAt,
          blockedUntil: blockedUntil,
        );
      }

      final expiredWindow = windowStartedAt.add(window).isBefore(now);
      if (expiredWindow) {
        await tx.execute(
          Sql.named(
            '''
            update security_throttles
            set hits = 1,
                window_started_at = @now,
                blocked_until = null,
                updated_at = @now
            where scope = @scope and subject = @subject
            ''',
          ),
          parameters: {
            'scope': scope,
            'subject': subject,
            'now': now,
          },
        );

        return ThrottleState(hits: 1, windowStartedAt: now);
      }

      final nextHits = previousHits + 1;
      final nextBlockedUntil = nextHits > limit ? now.add(blockDuration) : null;

      await tx.execute(
        Sql.named(
          '''
          update security_throttles
          set hits = @hits,
              blocked_until = @blocked_until,
              updated_at = @now
          where scope = @scope and subject = @subject
          ''',
        ),
        parameters: {
          'scope': scope,
          'subject': subject,
          'hits': nextHits,
          'blocked_until': nextBlockedUntil,
          'now': now,
        },
      );

      return ThrottleState(
        hits: nextHits,
        windowStartedAt: windowStartedAt,
        blockedUntil: nextBlockedUntil,
      );
    });
  }

  Future<void> clearThrottle({
    required String scope,
    required String subject,
  }) async {
    await _db.execute(
      'delete from security_throttles where scope = @scope and subject = @subject',
      params: {
        'scope': scope,
        'subject': subject,
      },
    );
  }

  Future<void> setBlockedUntil({
    required String scope,
    required String subject,
    required DateTime blockedUntil,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.execute(
      '''
      insert into security_throttles(scope, subject, hits, window_started_at, blocked_until, updated_at)
      values (@scope, @subject, 0, @now, @blocked_until, @now)
      on conflict (scope, subject) do update
      set blocked_until = @blocked_until,
          updated_at = @now
      ''',
      params: {
        'scope': scope,
        'subject': subject,
        'now': now,
        'blocked_until': blockedUntil,
      },
    );
  }
}
