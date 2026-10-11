class PasswordPolicyResult {
  const PasswordPolicyResult._(this.ok, this.message);

  const PasswordPolicyResult.valid() : this._(true, null);
  const PasswordPolicyResult.invalid(String message) : this._(false, message);

  final bool ok;
  final String? message;
}

class PasswordPolicy {
  static const minLength = 8;
  static const maxLength = 128;
  static const _blockedExact = {
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

  // Match only high-confidence leaked-password shapes. Common substitutions
  // are normalized and other symbols removed, so cosmetic changes such as
  // `P@ssw0rd-123` do not bypass the policy.
  // Cosmetic substitutions do not make a common password safe.
  static final _commonBaseWithDecoration = RegExp(
    r'^(?:password|passw0rd|p(?:a|4)ssw(?:o|0)rd|qwerty|admin|administrator|'
    r'letmein|welcome|iloveyou|changeme|monkey|dragon|football|baseball|'
    r'sunshine|princess|trustno1|superman|computer|internet|master|login|'
    r'secret)\d*$',
  );

  static final _repeatedShortBlock = RegExp(r'^(.{1,4})\1{2,}$');

  PasswordPolicyResult validate(String password) {
    final length = password.runes.length;
    if (length < minLength || length > maxLength) {
      return const PasswordPolicyResult.invalid('密码不得少于 8 个字符或超过 128 个字符。');
    }
    // Google account character guidance: printable ASCII, no edge spaces.
    // This applies only when setting a password; existing logins are unchanged.
    if (!RegExp(r'^[\x20-\x7e]+$').hasMatch(password) ||
        password != password.trim()) {
      return const PasswordPolicyResult.invalid('请使用英文字母、数字或符号，首尾不能有空格。');
    }
    final categories = [
      RegExp(r'[a-zA-Z]').hasMatch(password),
      RegExp(r'[0-9]').hasMatch(password),
      RegExp(r'[!-/:-@\[-`{-~]').hasMatch(password),
    ].where((present) => present).length;
    if (categories < 2) {
      return const PasswordPolicyResult.invalid('字母、数字、符号中至少包含两种。');
    }
    final lowercase = password.toLowerCase();
    final alphanumeric = lowercase
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll(RegExp('[^a-z0-9]'), '');
    if (_blockedExact.contains(lowercase) ||
        _blockedExact.contains(alphanumeric) ||
        _commonBaseWithDecoration.hasMatch(alphanumeric) ||
        _repeatedShortBlock.hasMatch(lowercase)) {
      return const PasswordPolicyResult.invalid('该密码过于常见，请使用更难猜测的密码。');
    }
    return const PasswordPolicyResult.valid();
  }
}
