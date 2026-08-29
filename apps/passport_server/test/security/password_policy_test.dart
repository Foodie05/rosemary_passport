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
    expect(policy.validate('password1234').ok, isFalse);
    expect(policy.validate('x' * 129).ok, isFalse);
  });
}
