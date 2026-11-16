import 'package:flutter_test/flutter_test.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
  test(
    'combined login preserves email and normalizes supported mobile formats',
    () {
      final email = RosmCodeLoginIdentifier.tryParse(
        '  example+login@example.com  ',
      )!;
      expect(email.method, RosmSignInMethod.emailCode);
      expect(email.identifier, 'example+login@example.com');
      for (final raw in [
        '13800138000',
        '+86 138-0013-8000',
        '86(138)00138000',
      ]) {
        final phone = RosmCodeLoginIdentifier.tryParse(raw)!;
        expect(phone.method, RosmSignInMethod.phoneCode);
        expect(phone.identifier, '13800138000');
      }
      for (final raw in [
        '',
        'name@',
        'a b@example.com',
        '+1 13800138000',
        '1380013800',
        '13800138000junk',
      ]) {
        expect(RosmCodeLoginIdentifier.tryParse(raw), isNull, reason: raw);
      }
    },
  );
}
