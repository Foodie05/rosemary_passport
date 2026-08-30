import 'dart:convert';

import 'package:crypto/crypto.dart';

class AuditChain {
  const AuditChain._();

  static String entryHash({
    required String previousHash,
    required String id,
    required String action,
    required String actorId,
    required String actorType,
    required String resourceType,
    required String resourceId,
    required Map<String, dynamic> metadata,
    required String? ipAddress,
    required DateTime createdAt,
  }) {
    final canonical = canonicalJson({
      'id': id,
      'action': action,
      'actor_id': actorId,
      'actor_type': actorType,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'metadata': metadata,
      'ip_address': ipAddress,
      'created_at': createdAt.toUtc().toIso8601String(),
    });
    return sha256.convert(utf8.encode('$previousHash\n$canonical')).toString();
  }

  static String verify(
    List<Map<String, dynamic>> records, {
    String previousHash = '',
  }) {
    var expectedPrevious = previousHash;
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final storedPrevious = record['previous_hash']?.toString() ?? '';
      if (storedPrevious != expectedPrevious) {
        throw StateError('Audit chain link mismatch at position $index.');
      }
      final storedHash = record['entry_hash']?.toString() ?? '';
      final computedHash = entryHash(
        previousHash: expectedPrevious,
        id: record['id'].toString(),
        action: record['action'].toString(),
        actorId: record['actor_id'].toString(),
        actorType: record['actor_type'].toString(),
        resourceType: record['resource_type'].toString(),
        resourceId: record['resource_id'].toString(),
        metadata: Map<String, dynamic>.from(record['metadata'] as Map),
        ipAddress: record['ip_address']?.toString(),
        createdAt: record['created_at'] as DateTime,
      );
      if (storedHash != computedHash) {
        throw StateError('Audit entry hash mismatch at position $index.');
      }
      expectedPrevious = computedHash;
    }
    return expectedPrevious;
  }

  static String canonicalJson(dynamic value) {
    dynamic normalize(dynamic item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        return {for (final key in keys) key: normalize(item[key])};
      }
      if (item is List) {
        return item.map(normalize).toList();
      }
      return item;
    }

    return jsonEncode(normalize(value));
  }
}
