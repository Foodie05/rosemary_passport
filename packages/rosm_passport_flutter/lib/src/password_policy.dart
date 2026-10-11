import 'models.dart';

/// Local feedback for new passwords only. The server remains authoritative.
class RosmPasswordPolicy {
  const RosmPasswordPolicy();
  static const minLength = 8;
  static const maxLength = 128;
  static const _blocked = {
    '1234567',
    '12345678',
    '123456789',
    '1234567890',
    'abcd1234',
    'abc12345',
    'qazwsx12',
    'asdf1234',
    '123456789012',
    '123456789123',
    '123456789abc',
    '1234567890ab',
    '012345678901',
    '987654321098',
    'abcdefghijkl',
    'abcdefgh1234',
    'abcd1234abcd',
    'password1234',
    'password123!',
    'password12345',
    'password@123',
    'passw0rd1234',
    'p@ssword1234',
    'p@ssw0rd1234',
    'qwertyuiop12',
    'qwerty123456',
    'qwertyuiop123',
    'qwerty123456789',
    'asdfghjkl123',
    'zxcvbnm12345',
    'admin1234567',
    'administrator',
    'letmein123456',
    'welcome12345',
    'iloveyou1234',
    'changeme1234',
    'monkey123456',
    'dragon123456',
    'football1234',
    'baseball12345',
    'sunshine1234',
    'princess1234',
    'trustno112345',
    'superman1234',
    'computer1234',
    'internet1234',
    'master123456',
    'login1234567',
    'secret123456',
    'welcome@123',
    'qazwsx123456',
    '1q2w3e4r5t6y',
    '1qaz2wsx3edc',
    '111111111111',
  };
  static final _common = RegExp(
    r'^(?:password|passw0rd|p(?:a|4)ssw(?:o|0)rd|qwerty|admin|administrator|letmein|welcome|iloveyou|changeme|monkey|dragon|football|baseball|sunshine|princess|trustno1|superman|computer|internet|master|login|secret)\d*$',
  );

  RosmPasswordValidation evaluate(String password) {
    final length = password.runes.length;
    final lengthValid = length >= minLength && length <= maxLength;
    final formatValid =
        RegExp(r'^[\x20-\x7e]*$').hasMatch(password) &&
        password == password.trim();
    final compositionValid =
        [
          RegExp(r'[a-zA-Z]'),
          RegExp(r'[0-9]'),
          RegExp(r'[!-/:-@\[-`{-~]'),
        ].where((pattern) => pattern.hasMatch(password)).length >=
        2;
    final lower = password.toLowerCase();
    final normalized = lower
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll(RegExp('[^a-z0-9]'), '');
    final uncommon =
        !_blocked.contains(lower) &&
        !_blocked.contains(normalized) &&
        !_common.hasMatch(normalized) &&
        !RegExp(r'^(.{1,4})\1{2,}$').hasMatch(lower);
    final message = !lengthValid
        ? (length < minLength
              ? '不少于 8 个字符，还需 ${minLength - length} 个。'
              : '最多 128 个字符，请缩短密码。')
        : !formatValid
        ? '请使用英文字母、数字或符号，首尾不能有空格。'
        : !compositionValid
        ? '字母、数字、符号中至少包含两种。'
        : !uncommon
        ? '这个密码很容易被猜到，请避开常见词、连续字符或重复模式。'
        : null;
    return RosmPasswordValidation(
      length: length,
      lengthValid: lengthValid,
      formatValid: formatValid,
      compositionValid: compositionValid,
      uncommon: uncommon,
      message: message,
    );
  }

  void requireValid(String password) {
    final result = evaluate(password);
    if (!result.ok)
      throw RosmApiException('password_policy_violation', result.message!);
  }

  bool containsPersonalInfo(String password, Iterable<String> personalInfo) {
    final lower = password.toLowerCase();
    return personalInfo.any((value) {
      final candidate = value.trim().toLowerCase().split('@').first;
      return candidate.length >= 3 && lower.contains(candidate);
    });
  }
}

/// Contains only checks and feedback; never stores the evaluated password.
class RosmPasswordValidation {
  const RosmPasswordValidation({
    required this.length,
    required this.lengthValid,
    required this.formatValid,
    required this.compositionValid,
    required this.uncommon,
    this.message,
  });
  final int length;
  final bool lengthValid, formatValid, compositionValid, uncommon;
  final String? message;
  bool get ok => lengthValid && formatValid && compositionValid && uncommon;
}
