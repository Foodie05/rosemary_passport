import 'token_store.dart';

/// Routes a combined code-login field without checking account existence.
class RosmCodeLoginIdentifier {
  const RosmCodeLoginIdentifier(this.method, this.identifier);
  final RosmSignInMethod method;
  final String identifier;
  bool get isEmail => method == RosmSignInMethod.emailCode;

  static RosmCodeLoginIdentifier? tryParse(String raw) {
    final value = raw.trim();
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return RosmCodeLoginIdentifier(RosmSignInMethod.emailCode, value);
    }
    var phone = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.startsWith('+86')) {
      phone = phone.substring(3);
    } else if (phone.startsWith('86') && phone.length == 13) {
      phone = phone.substring(2);
    }
    return RegExp(r'^1\d{10}$').hasMatch(phone)
        ? RosmCodeLoginIdentifier(RosmSignInMethod.phoneCode, phone)
        : null;
  }
}
