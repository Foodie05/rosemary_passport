import 'package:rosm_passport_server/src/security/audit_chain.dart';
import 'package:test/test.dart';

void main() {
  test('verifies canonical records and detects content or link tampering', () {
    final createdAt = DateTime.utc(2026, 8, 30, 1, 2, 3, 456, 789);
    final first = _record(
      previousHash: '',
      id: 'first-id',
      metadata: {
        'nested': {'z': 1, 'a': true},
      },
      createdAt: createdAt,
    );
    final second = _record(
      previousHash: first['entry_hash'] as String,
      id: 'second-id',
      metadata: const {'result': 'ok'},
      createdAt: createdAt.add(const Duration(microseconds: 1)),
    );

    expect(AuditChain.verify([first, second]), second['entry_hash']);
    expect(
      AuditChain.verify([second], previousHash: first['entry_hash'] as String),
      second['entry_hash'],
    );

    final alteredContent = [
      first,
      {
        ...second,
        'metadata': const {'result': 'altered'},
      },
    ];
    expect(() => AuditChain.verify(alteredContent), throwsStateError);

    final alteredLink = [
      first,
      {...second, 'previous_hash': List.filled(64, '0').join()},
    ];
    expect(() => AuditChain.verify(alteredLink), throwsStateError);
  });
}

Map<String, dynamic> _record({
  required String previousHash,
  required String id,
  required Map<String, dynamic> metadata,
  required DateTime createdAt,
}) {
  final record = <String, dynamic>{
    'id': id,
    'action': 'user.updated',
    'actor_id': 'actor-id',
    'actor_type': 'user',
    'resource_type': 'user',
    'resource_id': 'resource-id',
    'metadata': metadata,
    'ip_address': '192.0.2.10',
    'created_at': createdAt,
    'previous_hash': previousHash.isEmpty ? null : previousHash,
  };
  record['entry_hash'] = AuditChain.entryHash(
    previousHash: previousHash,
    id: id,
    action: record['action'] as String,
    actorId: record['actor_id'] as String,
    actorType: record['actor_type'] as String,
    resourceType: record['resource_type'] as String,
    resourceId: record['resource_id'] as String,
    metadata: metadata,
    ipAddress: record['ip_address'] as String,
    createdAt: createdAt,
  );
  return record;
}
