import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'query timeout bounds a stalled database call and the pool recovers',
    () async {
      final database = Database(
        AppConfig.forTesting({
          'DB_HOST': Platform.environment['TEST_DB_HOST'] ?? '127.0.0.1',
          'DB_PORT': Platform.environment['TEST_DB_PORT'] ?? '5432',
          'DB_USER': Platform.environment['TEST_DB_USER'] ?? 'postgres',
          'DB_PASSWORD': Platform.environment['TEST_DB_PASSWORD'] ?? 'postgres',
          'DB_NAME':
              Platform.environment['TEST_DB_NAME'] ?? 'rosm_passport_test',
          'DB_SSL_MODE': 'disable',
          'DB_POOL_MIN_CONNECTIONS': '1',
          'DB_POOL_MAX_CONNECTIONS': '2',
          'DB_QUERY_TIMEOUT_SECONDS': '1',
        }),
      );
      final stopwatch = Stopwatch()..start();
      try {
        await expectLater(
          database.execute('select pg_sleep(3)'),
          throwsA(anything),
        );
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));

        final recovered = await database.execute('select 1');
        expect(recovered.first[0], 1);
      } finally {
        await database.close();
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
