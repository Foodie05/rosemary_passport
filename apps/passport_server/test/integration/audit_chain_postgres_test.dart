import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/db/migration_runner.dart';
import 'package:rosm_passport_server/src/services/audit_service.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'recomputes persisted audit hashes and rejects metadata tampering',
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
      final audit = AuditService(database);
      const action = 'test.audit_chain.integrity';
      try {
        await MigrationRunner(database).migrate();
        final before = await audit.verifyChain();
        await audit.log(
          action: action,
          actorId: 'test-actor',
          actorType: 'test',
          resourceType: 'test-record',
          resourceId: 'first',
          metadata: const {
            'result': 'created',
            'nested': {'z': 1, 'a': true},
          },
          ip: '192.0.2.10',
        );
        await audit.log(
          action: action,
          actorId: 'test-actor',
          actorType: 'test',
          resourceType: 'test-record',
          resourceId: 'second',
          metadata: const {'result': 'updated'},
          ip: '192.0.2.11',
        );
        expect(await audit.verifyChain(), before + 2);

        await database.execute(
          '''
          update audit_logs
          set metadata = '{"result":"tampered"}'::jsonb
          where action = @action and resource_id = 'second'
          ''',
          params: {'action': action},
        );
        await expectLater(audit.verifyChain(), throwsStateError);
      } finally {
        try {
          await database.execute(
            'delete from audit_logs where action = @action',
            params: {'action': action},
          );
        } finally {
          await database.close();
        }
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
