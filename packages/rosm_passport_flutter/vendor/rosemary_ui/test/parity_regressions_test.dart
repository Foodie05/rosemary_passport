import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';
import 'package:rosemary_ui/src/disclosure_curve.dart';

Widget host(Widget child) => MaterialApp(
  home: RosemaryTheme(child: Scaffold(body: child)),
);
void main() {
  test(
    'disclosure curve uses actual rounded portal samples in both directions',
    () {
      for (final opening in [true, false]) {
        final curve = RosemaryDisclosureCurve(opening);
        final points = opening
            ? RosemaryInteraction.disclosureEnter
            : RosemaryInteraction.disclosureExit;
        for (var i = 0; i < 41; i++)
          expect(curve.transform(i / 40), closeTo(points[i], .000001));
        expect(curve.transform(.25), greaterThan(.3));
      }
    },
  );
  testWidgets('selection spring moves only marker and settles after overshoot', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        RosemaryCheckbox(
          value: false,
          onChanged: (_) {
            calls++;
          },
          label: 'Stable label',
        ),
      ),
    );
    final text = find.text('Stable label');
    final before = tester.getRect(text);
    final mark = find.byType(RosemarySelectionMark);
    double scale() => tester
        .widget<Transform>(
          find.descendant(of: mark, matching: find.byType(Transform)).first,
        )
        .transform
        .storage[0];
    final gesture = await tester.startGesture(tester.getCenter(text));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 160));
    expect(scale(), lessThan(.95));
    expect(tester.getRect(text), before);
    await gesture.up();
    var peak = 1.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      peak = math.max(peak, scale());
    }
    expect(peak, greaterThan(1.003));
    await tester.pumpAndSettle();
    expect(scale(), closeTo(1, .001));
    expect(calls, 1);
    // Host rejected the checked value: visual feedback must not commit local state.
    expect(
      tester.widget<RosemaryCheckbox>(find.byType(RosemaryCheckbox)).value,
      false,
    );
  });
  testWidgets('one nonlinear progress drives both select head and reveal', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        RosemarySelect(
          label: 'Category',
          value: 'a',
          onChanged: (_) {},
          options: const [
            RosemaryOption('a', 'Alpha'),
            RosemaryOption('b', 'Beta'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final expected = const RosemaryDisclosureCurve(true).transform(.5);
    final clip = find.byWidgetPredicate(
      (w) => w is ClipRect && w.clipper != null,
    );
    expect(clip, findsOneWidget);
    expect(
      tester
              .widget<ClipRect>(clip)
              .clipper!
              .getClip(const Size(100, 100))
              .height /
          100,
      closeTo(expected, .00001),
    );
    final arrow = find.byWidgetPredicate(
      (w) => w is RosemaryIcon && w.name == 'down',
    );
    final transforms = tester.widgetList<Transform>(
      find.ancestor(of: arrow, matching: find.byType(Transform)),
    );
    expect(
      transforms.any(
        (w) =>
            (w.transform.storage[0] - math.cos(expected * math.pi)).abs() <
            .00001,
      ),
      true,
    );
    await tester.pumpAndSettle();
  });
  testWidgets(
    'keyboard press is held until release and slider keeps keyboard and semantics',
    (tester) async {
      var calls = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        host(
          RosemaryButton(
            label: 'Hold',
            focusNode: focus,
            onPressed: () => calls++,
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(calls, 0);
      final scale = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(RosemaryActionSurface),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0];
      expect(scale, lessThan(.99));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(calls, 1);
      double value = 25;
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, set) => SizedBox(
              width: 300,
              child: RosemarySlider(
                label: 'Level',
                value: value,
                onChanged: (v) => set(() => value = v),
              ),
            ),
          ),
        ),
      );
      expect(find.text('−'), findsNothing);
      expect(find.text('+'), findsNothing);
      final keyboard = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(RosemarySlider),
              matching: find.byType(Focus),
            )
            .first,
      );
      keyboard.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(value, 26);
      final node = tester.getSemantics(find.bySemanticsLabel('Level'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), true);
      final knob = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(tester.getSize(knob), const Size(16, 16));
      semantics.dispose();
    },
  );
}
