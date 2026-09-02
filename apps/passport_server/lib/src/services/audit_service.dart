import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../security/audit_chain.dart';

class AuditService {
  AuditService(this._db, {String? ipHashKey}) : _ipHashKey = ipHashKey;

  final Database _db;
  final String? _ipHashKey;
  final _uuid = const Uuid();

  Future<void> log({
    required String action,
    required String actorId,
    required String actorType,
    required String resourceType,
    required String resourceId,
    required Map<String, dynamic> metadata,
    String? ip,
  }) async {
    final sanitizedMetadata = _sanitizeMetadata(metadata);
    final protectedIp = _protectIp(ip);
    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    await _db.runTx((tx) async {
      await tx.execute('select pg_advisory_xact_lock(82463207240630)');
      final previous = await tx.execute('''
        select entry_hash from audit_logs
        where entry_hash is not null
        order by chain_position desc
        limit 1
      ''');
      final previousHash = previous.isEmpty ? '' : previous.first[0].toString();
      final entryHash = AuditChain.entryHash(
        previousHash: previousHash,
        id: id,
        action: action,
        actorId: actorId,
        actorType: actorType,
        resourceType: resourceType,
        resourceId: resourceId,
        metadata: sanitizedMetadata,
        ipAddress: protectedIp,
        createdAt: createdAt,
      );
      await tx.execute(
        Sql.named('''
          insert into audit_logs(
            id, action, actor_id, actor_type, resource_type, resource_id,
            metadata, ip_address, created_at, previous_hash, entry_hash
          ) values (
            cast(@id as uuid), @action, @actor_id, @actor_type,
            @resource_type, @resource_id, @metadata::jsonb, @ip,
            @created_at, @previous_hash, @entry_hash
          )
        '''),
        parameters: {
          'id': id,
          'action': action,
          'actor_id': actorId,
          'actor_type': actorType,
          'resource_type': resourceType,
          'resource_id': resourceId,
          'metadata': jsonEncode(sanitizedMetadata),
          'ip': protectedIp,
          'created_at': createdAt,
          'previous_hash': previousHash.isEmpty ? null : previousHash,
          'entry_hash': entryHash,
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> list({
    int limit = 50,
    int offset = 0,
  }) async {
    final result = await _db.execute(
      '''
      select id, action, actor_id, actor_type, resource_type, resource_id,
             metadata, ip_address, created_at, previous_hash, entry_hash,
             chain_position
      from audit_logs
      order by chain_position desc
      limit @limit offset @offset
      ''',
      params: {'limit': limit, 'offset': offset},
    );

    return result
        .map(
          (row) => {
            'id': row[0],
            'action': row[1],
            'actor_id': row[2],
            'actor_type': row[3],
            'resource_type': row[4],
            'resource_id': row[5],
            'metadata': row[6],
            'ip_address': row[7],
            'created_at': row[8].toString(),
            'previous_hash': row[9],
            'entry_hash': row[10],
            'chain_position': row[11],
          },
        )
        .toList();
  }

  Future<int> verifyChain() async {
    final unhashed = await _db.execute('''
      select count(*)
      from audit_logs
      where entry_hash is null
        and chain_position > coalesce(
          (select min(chain_position) from audit_logs where entry_hash is not null),
          9223372036854775807
        )
    ''');
    if ((unhashed.first[0] as int) > 0) {
      throw StateError('Unhashed audit records exist inside the hash chain.');
    }
    var afterPosition = 0;
    var previousHash = '';
    var verified = 0;
    while (true) {
      final result = await _db.execute(
        '''
        select id, action, actor_id, actor_type, resource_type, resource_id,
               metadata, ip_address, created_at, previous_hash, entry_hash,
               chain_position
        from audit_logs
        where entry_hash is not null
          and chain_position > @after_position
        order by chain_position
        limit 1000
        ''',
        params: {'after_position': afterPosition},
      );
      if (result.isEmpty) {
        return verified;
      }
      final records = result
          .map(
            (row) => <String, dynamic>{
              'id': row[0],
              'action': row[1],
              'actor_id': row[2],
              'actor_type': row[3],
              'resource_type': row[4],
              'resource_id': row[5],
              'metadata': row[6],
              'ip_address': row[7],
              'created_at': row[8],
              'previous_hash': row[9],
              'entry_hash': row[10],
              'chain_position': row[11],
            },
          )
          .toList();
      previousHash = AuditChain.verify(records, previousHash: previousHash);
      verified += records.length;
      afterPosition = records.last['chain_position'] as int;
    }
  }

  Future<int> backfillLegacyHashes() async {
    return _db.runTx((tx) async {
      await tx.execute('select pg_advisory_xact_lock(82463207240630)');
      var afterPosition = 0;
      var previousHash = '';
      var existingPreviousHash = '';
      var existingChainStarted = false;
      var unhashedTailStarted = false;
      var migrated = 0;
      while (true) {
        final result = await tx.execute(
          Sql.named('''
            select id, action, actor_id, actor_type, resource_type, resource_id,
                   metadata, ip_address, created_at, previous_hash, entry_hash,
                   chain_position
            from audit_logs
            where chain_position > @after_position
            order by chain_position
            limit 1000
          '''),
          parameters: {'after_position': afterPosition},
        );
        if (result.isEmpty) {
          return migrated;
        }
        for (final row in result) {
          final expectedHash = AuditChain.entryHash(
            previousHash: previousHash,
            id: row[0].toString(),
            action: row[1].toString(),
            actorId: row[2].toString(),
            actorType: row[3].toString(),
            resourceType: row[4].toString(),
            resourceId: row[5].toString(),
            metadata: Map<String, dynamic>.from(row[6] as Map),
            ipAddress: row[7]?.toString(),
            createdAt: row[8] as DateTime,
          );
          final storedPrevious = row[9]?.toString() ?? '';
          final storedHash = row[10]?.toString() ?? '';
          if (storedHash.isNotEmpty) {
            if (unhashedTailStarted) {
              throw StateError(
                'Existing audit hash chain has an unhashed gap before '
                'position ${row[11]}.',
              );
            }
            existingChainStarted = true;
            existingPreviousHash = AuditChain.verify([
              <String, dynamic>{
                'id': row[0],
                'action': row[1],
                'actor_id': row[2],
                'actor_type': row[3],
                'resource_type': row[4],
                'resource_id': row[5],
                'metadata': row[6],
                'ip_address': row[7],
                'created_at': row[8],
                'previous_hash': row[9],
                'entry_hash': row[10],
              },
            ], previousHash: existingPreviousHash);
          } else if (existingChainStarted) {
            unhashedTailStarted = true;
          }
          if (storedPrevious != previousHash || storedHash != expectedHash) {
            await tx.execute(
              Sql.named('''
                update audit_logs
                set previous_hash = @previous_hash, entry_hash = @entry_hash
                where id = cast(@id as uuid) and entry_hash is null
              '''),
              parameters: {
                'id': row[0].toString(),
                'previous_hash': previousHash.isEmpty ? null : previousHash,
                'entry_hash': expectedHash,
              },
            );
            migrated++;
          }
          previousHash = expectedHash;
        }
        afterPosition = result.last[11] as int;
      }
    });
  }

  Map<String, dynamic> _sanitizeMetadata(Map<String, dynamic> metadata) {
    final next = <String, dynamic>{};
    for (final entry in metadata.entries) {
      next[entry.key] = _sanitizeValue(entry.key, entry.value);
    }
    return next;
  }

  dynamic _sanitizeValue(String key, dynamic value) {
    if (value is Map<String, dynamic>) {
      return _sanitizeMetadata(value);
    }
    if (value is Map) {
      return _sanitizeMetadata(
        value.map((innerKey, innerValue) => MapEntry('$innerKey', innerValue)),
      );
    }
    if (value is List) {
      return value.map((item) => _sanitizeValue(key, item)).toList();
    }
    final normalizedKey = key.toLowerCase();
    if (normalizedKey.contains('password') ||
        normalizedKey.contains('secret') ||
        normalizedKey.contains('token') ||
        normalizedKey.contains('authorization') ||
        normalizedKey.contains('cookie') ||
        normalizedKey.endsWith('code')) {
      return '[REDACTED]';
    }
    if (value is String &&
        (normalizedKey.contains('email') || value.contains('@'))) {
      return _maskEmail(value);
    }
    return value;
  }

  String _maskEmail(String raw) {
    final trimmed = raw.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0 || atIndex == trimmed.length - 1) {
      return trimmed;
    }
    final local = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex + 1);
    if (local.length <= 2) {
      return '${local[0]}***@$domain';
    }
    return '${local.substring(0, 2)}***@$domain';
  }

  String? _protectIp(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final key = _ipHashKey;
    if (key == null || key.isEmpty) return value;
    return 'hmac-sha256:${Hmac(sha256, utf8.encode(key)).convert(utf8.encode(value))}';
  }
}
