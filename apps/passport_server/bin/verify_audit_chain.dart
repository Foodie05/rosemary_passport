import 'dart:convert';
import 'dart:io';

import '../lib/src/config/app_config.dart';
import '../lib/src/db/database.dart';
import '../lib/src/security/audit_chain.dart';
import '../lib/src/services/audit_service.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--stdin')) {
    await _verifyArchiveFromStdin();
    return;
  }
  final database = Database(AppConfig.fromEnv());
  try {
    await database.warmUp();
    final verified = await AuditService(database).verifyChain();
    // ignore: avoid_print
    print('Verified $verified audit chain entries.');
  } finally {
    await database.close();
  }
}

Future<void> _verifyArchiveFromStdin() async {
  var previousHash = '';
  var verified = 0;
  var chainStarted = false;
  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) {
      continue;
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(line) as Map);
    final entryHash = decoded['entry_hash']?.toString() ?? '';
    if (entryHash.isEmpty) {
      if (chainStarted) {
        throw StateError('Unhashed audit record found inside the hash chain.');
      }
      continue;
    }
    chainStarted = true;
    decoded['created_at'] = DateTime.parse(decoded['created_at'].toString());
    previousHash = AuditChain.verify([decoded], previousHash: previousHash);
    verified++;
  }
  // ignore: avoid_print
  print('Verified $verified archived audit chain entries.');
}
