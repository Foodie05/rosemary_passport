import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/repositories/oidc_repository.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'a concurrent refresh succeeds once and replay revokes the family',
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
          'DB_POOL_MIN_CONNECTIONS': '2',
          'DB_POOL_MAX_CONNECTIONS': '4',
        }),
      );
      final repository = OidcRepository(database);
      const userId = 'fd11dbf0-7048-4790-b576-8c5a69bab001';
      const familyId = 'fd11dbf0-7048-4790-b576-8c5a69bab002';
      final now = DateTime.now().toUtc();

      try {
        await database.execute(
          '''
          insert into users(id, email, nickname, password_hash)
          values (
            cast(@id as uuid), 'refresh-test@example.invalid',
            'Refresh Test', 'not-a-real-password-hash'
          )
          on conflict (id) do nothing
        ''',
          params: {'id': userId},
        );
        await database.execute(
          'delete from oidc_access_tokens where family_id = cast(@family as uuid)',
          params: {'family': familyId},
        );
        await database.execute(
          'delete from oidc_refresh_tokens where family_id = cast(@family as uuid)',
          params: {'family': familyId},
        );
        await repository.storeTokenPair(
          accessTokenId: 'access-old',
          refreshTokenId: 'refresh-old',
          familyId: familyId,
          userId: userId,
          clientId: 'first_party_web',
          accessExpiresAt: now.add(const Duration(minutes: 15)),
          refreshExpiresAt: now.add(const Duration(days: 1)),
        );

        Future<RefreshRotationStatus> rotate(String suffix) {
          return repository.rotateRefreshToken(
            oldTokenId: 'refresh-old',
            newAccessTokenId: 'access-$suffix',
            newRefreshTokenId: 'refresh-$suffix',
            familyId: familyId,
            userId: userId,
            clientId: 'first_party_web',
            accessExpiresAt: now.add(const Duration(minutes: 15)),
            refreshExpiresAt: now.add(const Duration(days: 1)),
          );
        }

        final results = await Future.wait([rotate('one'), rotate('two')]);
        expect(
          results.where((value) => value == RefreshRotationStatus.success),
          hasLength(1),
        );
        expect(
          results.where((value) => value == RefreshRotationStatus.reused),
          hasLength(1),
        );

        final active = await database.execute(
          '''
          select count(*) from (
            select token_id from oidc_access_tokens
            where family_id = cast(@family as uuid) and revoked_at is null
            union all
            select token_id from oidc_refresh_tokens
            where family_id = cast(@family as uuid) and revoked_at is null
          ) active_tokens
        ''',
          params: {'family': familyId},
        );
        expect(active.first[0], 0);
      } finally {
        await database.close();
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
