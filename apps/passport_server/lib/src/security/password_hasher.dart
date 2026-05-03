import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';

import '../config/app_config.dart';

class PasswordHasher {
  PasswordHasher(this._config);

  final AppConfig _config;
  final _secure = Random.secure();

  Future<String> hash(String password) async {
    final salt =
        Uint8List.fromList(List<int>.generate(16, (_) => _secure.nextInt(256)));
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      iterations: _config.argon2Iterations,
      memory: _config.argon2MemoryKb,
      lanes: _config.argon2Parallelism,
    );

    final generator = Argon2BytesGenerator()..init(parameters);
    final output = Uint8List(32);
    generator.generateBytes(
        parameters.converter.convert(password), output, 0, output.length);

    final saltB64 = base64Url.encode(salt).replaceAll('=', '');
    final hashB64 = base64Url.encode(output).replaceAll('=', '');
    return 'argon2id:m=${_config.argon2MemoryKb},t=${_config.argon2Iterations},p=${_config.argon2Parallelism}:$saltB64:$hashB64';
  }

  Future<bool> verify(String hashedPassword, String password) async {
    try {
      final parts = hashedPassword.split(':');
      if (parts.length != 4 || !parts.first.startsWith('argon2id')) {
        return false;
      }

      final paramPairs = parts[1].split(',');
      final memory = int.parse(paramPairs[0].split('=').last);
      final iterations = int.parse(paramPairs[1].split('=').last);
      final lanes = int.parse(paramPairs[2].split('=').last);
      final salt = base64Url.decode(base64Url.normalize(parts[2]));
      final expected = base64Url.decode(base64Url.normalize(parts[3]));

      final parameters = Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        Uint8List.fromList(salt),
        iterations: iterations,
        memory: memory,
        lanes: lanes,
      );
      final generator = Argon2BytesGenerator()..init(parameters);
      final actual = Uint8List(expected.length);
      generator.generateBytes(
          parameters.converter.convert(password), actual, 0, actual.length);
      return _timingSafeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  bool _timingSafeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
