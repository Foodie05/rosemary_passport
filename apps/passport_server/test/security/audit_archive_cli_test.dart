import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rosm_passport_server/src/security/audit_chain.dart';
import 'package:test/test.dart';

void main() {
  test(
    'archive verifier accepts exact content and rejects tampering',
    () async {
      final createdAt = DateTime.utc(2026, 8, 30, 2, 3, 4, 5, 6);
      final record = <String, dynamic>{
        'id': 'archive-id',
        'action': 'archive.created',
        'actor_id': 'actor-id',
        'actor_type': 'system',
        'resource_type': 'audit-archive',
        'resource_id': 'archive-id',
        'metadata': const {'result': 'ok'},
        'ip_address': null,
        'created_at': createdAt.toIso8601String(),
        'previous_hash': null,
        'chain_position': 1,
      };
      record['entry_hash'] = AuditChain.entryHash(
        previousHash: '',
        id: record['id'] as String,
        action: record['action'] as String,
        actorId: record['actor_id'] as String,
        actorType: record['actor_type'] as String,
        resourceType: record['resource_type'] as String,
        resourceId: record['resource_id'] as String,
        metadata: Map<String, dynamic>.from(record['metadata'] as Map),
        ipAddress: null,
        createdAt: createdAt,
      );

      final valid = await _verify('${jsonEncode(record)}\n');
      expect(valid.exitCode, 0, reason: valid.stderr);
      expect(
        valid.stdout,
        contains('Verified 1 archived audit chain entries.'),
      );

      final tampered = {
        ...record,
        'metadata': const {'result': 'tampered'},
      };
      final rejected = await _verify('${jsonEncode(tampered)}\n');
      expect(rejected.exitCode, isNot(0));
    },
  );
}

Future<({int exitCode, String stdout, String stderr})> _verify(
  String input,
) async {
  final process = await Process.start(Platform.resolvedExecutable, const [
    'run',
    'bin/verify_audit_chain.dart',
    '--stdin',
  ], workingDirectory: Directory.current.path);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  process.stdin.write(input);
  await process.stdin.close();
  final results = await Future.wait<Object>([
    process.exitCode,
    output,
    errors,
  ]).timeout(const Duration(seconds: 20));
  return (
    exitCode: results[0] as int,
    stdout: results[1] as String,
    stderr: results[2] as String,
  );
}
