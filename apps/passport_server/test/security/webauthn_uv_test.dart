import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('new WebAuthn registration options require user verification', () async {
    final process = await Process.start('node', [
      'scripts/webauthn-register-options.mjs',
    ]);
    process.stdin.writeln(
      jsonEncode({
        'rpID': 'passport.example.com',
        'rpName': 'ROSM Pass',
        'userID': 'user-1',
        'userName': 'user@example.com',
        'userDisplayName': 'User',
        'excludeCredentialIDs': <String>[],
      }),
    );
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    final error = await process.stderr.transform(utf8.decoder).join();
    expect(await process.exitCode, 0, reason: error);
    final body = Map<String, dynamic>.from(jsonDecode(output) as Map);
    final selection = Map<String, dynamic>.from(
      body['authenticatorSelection'] as Map,
    );
    expect(selection['userVerification'], 'required');
  });
}
