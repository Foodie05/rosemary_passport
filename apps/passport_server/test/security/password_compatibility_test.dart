import 'dart:async';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:test/test.dart';

void main() {
  test(
    'password work leaves the event loop responsive and bounds its queue',
    () async {
      final hasher = PasswordHasher(
        AppConfig.forTesting({
          'ARGON2_MEMORY_KB': '8192',
          'ARGON2_ITERATIONS': '2',
          'ARGON2_PARALLELISM': '1',
        }),
      );
      final tick = Completer<void>();
      Timer.run(tick.complete);
      var completed = 0;
      final jobs = List.generate(
        18,
        (_) => hasher.hash('concurrent test passphrase').then((hash) {
          completed++;
          return hash;
        }),
      );
      await expectLater(
        hasher.hash('excess request'),
        throwsA(isA<PasswordWorkUnavailable>()),
      );
      await tick.future;
      expect(
        completed,
        0,
        reason: 'Argon2 must not monopolize the HTTP event loop',
      );
      final hashes = await Future.wait(jobs);
      expect(hashes.toSet(), hasLength(18));
      expect(
        await hasher.verify(hashes.first, 'concurrent test passphrase'),
        isTrue,
      );
      expect(await hasher.verify(hashes.first, 'wrong'), isFalse);
    },
  );
  test(
    'legacy weak hashes remain verifiable but cannot be newly selected',
    () async {
      final hasher = PasswordHasher(
        AppConfig.forTesting({
          'ARGON2_MEMORY_KB': '8192',
          'ARGON2_ITERATIONS': '1',
          'ARGON2_PARALLELISM': '1',
        }),
      );
      const legacyPassword = 'old';
      final hash = await hasher.hash(legacyPassword);
      expect(await hasher.verify(hash, legacyPassword), isTrue);
      expect(PasswordPolicy().validate(legacyPassword).ok, isFalse);
    },
  );
}
