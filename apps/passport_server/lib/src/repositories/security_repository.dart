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

class ThrottleRecord {
  const ThrottleRecord({
    required this.scope,
    required this.subject,
    required this.subjectType,
    required this.hits,
    required this.windowStartedAt,
    required this.updatedAt,
    required this.isActive,
    required this.remainingSeconds,
    this.blockedUntil,
  });

  final String scope;
  final String subject;
  final String subjectType;
  final int hits;
  final DateTime windowStartedAt;
  final DateTime? blockedUntil;
  final DateTime updatedAt;
  final bool isActive;
  final int remainingSeconds;

  Map<String, dynamic> toJson() => {
    'scope': scope,
    'subject': subject,
    'subject_type': subjectType,
    'hits': hits,
    'window_started_at': windowStartedAt.toUtc().toIso8601String(),
    'blocked_until': blockedUntil?.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'is_active': isActive,
    'remaining_seconds': remainingSeconds,
  };
}

class ThrottlePage {
  const ThrottlePage({required this.records, required this.total});

  final List<ThrottleRecord> records;
  final int total;
}

class SecurityRepository {
  SecurityRepository(this._db);

  final Database _db;

  Future<ThrottlePage> listVerificationCodeThrottles({
    required int limit,
    required int offset,
    String search = '',
    String subjectType = 'all',
    bool activeOnly = false,
  }) async {
    final filters = <String>["scope like 'verification-code:%'"];
    final params = <String, Object?>{};
    if (search.isNotEmpty) {
      filters.add('(scope ilike @search or subject ilike @search)');
      params['search'] = '%$search%';
    }
    if (subjectType != 'all') {
      filters.add('''
        case
          when scope like '%:ip' then 'ip'
          when scope like '%:phone' then 'phone'
          else 'email'
        end = @subject_type
      ''');
      params['subject_type'] = subjectType;
    }
    if (activeOnly) {
      filters.add('blocked_until > clock_timestamp()');
    }
    final where = filters.join(' and ');
    final rows = await _db.execute(
      '''
      select scope,
             subject,
             case
               when scope like '%:ip' then 'ip'
               when scope like '%:phone' then 'phone'
               else 'email'
             end as subject_type,
             hits,
             window_started_at,
             blocked_until,
             updated_at,
             blocked_until > clock_timestamp() as is_active,
             case
               when blocked_until > clock_timestamp()
                 then greatest(
                   1,
                   ceil(extract(epoch from blocked_until - clock_timestamp()))
                 )::integer
               else 0
             end as remaining_seconds
      from security_throttles
      where $where
      order by (blocked_until > clock_timestamp()) desc, updated_at desc,
               scope, subject
      limit @limit offset @offset
      ''',
      params: {...params, 'limit': limit, 'offset': offset},
    );
    final count = await _db.execute(
      'select count(*) from security_throttles where $where',
      params: params,
    );
    return ThrottlePage(
      records: rows
          .map(
            (row) => ThrottleRecord(
              scope: row[0] as String,
              subject: row[1] as String,
              subjectType: row[2] as String,
              hits: row[3] as int,
              windowStartedAt: row[4] as DateTime,
              blockedUntil: row[5] as DateTime?,
              updatedAt: row[6] as DateTime,
              isActive: row[7] as bool,
              remainingSeconds: row[8] as int,
            ),
          )
          .toList(),
      total: count.first[0] as int,
    );
  }

  Future<bool> deleteVerificationCodeThrottle({
    required String scope,
    required String subject,
  }) async {
    final result = await _db.execute(
      '''
      delete from security_throttles
      where scope = @scope
        and subject = @subject
        and scope like 'verification-code:%'
      returning scope
      ''',
      params: {'scope': scope, 'subject': subject},
    );
    return result.isNotEmpty;
  }

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
      params: {'scope': scope, 'subject': subject},
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
        Sql.named('''
          select hits, window_started_at, blocked_until
          from security_throttles
          where scope = @scope and subject = @subject
          for update
          '''),
        parameters: {'scope': scope, 'subject': subject},
      );

      final now = DateTime.now().toUtc();
      if (result.isEmpty) {
        await tx.execute(
          Sql.named('''
            insert into security_throttles(scope, subject, hits, window_started_at, blocked_until, updated_at)
            values (@scope, @subject, 1, @now, null, @now)
            '''),
          parameters: {'scope': scope, 'subject': subject, 'now': now},
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
          Sql.named('''
            update security_throttles
            set hits = 1,
                window_started_at = @now,
                blocked_until = null,
                updated_at = @now
            where scope = @scope and subject = @subject
            '''),
          parameters: {'scope': scope, 'subject': subject, 'now': now},
        );

        return ThrottleState(hits: 1, windowStartedAt: now);
      }

      final nextHits = previousHits + 1;
      final nextBlockedUntil = nextHits > limit ? now.add(blockDuration) : null;

      await tx.execute(
        Sql.named('''
          update security_throttles
          set hits = @hits,
              blocked_until = @blocked_until,
              updated_at = @now
          where scope = @scope and subject = @subject
          '''),
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
      params: {'scope': scope, 'subject': subject},
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
