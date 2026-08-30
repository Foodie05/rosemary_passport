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
    DatabaseMigration('20260830_001_oidc_schema_managed', '''
      alter table oidc_clients
        add column if not exists display_name text;
      alter table oidc_clients
        add column if not exists is_official boolean not null default false;
      alter table oidc_auth_codes
        add column if not exists nonce text;
      create index if not exists idx_oidc_auth_codes_user
        on oidc_auth_codes(user_id);

      insert into oidc_clients(
        client_id,
        display_name,
        is_official,
        client_secret_hash,
        redirect_uris,
        scopes,
        grant_types,
        is_confidential,
        is_active
      ) values (
        'first_party_web',
        'ROSM Pass',
        true,
        null,
        array['http://localhost:5173/callback']::text[],
        array['openid', 'profile', 'email', 'phone']::text[],
        array['authorization_code', 'refresh_token']::text[],
        false,
        true
      ) on conflict (client_id) do nothing;

      update oidc_clients
      set display_name = coalesce(display_name, 'ROSM Pass'),
          is_official = true
      where client_id = 'first_party_web';
    '''),
    DatabaseMigration('20260830_002_audit_chain_position', '''
      create sequence if not exists audit_chain_position_seq;
      alter table audit_logs
        add column if not exists chain_position bigint;
      with ranked as (
        select id, row_number() over (order by created_at, id) as position
        from audit_logs
      )
      update audit_logs as target
      set chain_position = ranked.position
      from ranked
      where target.id = ranked.id and target.chain_position is null;
      select setval(
        'audit_chain_position_seq',
        coalesce(max(chain_position), 1),
        max(chain_position) is not null
      ) from audit_logs;
      alter sequence audit_chain_position_seq
        owned by audit_logs.chain_position;
      alter table audit_logs
        alter column chain_position
        set default nextval('audit_chain_position_seq');
      alter table audit_logs
        alter column chain_position set not null;
      create unique index if not exists idx_audit_chain_position
        on audit_logs(chain_position);
    '''),
    DatabaseMigration('20260830_003_rollback_compatibility_defaults', '''
      update oidc_refresh_tokens
      set family_id = gen_random_uuid()
      where family_id is null;
      alter table oidc_refresh_tokens
        alter column family_id set default gen_random_uuid();

      update user_webauthn_credentials
      set uv_grace_expires_at = now() + interval '14 days'
      where uv_required = false and uv_grace_expires_at is null;
      alter table user_webauthn_credentials
        alter column uv_grace_expires_at
        set default (now() + interval '14 days');
    '''),
    DatabaseMigration('20260830_004_sla_recovery_markers', '''
      create table if not exists sla_recovery_markers (
        marker_id text primary key,
        created_at timestamptz not null default clock_timestamp()
      );
      create index if not exists idx_sla_recovery_markers_created_at
        on sla_recovery_markers(created_at desc);
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
      for (final migration in migrations) {
        final result = await _database.execute(
          'select checksum from schema_migrations where version = @version',
          params: {'version': migration.version},
        );
        if (result.isEmpty || result.first[0] != migration.checksum) {
          return false;
        }
      }
      return true;
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
