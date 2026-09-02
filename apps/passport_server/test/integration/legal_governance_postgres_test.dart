import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/db/migration_runner.dart';
import 'package:rosm_passport_server/src/repositories/legal_repository.dart';
import 'package:rosm_passport_server/src/models/authenticated_user.dart';
import 'package:rosm_passport_server/src/security/token_service.dart';
import 'package:rosm_passport_server/src/services/activity_log_service.dart';
import 'package:rosm_passport_server/src/services/legal_service.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'initial legal versions are idempotent and acceptance is version-bound',
    () async {
      final keyDirectory = await Directory.systemTemp.createTemp(
        'rosm-legal-jwt-',
      );
      final privatePath = '${keyDirectory.path}/active.private.pem';
      final publicPath = '${keyDirectory.path}/active.public.pem';
      final termsPath = '${keyDirectory.path}/terms-v1.md';
      final privacyPath = '${keyDirectory.path}/privacy-v1.md';
      await File(
        termsPath,
      ).writeAsString('Integration terms for Rosemary Island LLC.');
      await File(
        privacyPath,
      ).writeAsString('Integration privacy policy for Rosemary Island LLC.');
      expect(
        (await Process.run('openssl', [
          'genrsa',
          '-out',
          privatePath,
          '2048',
        ])).exitCode,
        0,
      );
      expect(
        (await Process.run('openssl', [
          'rsa',
          '-in',
          privatePath,
          '-pubout',
          '-out',
          publicPath,
        ])).exitCode,
        0,
      );
      final config = AppConfig.forTesting({
        'DB_HOST': Platform.environment['TEST_DB_HOST'] ?? '127.0.0.1',
        'DB_PORT': Platform.environment['TEST_DB_PORT'] ?? '5432',
        'DB_USER': Platform.environment['TEST_DB_USER'] ?? 'postgres',
        'DB_PASSWORD': Platform.environment['TEST_DB_PASSWORD'] ?? 'postgres',
        'DB_NAME': Platform.environment['TEST_DB_NAME'] ?? 'rosm_passport_test',
        'DB_SSL_MODE': 'disable',
        'DB_POOL_MIN_CONNECTIONS': '1',
        'DB_POOL_MAX_CONNECTIONS': '2',
        'JWT_ACTIVE_KID': 'active',
        'JWT_SIGNING_KEYS_DIR': keyDirectory.path,
        'JWT_BINDING_KEY':
            'legal-integration-binding-key-with-more-than-32-characters',
        'LEGAL_INITIAL_TERMS_FILE': termsPath,
        'LEGAL_INITIAL_PRIVACY_FILE': privacyPath,
      });
      final database = Database(config);
      final repository = LegalRepository(database);
      final service = LegalService(repository, config);
      const userId = 'fd11dbf0-7048-4790-b576-8c5a69bab040';
      try {
        await MigrationRunner(database).migrate();
        await service.ensureInitialDocuments();
        await service.ensureInitialDocuments();
        final current = await service.currentBundle();
        expect(current['terms']['content'], contains('Rosemary Island LLC'));
        expect(current['privacy']['content'], contains('Rosemary Island LLC'));

        await database.execute(
          '''
          insert into users(id, email, nickname, password_hash)
          values (cast(@id as uuid), 'legal-test@example.invalid', 'Legal Test', 'legacy-hash')
          on conflict (id) do nothing
          ''',
          params: {'id': userId},
        );
        expect(await service.hasAcceptedCurrent(userId), isFalse);
        final validation = await service.validate(
          LegalSubmission(
            terms: current['terms']['version'] as int,
            privacy: current['privacy']['version'] as int,
            accepted: true,
          ),
        );
        expect(validation.ok, isTrue);
        await service.record(
          userId: userId,
          validation: validation,
          context: 'integration_test',
          ip: '192.0.2.1',
          userAgent: 'integration-test',
        );
        expect(await service.hasAcceptedCurrent(userId), isTrue);

        final tokens = TokenService(config).issueTokenPair(
          const AuthenticatedUser(
            id: userId,
            email: 'legal-test@example.invalid',
            nickname: 'Legal Test',
            roles: ['user'],
            accessTokenId: 'integration-access',
          ),
        );
        await ActivityLogService(
          database,
          config,
          TokenService(config),
        ).recordRequest(
          method: 'GET',
          path: '/api/v1/me/devices/123',
          statusCode: 403,
          authorization: null,
          cookie: 'rosm_access_token=${tokens.accessToken}',
          ip: '192.0.2.1',
          userAgent: 'integration-test',
        );
        final activity = await database.execute(
          '''
          select actor_id, route_template, risk_level, ip_hash
          from activity_logs where actor_id = cast(@id as uuid)
          order by created_at desc limit 1
          ''',
          params: {'id': userId},
        );
        expect(activity.single[0].toString(), userId);
        expect(activity.single[1], '/api/v1/me/devices/:number');
        expect(activity.single[2], 'security');
        expect(activity.single[3], isNot('192.0.2.1'));
      } finally {
        await database.execute(
          'delete from activity_logs where actor_id = cast(@id as uuid)',
          params: {'id': userId},
        );
        await database.execute(
          'delete from users where id = cast(@id as uuid)',
          params: {'id': userId},
        );
        await database.close();
        await keyDirectory.delete(recursive: true);
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
