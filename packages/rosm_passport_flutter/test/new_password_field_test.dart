import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';
import 'package:rosm_passport_flutter/src/epass_motion.dart';
import 'package:rosm_passport_flutter/src/rosm_passport_theme.dart';

void main() {
  testWidgets(
    'autofill changes immediately update local feedback and visibility',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_field(controller));
      expect(find.text('不少于 8 个字符'), findsOneWidget);
      expect(find.textContaining('128'), findsNothing);
      controller.text = 'orchid';
      await tester.pump();
      expect(find.text('不少于 8 个字符，还需 2 个。'), findsOneWidget);
      controller.text = 'aBcDeFgH';
      await tester.pump();
      expect(find.text('字母、数字、符号中至少包含两种。'), findsOneWidget);
      controller.text = 'orchid-willow';
      await tester.pump();
      expect(find.text('已满足密码要求。'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('显示密码'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
      controller.text = 'x' * 129;
      await tester.pump();
      expect(find.text('最多 128 个字符，请缩短密码。'), findsOneWidget);
      controller.text = 'Password!2026';
      await tester.pump();
      expect(find.textContaining('很容易被猜到'), findsOneWidget);
    },
  );
  testWidgets(
    '320px, 200% text scale preserves all guidance without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(text: 'orchid-willow');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_field(controller, scale: 2));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('已满足密码要求。'), findsOneWidget);
    },
  );
  testWidgets(
    'theme consumes official extension and exact light/dark semantic colors',
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
        expect(theme.extension<RosemaryThemeData>(), isNotNull);
        expect(
          theme.scaffoldBackgroundColor,
          Color(dark ? 0xff141c18 : 0xfff6f5ef),
        );
        expect(
          theme.colorScheme.primary,
          Color(dark ? 0xffb8cbb5 : 0xff315747),
        );
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
