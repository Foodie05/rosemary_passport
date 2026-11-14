import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import '../../lib/src/config/app_config.dart';
import '../../lib/src/db/database.dart';
import '../../lib/src/repositories/user_repository.dart';
import '../../lib/src/security/settings_cipher.dart';

void main() {
  test('role assignment checks active admin inside the write transaction', () async {
    final config = AppConfig.forTesting({
      'DB_HOST': Platform.environment['TEST_DB_HOST'] ?? '127.0.0.1',
      'DB_PORT': Platform.environment['TEST_DB_PORT'] ?? '5432',
      'DB_USER': Platform.environment['TEST_DB_USER'] ?? 'postgres',
      'DB_PASSWORD': Platform.environment['TEST_DB_PASSWORD'] ?? 'postgres',
      'DB_NAME': Platform.environment['TEST_DB_NAME'] ?? 'rosm_passport_test',
      'DB_SSL_MODE': 'disable',
      'DB_POOL_MIN_CONNECTIONS': '1',
      'DB_POOL_MAX_CONNECTIONS': '3',
    });
    final db = Database(config);
    final users = UserRepository(db, config, SettingsCipher(config));
    const admin = '00a00000-0000-4000-8000-000000000001';
    const target = '00a00000-0000-4000-8000-000000000002';
    const created = '00a00000-0000-4000-8000-000000000003';
    try {
      for (final id in [admin, target, created])
        await users.deleteUser(userId: id);
      await users.createUser(
        userId: admin,
        email: 'role-admin@example.invalid',
        nickname: 'Admin',
        passwordHash: 'hash',
        roles: ['admin'],
      );
      await users.createUser(
        userId: target,
        email: 'role-target@example.invalid',
        nickname: 'Target',
        passwordHash: 'hash',
        roles: ['user'],
      );
      await users.updateRoles(
        userId: target,
        roles: ['admin', 'user'],
        adminActorId: admin,
      );
      expect(
        (await users.findById(target))!.roles,
        containsAll(['user', 'admin']),
      );
      await users.createUser(
        userId: created,
        email: 'role-created@example.invalid',
        nickname: 'Created',
        passwordHash: 'hash',
        roles: ['admin'],
        adminActorId: admin,
      );
      expect((await users.findById(created))!.roles, contains('admin'));
      await users.deleteUser(userId: created);
      // A demotion can complete while the administrator is doing MFA. The final
      // transaction must consult current roles instead of trusting the snapshot.
      await users.updateRoles(userId: admin, roles: ['user']);
      await expectLater(
        users.updateRoles(userId: target, roles: ['user'], adminActorId: admin),
        throwsA(isA<AdminRoleAssignmentDenied>()),
      );
      expect(
        (await users.findById(target))!.roles,
        containsAll(['user', 'admin']),
      );
      await expectLater(
        users.createUser(
          userId: created,
          email: 'role-created@example.invalid',
          nickname: 'Created',
          passwordHash: 'hash',
          roles: ['admin'],
          adminActorId: admin,
        ),
        throwsA(isA<AdminRoleAssignmentDenied>()),
      );
      expect(await users.findById(created), isNull);
      await users.updateRoles(userId: admin, roles: ['admin']);
      await expectLater(
        users.updateRoles(
          userId: created,
          roles: ['user'],
          adminActorId: admin,
        ),
        throwsA(isA<RoleAssignmentTargetNotFound>()),
      );
      await db.execute(
        "update users set account_status='banned' where id=@id",
        params: {'id': admin},
      );
      await expectLater(
        users.updateRoles(userId: target, roles: ['user'], adminActorId: admin),
        throwsA(isA<AdminRoleAssignmentDenied>()),
      );
      await db.execute(
        "update users set account_status='active' where id=@id",
        params: {'id': admin},
      );
      // A row lock forces a concurrently pending role replacement to observe
      // the demotion when it finally acquires the acting administrator's lock.
      Future<void>? pending;
      await db.runTx((tx) async {
        await tx.execute(
          Sql.named('select id from users where id = @id for update'),
          parameters: {'id': admin},
        );
        await tx.execute(
          Sql.named(
            "delete from user_roles where user_id=@id and role='admin'",
          ),
          parameters: {'id': admin},
        );
        pending = users.updateRoles(
          userId: target,
          roles: ['user'],
          adminActorId: admin,
        );
        // Attach the failure assertion before the transaction releases its lock.
        pending = expectLater(
          pending,
          throwsA(isA<AdminRoleAssignmentDenied>()),
        );
      });
      await pending;
      expect((await users.findById(target))!.roles, contains('admin'));
    } finally {
      for (final id in [created, target, admin])
        await users.deleteUser(userId: id);
      await db.close();
    }
  }, skip: Platform.environment['RUN_POSTGRES_TESTS'] != 'true');
}
