import 'dart:convert';
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

  test('encrypts standalone strings and rejects malformed envelopes', () async {
    final cipher = SettingsCipher(
      AppConfig.forTesting({
        'DATA_ENCRYPTION_ACTIVE_KID': 'test-v1',
        'DATA_ENCRYPTION_KEY': base64Encode(List<int>.generate(32, (i) => i)),
      }),
    );
    final encrypted = await cipher.encryptString('standalone-secret');
    expect(encrypted, startsWith('a256gcm:'));
    expect(await cipher.decryptString(encrypted), 'standalone-secret');
    await expectLater(
      cipher.decryptString('plaintext'),
      throwsA(isA<FormatException>()),
    );
    final invalidShape = base64UrlEncode(utf8.encode(jsonEncode(['invalid'])));
    await expectLater(
      cipher.decryptString('a256gcm:$invalidShape'),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'preserves empty values and rejects unknown or tampered envelopes',
    () async {
      final cipher = SettingsCipher(
        AppConfig.forTesting({
          'DATA_ENCRYPTION_ACTIVE_KID': 'test-v1',
          'DATA_ENCRYPTION_KEY':
              'test-key-material-with-more-than-32-characters',
        }),
      );
      final encrypted = await cipher.encryptSensitiveFields({
        'password': '',
        'phone_sms_access_key_secret': 'sms-secret',
        'count': 3,
      });
      expect(encrypted['password'], '');
      expect(encrypted['count'], 3);
      final envelope = Map<String, dynamic>.from(
        encrypted['phone_sms_access_key_secret'] as Map,
      );
      final inner = Map<String, dynamic>.from(envelope['_enc'] as Map);

      final unsupported = Map<String, dynamic>.from(inner)..['v'] = 2;
      await expectLater(
        cipher.decryptEnvelopes({
          'password': {'_enc': unsupported},
        }),
        throwsA(isA<FormatException>()),
      );

      final unknownKey = Map<String, dynamic>.from(inner)..['kid'] = 'missing';
      await expectLater(
        cipher.decryptEnvelopes({
          'password': {'_enc': unknownKey},
        }),
        throwsA(isA<StateError>()),
      );

      final tampered = Map<String, dynamic>.from(inner)
        ..['ciphertext'] = base64UrlEncode(utf8.encode('tampered'));
      await expectLater(
        cipher.decryptEnvelopes({
          'password': {'_enc': tampered},
        }),
        throwsA(anything),
      );
    },
  );
}
