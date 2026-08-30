import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/db/migration_runner.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/settings_cipher.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test('expand migration preserves legacy rows and is idempotent', () async {
    final keyDirectory = await Directory.systemTemp.createTemp(
      'rosm-migration-keys-',
    );
    File('${keyDirectory.path}/old.key').writeAsStringSync(
      'old-database-key-material-with-more-than-thirty-two-characters',
    );
    File('${keyDirectory.path}/new.key').writeAsStringSync(
      'new-database-key-material-with-more-than-thirty-two-characters',
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
      'DATA_ENCRYPTION_ACTIVE_KID': 'new',
      'DATA_ENCRYPTION_KEYS_DIR': keyDirectory.path,
    });
    final database = Database(config);
    final runner = MigrationRunner(database);
    const userId = 'fd11dbf0-7048-4790-b576-8c5a69bab010';
    try {
      await runner.migrate();
      final compatibilityMigration = MigrationRunner.migrations.last;
      await database.execute(
        'delete from schema_migrations where version = @version',
        params: {'version': compatibilityMigration.version},
      );
      await database.execute(
        'alter table oidc_refresh_tokens alter column family_id drop default',
      );
      await database.execute(
        'alter table user_webauthn_credentials alter column uv_grace_expires_at drop default',
      );
      await database.execute(
        '''
          insert into users(id, email, nickname, password_hash)
          values (
            cast(@id as uuid), 'migration-test@example.invalid',
            'Migration Test', 'legacy-password-hash'
          ) on conflict (id) do nothing
        ''',
        params: {'id': userId},
      );
      await database.execute(
        '''
          update users set authenticator_secret = concat(
            'enc:', encode(
              pgp_sym_encrypt(
                'HISTORICAL-TOTP-SECRET',
                'old-database-key-material-with-more-than-thirty-two-characters'
              ),
              'base64'
            )
          ) where id = cast(@id as uuid)
          ''',
        params: {'id': userId},
      );
      await database.execute(
        '''
          insert into oidc_refresh_tokens(
            token_id, user_id, client_id, expires_at, family_id
          ) values (
            'legacy-refresh-token', cast(@user_id as uuid),
            'first_party_web', now() + interval '1 day', null
          ) on conflict (token_id) do update set family_id = null
        ''',
        params: {'user_id': userId},
      );
      final usersBefore = await database.execute('select count(*) from users');
      final tokensBefore = await database.execute(
        'select count(*) from oidc_refresh_tokens',
      );

      await runner.migrate();
      await runner.migrate();
      final users = UserRepository(database, config, SettingsCipher(config));
      expect(
        await users.findAuthenticatorSecretByUserId(userId),
        'HISTORICAL-TOTP-SECRET',
      );
      expect(await users.migratePlaintextAuthenticatorSecrets(), 1);
      expect(
        await users.findAuthenticatorSecretByUserId(userId),
        'HISTORICAL-TOTP-SECRET',
      );
      final authenticatorEnvelope = await database.execute(
        'select authenticator_secret from users where id = cast(@id as uuid)',
        params: {'id': userId},
      );
      expect(authenticatorEnvelope.single[0], startsWith('a256gcm:'));

      final usersAfter = await database.execute('select count(*) from users');
      final tokensAfter = await database.execute(
        'select count(*) from oidc_refresh_tokens',
      );
      final migrated = await database.execute('''
          select family_id, token_id, user_id
          from oidc_refresh_tokens where token_id = 'legacy-refresh-token'
        ''');
      expect(usersAfter.first[0], usersBefore.first[0]);
      expect(tokensAfter.first[0], tokensBefore.first[0]);
      expect(migrated.single[0], isNotNull);
      expect(migrated.single[1], 'legacy-refresh-token');
      expect(migrated.single[2].toString(), userId);
      final firstPartyClient = await database.execute('''
          select display_name, is_official, is_confidential
          from oidc_clients where client_id = 'first_party_web'
        ''');
      expect(firstPartyClient.single[0], 'ROSM Pass');
      expect(firstPartyClient.single[1], isTrue);
      expect(firstPartyClient.single[2], isFalse);
      expect(await runner.isCurrent(), isTrue);

      // Corrupt the oldest checksum while leaving the latest row intact, so
      // readiness proves that it validates the complete migration chain.
      final migration = MigrationRunner.migrations.first;
      expect(migration.checksum, hasLength(64));
      await database.execute(
        '''
          update schema_migrations set checksum = 'corrupted'
          where version = @version
          ''',
        params: {'version': migration.version},
      );
      expect(await runner.isCurrent(), isFalse);
      await expectLater(runner.migrate(), throwsA(isA<StateError>()));
      await database.execute(
        '''
          update schema_migrations set checksum = @checksum
          where version = @version
          ''',
        params: {'version': migration.version, 'checksum': migration.checksum},
      );
      expect(await runner.isCurrent(), isTrue);

      await database.execute(
        'alter table schema_migrations rename to schema_migrations_hidden',
      );
      try {
        expect(await runner.isCurrent(), isFalse);
      } finally {
        await database.execute(
          'alter table schema_migrations_hidden rename to schema_migrations',
        );
      }
    } finally {
      await database.close();
      await keyDirectory.delete(recursive: true);
    }
  }, skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.');
}
