import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/security/password_hasher.dart';
import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:test/test.dart';

void main() {
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
