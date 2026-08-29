import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import 'database.dart';

class DatabaseMigration {
  const DatabaseMigration(this.version, this.sql);

  final String version;
  final String sql;

  String get checksum => sha256.convert(utf8.encode(sql)).toString();
}

class MigrationRunner {
  MigrationRunner(this._database);

  static const advisoryLockId = 82463207240629;
  static const migrations = <DatabaseMigration>[
    DatabaseMigration('20260829_001_sla_expand', '''
      create extension if not exists pgcrypto;

      alter table oidc_refresh_tokens
        add column if not exists family_id uuid;
      alter table oidc_refresh_tokens
        add column if not exists parent_token_id text;
      alter table oidc_refresh_tokens
        add column if not exists replaced_by_token_id text;
      alter table oidc_refresh_tokens
        add column if not exists consumed_at timestamptz;
      alter table oidc_refresh_tokens
        add column if not exists reuse_detected_at timestamptz;
      update oidc_refresh_tokens
      set family_id = gen_random_uuid()
      where family_id is null;
      create index if not exists idx_oidc_refresh_tokens_family
        on oidc_refresh_tokens(family_id);
      create index if not exists idx_oidc_refresh_tokens_user_client
        on oidc_refresh_tokens(user_id, client_id, created_at desc);

      alter table oidc_access_tokens
        add column if not exists family_id uuid;
      create index if not exists idx_oidc_access_tokens_family
        on oidc_access_tokens(family_id);

      alter table user_webauthn_credentials
        add column if not exists uv_verified_at timestamptz;
      alter table user_webauthn_credentials
        add column if not exists uv_required boolean not null default false;
      alter table user_webauthn_credentials
        add column if not exists uv_grace_expires_at timestamptz;
      update user_webauthn_credentials
      set uv_grace_expires_at = now() + interval '14 days'
      where uv_required = false and uv_grace_expires_at is null;

      alter table audit_logs
        add column if not exists previous_hash text;
      alter table audit_logs
        add column if not exists entry_hash text;
      create index if not exists idx_audit_entry_hash
        on audit_logs(entry_hash)
        where entry_hash is not null;
    '''),
  ];

  final Database _database;

  String get latestVersion => migrations.last.version;

  Future<void> migrate() async {
    await _database.withConnection((connection) async {
      await connection.execute(
        Sql.named('select pg_advisory_lock(@lock_id)'),
        parameters: {'lock_id': advisoryLockId},
      );
      try {
        await _ensureMetadata(connection);
        for (final migration in migrations) {
          await _apply(connection, migration);
        }
      } finally {
        await connection.execute(
          Sql.named('select pg_advisory_unlock(@lock_id)'),
          parameters: {'lock_id': advisoryLockId},
        );
      }
    });
  }

  Future<bool> isCurrent() async {
    try {
      final result = await _database.execute(
        'select checksum from schema_migrations where version = @version',
        params: {'version': latestVersion},
      );
      return result.isNotEmpty && result.first[0] == migrations.last.checksum;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureMetadata(Connection connection) async {
    await connection.execute('''
      create table if not exists schema_migrations (
        version text primary key,
        checksum text not null,
        applied_at timestamptz not null default now()
      )
    ''');
  }

  Future<void> _apply(
    Connection connection,
    DatabaseMigration migration,
  ) async {
    final existing = await connection.execute(
      Sql.named(
        'select checksum from schema_migrations where version = @version',
      ),
      parameters: {'version': migration.version},
    );
    if (existing.isNotEmpty) {
      if (existing.first[0] != migration.checksum) {
        throw StateError(
          'Migration checksum mismatch for ${migration.version}.',
        );
      }
      return;
    }

    await connection.runTx((tx) async {
      await tx.execute(migration.sql, queryMode: QueryMode.simple);
      await tx.execute(
        Sql.named('''
          insert into schema_migrations(version, checksum)
          values (@version, @checksum)
        '''),
        parameters: {
          'version': migration.version,
          'checksum': migration.checksum,
        },
      );
    });
  }
}
