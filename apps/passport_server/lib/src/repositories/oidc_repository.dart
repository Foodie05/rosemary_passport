import '../db/database.dart';
import 'package:postgres/postgres.dart';

class OidcRepository {
  OidcRepository(this._db);

  final Database _db;
  Future<void>? _schemaReady;

  Future<void> _ensureSchema() {
    return _schemaReady ??= _createSchemaIfNeeded();
  }

  Future<void> _createSchemaIfNeeded() async {
    await _db.execute('''
      create table if not exists oidc_clients (
        client_id text primary key,
        display_name text,
        is_official boolean not null default false,
        client_secret_hash text,
        redirect_uris text[] not null,
        scopes text[] not null default array['openid', 'profile', 'email', 'phone']::text[],
        grant_types text[] not null default array['authorization_code', 'refresh_token']::text[],
        is_confidential boolean not null default true,
        is_active boolean not null default true,
        created_at timestamptz not null default now()
      )
      ''');
    await _db.execute(
      'alter table oidc_clients add column if not exists display_name text',
    );
    await _db.execute(
      'alter table oidc_clients add column if not exists is_official boolean not null default false',
    );
    await _db.execute('''
      create table if not exists oidc_auth_codes (
        code text primary key,
        client_id text not null references oidc_clients(client_id),
        user_id uuid not null references users(id) on delete cascade,
        redirect_uri text not null,
        scopes text[] not null,
        nonce text,
        code_challenge text,
        code_challenge_method text,
        expires_at timestamptz not null,
        used_at timestamptz,
        created_at timestamptz not null default now()
      )
      ''');
    await _db.execute(
      'alter table oidc_auth_codes add column if not exists nonce text',
    );
    await _db.execute('''
      create index if not exists idx_oidc_auth_codes_user
      on oidc_auth_codes(user_id)
      ''');
    await _db.execute('''
      create table if not exists oidc_access_tokens (
        token_id text primary key,
        user_id uuid not null references users(id) on delete cascade,
        client_id text not null references oidc_clients(client_id),
        expires_at timestamptz not null,
        revoked_at timestamptz,
        created_at timestamptz not null default now()
      )
      ''');
    await _db.execute('''
      create table if not exists oidc_refresh_tokens (
        token_id text primary key,
        user_id uuid not null references users(id) on delete cascade,
        client_id text not null references oidc_clients(client_id),
        expires_at timestamptz not null,
        revoked_at timestamptz,
        created_at timestamptz not null default now()
      )
      ''');
    await _db.execute('''
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
      )
      values (
        'first_party_web',
        'ROSM Pass',
        true,
        null,
        array['http://localhost:5173/callback']::text[],
        array['openid', 'profile', 'email', 'phone']::text[],
        array['authorization_code', 'refresh_token']::text[],
        false,
        true
      )
      on conflict (client_id) do nothing
      ''');
  }

  Future<Map<String, dynamic>?> findClient(String clientId) async {
    await _ensureSchema();
    final result = await _db.execute(
      '''
      select client_id, client_secret_hash, redirect_uris, scopes, grant_types, is_confidential, display_name, is_official
      from oidc_clients
      where client_id = @client_id and is_active = true
      ''',
      params: {'client_id': clientId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return {
      'client_id': row[0],
      'client_secret_hash': row[1],
      'redirect_uris': (row[2] as List).map((e) => e.toString()).toList(),
      'scopes': (row[3] as List).map((e) => e.toString()).toList(),
      'grant_types': (row[4] as List).map((e) => e.toString()).toList(),
      'is_confidential': row[5] as bool,
      'display_name': (row[6] as String?)?.trim(),
      'is_official': row[7] as bool,
    };
  }

  Future<List<Map<String, dynamic>>> listClients() async {
    await _ensureSchema();
    final result = await _db.execute('''
      select client_id, display_name, is_official, redirect_uris, scopes, grant_types, is_confidential, is_active, client_secret_hash, created_at
      from oidc_clients
      order by client_id asc
      ''');

    return result
        .map(
          (row) => {
            'client_id': row[0],
            'display_name': (row[1] as String?)?.trim(),
            'is_official': row[2] as bool,
            'redirect_uris': (row[3] as List).map((e) => e.toString()).toList(),
            'scopes': (row[4] as List).map((e) => e.toString()).toList(),
            'grant_types': (row[5] as List).map((e) => e.toString()).toList(),
            'is_confidential': row[6] as bool,
            'is_active': row[7] as bool,
            'has_client_secret': row[8] != null,
            'created_at': row[9].toString(),
          },
        )
        .toList();
  }

  Future<Map<String, dynamic>?> findRefreshToken(String tokenId) async {
    await _ensureSchema();
    final result = await _db.execute(
      '''
      select token_id, user_id, client_id, expires_at, revoked_at
      from oidc_refresh_tokens
      where token_id = @token_id
      ''',
      params: {'token_id': tokenId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return {
      'token_id': row[0],
      'user_id': row[1],
      'client_id': row[2],
      'expires_at': row[3] as DateTime,
      'revoked_at': row[4] as DateTime?,
    };
  }

  Future<Map<String, dynamic>?> findAccessToken(String tokenId) async {
    await _ensureSchema();
    final result = await _db.execute(
      '''
      select token_id, user_id, client_id, expires_at, revoked_at
      from oidc_access_tokens
      where token_id = @token_id
      ''',
      params: {'token_id': tokenId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return {
      'token_id': row[0],
      'user_id': row[1],
      'client_id': row[2],
      'expires_at': row[3] as DateTime,
      'revoked_at': row[4] as DateTime?,
    };
  }

  Future<void> storeAuthCode({
    required String code,
    required String clientId,
    required String userId,
    required String redirectUri,
    required List<String> scopes,
    required String? nonce,
    required String? codeChallenge,
    required String? codeChallengeMethod,
    required DateTime expiresAt,
  }) async {
    await _ensureSchema();
    await _db.execute(
      '''
      insert into oidc_auth_codes(code, client_id, user_id, redirect_uri, scopes, nonce, code_challenge, code_challenge_method, expires_at)
      values (@code, @client_id, @user_id, @redirect_uri, @scopes, @nonce, @code_challenge, @code_challenge_method, @expires_at)
      ''',
      params: {
        'code': code,
        'client_id': clientId,
        'user_id': userId,
        'redirect_uri': redirectUri,
        'scopes': scopes,
        'nonce': nonce,
        'code_challenge': codeChallenge,
        'code_challenge_method': codeChallengeMethod,
        'expires_at': expiresAt,
      },
    );
  }

  Future<Map<String, dynamic>?> consumeAuthCode(String code) async {
    await _ensureSchema();
    return _db.runTx((tx) async {
      final result = await tx.execute(
        Sql.named('''
          select code, client_id, user_id, redirect_uri, scopes, nonce, code_challenge, code_challenge_method, expires_at, used_at
          from oidc_auth_codes
          where code = @code
          for update
          '''),
        parameters: {'code': code},
      );

      if (result.isEmpty) {
        return null;
      }

      final row = result.first;
      final usedAt = row[9] as DateTime?;
      final expiresAt = row[8] as DateTime;
      if (usedAt != null || expiresAt.isBefore(DateTime.now().toUtc())) {
        return null;
      }

      await tx.execute(
        Sql.named(
          'update oidc_auth_codes set used_at = now() where code = @code',
        ),
        parameters: {'code': code},
      );

      return {
        'client_id': row[1],
        'user_id': row[2],
        'redirect_uri': row[3],
        'scopes': (row[4] as List).map((e) => e.toString()).toList(),
        'nonce': row[5] as String?,
        'code_challenge': row[6] as String?,
        'code_challenge_method': row[7] as String?,
      };
    });
  }

  Future<void> storeAccessToken({
    required String tokenId,
    required String userId,
    required String clientId,
    required DateTime expiresAt,
  }) async {
    await _ensureSchema();
    await _db.execute(
      '''
      insert into oidc_access_tokens(token_id, user_id, client_id, expires_at)
      values (@token_id, @user_id, @client_id, @expires_at)
      ''',
      params: {
        'token_id': tokenId,
        'user_id': userId,
        'client_id': clientId,
        'expires_at': expiresAt,
      },
    );
  }

  Future<bool> isAccessTokenActive(String tokenId) async {
    await _ensureSchema();
    final result = await _db.execute(
      '''
      select revoked_at, expires_at
      from oidc_access_tokens
      where token_id = @token_id
      ''',
      params: {'token_id': tokenId},
    );

    if (result.isEmpty) {
      return false;
    }

    final row = result.first;
    final revokedAt = row[0] as DateTime?;
    final expiresAt = row[1] as DateTime;
    return revokedAt == null && expiresAt.isAfter(DateTime.now().toUtc());
  }

  Future<void> storeRefreshToken({
    required String tokenId,
    required String userId,
    required String clientId,
    required DateTime expiresAt,
  }) async {
    await _ensureSchema();
    await _db.execute(
      '''
      insert into oidc_refresh_tokens(token_id, user_id, client_id, expires_at)
      values (@token_id, @user_id, @client_id, @expires_at)
      ''',
      params: {
        'token_id': tokenId,
        'user_id': userId,
        'client_id': clientId,
        'expires_at': expiresAt,
      },
    );
  }

  Future<bool> isRefreshTokenActive(String tokenId) async {
    await _ensureSchema();
    final result = await _db.execute(
      '''
      select revoked_at, expires_at
      from oidc_refresh_tokens
      where token_id = @token_id
      ''',
      params: {'token_id': tokenId},
    );

    if (result.isEmpty) {
      return false;
    }

    final row = result.first;
    final revokedAt = row[0] as DateTime?;
    final expiresAt = row[1] as DateTime;
    return revokedAt == null && expiresAt.isAfter(DateTime.now().toUtc());
  }

  Future<void> revokeRefreshToken(String tokenId) async {
    await _ensureSchema();
    await _db.execute(
      'update oidc_refresh_tokens set revoked_at = now() where token_id = @token_id and revoked_at is null',
      params: {'token_id': tokenId},
    );
  }

  Future<void> revokeRefreshTokensForUser(String userId) async {
    await _ensureSchema();
    await _db.execute(
      '''
      update oidc_refresh_tokens
      set revoked_at = now()
      where user_id = @user_id
        and revoked_at is null
      ''',
      params: {'user_id': userId},
    );
  }

  Future<void> revokeAccessToken(String tokenId) async {
    await _ensureSchema();
    await _db.execute(
      '''
      update oidc_access_tokens
      set revoked_at = now()
      where token_id = @token_id
        and revoked_at is null
      ''',
      params: {'token_id': tokenId},
    );
  }

  Future<void> revokeAccessTokensForUser(String userId) async {
    await _ensureSchema();
    await _db.execute(
      '''
      update oidc_access_tokens
      set revoked_at = now()
      where user_id = @user_id
        and revoked_at is null
      ''',
      params: {'user_id': userId},
    );
  }

  Future<void> upsertClient({
    required String clientId,
    required String? displayName,
    required bool isOfficial,
    required List<String> redirectUris,
    required List<String> scopes,
    required List<String> grantTypes,
    required bool isConfidential,
    required bool isActive,
    String? clientSecretHash,
  }) async {
    await _ensureSchema();
    await _db.execute(
      '''
      insert into oidc_clients(
        client_id,
        display_name,
        is_official,
        client_secret_hash,
        redirect_uris,
        scopes,
        grant_types,
        is_confidential,
        is_active,
        created_at
      )
      values (
        @client_id,
        @display_name,
        @is_official,
        @client_secret_hash,
        @redirect_uris,
        @scopes,
        @grant_types,
        @is_confidential,
        @is_active,
        now()
      )
      on conflict (client_id)
      do update set
        client_secret_hash = coalesce(@client_secret_hash, oidc_clients.client_secret_hash),
        display_name = @display_name,
        is_official = @is_official,
        redirect_uris = @redirect_uris,
        scopes = @scopes,
        grant_types = @grant_types,
        is_confidential = @is_confidential,
        is_active = @is_active
      ''',
      params: {
        'client_id': clientId,
        'display_name': displayName,
        'is_official': isOfficial,
        'client_secret_hash': clientSecretHash,
        'redirect_uris': redirectUris,
        'scopes': scopes,
        'grant_types': grantTypes,
        'is_confidential': isConfidential,
        'is_active': isActive,
      },
    );
  }

  Future<void> deleteClient(String clientId) async {
    await _ensureSchema();
    await _db.runTx((tx) async {
      await tx.execute(
        Sql.named(
          'delete from app_authorizations where client_id = @client_id',
        ),
        parameters: {'client_id': clientId},
      );
      await tx.execute(
        Sql.named(
          'delete from oidc_refresh_tokens where client_id = @client_id',
        ),
        parameters: {'client_id': clientId},
      );
      await tx.execute(
        Sql.named(
          'delete from oidc_access_tokens where client_id = @client_id',
        ),
        parameters: {'client_id': clientId},
      );
      await tx.execute(
        Sql.named('delete from oidc_auth_codes where client_id = @client_id'),
        parameters: {'client_id': clientId},
      );
      await tx.execute(
        Sql.named('delete from oidc_clients where client_id = @client_id'),
        parameters: {'client_id': clientId},
      );
    });
  }
}
