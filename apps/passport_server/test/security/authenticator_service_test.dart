import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:rosm_passport_server/src/services/authenticator_service.dart';
import 'package:test/test.dart';

void main() {
  test('generates base32 secrets and escaped OTP Auth URIs', () {
    final service = AuthenticatorService(issuer: 'ROSM Pass & Identity');
    final secret = service.generateSecret();
    expect(secret, hasLength(32));
    expect(secret, matches(RegExp(r'^[A-Z2-7]+$')));

    final uri = Uri.parse(
      service.buildOtpAuthUri(
        email: 'user+security@example.invalid',
        secret: secret,
      ),
    );
    expect(uri.scheme, 'otpauth');
    expect(uri.host, 'totp');
    expect(uri.queryParameters['secret'], secret);
    expect(uri.queryParameters['issuer'], 'ROSM Pass & Identity');
  });

  test('validates current TOTP with timing-safe comparison', () {
    const secret = 'JBSWY3DPEHPK3PXP';
    final service = AuthenticatorService();
    final counter = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
    final currentCode = _totp(_base32Decode(secret), counter);

    expect(
      service.verifyCode(secret: secret, code: currentCode, window: 1),
      isTrue,
    );
    expect(service.verifyCode(secret: secret, code: 'not-code'), isFalse);
    expect(
      service.verifyCode(secret: secret, code: '000000', window: 0),
      isFalse,
    );
    expect(
      service.verifyCode(secret: 'JBSW====!!!!', code: '000000', window: 0),
      isFalse,
    );
  });
}

Uint8List _base32Decode(String input) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var current = 0;
  var bits = 0;
  final output = <int>[];
  for (final rune in input.runes) {
    final index = alphabet.indexOf(String.fromCharCode(rune));
    if (index < 0) continue;
    current = (current << 5) | index;
    bits += 5;
    if (bits >= 8) {
      output.add((current >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return Uint8List.fromList(output);
}

String _totp(Uint8List secret, int counter) {
  final counterBytes = ByteData(8)..setInt64(0, counter);
  final bytes = Hmac(
    sha1,
    secret,
  ).convert(counterBytes.buffer.asUint8List()).bytes;
  final offset = bytes.last & 0x0f;
  final binary =
      ((bytes[offset] & 0x7f) << 24) |
      ((bytes[offset + 1] & 0xff) << 16) |
      ((bytes[offset + 2] & 0xff) << 8) |
      (bytes[offset + 3] & 0xff);
  return (binary % 1000000).toString().padLeft(6, '0');
}
