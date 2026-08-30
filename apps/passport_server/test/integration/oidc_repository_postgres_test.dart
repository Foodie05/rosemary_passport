import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/repositories/oidc_repository.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'OIDC client, code, token, and revocation lifecycle is consistent',
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
          'DB_POOL_MAX_CONNECTIONS': '3',
        }),
      );
      final repository = OidcRepository(database);
      const userId = 'fd11dbf0-7048-4790-b576-8c5a69bab020';
      const clientId = 'integration_lifecycle_client';
      final now = DateTime.now().toUtc();

      Future<void> storeAccess(
        String tokenId, {
        DateTime? expiresAt,
        String? familyId,
      }) => repository.storeAccessToken(
        tokenId: tokenId,
        userId: userId,
        clientId: clientId,
        expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
        familyId: familyId,
      );

      Future<void> storeRefresh(
        String tokenId, {
        DateTime? expiresAt,
        String? familyId,
      }) => repository.storeRefreshToken(
        tokenId: tokenId,
        userId: userId,
        clientId: clientId,
        expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
        familyId: familyId,
      );

      try {
        await database.execute(
          '''
          insert into users(id, email, nickname, password_hash)
          values (
            cast(@id as uuid), 'oidc-lifecycle@example.invalid',
            'OIDC Lifecycle', 'not-a-real-password-hash'
          ) on conflict (id) do nothing
          ''',
          params: {'id': userId},
        );
        await repository.deleteClient(clientId);

        expect(await repository.findClient('missing-client'), isNull);
        await repository.upsertClient(
          clientId: clientId,
          displayName: 'Integration Client',
          isOfficial: false,
          redirectUris: const ['https://client.example.invalid/callback'],
          scopes: const ['openid', 'profile'],
          grantTypes: const ['authorization_code', 'refresh_token'],
          isConfidential: true,
          isActive: true,
          clientSecretHash: 'secret-hash',
        );
        final client = await repository.findClient(clientId);
        expect(client, isNotNull);
        expect(client!['display_name'], 'Integration Client');
        expect(client['client_secret_hash'], 'secret-hash');
        expect(client['redirect_uris'], hasLength(1));
        expect(client['is_confidential'], isTrue);

        await repository.upsertClient(
          clientId: clientId,
          displayName: null,
          isOfficial: true,
          redirectUris: const ['https://client.example.invalid/new-callback'],
          scopes: const ['openid'],
          grantTypes: const ['authorization_code'],
          isConfidential: true,
          isActive: true,
        );
        final listed = (await repository.listClients()).singleWhere(
          (item) => item['client_id'] == clientId,
        );
        expect(listed['display_name'], isNull);
        expect(listed['is_official'], isTrue);
        expect(listed['has_client_secret'], isTrue);

        await repository.storeAuthCode(
          code: 'valid-code',
          clientId: clientId,
          userId: userId,
          redirectUri: 'https://client.example.invalid/new-callback',
          scopes: const ['openid'],
          nonce: 'nonce',
          codeChallenge: 'challenge',
          codeChallengeMethod: 'S256',
          expiresAt: now.add(const Duration(minutes: 5)),
        );
        final code = await repository.consumeAuthCode('valid-code');
        expect(code?['client_id'], clientId);
        expect(code?['nonce'], 'nonce');
        expect(code?['code_challenge_method'], 'S256');
        expect(await repository.consumeAuthCode('valid-code'), isNull);
        expect(await repository.consumeAuthCode('missing-code'), isNull);

        await repository.storeAuthCode(
          code: 'expired-code',
          clientId: clientId,
          userId: userId,
          redirectUri: 'https://client.example.invalid/new-callback',
          scopes: const ['openid'],
          nonce: null,
          codeChallenge: null,
          codeChallengeMethod: null,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        );
        expect(await repository.consumeAuthCode('expired-code'), isNull);

        expect(await repository.findAccessToken('missing-access'), isNull);
        expect(await repository.isAccessTokenActive('missing-access'), isFalse);
        await storeAccess('active-access');
        expect(await repository.findAccessToken('active-access'), isNotNull);
        expect(await repository.isAccessTokenActive('active-access'), isTrue);
        await repository.revokeAccessToken('active-access');
        expect(await repository.isAccessTokenActive('active-access'), isFalse);
        await storeAccess(
          'expired-access',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        );
        expect(await repository.isAccessTokenActive('expired-access'), isFalse);

        expect(await repository.findRefreshToken('missing-refresh'), isNull);
        expect(
          await repository.isRefreshTokenActive('missing-refresh'),
          isFalse,
        );
        await storeRefresh('active-refresh');
        expect(await repository.findRefreshToken('active-refresh'), isNotNull);
        expect(await repository.isRefreshTokenActive('active-refresh'), isTrue);
        await repository.revokeRefreshToken('active-refresh');
        expect(
          await repository.isRefreshTokenActive('active-refresh'),
          isFalse,
        );
        await storeRefresh(
          'expired-refresh',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        );
        expect(
          await repository.isRefreshTokenActive('expired-refresh'),
          isFalse,
        );

        const invalidFamily = 'fd11dbf0-7048-4790-b576-8c5a69bab021';
        await storeRefresh('rotation-source', familyId: invalidFamily);
        Future<RefreshRotationStatus> rotate({
          String oldTokenId = 'rotation-source',
          String familyId = invalidFamily,
          String rotatedUserId = userId,
          String rotatedClientId = clientId,
        }) => repository.rotateRefreshToken(
          oldTokenId: oldTokenId,
          newAccessTokenId: 'new-access-$oldTokenId-$familyId',
          newRefreshTokenId: 'new-refresh-$oldTokenId-$familyId',
          familyId: familyId,
          userId: rotatedUserId,
          clientId: rotatedClientId,
          accessExpiresAt: now.add(const Duration(minutes: 15)),
          refreshExpiresAt: now.add(const Duration(hours: 1)),
        );

        expect(
          await rotate(oldTokenId: 'unknown-rotation-source'),
          RefreshRotationStatus.invalid,
        );
        expect(
          await rotate(familyId: 'fd11dbf0-7048-4790-b576-8c5a69bab022'),
          RefreshRotationStatus.invalid,
        );
        expect(
          await rotate(rotatedUserId: 'fd11dbf0-7048-4790-b576-8c5a69bab023'),
          RefreshRotationStatus.invalid,
        );
        expect(
          await rotate(rotatedClientId: 'first_party_web'),
          RefreshRotationStatus.invalid,
        );

        const expiredFamily = 'fd11dbf0-7048-4790-b576-8c5a69bab024';
        await storeRefresh(
          'expired-rotation-source',
          familyId: expiredFamily,
          expiresAt: now.subtract(const Duration(seconds: 1)),
        );
        expect(
          await rotate(
            oldTokenId: 'expired-rotation-source',
            familyId: expiredFamily,
          ),
          RefreshRotationStatus.invalid,
        );

        await storeAccess('preserved-access');
        await storeAccess('revoked-access');
        await repository.revokeAccessTokensForUserExcept(
          userId,
          'preserved-access',
        );
        expect(
          await repository.isAccessTokenActive('preserved-access'),
          isTrue,
        );
        expect(await repository.isAccessTokenActive('revoked-access'), isFalse);
        await repository.revokeAccessTokensForUser(userId);
        expect(
          await repository.isAccessTokenActive('preserved-access'),
          isFalse,
        );

        await storeRefresh('user-refresh');
        await repository.revokeRefreshTokensForUser(userId);
        expect(await repository.isRefreshTokenActive('user-refresh'), isFalse);

        const familyToRevoke = 'fd11dbf0-7048-4790-b576-8c5a69bab025';
        await storeAccess('family-access', familyId: familyToRevoke);
        await storeRefresh('family-refresh', familyId: familyToRevoke);
        await repository.revokeTokenFamily(familyToRevoke);
        expect(await repository.isAccessTokenActive('family-access'), isFalse);
        expect(
          await repository.isRefreshTokenActive('family-refresh'),
          isFalse,
        );

        await repository.upsertClient(
          clientId: clientId,
          displayName: 'Inactive Client',
          isOfficial: false,
          redirectUris: const ['https://client.example.invalid/callback'],
          scopes: const ['openid'],
          grantTypes: const ['authorization_code'],
          isConfidential: true,
          isActive: false,
        );
        expect(await repository.findClient(clientId), isNull);
      } finally {
        await repository.deleteClient(clientId);
        await database.close();
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
