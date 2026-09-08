import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/db/database.dart';
import 'package:rosm_passport_server/src/db/migration_runner.dart';
import 'package:rosm_passport_server/src/repositories/security_repository.dart';
import 'package:rosm_passport_server/src/repositories/webauthn_repository.dart';
import 'package:rosm_passport_server/src/services/auth_throttle_service.dart';
import 'package:rosm_passport_server/src/services/security_service.dart';
import 'package:test/test.dart';

void main() {
  final enabled = Platform.environment['RUN_POSTGRES_TESTS'] == 'true';
  late Database db;
  setUp(() async {
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
        'DB_POOL_MAX_CONNECTIONS': '4',
      }),
    );
    await MigrationRunner(db).migrate();
  });
  tearDown(() async {
    if (enabled) await db.close();
  });

  test(
    'duplicate credential registration cannot replace any owner or key, including concurrent inserts',
    () async {
      const owner = 'abade0d1-5149-4a2a-a4db-ff0d8f122101';
      const attacker = 'abade0d1-5149-4a2a-a4db-ff0d8f122102';
      final repository = WebAuthnRepository(db);
      Future<bool> insert(
        String userId,
        String key, {
        String id = 'audit-credential',
      }) => repository.insertCredential(
        userId: userId,
        credentialId: id,
        publicKey: key,
        counter: 0,
        transports: ['internal'],
        backedUp: false,
      );
      try {
        for (final id in [owner, attacker]) {
          await db.execute(
            "insert into users(id, email, nickname, password_hash) values(cast(@id as uuid), @email, 'Test', 'hash')",
            params: {'id': id, 'email': '$id@example.invalid'},
          );
        }
        expect(await insert(owner, 'original-key'), isTrue);
        final original = await repository.findCredential('audit-credential');
        expect(await insert(attacker, 'attacker-key'), isFalse);
        expect(await insert(owner, 'replacement-key'), isFalse);
        final retained = await repository.findCredential('audit-credential');
        expect(retained?.userId, owner);
        expect(retained?.publicKey, original?.publicKey);
        expect(retained?.createdAt, original?.createdAt);
        final results = await Future.wait([
          insert(owner, 'key-a', id: 'audit-racing-credential'),
          insert(attacker, 'key-b', id: 'audit-racing-credential'),
        ]);
        expect(results.where((inserted) => inserted), hasLength(1));
        final winner = await repository.findCredential(
          'audit-racing-credential',
        );
        expect(winner?.publicKey, results.first ? 'key-a' : 'key-b');
        expect(winner?.userId, results.first ? owner : attacker);
      } finally {
        await db.execute(
          'delete from users where id in (cast(@owner as uuid), cast(@attacker as uuid))',
          params: {'owner': owner, 'attacker': attacker},
        );
      }
    },
    skip: !enabled,
  );

  test(
    'MFA attempt budget is shared across service instances and consumed even on unsuccessful attempts',
    () async {
      final repository = SecurityRepository(db);
      final first = AuthThrottleService(
        securityService: SecurityService(repository),
      );
      final second = AuthThrottleService(
        securityService: SecurityService(SecurityRepository(db)),
      );
      const proof = 'audit-mfa-proof';
      try {
        expect(await first.admitLoginStepUpAttempt(proof), isTrue);
        final decisions = await Future.wait(
          List.generate(
            8,
            (index) =>
                (index.isEven ? first : second).admitLoginStepUpAttempt(proof),
          ),
        );
        expect(decisions.where((allowed) => allowed), hasLength(4));
        expect(await second.admitLoginStepUpAttempt(proof), isFalse);
      } finally {
        await repository.clearThrottle(
          scope: 'auth:login-step-up-attempt',
          subject: proof,
        );
      }
    },
    skip: !enabled,
  );

  test(
    'PITR source and restored count queries execute against the real schema',
    () async {
      final script = File(
        '../../ops/deploy/auth_cruty_cn/pitr_drill.sh',
      ).readAsStringSync();
      final queries = RegExp(
        r'select json_build_object\([\s\S]*?\n\s*\)',
      ).allMatches(script).toList();
      expect(queries, hasLength(2));
      for (final query in queries) {
        final result = await db.execute(query.group(0)!);
        expect(result, hasLength(1));
      }
    },
    skip: !enabled,
  );
}
