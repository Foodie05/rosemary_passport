import 'dart:ui' show ColorSpace;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosemary_ui/rosemary_ui.dart';

Widget host(Widget child, {bool reduced = true}) => MaterialApp(
  home: RosemaryTheme(
    reduceMotion: reduced,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);
void main() {
  testWidgets(
    'paired scheme inherits explicit parent appearance and switches modes',
    (tester) async {
      final scheme = RosemaryColorScheme(
        light: RosemaryTokens.light.copyWith(
          fieldFill: const Color(0xFFEEDDCC),
        ),
        dark: RosemaryTokens.dark.copyWith(fieldFill: const Color(0xFF223344)),
      );
      RosemaryColors? observed;
      Widget app(RosemaryThemeMode mode) => MaterialApp(
        home: RosemaryTheme(
          mode: mode,
          child: RosemaryTheme(
            scheme: scheme,
            child: Builder(
              builder: (context) {
                observed = RosemaryThemeData.of(context).colors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(RosemaryThemeMode.dark));
      expect(observed!.fieldFill, scheme.dark.fieldFill);
      await tester.pumpWidget(app(RosemaryThemeMode.light));
      expect(observed!.fieldFill, scheme.light.fieldFill);
    },
  );
  test(
    'paired canonical recipe import preserves all surface/content roles',
    () {
      const roles = [
        'surface-navigation',
        'surface-topbar',
        'navigation-active',
        'on-navigation-active',
        'field-fill',
        'surface-group',
        'surface-floating',
      ];
      final light = RosemaryTokens.light.toMap().map(
        (key, value) => MapEntry(
          key,
          '#' + value.toARGB32().toRadixString(16).substring(2).toUpperCase(),
        ),
      );
      final dark = RosemaryTokens.dark.toMap().map(
        (key, value) => MapEntry(
          key,
          '#' + value.toARGB32().toRadixString(16).substring(2).toUpperCase(),
        ),
      );
      final scheme = RosemaryColorScheme.fromJson({
        'colors': {'light': light, 'dark': dark},
      });
      for (final role in roles) {
        expect(scheme.light.toMap()[role], RosemaryTokens.light.toMap()[role]);
        expect(scheme.dark.toMap()[role], RosemaryTokens.dark.toMap()[role]);
      }
      expect(
        () => RosemaryColorScheme.fromJson({
          'themes': {'light': light},
        }),
        throwsArgumentError,
      );
      expect(
        () => RosemaryColors.fromHex({...light, 'field-fill': 'transparent'}),
        throwsArgumentError,
      );
    },
  );

  WidgetController.hitTestWarningShouldBeFatal = true;
  test('strict local date/time and shared theme diagnostics', () {
    expect(RosemaryLocalDate.parse('0001-01-01'), RosemaryLocalDate(1, 1, 1));
    expect(
      RosemaryLocalDate.parse('9999-12-31'),
      RosemaryLocalDate(9999, 12, 31),
    );
    for (final value in [
      '0000-01-01',
      '10000-01-01',
      '2025-02-29',
      '2026-1-01',
    ]) {
      expect(RosemaryLocalDate.parse(value), isNull);
    }
    for (var hour = 0; hour < 24; hour++) {
      for (var minute = 0; minute < 60; minute++) {
        expect(
          RosemaryLocalTime.parse(
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
          ),
          RosemaryLocalTime(hour, minute),
        );
      }
    }
    expect(
      () => RosemaryDateRange(
        RosemaryLocalDate(2026, 2, 1),
        RosemaryLocalDate(2026, 1, 1),
      ),
      throwsArgumentError,
    );
    for (final palette in [RosemaryTokens.light, RosemaryTokens.dark]) {
      final results = rosemaryValidateTheme(palette);
      expect(results.length, 56);
      expect(results.every((d) => d.passes), isTrue);
    }
    expect(
      () => rosemaryValidateTheme(
        RosemaryTokens.light.copyWith(primary: Colors.transparent),
      ),
      throwsArgumentError,
    );
    expect(
      () => rosemaryValidateTheme(
        RosemaryTokens.light.copyWith(
          primary: const Color.from(
            alpha: 1,
            red: .3,
            green: .5,
            blue: .7,
            colorSpace: ColorSpace.displayP3,
          ),
        ),
      ),
      throwsArgumentError,
    );
  });
  testWidgets('diagnostic callback can store results without a rebuild loop', (
    tester,
  ) async {
    var callbacks = 0;
    List<RosemaryContrastDiagnostic>? results;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => RosemaryTheme(
            colors: RosemaryTokens.light.copyWith(),
            onContrastDiagnostics: (values) => setState(() {
              callbacks++;
              results = values;
            }),
            child: const RosemaryText('Theme'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(callbacks, 1);
    expect(results?.length, 56);
  });
  testWidgets('controlled native editing emits once and echoes host value', (
    tester,
  ) async {
    var name = '', calls = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => RosemaryInput(
            value: name,
            onChanged: (v) => setState(() {
              name = v;
              calls++;
            }),
            label: 'Name',
            error: name.isEmpty ? 'Required' : null,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Rosemary');
    await tester.pump();
    expect(calls, 1);
    expect(name, 'Rosemary');
    expect(find.text('Rosemary'), findsOneWidget);
    expect(find.text('Required'), findsNothing);
  });
  testWidgets('Select skips disabled options and restores trigger focus', (
    tester,
  ) async {
    var value = 'a';
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => RosemarySelect(
            value: value,
            onChanged: (v) => setState(() => value = v),
            label: 'Section',
            options: const [
              RosemaryOption('a', 'Alpha'),
              RosemaryOption('b', 'Blocked', enabled: false),
              RosemaryOption('c', 'Charlie'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, 'c');
    expect(find.text('Blocked'), findsNothing);
    expect(FocusManager.instance.primaryFocus?.context?.widget, isA<Focus>());
  });
  testWidgets('local overlay retains theme RTL strings and scaled text', (
    tester,
  ) async {
    bool open = false;
    final local = RosemaryTokens.dark.copyWith(
      primary: const Color(0xFF9BD6C0),
    );
    RosemaryThemeData? observed;
    TextDirection? direction;
    double? scale;
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: RosemaryTheme(
            child: StatefulBuilder(
              builder: (context, setState) => RosemaryTheme(
                colors: local,
                locale: const Locale('zh'),
                direction: TextDirection.rtl,
                reduceMotion: true,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: RosemaryPopover(
                    open: open,
                    onDismiss: (_) => setState(() => open = false),
                    trigger: RosemaryButton(
                      label: 'Open',
                      onPressed: () => setState(() => open = true),
                    ),
                    child: Builder(
                      builder: (context) {
                        observed = RosemaryThemeData.of(context);
                        direction = Directionality.of(context);
                        scale = MediaQuery.textScalerOf(context).scale(10);
                        return RosemaryButton(
                          label: rString(context, 'Cancel'),
                          onPressed: () => setState(() => open = false),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(observed?.primary, local.primary);
    expect(observed?.reduceMotion, isTrue);
    expect(direction, TextDirection.rtl);
    expect(scale, 13);
    expect(find.text('取消'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'date dedicated year/month views reach boundaries and cancel time draft',
    (tester) async {
      var date = RosemaryLocalDate(1, 1, 1);
      var time = RosemaryLocalTime(23, 59);
      var commits = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => RosemaryDate(
              value: date,
              onChanged: (v) => setState(() {
                date = v;
                commits++;
              }),
              time: time,
              onTimeChanged: (v) => setState(() => time = v),
              mode: RosemaryDateMode.dateTime,
              label: 'Appointment',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0001'));
      await tester.pumpAndSettle();
      final fields = find.byType(EditableText);
      await tester.enterText(fields.last, '9999');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('9999').last);
      await tester.tap(find.text('9999').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('12').first);
      await tester.tap(find.text('12').first);
      await tester.pumpAndSettle();
      expect(find.text('Next month'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(date, RosemaryLocalDate(1, 1, 1));
      expect(time, RosemaryLocalTime(23, 59));
      expect(commits, 0);
    },
  );
  testWidgets(
    'drawer reverses a real exit and restores keyboard focus; cancelled progress stops',
    (tester) async {
      bool open = false;
      var finished = 0;
      final trigger = FocusNode();
      late StateSetter hostSet;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              hostSet = setState;
              return Column(
                children: [
                  RosemaryButton(
                    label: 'Open drawer',
                    focusNode: trigger,
                    onPressed: () => setState(() => open = true),
                  ),
                  RosemaryDrawer(
                    open: open,
                    title: 'Settings',
                    onDismiss: (_) => setState(() => open = false),
                    onAnimationFinished: () => finished++,
                    child: RosemaryButton(
                      label: 'Close panel',
                      onPressed: () => setState(() => open = false),
                    ),
                  ),
                ],
              );
            },
          ),
          reduced: false,
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Open drawer'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      final startX = tester.getTopLeft(find.text('Settings')).dx;
      await tester.tap(find.text('Close panel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 64));
      expect(find.text('Settings'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Settings')).dx, greaterThan(startX));
      hostSet(() => open = true);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Close panel'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsNothing);
      expect(trigger.hasFocus, isTrue);
      expect(finished, greaterThanOrEqualTo(2));
      await tester.pumpWidget(
        host(
          const RosemaryProgress(
            value: 35,
            state: RosemaryProgressState.cancelled,
          ),
          reduced: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      trigger.dispose();
    },
  );
}
