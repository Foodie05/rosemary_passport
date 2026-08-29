import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../config/app_config.dart';

class SettingsCipher {
  SettingsCipher(AppConfig config)
    : _activeKid = config.dataEncryptionActiveKid,
      _keys = config.dataEncryptionKeys.map(
        (kid, material) => MapEntry(kid, SecretKey(_normalizeKey(material))),
      );

  static const _sensitiveFields = {
    'password',
    'aliyun_captcha_access_key_id',
    'aliyun_captcha_access_key_secret',
    'phone_sms_access_key_id',
    'phone_sms_access_key_secret',
  };

  final String _activeKid;
  final Map<String, SecretKey> _keys;
  final _algorithm = AesGcm.with256bits();

  Future<String> encryptString(String plaintext) async {
    final wrapped = await _encrypt(plaintext);
    return 'a256gcm:${base64UrlEncode(utf8.encode(jsonEncode(wrapped['_enc'])))}';
  }

  Future<String> decryptString(String value) async {
    if (!value.startsWith('a256gcm:')) {
      throw const FormatException('Unsupported encrypted string envelope.');
    }
    final encoded = value.substring('a256gcm:'.length);
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
    );
    if (decoded is! Map) {
      throw const FormatException('Invalid encrypted string envelope.');
    }
    return _decrypt(Map<String, dynamic>.from(decoded));
  }

  Future<Map<String, dynamic>> encryptSensitiveFields(
    Map<String, dynamic> value,
  ) async {
    final encrypted = <String, dynamic>{};
    for (final entry in value.entries) {
      final item = entry.value;
      if (_sensitiveFields.contains(entry.key) &&
          item is String &&
          item.isNotEmpty) {
        encrypted[entry.key] = await _encrypt(item);
      } else {
        encrypted[entry.key] = item;
      }
    }
    return encrypted;
  }

  Future<Map<String, dynamic>> decryptEnvelopes(
    Map<String, dynamic> value,
  ) async {
    final decrypted = <String, dynamic>{};
    for (final entry in value.entries) {
      final item = entry.value;
      if (item is Map && item['_enc'] is Map) {
        decrypted[entry.key] = await _decrypt(
          Map<String, dynamic>.from(item['_enc'] as Map),
        );
      } else {
        decrypted[entry.key] = item;
      }
    }
    return decrypted;
  }

  bool containsPlaintextSensitiveField(Map<String, dynamic> value) {
    return value.entries.any(
      (entry) =>
          _sensitiveFields.contains(entry.key) &&
          entry.value is String &&
          (entry.value as String).isNotEmpty,
    );
  }

  Future<Map<String, dynamic>> _encrypt(String plaintext) async {
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _keys[_activeKid]!,
      nonce: nonce,
    );
    return {
      '_enc': {
        'v': 1,
        'alg': 'A256GCM',
        'kid': _activeKid,
        'nonce': base64UrlEncode(box.nonce),
        'ciphertext': base64UrlEncode(box.cipherText),
        'mac': base64UrlEncode(box.mac.bytes),
      },
    };
  }

  Future<String> _decrypt(Map<String, dynamic> envelope) async {
    if (envelope['v'] != 1 || envelope['alg'] != 'A256GCM') {
      throw const FormatException('Unsupported settings encryption envelope.');
    }
    final kid = envelope['kid']?.toString() ?? '';
    final key = _keys[kid];
    if (key == null) {
      throw StateError('Settings encryption key is unavailable: $kid');
    }
    final box = SecretBox(
      base64Url.decode(base64Url.normalize(envelope['ciphertext'].toString())),
      nonce: base64Url.decode(
        base64Url.normalize(envelope['nonce'].toString()),
      ),
      mac: Mac(
        base64Url.decode(base64Url.normalize(envelope['mac'].toString())),
      ),
    );
    final cleartext = await _algorithm.decrypt(box, secretKey: key);
    return utf8.decode(cleartext);
  }

  static List<int> _normalizeKey(String material) {
    try {
      final decoded = base64.decode(base64.normalize(material));
      if (decoded.length == 32) {
        return decoded;
      }
    } catch (_) {
      // Legacy keys are deterministically derived without changing old config.
    }
    return sha256.convert(utf8.encode(material)).bytes;
  }
}
