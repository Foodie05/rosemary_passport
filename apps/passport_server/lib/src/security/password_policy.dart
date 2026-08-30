class PasswordPolicyResult {
  const PasswordPolicyResult._(this.ok, this.message);

  const PasswordPolicyResult.valid() : this._(true, null);
  const PasswordPolicyResult.invalid(String message) : this._(false, message);

  final bool ok;
  final String? message;
}

class PasswordPolicy {
  static const minLength = 12;
  static const maxLength = 128;
  static const _blockedExact = {
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
  // This deliberately does not impose composition rules on genuine passphrases.
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
      return const PasswordPolicyResult.invalid('密码长度必须为 12–128 个字符。');
    }
    final lowercase = password.toLowerCase();
    final alphanumeric = lowercase
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll(RegExp('[^a-z0-9]'), '');
    if (_blockedExact.contains(lowercase) ||
        _commonBaseWithDecoration.hasMatch(alphanumeric) ||
        _repeatedShortBlock.hasMatch(lowercase)) {
      return const PasswordPolicyResult.invalid('该密码过于常见，请使用更难猜测的密码。');
    }
    return const PasswordPolicyResult.valid();
  }
}
