import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosm_passport_flutter/src/forma_controls.dart';
import 'package:rosm_passport_flutter/src/rosm_passport_theme.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';

void main() {
  testWidgets(
    'autofill and IME adapter preserves selection, composing and controller text',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => RosmEpassTheme(
              data: buildRosmPassportTheme(
                context,
                RosmPassportThemeMode.light,
              ),
              child: Scaffold(
                body: RosmEpassInput(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: '邮箱'),
                ),
              ),
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, [AutofillHints.email]);
      expect(field.textInputAction, TextInputAction.next);
      await tester.tap(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'willow@example.com',
          selection: TextSelection.collapsed(offset: 6),
          composing: TextRange(start: 0, end: 6),
        ),
      );
      await tester.pump();
      expect(controller.text, 'willow@example.com');
      expect(controller.selection.baseOffset, 6);
      expect(controller.value.composing, const TextRange(start: 0, end: 6));
    },
  );
  testWidgets(
    'capitalized lockup stays centred on the mother logo at 200% text scale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(body: Center(child: RosmEpassBrand())),
          ),
        ),
      );
      expect(find.text('Rosemary'), findsOneWidget);
      expect(find.text('Epass'), findsOneWidget);
      final logo = tester.getCenter(find.byType(Image));
      final words = find.ancestor(
        of: find.text('Rosemary'),
        matching: find.byType(Column),
      );
      expect(tester.getCenter(words).dy, closeTo(logo.dy, .5));
      expect(tester.takeException(), isNull);
    },
  );
}
