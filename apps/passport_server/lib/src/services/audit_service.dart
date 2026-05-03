import '../db/database.dart';

class AuditService {
  AuditService(this._db);

  final Database _db;

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
    await _db.execute(
      '''
      insert into audit_logs(action, actor_id, actor_type, resource_type, resource_id, metadata, ip_address)
      values (@action, @actor_id, @actor_type, @resource_type, @resource_id, @metadata::jsonb, @ip)
      ''',
      params: {
        'action': action,
        'actor_id': actorId,
        'actor_type': actorType,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'metadata': sanitizedMetadata,
        'ip': ip,
      },
    );
  }

  Future<List<Map<String, dynamic>>> list(
      {int limit = 50, int offset = 0}) async {
    final result = await _db.execute(
      '''
      select id, action, actor_id, actor_type, resource_type, resource_id, metadata, ip_address, created_at
      from audit_logs
      order by created_at desc
      limit @limit offset @offset
      ''',
      params: {
        'limit': limit,
        'offset': offset,
      },
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
          },
        )
        .toList();
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
}
