import '../db/database.dart';
import 'package:postgres/postgres.dart';

class WebAuthnCredentialRecord {
  const WebAuthnCredentialRecord({
    required this.userId,
    required this.credentialId,
    required this.publicKey,
    required this.counter,
    required this.transports,
    required this.deviceType,
    required this.backedUp,
    required this.createdAt,
  });

  final String userId;
  final String credentialId;
  final String publicKey;
  final int counter;
  final List<String> transports;
  final String? deviceType;
  final bool backedUp;
  final DateTime createdAt;
}

class WebAuthnChallengeRecord {
  const WebAuthnChallengeRecord({
    required this.id,
    required this.challenge,
    required this.rpId,
    required this.origin,
    required this.expiresAt,
  });

  final String id;
  final String challenge;
  final String rpId;
  final String origin;
  final DateTime expiresAt;
}

class WebAuthnRepository {
  WebAuthnRepository(this._db);

  final Database _db;

  Future<List<WebAuthnCredentialRecord>> listCredentialsForUser(
    String userId,
  ) async {
    final result = await _db.execute(
      '''
      select user_id, credential_id, public_key, counter, transports, device_type, backed_up, created_at
      from user_webauthn_credentials
      where user_id = @user_id
      order by created_at desc
      ''',
      params: {'user_id': userId},
    );

    return result
        .map(
          (row) => WebAuthnCredentialRecord(
            userId: row[0] as String,
            credentialId: row[1] as String,
            publicKey: row[2] as String,
            counter: row[3] as int,
            transports: (row[4] as List? ?? const [])
                .map((item) => item.toString())
                .toList(),
            deviceType: row[5] as String?,
            backedUp: row[6] as bool? ?? false,
            createdAt: row[7] as DateTime,
          ),
        )
        .toList();
  }

  Future<WebAuthnCredentialRecord?> findCredential(String credentialId) async {
    final result = await _db.execute(
      '''
      select user_id, credential_id, public_key, counter, transports, device_type, backed_up, created_at
      from user_webauthn_credentials
      where credential_id = @credential_id
      limit 1
      ''',
      params: {'credential_id': credentialId},
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return WebAuthnCredentialRecord(
      userId: row[0] as String,
      credentialId: row[1] as String,
      publicKey: row[2] as String,
      counter: row[3] as int,
      transports: (row[4] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      deviceType: row[5] as String?,
      backedUp: row[6] as bool? ?? false,
      createdAt: row[7] as DateTime,
    );
  }

  Future<int> countCredentialsForUser(String userId) async {
    final result = await _db.execute(
      '''
      select count(*)
      from user_webauthn_credentials
      where user_id = @user_id
      ''',
      params: {'user_id': userId},
    );

    if (result.isEmpty) {
      return 0;
    }
    return result.first[0] as int;
  }

  Future<void> insertCredential({
    required String userId,
    required String credentialId,
    required String publicKey,
    required int counter,
    required List<String> transports,
    String? deviceType,
    required bool backedUp,
  }) async {
    await _db.execute(
      '''
      insert into user_webauthn_credentials(
        user_id, credential_id, public_key, counter, transports, device_type, backed_up
      )
      values (
        cast(@user_id as uuid),
        cast(@credential_id as text),
        cast(@public_key as text),
        cast(@counter as bigint),
        cast(@transports as text[]),
        cast(@device_type as text),
        cast(@backed_up as boolean)
      )
      on conflict (credential_id) do update
      set public_key = excluded.public_key,
          counter = excluded.counter,
          transports = excluded.transports,
          device_type = excluded.device_type,
          backed_up = excluded.backed_up
      ''',
      params: {
        'user_id': userId,
        'credential_id': credentialId,
        'public_key': publicKey,
        'counter': counter,
        'transports': transports,
        'device_type': deviceType,
        'backed_up': backedUp,
      },
    );
  }

  Future<void> updateCredentialCounter({
    required String credentialId,
    required int counter,
  }) async {
    await _db.execute(
      '''
      update user_webauthn_credentials
      set counter = @counter
      where credential_id = @credential_id
      ''',
      params: {
        'credential_id': credentialId,
        'counter': counter,
      },
    );
  }

  Future<void> deleteCredential({
    required String userId,
    required String credentialId,
  }) async {
    await _db.execute(
      '''
      delete from user_webauthn_credentials
      where user_id = @user_id and credential_id = @credential_id
      ''',
      params: {
        'user_id': userId,
        'credential_id': credentialId,
      },
    );
  }

  Future<void> storeChallenge({
    String? userId,
    String? email,
    required String purpose,
    required String challenge,
    required String rpId,
    required String origin,
    required DateTime expiresAt,
  }) async {
    await _db.execute(
      '''
      insert into user_webauthn_challenges(
        user_id, email, purpose, challenge, rp_id, origin, expires_at
      )
      values (
        cast(@user_id as uuid),
        cast(@email as text),
        cast(@purpose as text),
        cast(@challenge as text),
        cast(@rp_id as text),
        cast(@origin as text),
        cast(@expires_at as timestamptz)
      )
      ''',
      params: {
        'user_id': userId,
        'email': email,
        'purpose': purpose,
        'challenge': challenge,
        'rp_id': rpId,
        'origin': origin,
        'expires_at': expiresAt,
      },
    );
  }

  Future<WebAuthnChallengeRecord?> findLatestChallenge({
    String? userId,
    String? email,
    required String purpose,
  }) async {
    late final Result result;
    if (userId != null && userId.trim().isNotEmpty && email != null && email.trim().isNotEmpty) {
      result = await _db.execute(
        '''
        select id, challenge, rp_id, origin, expires_at
        from user_webauthn_challenges
        where purpose = cast(@purpose as text)
          and user_id = cast(@user_id as uuid)
          and lower(email) = lower(cast(@email as text))
        order by created_at desc
        limit 1
        ''',
        params: {
          'purpose': purpose,
          'user_id': userId,
          'email': email,
        },
      );
    } else if (userId != null && userId.trim().isNotEmpty) {
      result = await _db.execute(
        '''
        select id, challenge, rp_id, origin, expires_at
        from user_webauthn_challenges
        where purpose = cast(@purpose as text)
          and user_id = cast(@user_id as uuid)
        order by created_at desc
        limit 1
        ''',
        params: {
          'purpose': purpose,
          'user_id': userId,
        },
      );
    } else if (email != null && email.trim().isNotEmpty) {
      result = await _db.execute(
        '''
        select id, challenge, rp_id, origin, expires_at
        from user_webauthn_challenges
        where purpose = cast(@purpose as text)
          and lower(email) = lower(cast(@email as text))
        order by created_at desc
        limit 1
        ''',
        params: {
          'purpose': purpose,
          'email': email,
        },
      );
    } else {
      result = await _db.execute(
        '''
        select id, challenge, rp_id, origin, expires_at
        from user_webauthn_challenges
        where purpose = cast(@purpose as text)
        order by created_at desc
        limit 1
        ''',
        params: {
          'purpose': purpose,
        },
      );
    }

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return WebAuthnChallengeRecord(
      id: row[0] as String,
      challenge: row[1] as String,
      rpId: row[2] as String,
      origin: row[3] as String,
      expiresAt: row[4] as DateTime,
    );
  }

  Future<void> deleteChallenge(String id) async {
    await _db.execute(
      'delete from user_webauthn_challenges where id = @id',
      params: {'id': id},
    );
  }
}
