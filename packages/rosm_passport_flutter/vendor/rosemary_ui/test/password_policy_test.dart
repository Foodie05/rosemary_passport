import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

void main() {
  test('unified password acceptance and all ASCII boundaries', () {
    for (final value in ['abc12345', 'abcdefg!', '1234567!', '${'A' * 31}1']) {
      expect(RosemaryPasswordPolicy.check(value).valid, isTrue);
    }
    for (final value in ['', 'AbCdEfGh', '12345678', '!!!!!!!!', 'Abc12345中', 'Abc12345😀', 'Abc12345 ', '${'A' * 32}1']) {
      expect(RosemaryPasswordPolicy.check(value).valid, isFalse);
    }
    for (var n = 0; n <= 127; n++) {
      expect(RosemaryPasswordPolicy.check('Ab12345${String.fromCharCode(n)}').valid, n >= 33 && n <= 126);
    }
  });
}
