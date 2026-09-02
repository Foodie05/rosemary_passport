import 'package:postgres/postgres.dart';

import '../db/database.dart';

class LegalRepository {
  LegalRepository(this._db);

  final Database _db;

  Future<Map<String, dynamic>?> current(String type) async {
    final rows = await _db.execute(
      '''
      select id, document_type, version, title, content, status,
             published_at, created_at, updated_at
      from legal_documents
      where document_type = @type and status = 'published'
      order by version desc
      limit 1
      ''',
      params: {'type': type},
    );
    return rows.isEmpty ? null : _document(rows.first);
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    final rows = await _db.execute('''
      select id, document_type, version, title, content, status,
             published_at, created_at, updated_at
      from legal_documents
      order by document_type, version desc
      ''');
    return rows.map(_document).toList();
  }

  Future<Map<String, dynamic>> saveDraft({
    required String type,
    required String title,
    required String content,
    required String actorId,
  }) async {
    return _db.runTx((tx) async {
      await tx.execute('select pg_advisory_xact_lock(82463207240631)');
      final rows = await tx.execute(
        Sql.named('''
          insert into legal_documents(
            document_type, version, title, content, status, created_by
          ) values (
            @type,
            coalesce((select max(version) + 1 from legal_documents where document_type = @type), 1),
            @title, @content, 'draft', cast(@actor_id as uuid)
          )
          on conflict (document_type) where status = 'draft'
          do update set title = excluded.title,
                        content = excluded.content,
                        updated_at = now()
          returning id, document_type, version, title, content, status,
                    published_at, created_at, updated_at
          '''),
        parameters: {
          'type': type,
          'title': title,
          'content': content,
          'actor_id': actorId,
        },
      );
      return _document(rows.single);
    });
  }

  Future<Map<String, dynamic>?> publish({
    required String documentId,
    required String actorId,
  }) async {
    return _db.runTx((tx) async {
      await tx.execute('select pg_advisory_xact_lock(82463207240631)');
      final draft = await tx.execute(
        Sql.named('''
          select id, document_type
          from legal_documents
          where id = cast(@id as uuid) and status = 'draft'
          for update
        '''),
        parameters: {'id': documentId},
      );
      if (draft.isEmpty) return null;
      final rows = await tx.execute(
        Sql.named('''
          update legal_documents
          set status = 'published',
              published_by = cast(@actor_id as uuid),
              published_at = now(),
              updated_at = now()
          where id = cast(@id as uuid)
          returning id, document_type, version, title, content, status,
                    published_at, created_at, updated_at
        '''),
        parameters: {'id': documentId, 'actor_id': actorId},
      );
      return _document(rows.single);
    });
  }

  Future<void> recordAcceptance({
    required String userId,
    required String termsId,
    required String privacyId,
    required String context,
    required String? ipHash,
    required String? userAgentHash,
  }) async {
    await _db.execute(
      '''
      insert into user_legal_acceptances(
        user_id, terms_document_id, privacy_document_id,
        acceptance_context, ip_hash, user_agent_hash
      ) values (
        cast(@user_id as uuid), cast(@terms_id as uuid),
        cast(@privacy_id as uuid), @context, @ip_hash, @user_agent_hash
      )
      ''',
      params: {
        'user_id': userId,
        'terms_id': termsId,
        'privacy_id': privacyId,
        'context': context,
        'ip_hash': ipHash,
        'user_agent_hash': userAgentHash,
      },
    );
  }

  Future<bool> hasAcceptedCurrent(String userId) async {
    final rows = await _db.execute(
      '''
      select exists(
        select 1
        from user_legal_acceptances ula
        join legal_documents terms on terms.id = ula.terms_document_id
        join legal_documents privacy on privacy.id = ula.privacy_document_id
        where ula.user_id = cast(@user_id as uuid)
          and terms.id = (
            select id from legal_documents
            where document_type = 'terms' and status = 'published'
            order by version desc limit 1
          )
          and privacy.id = (
            select id from legal_documents
            where document_type = 'privacy' and status = 'published'
            order by version desc limit 1
          )
      )
      ''',
      params: {'user_id': userId},
    );
    return rows.isNotEmpty && rows.first[0] == true;
  }

  Map<String, dynamic> _document(ResultRow row) => {
    'id': row[0].toString(),
    'type': row[1].toString(),
    'version': row[2] as int,
    'title': row[3].toString(),
    'content': row[4].toString(),
    'status': row[5].toString(),
    'published_at': row[6]?.toString(),
    'created_at': row[7].toString(),
    'updated_at': row[8].toString(),
  };
}
