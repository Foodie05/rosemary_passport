import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

void main() {
  test('first nonempty blur and clear reset, IME deferred', () {
    final s = RosemaryFieldValidationState();
    s.blur('abc');
    expect(s.armed, false);
    s.focus();
    s.edit('abc');
    expect(s.armed, false);
    s.blur('abc', composing: true);
    expect(s.armed, false);
    s.focus();
    s.blur('abc');
    expect(s.armed, true);
    s.edit('');
    expect(s.armed, false);
    s.edit('abc12345');
    expect(s.armed, false);
    expect(
      RosemaryFieldRequirement.password().every((r) => r.check('abcdefg!')),
      true,
    );
  });
  testWidgets(
    'requirements are neutral until blur and verification stays below input',
    (tester) async {
      String value = '';
      await tester.pumpWidget(
        MaterialApp(
          home: RosemaryTheme(
            reduceMotion: true,
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, set) => Column(
                  children: [
                    RosemaryInput(
                      label: 'Create password',
                      value: value,
                      onChanged: (v) => set(() => value = v),
                      password: true,
                      requirements: RosemaryFieldRequirement.password(),
                      verification: const Text('Verify this field'),
                    ),
                    RosemaryButton(
                      label: 'Next',
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final field = find.byType(EditableText);
      expect(find.byType(RosemaryIcon), findsNothing);
      await tester.tap(field);
      await tester.enterText(field, 'abc');
      await tester.pump();
      expect(find.byType(RosemaryIcon), findsNothing);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is RosemaryIcon && w.name == 'close'),
        findsNWidgets(2),
      );
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(find.byType(RosemaryIcon), findsNothing);
      final inputBox = tester.getRect(field),
          verification = tester.getRect(find.text('Verify this field'));
      expect(verification.top, greaterThan(inputBox.bottom));
    },
  );

  testWidgets(
    'joined select can reopen during exit without duplicating the popup',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RosemaryTheme(
            child: Scaffold(
              body: RosemarySelect(
                value: 'a',
                label: 'Section',
                onChanged: (_) {},
                options: const [
                  RosemaryOption('a', 'Alpha'),
                  RosemaryOption('b', 'Beta'),
                ],
              ),
            ),
          ),
        ),
      );
      final head = find.descendant(
        of: find.byType(RosemarySelect),
        matching: find.text('Alpha'),
      );
      await tester.tap(head);
      await tester.pumpAndSettle();
      final trigger = find.descendant(
        of: find.byType(RosemarySelect),
        matching: find.byType(RosemaryActionSurface),
      );
      expect(
        tester.widget<RosemaryActionSurface>(trigger).physicalPress,
        false,
      );
      expect(
        tester.widget<RosemaryActionSurface>(trigger).corners!.bottomLeft,
        Radius.zero,
      );
      await tester.tap(head);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(head);
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsOneWidget);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(find.text('Beta'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard hints preserve multiline editing and secure password entry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RosemaryTheme(
            child: Scaffold(
              body: Column(
                children: [
                  RosemaryTextarea(
                    label: 'Notes',
                    value: '',
                    onChanged: (_) {},
                  ),
                  RosemaryInput(
                    label: 'Password',
                    value: '',
                    onChanged: (_) {},
                    password: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final editors = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .toList();
      expect(editors[0].keyboardType, TextInputType.multiline);
      expect(editors[1].keyboardType, TextInputType.visiblePassword);
    },
  );
}
