import 'visual_support.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'package:rosm_passport_flutter/rosm_passport_flutter.dart';
import 'package:rosm_passport_flutter/src/agreement.dart';
import 'package:rosm_passport_flutter/src/forma_controls.dart';
import 'package:rosm_passport_flutter/src/rosm_passport_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadVisualFonts);
  testWidgets(
    'agreement text and independent keyboard links share a baseline',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var changes = 0, terms = 0, privacy = 0;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(20),
              child: RosmEpassAgreement(
                checked: false,
                enabled: true,
                onChanged: (_) => changes++,
                onTerms: () => terms++,
                onPrivacy: () => privacy++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      double baseline(String text) {
        final box = tester.renderObject<RenderBox>(find.text(text));
        return box
            .localToGlobal(
              Offset(
                0,
                box.getDryBaseline(
                  BoxConstraints.tight(box.size),
                  TextBaseline.alphabetic,
                )!,
              ),
            )
            .dy;
      }

      final start = baseline('我已阅读并同意');
      for (final text in ['《使用条款》', '《隐私政策》']) {
        final delta = (baseline(text) - start).abs();
        expect((delta / 24) - (delta / 24).round(), closeTo(0, .02));
      }
      expect(baseline('《使用条款》'), closeTo(baseline('《隐私政策》'), .5));
      expect(find.textContaining('版本'), findsNothing);
      await tester.tap(find.text('我已阅读并同意'));
      expect(changes, 1);
      await tester.tap(find.text('《使用条款》'));
      expect(terms, 1);
      expect(changes, 1);
      Focus.of(tester.element(find.text('《隐私政策》'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(privacy, 1);
      expect(changes, 1);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'sdk-agreement');
    },
  );

  for (final keyboard in [0.0, 300.0]) {
    testWidgets(
      'dialog retains gutters, scrolling and focus with keyboard=$keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding();
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) => TextButton(
                focusNode: focus,
                child: const Text('打开示例弹窗'),
                onPressed: () => showRosmEpassDialog<void>(
                  context: context,
                  theme: Theme.of(context),
                  title: '协议确认与密码重置示例',
                  builder: (context, close) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TextField(
                        decoration: InputDecoration(labelText: '示例输入'),
                      ),
                      Text(
                        List.filled(50, '这是一段用于检查长内容和滚动边界的示例文字。').join('\n'),
                      ),
                      RosemaryButton(
                        label: '完成并关闭',
                        onPressed: () => close(null),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        await tester.tap(find.text('打开示例弹窗'));
        await tester.pumpAndSettle();
        if (keyboard > 0) {
          await tester.tap(find.byType(TextField));
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          await tester.pumpAndSettle();
        }
        final panel = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false),
        );
        expect(panel, findsOneWidget);
        final rect = tester.getRect(panel);
        expect(rect.left, greaterThanOrEqualTo(20));
        expect(rect.right, lessThanOrEqualTo(340));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(800 - keyboard - 24));
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          keyboard == 0 ? 'sdk-dialog' : 'sdk-dialog-keyboard',
        );
        await tester.scrollUntilVisible(
          find.text('完成并关闭'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('完成并关闭'));
        await tester.pumpAndSettle();
        expect(find.text('协议确认与密码重置示例'), findsNothing);
        expect(focus.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Widget _host(Widget child) => RepaintBoundary(
  key: const ValueKey('visual-frame'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Builder(
      builder: (context) => RosmEpassTheme(
        data: buildRosmPassportTheme(context, RosmPassportThemeMode.light),
        child: Scaffold(body: child),
      ),
    ),
  ),
);
Future<void> _capture(WidgetTester tester, String name) async {
  final output = Platform.environment['ROSM_VISUAL_OUTPUT'];
  if (output == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('visual-frame')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
