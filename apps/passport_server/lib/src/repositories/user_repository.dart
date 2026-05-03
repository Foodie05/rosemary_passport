import '../config/app_config.dart';
import '../db/database.dart';
import '../models/authenticated_user.dart';
import 'package:postgres/postgres.dart';

class UserRecord {
  const UserRecord({
    required this.id,
    required this.email,
    required this.nickname,
    required this.passwordHash,
    required this.passkeyHash,
    required this.securityCodeHash,
    required this.authenticatorSecret,
    required this.hasAuthenticator,
    required this.roles,
    required this.isEmailVerified,
  });

  final String id;
  final String email;
  final String nickname;
  final String passwordHash;
  final String? passkeyHash;
  final String? securityCodeHash;
  final String? authenticatorSecret;
  final bool hasAuthenticator;
  final List<String> roles;
  final bool isEmailVerified;

  bool get hasPasskey => passkeyHash != null && passkeyHash!.trim().isNotEmpty;
  bool get hasSecurityCode =>
      securityCodeHash != null && securityCodeHash!.trim().isNotEmpty;

  AuthenticatedUser toAuthenticatedUser({
    String? accessTokenId,
    DateTime? postRegistrationPasskeyBootstrapUntil,
  }) => AuthenticatedUser(
    id: id,
    email: email,
    nickname: nickname,
    roles: roles,
    accessTokenId: accessTokenId,
    postRegistrationPasskeyBootstrapUntil:
        postRegistrationPasskeyBootstrapUntil,
  );
}

class UserRepository {
  UserRepository(this._db, this._config);

  final Database _db;
  final AppConfig _config;

  Future<UserRecord?> findByEmail(String email) async {
    final result = await _db.execute(
      '''
      select u.id, u.email, u.nickname, u.password_hash, u.passkey_hash,
             u.security_code_hash,
             (u.authenticator_secret is not null and length(trim(u.authenticator_secret)) > 0)
               as has_authenticator,
             u.is_email_verified,
             coalesce(array_agg(ur.role) filter (where ur.role is not null), '{}') as roles
      from users u
      left join user_roles ur on ur.user_id = u.id
      where lower(u.email) = lower(@email)
      group by u.id
      ''',
      params: {'email': email},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return UserRecord(
      id: row[0] as String,
      email: row[1] as String,
      nickname: row[2] as String,
      passwordHash: row[3] as String,
      passkeyHash: row[4] as String?,
      securityCodeHash: row[5] as String?,
      authenticatorSecret: null,
      hasAuthenticator: row[6] as bool,
      isEmailVerified: row[7] as bool,
      roles: (row[8] as List).map((e) => e.toString()).toList(),
    );
  }

  Future<UserRecord?> findById(String userId) async {
    final result = await _db.execute(
      '''
      select u.id, u.email, u.nickname, u.password_hash, u.passkey_hash,
             u.security_code_hash,
             (u.authenticator_secret is not null and length(trim(u.authenticator_secret)) > 0)
               as has_authenticator,
             u.is_email_verified,
             coalesce(array_agg(ur.role) filter (where ur.role is not null), '{}') as roles
      from users u
      left join user_roles ur on ur.user_id = u.id
      where u.id = @user_id
      group by u.id
      ''',
      params: {'user_id': userId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return UserRecord(
      id: row[0] as String,
      email: row[1] as String,
      nickname: row[2] as String,
      passwordHash: row[3] as String,
      passkeyHash: row[4] as String?,
      securityCodeHash: row[5] as String?,
      authenticatorSecret: null,
      hasAuthenticator: row[6] as bool,
      isEmailVerified: row[7] as bool,
      roles: (row[8] as List).map((e) => e.toString()).toList(),
    );
  }

  Future<String?> findAuthenticatorSecretByUserId(String userId) async {
    final result = await _db.execute(
      '''
      select case
               when u.authenticator_secret is null or
                    length(trim(u.authenticator_secret)) = 0 then null
               when u.authenticator_secret like 'enc:%' then
                 pgp_sym_decrypt(
                   decode(substring(u.authenticator_secret from 5), 'base64')::bytea,
                   @encryption_key
                 )
               else u.authenticator_secret
             end as authenticator_secret
      from users u
      where u.id = @user_id
      ''',
      params: {'user_id': userId, 'encryption_key': _config.dataEncryptionKey},
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first[0] as String?;
  }

  Future<void> createUser({
    required String userId,
    required String email,
    required String nickname,
    required String passwordHash,
    List<String> roles = const ['user'],
    bool isEmailVerified = true,
  }) async {
    await _db.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          insert into users(id, email, nickname, password_hash, is_email_verified)
          values (@id, lower(@email), @nickname, @password_hash, @is_email_verified)
          '''),
        parameters: {
          'id': userId,
          'email': email,
          'nickname': nickname,
          'password_hash': passwordHash,
          'is_email_verified': isEmailVerified,
        },
      );

      for (final role in roles.toSet()) {
        await tx.execute(
          Sql.named(
            'insert into user_roles(user_id, role) values (@user_id, @role)',
          ),
          parameters: {'user_id': userId, 'role': role},
        );
      }
    });
  }

  Future<void> updateRoles({
    required String userId,
    required List<String> roles,
  }) async {
    await _db.runTx((tx) async {
      await tx.execute(
        Sql.named('delete from user_roles where user_id = @user_id'),
        parameters: {'user_id': userId},
      );

      for (final role in roles) {
        await tx.execute(
          Sql.named(
            'insert into user_roles(user_id, role) values (@user_id, @role)',
          ),
          parameters: {'user_id': userId, 'role': role},
        );
      }
    });
  }

  Future<void> deleteUser({required String userId}) async {
    await _db.execute(
      'delete from users where id = @user_id',
      params: {'user_id': userId},
    );
  }

  Future<void> updateNickname({
    required String userId,
    required String nickname,
  }) async {
    await _db.execute(
      'update users set nickname = @nickname, updated_at = now() where id = @user_id',
      params: {'nickname': nickname, 'user_id': userId},
    );
  }

  Future<void> updateEmail({
    required String userId,
    required String email,
  }) async {
    await _db.execute(
      'update users set email = lower(@email), is_email_verified = true, updated_at = now() where id = @user_id',
      params: {'email': email, 'user_id': userId},
    );
  }

  Future<void> updatePasswordHash({
    required String userId,
    required String passwordHash,
  }) async {
    await _db.execute(
      'update users set password_hash = @password_hash, updated_at = now() where id = @user_id',
      params: {'password_hash': passwordHash, 'user_id': userId},
    );
  }

  Future<void> updatePasskeyHash({
    required String userId,
    required String passkeyHash,
  }) async {
    await _db.execute(
      'update users set passkey_hash = @passkey_hash, updated_at = now() where id = @user_id',
      params: {'passkey_hash': passkeyHash, 'user_id': userId},
    );
  }

  Future<void> updateSecurityCodeHash({
    required String userId,
    required String securityCodeHash,
  }) async {
    await _db.execute(
      'update users set security_code_hash = @security_code_hash, updated_at = now() where id = @user_id',
      params: {'security_code_hash': securityCodeHash, 'user_id': userId},
    );
  }

  Future<void> updateAuthenticatorSecret({
    required String userId,
    required String authenticatorSecret,
  }) async {
    await _db.execute(
      '''
      update users
      set authenticator_secret = concat(
            'enc:',
            encode(
              pgp_sym_encrypt(@authenticator_secret, @encryption_key),
              'base64'
            )
          ),
          authenticator_verified_at = now(),
          updated_at = now()
      where id = @user_id
      ''',
      params: {
        'authenticator_secret': authenticatorSecret,
        'encryption_key': _config.dataEncryptionKey,
        'user_id': userId,
      },
    );
  }

  Future<void> migratePlaintextAuthenticatorSecrets() async {
    await _db.execute(
      '''
      update users
      set authenticator_secret = concat(
            'enc:',
            encode(
              pgp_sym_encrypt(authenticator_secret, @encryption_key),
              'base64'
            )
          ),
          updated_at = now()
      where authenticator_secret is not null
        and length(trim(authenticator_secret)) > 0
        and authenticator_secret not like 'enc:%'
      ''',
      params: {'encryption_key': _config.dataEncryptionKey},
    );
  }

  Future<List<Map<String, dynamic>>> listUsers({
    int limit = 50,
    int offset = 0,
    String? search,
  }) async {
    final searchValue = search?.trim() ?? '';
    final result = await _db.execute(
      '''
      select u.id, u.email, u.nickname, u.is_email_verified, u.created_at,
             exists(
               select 1
               from user_webauthn_credentials uwc
               where uwc.user_id = u.id
             ) as has_passkey,
             (u.authenticator_secret is not null and length(trim(u.authenticator_secret)) > 0) as has_authenticator,
             coalesce(array_agg(ur.role) filter (where ur.role is not null), '{}') as roles
      from users u
      left join user_roles ur on ur.user_id = u.id
      where (
        @search = '' or
        lower(u.email) like lower(@search_like) or
        lower(u.nickname) like lower(@search_like)
      )
      group by u.id
      order by u.created_at desc
      limit @limit offset @offset
      ''',
      params: {
        'limit': limit,
        'offset': offset,
        'search': searchValue,
        'search_like': '%$searchValue%',
      },
    );

    return result
        .map(
          (row) => {
            'id': row[0],
            'email': row[1],
            'nickname': row[2],
            'is_email_verified': row[3],
            'created_at': row[4].toString(),
            'has_passkey': row[5],
            'has_authenticator': row[6],
            'roles': (row[7] as List).map((e) => e.toString()).toList(),
          },
        )
        .toList();
  }

  Future<int> countUsers({String? search}) async {
    final searchValue = search?.trim() ?? '';
    final result = await _db.execute(
      '''
      select count(*)
      from users u
      where (
        @search = '' or
        lower(u.email) like lower(@search_like) or
        lower(u.nickname) like lower(@search_like)
      )
      ''',
      params: {'search': searchValue, 'search_like': '%$searchValue%'},
    );

    if (result.isEmpty) {
      return 0;
    }
    return result.first[0] as int;
  }
}
