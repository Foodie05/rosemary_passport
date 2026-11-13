import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/repositories/security_repository.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';
  const prefix = 'verification-code:status-null-regression';
  late Database db;
  late SecurityRepository repository;

  setUpAll(() async {
    if (!enabled) return;
    db = Database(
      AppConfig.forTesting({
        'DB_HOST': Platform.environment['TEST_DB_HOST'] ?? '127.0.0.1',
        'DB_PORT': Platform.environment['TEST_DB_PORT'] ?? '5432',
        'DB_USER': Platform.environment['TEST_DB_USER'] ?? 'postgres',
        'DB_PASSWORD': Platform.environment['TEST_DB_PASSWORD'] ?? 'postgres',
        'DB_NAME': Platform.environment['TEST_DB_NAME'] ?? 'rosm_passport_test',
        'DB_SSL_MODE': 'disable',
        'DB_POOL_MIN_CONNECTIONS': '1',
        'DB_POOL_MAX_CONNECTIONS': '2',
      }),
    );
    repository = SecurityRepository(db);
    await db.execute('''
      create table if not exists security_throttles (
        scope text not null,
        subject text not null,
        hits integer not null,
        window_started_at timestamptz not null,
        blocked_until timestamptz,
        updated_at timestamptz not null,
        primary key (scope, subject)
      )
    ''');
    await db.execute('''
      insert into security_throttles
        (scope, subject, hits, window_started_at, blocked_until, updated_at)
      values
        ('$prefix:email', 'unblocked@example.invalid', 1, now(), null, now()),
        ('$prefix:phone', '+8613800000000', 2, now(), now() - interval '1 hour', now() - interval '1 minute'),
        ('$prefix:ip', '203.0.113.42', 3, now(), now() + interval '1 hour', now() - interval '2 minutes'),
        ('$prefix:email', 'expired@example.invalid', 4, now(), now() - interval '2 hours', now() - interval '3 minutes')
    ''');
  });

  tearDownAll(() async {
    if (!enabled) return;
    try {
      await db.execute(
        'delete from security_throttles where scope like @prefix',
        params: {'prefix': '$prefix:%'},
      );
    } finally {
      await db.close();
    }
  });

  test(
    'lists null, expired and active deadlines with non-null flags and active rows first',
    () async {
      final page = await repository.listVerificationCodeThrottles(
        limit: 25,
        offset: 0,
        search: prefix,
      );
      expect(page.total, 4);
      expect(page.records, hasLength(4));
      expect(page.records.first.subjectType, 'ip');
      expect(page.records.first.isActive, isTrue);
      expect(page.records.first.remainingSeconds, greaterThan(0));
      final unblocked = page.records.singleWhere(
        (row) => row.blockedUntil == null,
      );
      expect(unblocked.isActive, isFalse);
      expect(unblocked.remainingSeconds, 0);
      expect(page.records.where((row) => !row.isActive), hasLength(3));
    },
    skip: !enabled,
  );

  test(
    'subject, search and active-only filters retain their meaning',
    () async {
      for (final type in ['email', 'phone', 'ip']) {
        final page = await repository.listVerificationCodeThrottles(
          limit: 25,
          offset: 0,
          search: prefix,
          subjectType: type,
        );
        expect(page.total, type == 'email' ? 2 : 1);
        expect(page.records.every((row) => row.subjectType == type), isTrue);
      }
      final active = await repository.listVerificationCodeThrottles(
        limit: 25,
        offset: 0,
        search: prefix,
        activeOnly: true,
      );
      expect(active.total, 1);
      expect(active.records.single.subjectType, 'ip');
      final empty = await repository.listVerificationCodeThrottles(
        limit: 25,
        offset: 0,
        search: prefix,
        subjectType: 'email',
        activeOnly: true,
      );
      expect(empty.total, 0);
      expect(empty.records, isEmpty);
    },
    skip: !enabled,
  );

  test(
    'pagination traverses null and expired rows without gaps or duplicates',
    () async {
      final first = await repository.listVerificationCodeThrottles(
        limit: 2,
        offset: 0,
        search: prefix,
      );
      final second = await repository.listVerificationCodeThrottles(
        limit: 2,
        offset: 2,
        search: prefix,
      );
      expect(first.total, 4);
      expect(second.total, 4);
      expect(
        [...first.records, ...second.records].map((row) => row.subject).toSet(),
        hasLength(4),
      );
    },
    skip: !enabled,
  );

  test(
    'listing never changes deadlines, counters or stored identities',
    () async {
      Future<List<List<Object?>>> snapshot() async => (await db.execute(
        'select * from security_throttles where scope like @prefix order by scope, subject',
        params: {'prefix': '$prefix:%'},
      )).map((row) => row.toList()).toList();
      final before = await snapshot();
      await repository.listVerificationCodeThrottles(
        limit: 25,
        offset: 0,
        search: prefix,
      );
      await repository.listVerificationCodeThrottles(
        limit: 25,
        offset: 0,
        search: prefix,
        activeOnly: true,
      );
      expect(await snapshot(), equals(before));
    },
    skip: !enabled,
  );
}
