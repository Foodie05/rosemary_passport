import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:argon2/argon2.dart';

import '../config/app_config.dart';

class PasswordWorkUnavailable implements Exception {
  const PasswordWorkUnavailable();
}

class PasswordHasher {
  PasswordHasher(this._config);

  final AppConfig _config;
  static var _activeJobs = 0;
  static final _waiting = Queue<Completer<void>>();

  // Bound both memory-intensive workers and waiting requests per server isolate.
  // Work never runs on the HTTP event loop, including verification of old hashes.
  static Future<Object> _runJob(List<Object> job) async {
    if (_activeJobs >= 2) {
      if (_waiting.length >= 16) {
        throw const PasswordWorkUnavailable();
      }
      final ready = Completer<void>();
      _waiting.add(ready);
      await ready.future;
    } else {
      _activeJobs++;
    }
    try {
      return await Isolate.run(
        () => job[0] == 'hash'
            ? _hash(
                job[1] as String,
                job[2] as int,
                job[3] as int,
                job[4] as int,
              )
            : _verify(job[1] as String, job[2] as String),
      );
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _activeJobs--;
      }
    }
  }

  Future<String> hash(String password) async {
    return await _runJob([
          'hash',
          password,
          _config.argon2MemoryKb,
          _config.argon2Iterations,
          _config.argon2Parallelism,
        ])
        as String;
  }

  Future<bool> verify(String hashedPassword, String password) async {
    return await _runJob(['verify', hashedPassword, password]) as bool;
  }

  static String _hash(String password, int memory, int iterations, int lanes) {
    final secure = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => secure.nextInt(256)),
    );
    final parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      iterations: iterations,
      memory: memory,
      lanes: lanes,
    );

    final generator = Argon2BytesGenerator()..init(parameters);
    final output = Uint8List(32);
    generator.generateBytes(
      parameters.converter.convert(password),
      output,
      0,
      output.length,
    );

    final saltB64 = base64Url.encode(salt).replaceAll('=', '');
    final hashB64 = base64Url.encode(output).replaceAll('=', '');
    return 'argon2id:m=$memory,t=$iterations,p=$lanes:$saltB64:$hashB64';
  }

  static bool _verify(String hashedPassword, String password) {
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
        parameters.converter.convert(password),
        actual,
        0,
        actual.length,
      );
      return _timingSafeEquals(actual, expected);
    } catch (_) {
      return false;
    }
  }

  static bool _timingSafeEquals(List<int> a, List<int> b) {
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
