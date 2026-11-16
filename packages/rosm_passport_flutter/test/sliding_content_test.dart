import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosm_passport_flutter/src/epass_motion.dart';

void main() {
  testWidgets('sliding forms fade, resize, and exclude outgoing interaction', (
    tester,
  ) async {
    late StateSetter update;
    var index = 0;
    var reduced = false;
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 280,
                    child: RosmEpassSlidingContent(
                      value: index,
                      order: index,
                      child: SizedBox(
                        height: index == 0 ? 100 : 240,
                        child: TextButton(
                          onPressed: () => taps++,
                          child: Text('panel $index'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final panel = find.byType(RosmEpassSlidingContent);
    expect(tester.getSize(panel).height, 100);
    update(() => index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(panel).height, greaterThan(100));
    expect(tester.getSize(panel).height, lessThan(240));
    final outgoing = find.text('panel 0');
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(of: outgoing, matching: find.byType(IgnorePointer))
                .first,
          )
          .ignoring,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeFocus>(
            find
                .ancestor(of: outgoing, matching: find.byType(ExcludeFocus))
                .first,
          )
          .excluding,
      isTrue,
    );
    expect(
      tester
          .widget<ExcludeSemantics>(
            find
                .ancestor(of: outgoing, matching: find.byType(ExcludeSemantics))
                .first,
          )
          .excluding,
      isTrue,
    );
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(of: panel, matching: find.byType(FadeTransition)),
    );
    expect(
      fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    update(() => index = 0);
    await tester.pump(const Duration(milliseconds: 20));
    update(() => index = 1);
    await tester.pumpAndSettle();
    expect(find.text('panel 0'), findsNothing);
    expect(tester.getSize(panel).height, 240);
    await tester.tap(find.text('panel 1'));
    expect(taps, 1);
    update(() {
      reduced = true;
      index = 0;
    });
    await tester.pump();
    expect(tester.getSize(panel).height, 100);
    expect(find.text('panel 1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
