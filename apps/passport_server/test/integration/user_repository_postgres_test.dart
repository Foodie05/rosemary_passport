import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/repositories/user_repository.dart';
import 'package:rosm_passport_server/src/security/settings_cipher.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';

  test(
    'user repository preserves and updates every historical credential field',
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
        'DATA_ENCRYPTION_ACTIVE_KID': 'integration',
        'DATA_ENCRYPTION_KEY':
            'integration-data-key-with-more-than-thirty-two-characters',
      });
      final database = Database(config);
      final repository = UserRepository(
        database,
        config,
        SettingsCipher(config),
      );
      const userId = 'fd11dbf0-7048-4790-b576-8c5a69bab030';

      try {
        await repository.deleteUser(userId: userId);
        expect(await repository.findById(userId), isNull);
        expect(await repository.findByEmail('missing@example.invalid'), isNull);
        expect(await repository.findByPhoneNumber('+8613999999999'), isNull);

        await repository.createUser(
          userId: userId,
          email: 'Lifecycle@Example.Invalid',
          nickname: 'Lifecycle',
          passwordHash: 'password-hash-v1',
          roles: const ['user', 'user'],
          isEmailVerified: false,
        );
        var user = await repository.findByEmail('lifecycle@example.invalid');
        expect(user, isNotNull);
        expect(user!.id, userId);
        expect(user.email, 'lifecycle@example.invalid');
        expect(user.roles, ['user']);
        expect(user.isEmailVerified, isFalse);
        expect(user.hasPasskey, isFalse);
        expect(user.hasSecurityCode, isFalse);

        await repository.updateNickname(userId: userId, nickname: 'Updated');
        await repository.updateEmail(
          userId: userId,
          email: 'Updated@Example.Invalid',
        );
        await repository.updatePhoneNumber(
          userId: userId,
          phoneNumber: '+8613800000030',
        );
        await repository.updatePasswordHash(
          userId: userId,
          passwordHash: 'password-hash-v2',
        );
        await repository.updatePasskeyHash(
          userId: userId,
          passkeyHash: 'legacy-passkey-hash',
        );
        await repository.updateSecurityCodeHash(
          userId: userId,
          securityCodeHash: 'security-code-hash',
        );
        await repository.updateAuthenticatorSecret(
          userId: userId,
          authenticatorSecret: 'TOTP-INTEGRATION-SECRET',
        );
        await repository.updateRoles(
          userId: userId,
          roles: const ['user', 'admin'],
        );

        user = await repository.findById(userId);
        expect(user, isNotNull);
        expect(user!.email, 'updated@example.invalid');
        expect(user.nickname, 'Updated');
        expect(user.phoneNumber, '+8613800000030');
        expect(user.isPhoneVerified, isTrue);
        expect(user.passwordHash, 'password-hash-v2');
        expect(user.hasPasskey, isTrue);
        expect(user.hasSecurityCode, isTrue);
        expect(user.hasAuthenticator, isTrue);
        expect(user.roles, containsAll(['user', 'admin']));
        expect(
          await repository.findAuthenticatorSecretByUserId(userId),
          'TOTP-INTEGRATION-SECRET',
        );
        expect(
          (await repository.findByPhoneNumber('+8613800000030'))?.id,
          userId,
        );

        final authenticated = user.toAuthenticatedUser(
          accessTokenId: 'access-id',
          postRegistrationPasskeyBootstrapUntil: DateTime.now().toUtc().add(
            const Duration(minutes: 1),
          ),
        );
        expect(authenticated.isAdmin, isTrue);
        expect(authenticated.canBootstrapPasskeyAfterRegistration, isTrue);
        expect(authenticated.toJson()['phone_number'], '+8613800000030');

        await repository.updateAccountStatus(
          userId: userId,
          status: 'banned',
          reason: '集成测试封禁',
          actorId: userId,
        );
        user = await repository.findById(userId);
        expect(user!.isBanned, isTrue);
        expect(user.bannedReason, '集成测试封禁');
        final details = await repository.userDetails(userId);
        expect(details?['account_status'], 'banned');
        expect(details?['phone_number'], '+8613800000030');
        await repository.updateAccountStatus(
          userId: userId,
          status: 'active',
          reason: null,
          actorId: userId,
        );
        expect((await repository.findById(userId))?.isBanned, isFalse);

        final listed = await repository.listUsers(
          search: 'updated@example.invalid',
        );
        expect(listed.any((item) => item['id'].toString() == userId), isTrue);
        expect(await repository.countUsers(search: 'Updated'), greaterThan(0));
        expect(
          await repository.countUsers(search: '+8613800000030'),
          greaterThan(0),
        );
        expect(await repository.countUsers(search: 'not-present-value'), 0);
      } finally {
        await repository.deleteUser(userId: userId);
        await database.close();
      }
    },
    skip: enabled ? false : 'Set RUN_POSTGRES_TESTS=true for PostgreSQL tests.',
  );
}
