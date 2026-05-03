import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class AuthenticatorService {
  AuthenticatorService({String issuer = 'ROSM Pass'}) : _issuer = issuer;

  final String _issuer;
  final _random = Random.secure();
  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  String generateSecret() {
    final bytes =
        Uint8List.fromList(List<int>.generate(20, (_) => _random.nextInt(256)));
    return _base32Encode(bytes);
  }

  String buildOtpAuthUri({
    required String email,
    required String secret,
  }) {
    final label = Uri.encodeComponent('$_issuer:$email');
    final issuer = Uri.encodeComponent(_issuer);
    return 'otpauth://totp/$label?secret=$secret&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
  }

  bool verifyCode({
    required String secret,
    required String code,
    int window = 2,
  }) {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      return false;
    }
    final secretBytes = _base32Decode(secret);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final timeStep = now ~/ 30;

    for (var offset = -window; offset <= window; offset++) {
      final candidate = _generateTotp(secretBytes, timeStep + offset);
      if (_timingSafeEquals(candidate, normalizedCode)) {
        return true;
      }
    }
    return false;
  }

  String _generateTotp(Uint8List secret, int counter) {
    final counterBytes = ByteData(8)..setInt64(0, counter);
    final digest = Hmac(sha1, secret).convert(counterBytes.buffer.asUint8List());
    final bytes = digest.bytes;
    final offset = bytes.last & 0x0f;
    final binary = ((bytes[offset] & 0x7f) << 24) |
        ((bytes[offset + 1] & 0xff) << 16) |
        ((bytes[offset + 2] & 0xff) << 8) |
        (bytes[offset + 3] & 0xff);
    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  String _base32Encode(Uint8List bytes) {
    final buffer = StringBuffer();
    var current = 0;
    var bits = 0;

    for (final byte in bytes) {
      current = (current << 8) | byte;
      bits += 8;

      while (bits >= 5) {
        buffer.write(_base32Alphabet[(current >> (bits - 5)) & 31]);
        bits -= 5;
      }
    }

    if (bits > 0) {
      buffer.write(_base32Alphabet[(current << (5 - bits)) & 31]);
    }

    return buffer.toString();
  }

  Uint8List _base32Decode(String input) {
    final normalized = input.toUpperCase().replaceAll('=', '');
    var current = 0;
    var bits = 0;
    final output = <int>[];

    for (final rune in normalized.runes) {
      final index = _base32Alphabet.indexOf(String.fromCharCode(rune));
      if (index < 0) {
        continue;
      }
      current = (current << 5) | index;
      bits += 5;
      if (bits >= 8) {
        output.add((current >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }

    return Uint8List.fromList(output);
  }

  bool _timingSafeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }
    var diff = 0;
    for (var index = 0; index < left.length; index++) {
      diff |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return diff == 0;
  }
}
