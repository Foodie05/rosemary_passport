import 'package:rosm_passport_server/src/security/password_policy.dart';
import 'package:test/test.dart';

void main() {
  final policy = PasswordPolicy();

  test('accepts a long passphrase without requiring character classes', () {
    expect(policy.validate('correct horse battery staple').ok, isTrue);
  });

  test('rejects short, repeated, common, and overlong passwords', () {
    expect(policy.validate('short').ok, isFalse);
    expect(policy.validate('111111111111').ok, isFalse);
    expect(policy.validate('abcabcabcabc').ok, isFalse);
    expect(policy.validate('password1234').ok, isFalse);
    expect(policy.validate('Password!2026').ok, isFalse);
    expect(policy.validate('P@ssw0rd-2026').ok, isFalse);
    expect(policy.validate('1q2w3e4r5t6y').ok, isFalse);
    expect(policy.validate('x' * 129).ok, isFalse);
  });

  test('does not reject a passphrase merely for containing a common word', () {
    expect(policy.validate('my welcome phrase is private').ok, isTrue);
    expect(policy.validate('correct-horse-2026-battery').ok, isTrue);
  });
}
