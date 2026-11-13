import 'package:rosm_passport_flutter/src/forma_field_outline.dart';
import 'package:rosm_passport_flutter/src/epass_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';
import 'package:rosm_passport_flutter/src/epass_motion.dart';
import 'package:rosm_passport_flutter/src/rosm_passport_theme.dart';

void main() {
  testWidgets(
    'creation requirements arm on blur, update live, reset on clearing and preserve autofill',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_field(controller));
      expect(find.text('8–32 个字符'), findsOneWidget);
      controller.text = 'orchid';
      await tester.pump();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isFalse,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isTrue,
      );
      expect(
        tester
            .widget<RosemaryFieldRequirements>(
              find.byType(RosemaryFieldRequirements),
            )
            .active,
        isTrue,
      );
      controller.text = 'orchid-willow';
      await tester.pump();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isFalse,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).autofillHints, [
        AutofillHints.newPassword,
      ]);
      await tester.tap(find.bySemanticsLabel('显示密码'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      controller.clear();
      await tester.pump();
      expect(
        tester
            .widget<RosemaryFieldRequirements>(
              find.byType(RosemaryFieldRequirements),
            )
            .active,
        isFalse,
      );
      controller.text = 'short';
      await tester.pump();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isFalse,
      );
    },
  );
  testWidgets(
    'composition defers failure and retains the controller editing range',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_field(controller));
      await tester.tap(find.byType(TextField));
      controller.text = 'orchid';
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isTrue,
      );
      controller.value = const TextEditingValue(
        text: '中文组合',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 4),
      );
      await tester.pump();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isFalse,
      );
      expect(controller.selection.baseOffset, 2);
      expect(controller.value.composing, const TextRange(start: 0, end: 4));
      controller.value = controller.value.copyWith(composing: TextRange.empty);
      await tester.pump();
      expect(
        tester.widget<RosmFieldOutline>(find.byType(RosmFieldOutline)).invalid,
        isTrue,
      );
    },
  );
  testWidgets(
    '320px and 200% text scale retain adjacent requirements without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: 'orchid-willow');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_field(controller, scale: 2));
      await tester.pump();
      expect(find.text('8–32 个字符'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'both modes consume all 45 generated roles and pass official contrast checks',
    (tester) async {
      for (final dark in [false, true]) {
        late ThemeData theme;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                theme = buildRosmPassportTheme(
                  context,
                  dark
                      ? RosmPassportThemeMode.dark
                      : RosmPassportThemeMode.light,
                );
                return Theme(data: theme, child: const SizedBox());
              },
            ),
          ),
        );
        final expected = dark
            ? RosmEpassDarkTokens.colors
            : RosmEpassLightTokens.colors;
        expect(
          theme.extension<RosemaryThemeData>()!.colors.toMap(),
          expected.toMap(),
        );
        expect(expected.toMap(), hasLength(45));
        expect(
          rosemaryValidateTheme(expected).where((d) => !d.passes),
          isEmpty,
        );
        expect(theme.scaffoldBackgroundColor, expected.canvas);
        expect(theme.colorScheme.primary, expected.primary);
      }
    },
  );
  testWidgets(
    'selection retains a single live form, reverses continuously and stops on reduced motion',
    (tester) async {
      var value = 0;
      var reduced = false;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduced),
                child: RosmEpassSelectionContent(
                  value: value,
                  order: value,
                  child: Text('form $value'),
                ),
              );
            },
          ),
        ),
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      change(() => value = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final mid = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(mid, inExclusiveRange(0, 1));
      change(() => value = 0);
      await tester.pump();
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(mid, .001),
      );
      expect(find.text('form 1'), findsNothing);
      expect(find.text('form 0'), findsOneWidget);
      change(() => reduced = true);
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      change(() => value = 1);
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await tester.pumpAndSettle();
    },
  );
}

Widget _field(TextEditingController controller, {double scale = 1}) =>
    MaterialApp(
      home: Builder(
        builder: (context) => Theme(
          data: buildRosmPassportTheme(context, RosmPassportThemeMode.light),
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RosmNewPasswordField(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
