import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const _chars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

String randomUrlSafeString([int length = 64]) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => _chars[random.nextInt(_chars.length)],
  ).join();
}

String s256Challenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier)).bytes;
  return base64Url.encode(digest).replaceAll('=', '');
}
