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
  static const _blocked = {
    '123456789012',
    'password1234',
    'password123!',
    'qwertyuiop12',
    'qwerty123456',
    'admin1234567',
    'letmein123456',
    'welcome12345',
    'iloveyou1234',
    '111111111111',
  };

  PasswordPolicyResult validate(String password) {
    final length = password.runes.length;
    if (length < minLength || length > maxLength) {
      return const PasswordPolicyResult.invalid('密码长度必须为 12–128 个字符。');
    }
    if (_blocked.contains(password.toLowerCase()) ||
        RegExp(r'^(.)\1{11,}$').hasMatch(password)) {
      return const PasswordPolicyResult.invalid('该密码过于常见，请使用更难猜测的密码。');
    }
    return const PasswordPolicyResult.valid();
  }
}
