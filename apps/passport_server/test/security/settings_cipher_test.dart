import 'dart:io';

import 'package:rosm_passport_server/src/config/app_config.dart';
import 'package:rosm_passport_server/src/security/settings_cipher.dart';
import 'package:test/test.dart';

void main() {
  test(
    'encrypts sensitive fields and decrypts the versioned envelope',
    () async {
      final cipher = SettingsCipher(
        AppConfig.forTesting({
          'DATA_ENCRYPTION_ACTIVE_KID': 'test-v1',
          'DATA_ENCRYPTION_KEY':
              'test-key-material-with-more-than-32-characters',
          'JWT_BINDING_KEY': 'fallback-key-material-with-more-than-32-chars',
        }),
      );
      final encrypted = await cipher.encryptSensitiveFields({
        'host': 'smtp.example.com',
        'password': 'super-secret-password',
      });
      expect(encrypted['password'], isA<Map>());
      expect(encrypted.toString(), isNot(contains('super-secret-password')));

      final decrypted = await cipher.decryptEnvelopes(encrypted);
      expect(decrypted['password'], 'super-secret-password');
      expect(decrypted['host'], 'smtp.example.com');
    },
  );

  test('detects legacy plaintext sensitive fields', () {
    final cipher = SettingsCipher(
      AppConfig.forTesting({
        'DATA_ENCRYPTION_KEY': 'test-key-material-with-more-than-32-characters',
        'JWT_BINDING_KEY': 'fallback-key-material-with-more-than-32-chars',
      }),
    );
    expect(
      cipher.containsPlaintextSensitiveField({'password': 'legacy'}),
      isTrue,
    );
    expect(
      cipher.containsPlaintextSensitiveField({'host': 'localhost'}),
      isFalse,
    );
  });

  test('decrypts an envelope after overlapping data-key rotation', () async {
    final directory = await Directory.systemTemp.createTemp('rosm-data-keys-');
    try {
      File('${directory.path}/old.key').writeAsStringSync(
        'old-key-material-with-more-than-thirty-two-characters',
      );
      File('${directory.path}/new.key').writeAsStringSync(
        'new-key-material-with-more-than-thirty-two-characters',
      );
      SettingsCipher cipher(String activeKid) => SettingsCipher(
        AppConfig.forTesting({
          'DATA_ENCRYPTION_ACTIVE_KID': activeKid,
          'DATA_ENCRYPTION_KEYS_DIR': directory.path,
        }),
      );
      final envelope = await cipher(
        'old',
      ).encryptSensitiveFields({'password': 'historical-secret'});
      final decrypted = await cipher('new').decryptEnvelopes(envelope);
      expect(decrypted['password'], 'historical-secret');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
