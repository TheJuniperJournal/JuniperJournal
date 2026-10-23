import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';

void main() {
  testWidgets(
    'tap controls highlight on hover and keep their size and callback',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppTapTarget(
                onTap: () => taps++,
                child: const SizedBox(
                  width: 120,
                  height: 40,
                  child: Text('Add Impact'),
                ),
              ),
            ),
          ),
        ),
      );
      final bounds = tester.getRect(find.byType(AppTapTarget));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(bounds.center);
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration
              as BoxDecoration;
      expect(decoration.color, isNot(Colors.transparent));
      expect(tester.getRect(find.byType(AppTapTarget)), bounds);
      await tester.tap(find.text('Add Impact'));
      expect(taps, 1);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        (tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration
                as BoxDecoration)
            .color,
        Colors.transparent,
      );
      await mouse.removePointer();
    },
  );
  testWidgets('keyboard users can activate an action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTapTarget(onTap: () => taps++, child: const Text('Action')),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
  });
  testWidgets('disabled tap targets do not gain hover or keyboard handlers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppTapTarget(child: const Text('Disabled'))),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsNothing);
    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
