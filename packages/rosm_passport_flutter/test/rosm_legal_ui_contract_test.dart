import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('built-in sign-in keeps version-bound legal acceptance visible', () {
    final source = File('lib/src/rosemary_sign_in.dart').readAsStringSync();

    expect(source, contains('widget.client.currentLegalDocuments()'));
    expect(source, contains('_buildLegalAcceptance(colors)'));
    expect(source, contains('_requireLegalAcceptance()'));
    expect(source, contains('documents.acceptance'));
    expect(source, contains('使用条款与隐私政策同意'));
    expect(source, isNot(contains('CheckboxListTile')));
    expect(source, isNot(contains('AlertDialog')));
  });

  test('custom UI documentation submits current legal versions', () {
    final readme = File('README.md').readAsStringSync();

    expect(readme, contains('currentLegalDocuments()'));
    expect(readme, contains('legalAcceptance: legalDocuments.acceptance'));
    expect(readme, contains('ref: v0.8.1'));
  });
}
