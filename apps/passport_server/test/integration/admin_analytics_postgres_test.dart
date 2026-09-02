import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/db/migration_runner.dart';
import 'package:rosm_passport_server/src/repositories/admin_analytics_repository.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'dashboard uses Beijing calendar boundaries and date-only labels',
    () async {
      final config = AppConfig.forTesting({
        'DB_HOST': Platform.environment['TEST_DB_HOST'] ?? '127.0.0.1',
        'DB_PORT': Platform.environment['TEST_DB_PORT'] ?? '5432',
        'DB_USER': Platform.environment['TEST_DB_USER'] ?? 'postgres',
        'DB_PASSWORD': Platform.environment['TEST_DB_PASSWORD'] ?? 'postgres',
        'DB_NAME': Platform.environment['TEST_DB_NAME'] ?? 'rosm_passport_test',
        'DB_SSL_MODE': 'disable',
        'DB_POOL_MIN_CONNECTIONS': '1',
        'DB_POOL_MAX_CONNECTIONS': '2',
      });
      final database = Database(config);
      const todayUser = 'fd11dbf0-7048-4790-b576-8c5a69bab050';
      const previousUser = 'fd11dbf0-7048-4790-b576-8c5a69bab051';
      try {
        await MigrationRunner(database).migrate();
        await database.execute(
          '''
          insert into users(id, email, nickname, password_hash, created_at)
          values
            (
              cast(@today_id as uuid), 'analytics-today@example.invalid',
              'Analytics Today', 'legacy-hash', now()
            ),
            (
              cast(@previous_id as uuid), 'analytics-previous@example.invalid',
              'Analytics Previous', 'legacy-hash',
              (
                (now() at time zone 'Asia/Shanghai')::date
                  - interval '30 minutes'
              ) at time zone 'Asia/Shanghai'
            )
          on conflict (id) do update set created_at = excluded.created_at
          ''',
          params: {'today_id': todayUser, 'previous_id': previousUser},
        );

        final expectedDates = await database.execute('''
          select
            to_char(
              (now() at time zone 'Asia/Shanghai')::date,
              'YYYY-MM-DD'
            ),
            to_char(
              (now() at time zone 'Asia/Shanghai')::date - 1,
              'YYYY-MM-DD'
            )
          ''');
        final dashboard = await AdminAnalyticsRepository(
          database,
        ).dashboard(days: 7);
        final growth = dashboard['user_growth'] as List<dynamic>;
        expect(growth, hasLength(7));
        expect(
          growth.every(
            (dynamic row) => RegExp(
              r'^\d{4}-\d{2}-\d{2}$',
            ).hasMatch((row as Map<String, dynamic>)['date'] as String),
          ),
          isTrue,
        );

        final today = growth.cast<Map<String, dynamic>>().singleWhere(
          (row) => row['date'] == expectedDates.single[0],
        );
        final previous = growth.cast<Map<String, dynamic>>().singleWhere(
          (row) => row['date'] == expectedDates.single[1],
        );
        expect(today['new_users'] as int, greaterThanOrEqualTo(1));
        expect(previous['new_users'] as int, greaterThanOrEqualTo(1));
      } finally {
        await database.execute(
          'delete from users where id in (cast(@today as uuid), cast(@previous as uuid))',
          params: {'today': todayUser, 'previous': previousUser},
        );
        await database.close();
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
