import '../db/database.dart';

class EmailCodeRepository {
  EmailCodeRepository(this._db);

  final Database _db;

  Future<void> storeCode({
    required String email,
    required String codeHash,
    required DateTime expiresAt,
    required String purpose,
  }) async {
    await _db.execute(
      '''
      insert into email_verification_codes(email, code_hash, purpose, expires_at)
      values (lower(@email), @code_hash, @purpose, @expires_at)
      ''',
      params: {
        'email': email,
        'code_hash': codeHash,
        'purpose': purpose,
        'expires_at': expiresAt,
      },
    );
  }

  Future<Map<String, dynamic>?> findLatestCode({
    required String email,
    required String purpose,
  }) async {
    final result = await _db.execute(
      '''
      select id, code_hash, expires_at, used_at
           , failed_attempts
      from email_verification_codes
      where lower(email) = lower(@email)
        and purpose = @purpose
      order by created_at desc
      limit 1
      ''',
      params: {
        'email': email,
        'purpose': purpose,
      },
    );

    if (result.isEmpty) {
      return null;
    }

    final row = result.first;
    return {
      'id': row[0],
      'code_hash': row[1],
      'expires_at': row[2] as DateTime,
      'used_at': row[3] as DateTime?,
      'failed_attempts': row[4] as int,
    };
  }

  Future<void> markUsed(String codeId) async {
    await _db.execute(
      'update email_verification_codes set used_at = now() where id = @id',
      params: {'id': codeId},
    );
  }

  Future<bool> markUsedIfAvailable(String codeId) async {
    final result = await _db.execute(
      '''
      update email_verification_codes
      set used_at = now()
      where id = @id
        and used_at is null
        and expires_at > now()
      returning id
      ''',
      params: {'id': codeId},
    );
    return result.isNotEmpty;
  }

  Future<void> markFailed(String codeId) async {
    await _db.execute(
      '''
      update email_verification_codes
      set failed_attempts = failed_attempts + 1
      where id = @id and used_at is null
      ''',
      params: {'id': codeId},
    );
  }
}
