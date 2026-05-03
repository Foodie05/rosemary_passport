import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../lib/src/config/app_config.dart';
import '../lib/src/db/database.dart';
import '../lib/src/security/password_hasher.dart';

Future<void> main() async {
  final email = Platform.environment['LOCAL_ADMIN_EMAIL']?.trim();
  final password = Platform.environment['LOCAL_ADMIN_PASSWORD'];
  final nickname = Platform.environment['LOCAL_ADMIN_NICKNAME'] ?? 'ROSM Admin';

  if (email == null || email.isEmpty || password == null || password.isEmpty) {
    stderr.writeln('LOCAL_ADMIN_EMAIL and LOCAL_ADMIN_PASSWORD are required.');
    exitCode = 64;
    return;
  }
  if (!_isReservedBootstrapEmail(email)) {
    stderr.writeln(
      'LOCAL_ADMIN_EMAIL must use the reserved @rosm.local domain so the bootstrap admin must bind a formal email later.',
    );
    exitCode = 64;
    return;
  }

  final config = AppConfig.fromEnv();
  final db = Database(config);
  final passwordHasher = PasswordHasher(config);

  try {
    var created = false;
    var blockedReason = '';

    await db.runTx((tx) async {
      final bootstrapFlag = await tx.execute(
        Sql.named(
          '''
          select (value->>'allow_create')::boolean
          from system_settings
          where key = 'local_admin_bootstrap'
          for update
          ''',
        ),
      );

      if (bootstrapFlag.isEmpty) {
        blockedReason = 'local_admin_bootstrap flag missing';
        return null;
      }

      final allowCreate = bootstrapFlag.first[0] == true;
      if (!allowCreate) {
        blockedReason = 'bootstrap already locked';
        return null;
      }

      final userCountResult = await tx.execute(
        Sql.named('select count(*)::int from users'),
      );
      final userCount = userCountResult.first[0] as int;
      if (userCount > 0) {
        blockedReason = 'database already contains users';
        await tx.execute(
          Sql.named(
            '''
            update system_settings
            set value = jsonb_build_object(
              'allow_create', false,
              'bootstrap_login_enabled', false,
              'locked_reason', cast(@locked_reason as text),
              'locked_at', now()
            ),
                updated_at = now()
            where key = 'local_admin_bootstrap'
            ''',
          ),
          parameters: {'locked_reason': blockedReason},
        );
        return null;
      }

      final existing = await tx.execute(
        Sql.named(
          '''
          select id
          from users
          where lower(email) = lower(@email)
          limit 1
          ''',
        ),
        parameters: {'email': email},
      );
      if (existing.isNotEmpty) {
        blockedReason = 'email already exists';
        await tx.execute(
          Sql.named(
            '''
            update system_settings
            set value = jsonb_build_object(
              'allow_create', false,
              'bootstrap_login_enabled', false,
              'locked_reason', cast(@locked_reason as text),
              'locked_at', now()
            ),
                updated_at = now()
            where key = 'local_admin_bootstrap'
            ''',
          ),
          parameters: {'locked_reason': blockedReason},
        );
        return null;
      }

      final userId = const Uuid().v4();
      final hash = await passwordHasher.hash(password);
      await tx.execute(
        Sql.named(
          '''
          insert into users(id, email, nickname, password_hash, is_email_verified)
          values (@id, lower(@email), @nickname, @password_hash, true)
          ''',
        ),
        parameters: {
          'id': userId,
          'email': email,
          'nickname': nickname,
          'password_hash': hash,
        },
      );
      await tx.execute(
        Sql.named(
          '''
          insert into user_roles(user_id, role)
          values (@user_id, @role)
          ''',
        ),
        parameters: {
          'user_id': userId,
          'role': 'admin',
        },
      );
      await tx.execute(
        Sql.named(
          '''
          insert into user_roles(user_id, role)
          values (@user_id, @role)
          on conflict do nothing
          ''',
        ),
        parameters: {
          'user_id': userId,
          'role': 'user',
        },
      );
      await tx.execute(
        Sql.named(
          '''
            update system_settings
            set value = jsonb_build_object(
              'allow_create', false,
              'bootstrap_login_enabled', true,
              'created_email', cast(@email as text),
              'bootstrapped_at', now()
            ),
              updated_at = now()
          where key = 'local_admin_bootstrap'
          ''',
        ),
        parameters: {'email': email},
      );
      created = true;
      return null;
    });

    if (!created) {
      stdout.writeln('ROSM_LOCAL_ADMIN_CREATED=false');
      stdout.writeln('ROSM_LOCAL_ADMIN_EMAIL=$email');
      stdout.writeln('ROSM_LOCAL_ADMIN_BLOCKED=$blockedReason');
      return;
    }

    stdout.writeln('ROSM_LOCAL_ADMIN_CREATED=true');
    stdout.writeln('ROSM_LOCAL_ADMIN_EMAIL=$email');
  } finally {
    await db.close();
  }
}

bool _isReservedBootstrapEmail(String email) {
  return email.trim().toLowerCase().endsWith('@rosm.local');
}
