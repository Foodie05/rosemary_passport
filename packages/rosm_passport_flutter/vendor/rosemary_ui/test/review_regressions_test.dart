import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

Widget host(Widget child) => MaterialApp(
  home: RosemaryTheme(reduceMotion: true, child: Scaffold(body: child)),
);
void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'mixed checkbox renders a dash and select uses field error and disabled colors',
    (tester) async {
      await tester.pumpWidget(
        host(RosemaryCheckbox(value: null, label: 'Mixed', onChanged: (_) {})),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        host(
          RosemarySelect(
            value: null,
            label: 'Category',
            error: 'Required',
            onChanged: (_) {},
            options: const [RosemaryOption('a', 'A')],
          ),
        ),
      );
      var surface = tester.widget<RosemaryActionSurface>(
        find.byType(RosemaryActionSurface),
      );
      expect(surface.background, RosemaryTokens.light.dangerSoft);
      expect(surface.border, RosemaryTokens.light.danger);
      await tester.pumpWidget(
        host(
          RosemarySelect(
            value: null,
            enabled: false,
            label: 'Category',
            onChanged: (_) {},
            options: const [RosemaryOption('a', 'A')],
          ),
        ),
      );
      surface = tester.widget<RosemaryActionSurface>(
        find.byType(RosemaryActionSurface),
      );
      expect(surface.background, RosemaryTokens.light.surfaceInset);
      expect(surface.foreground, RosemaryTokens.light.muted);
      expect(surface.dimWhenDisabled, false);
      final opacity = find.ancestor(
        of: find.byType(RosemaryActionSurface),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, .65);
    },
  );
  testWidgets(
    'select keeps committed check while navigating and retains dropdown cue',
    (tester) async {
      await tester.pumpWidget(
        host(
          RosemarySelect(
            value: 'one',
            label: 'Category',
            onChanged: (_) {},
            options: const [
              RosemaryOption('one', 'First'),
              RosemaryOption('two', 'Second'),
            ],
          ),
        ),
      );
      final arrow = find.byWidgetPredicate(
        (w) => w is RosemaryIcon && w.name == 'down',
      );
      expect(arrow, findsOneWidget);
      await tester.tap(find.text('First'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final check = find.byWidgetPredicate(
        (w) => w is RosemaryIcon && w.name == 'check',
      );
      expect(check, findsOneWidget);
      expect(
        find.descendant(
          of: find
              .ancestor(of: check, matching: find.byType(RosemaryActionSurface))
              .first,
          matching: find.text('First'),
        ),
        findsOneWidget,
      );
      expect(arrow, findsOneWidget);
      final rotations = tester.widgetList<Transform>(
        find.ancestor(of: arrow, matching: find.byType(Transform)),
      );
      expect(
        rotations.any((w) => (w.transform.storage[0] + 1).abs() < .00001),
        true,
      );
      expect(
        tester
            .widget<RosemaryActionSurface>(
              find.descendant(
                of: find.byType(RosemarySelect),
                matching: find.byType(RosemaryActionSurface),
              ),
            )
            .transitionDuration,
        Duration.zero,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(check, findsNothing);
      expect(arrow, findsOneWidget);
      expect(
        tester
            .widgetList<Transform>(
              find.ancestor(of: arrow, matching: find.byType(Transform)),
            )
            .every((w) => w.transform.storage[0] > .99),
        true,
      );
    },
  );
  testWidgets(
    'two-route local overlay refuses Back/Escape, retains editing and restores trigger',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>(),
          trigger = FocusNode(),
          editor = FocusNode();
      bool open = false;
      var calls = 0;
      var value = 'draft';
      RosemaryThemeData? observed;
      final palette = RosemaryTokens.dark.copyWith(
        primary: const Color(0xFF9BD6C0),
      );
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Text('Background route'),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: RosemaryTheme(
              colors: palette,
              locale: const Locale('zh'),
              direction: TextDirection.rtl,
              reduceMotion: true,
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Foreground route'),
                      RosemaryButton(
                        label: 'Open review',
                        focusNode: trigger,
                        onPressed: () => setState(() => open = true),
                      ),
                      RosemaryDialog(
                        open: open,
                        title: 'Refusal review',
                        onDismiss: (_) {
                          calls++;
                          if (calls >= 3) setState(() => open = false);
                        },
                        child: Builder(
                          builder: (context) {
                            observed = RosemaryThemeData.of(context);
                            return Column(
                              children: [
                                RosemaryInput(
                                  value: value,
                                  onChanged: (v) => setState(() => value = v),
                                  label: 'Draft',
                                  focusNode: editor,
                                ),
                                RosemaryButton(
                                  label: 'Continue editing',
                                  onPressed: () {},
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      trigger.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(observed?.primary, palette.primary);
      expect(find.text('Refusal review'), findsOneWidget);
      final ctx = tester.element(find.text('Refusal review'));
      expect(Directionality.of(ctx), TextDirection.rtl);
      expect(Localizations.localeOf(ctx), const Locale('zh'));
      expect(MediaQuery.textScalerOf(ctx).scale(10), 13);
      await tester.enterText(find.byType(EditableText), 'retained');
      await tester.pumpAndSettle();
      expect(editor.hasFocus, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(editor.hasFocus, isTrue);
      expect(find.text('Foreground route'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(editor.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText), 'edited again');
      await tester.pumpAndSettle();
      expect(value, 'edited again');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Refusal review'), findsNothing);
      expect(trigger.hasFocus, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Background route'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      trigger.dispose();
      editor.dispose();
    },
  );
  testWidgets(
    'Select and Menu End reveal active items and dynamic lists retain safe IDs',
    (tester) async {
      tester.view.reset();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var options = [
        for (var i = 0; i < 30; i++) RosemaryOption('$i', 'Item $i'),
      ];
      String? chosen;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.bottomRight,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return SizedBox(
                  width: 120,
                  child: RosemarySelect(
                    value: '0',
                    onChanged: (v) => chosen = v,
                    options: options,
                    label: 'Edge',
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Item 0'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      final last = find.text('Item 29');
      expect(last.hitTestable(), findsOneWidget);
      final rect = tester.getRect(last);
      expect(rect.bottom, lessThanOrEqualTo(640));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.left, greaterThanOrEqualTo(0));
      update(
        () => options = [
          const RosemaryOption('0', 'Item 0', enabled: false),
          const RosemaryOption('next', 'Replacement'),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 'next');
      expect(tester.takeException(), isNull);
      var menuOpen = true;
      options = [
        for (var i = 0; i < 30; i++) RosemaryOption('$i', 'Action $i'),
      ];
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RosemaryMenu(
                open: menuOpen,
                trigger: RosemaryButton(
                  label: 'Actions',
                  onPressed: () => setState(() => menuOpen = true),
                ),
                items: options,
                onActivate: (value) => chosen = value,
                onOpenChanged: (value) => setState(() => menuOpen = value),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('Action 29').hitTestable(), findsOneWidget);
      update(
        () => options = [
          const RosemaryOption('29', 'Disabled former action', enabled: false),
          const RosemaryOption('safe', 'Safe replacement'),
        ],
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, 'safe');
      expect(menuOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'nonmodal ISO field commits directly; outside and Tab discard picker draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var date = RosemaryLocalDate(2026, 1, 1);
      var commits = 0;
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  RosemaryDate(
                    value: date,
                    onChanged: (v) => setState(() {
                      date = v;
                      commits++;
                    }),
                    label: 'Date',
                  ),
                  RosemaryButton(label: 'Background action', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '0001-01-01');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(date, RosemaryLocalDate(1, 1, 1));
      expect(commits, 1);
      expect(find.byType(RosemaryCalendar), findsNothing);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '320px open date panel');
      final panel = tester.getRect(find.byType(RosemaryCalendar));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(320));
      await tester.ensureVisible(find.text('Background action'));
      await tester.tap(find.text('Background action'));
      await tester.pumpAndSettle();
      expect(find.byType(RosemaryCalendar), findsNothing);
      await tester.ensureVisible(find.text('Choose'));
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 10 && find.byType(RosemaryCalendar).evaluate().isNotEmpty;
        i++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(find.byType(RosemaryCalendar), findsNothing);
      expect(commits, 1);
    },
  );
  testWidgets(
    'time has two roving columns, Home End and arrows, cancel retains host',
    (tester) async {
      var time = RosemaryLocalTime(23, 59);
      var commits = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => RosemaryDate(
              time: time,
              onTimeChanged: (v) => setState(() {
                time = v;
                commits++;
              }),
              mode: RosemaryDateMode.time,
              label: 'Time',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      final hour = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'Rosemary hours',
      );
      final minute = find.byWidgetPredicate(
        (w) => w is Focus && w.focusNode?.debugLabel == 'Rosemary minutes',
      );
      tester.widget<Focus>(hour).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.widget<Focus>(minute).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '00:59',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '00:01',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(time, RosemaryLocalTime(23, 59));
      expect(commits, 0);
    },
  );
  testWidgets(
    'disabled upload blocks all actions; OS high contrast uses explicit full palette at 200 percent',
    (tester) async {
      var calls = 0;
      RosemaryThemeData? theme;
      final high = RosemaryTokens.light.copyWith(
        border: RosemaryTokens.light.ink,
        control: RosemaryTokens.light.ink,
        focus: RosemaryTokens.light.ink,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              highContrast: true,
              textScaler: TextScaler.linear(2),
            ),
            child: RosemaryTheme(
              highContrastColors: high,
              reduceMotion: true,
              child: Builder(
                builder: (context) {
                  theme = RosemaryThemeData.of(context);
                  return Scaffold(
                    body: SingleChildScrollView(
                      child: RosemaryUpload(
                        label: 'Files',
                        enabled: false,
                        files: const [
                          RosemaryFile(
                            id: '1',
                            name: 'File',
                            canRetry: true,
                            canCancel: true,
                            state: RosemaryFileState.error,
                          ),
                        ],
                        onFilesSelected: (_) => calls++,
                        onRemoved: (_) => calls++,
                        onRetry: (_) => calls++,
                        onCancel: (_) => calls++,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Choose files', 'Remove File', 'Retry', 'Cancel']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(calls, 0);
      expect(theme?.colors, high);
      expect(rosemaryValidateTheme(high).every((d) => d.passes), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending native file selection cannot submit after host disables; refused ISO returns host value',
    (tester) async {
      final pending = Completer<List<XFile>>();
      bool enabled = true;
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RosemaryUpload(
                label: 'Upload',
                files: const [],
                enabled: enabled,
                chooseFiles: () => pending.future,
                onFilesSelected: (_) => selected++,
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Choose files'));
      await tester.pump();
      update(() => enabled = false);
      await tester.pump();
      pending.complete([XFile('/host-choice.txt')]);
      await tester.pumpAndSettle();
      expect(selected, 0);
      var proposals = 0;
      await tester.pumpWidget(
        host(
          RosemaryDate(
            value: RosemaryLocalDate(2026, 1, 1),
            onChanged: (_) => proposals++,
            label: 'Refused',
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '9999-12-31');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(proposals, 1);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '2026-01-01',
      );
    },
  );
  testWidgets(
    'short running loader never flashes; sustained task appears after shared delay',
    (tester) async {
      var state = RosemaryLoadingState.running;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return RosemaryLoading(state: state);
            },
          ),
        ),
      );
      final paint = find.descendant(
        of: find.byType(RosemaryLoading),
        matching: find.byType(CustomPaint),
      );
      expect(paint, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      update(() => state = RosemaryLoadingState.completed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(paint, findsNothing);
      await tester.pumpWidget(
        host(const RosemaryLoading(key: ValueKey('sustained'))),
      );
      await tester.pump(const Duration(milliseconds: 299));
      expect(paint, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(paint, findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    },
  );
  testWidgets(
    'optical fills retain equal frames and the full edge hit target',
    (tester) async {
      var activations = 0;
      Future<void> show(RosemaryThemeMode mode, {bool contrast = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(highContrast: contrast),
              child: RosemaryTheme(
                mode: mode,
                child: Scaffold(
                  body: Row(
                    children: RosemaryButtonVariant.values
                        .map(
                          (variant) => RosemaryButton(
                            key: ValueKey(variant),
                            label: 'Action',
                            variant: variant,
                            onPressed: () => activations++,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(RosemaryThemeMode.light);
      final frames = [
        for (final v in RosemaryButtonVariant.values)
          tester.getRect(find.byKey(ValueKey(v))),
      ];
      await show(RosemaryThemeMode.dark);
      for (var i = 0; i < RosemaryButtonVariant.values.length; i++) {
        final v = RosemaryButtonVariant.values[i];
        final button = find.byKey(ValueKey(v));
        final frame = tester.getRect(button);
        expect(frame, frames[i]);
        expect(frame.height, greaterThanOrEqualTo(44));
        final fill = find
            .descendant(of: button, matching: find.byType(Positioned))
            .first;
        final painted = find.descendant(
          of: fill,
          matching: find.byType(AnimatedContainer),
        );
        final paintRect = tester.getRect(painted);
        final inset =
            (v == RosemaryButtonVariant.primary ||
                v == RosemaryButtonVariant.danger)
            ? 1.0
            : 0.0;
        expect(paintRect, frame.deflate(inset));
        await tester.tapAt(frame.topLeft + const Offset(.5, .5));
        await tester.pumpAndSettle();
      }
      expect(activations, 4);
      await show(RosemaryThemeMode.dark, contrast: true);
      final primary = find.byKey(const ValueKey(RosemaryButtonVariant.primary));
      final fill = find
          .descendant(of: primary, matching: find.byType(Positioned))
          .first;
      expect(
        tester.getRect(
          find.descendant(of: fill, matching: find.byType(AnimatedContainer)),
        ),
        tester.getRect(primary),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
