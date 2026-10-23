import 'package:flutter/gestures.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';

void main() {
  for (final date in [false, true]) {
    for (final interaction in ['click', 'scroll', 'drag']) {
      testWidgets('${date ? "date" : "time"} supports $interaction selection', (tester) async {
        DateTime? selectedDate;
        Map<String, dynamic>? selectedTime;
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
          body: TextButton(onPressed: () async {
            if (date) {
              selectedDate = await showWheelDatePicker(context, DateTime(2026, 1, 1));
            } else {
              selectedTime = await showWheelTimePicker(context, 8, 0, 'AM');
            }
          }, child: const Text('Open')),
        ))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final wheels = find.byType(ListWheelScrollView);
        for (var i = 0; i < (date ? 3 : 2); i++) {
          final center = tester.getCenter(wheels.at(i));
          if (interaction == 'scroll') {
            await tester.sendEventToBinding(PointerScrollEvent(
              position: center, scrollDelta: const Offset(0, 44), kind: PointerDeviceKind.mouse,
            ));
          } else if (interaction == 'drag') {
            final mouse = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
            await mouse.moveBy(const Offset(0, -20));
            await tester.pump();
            await mouse.moveBy(const Offset(0, -44));
            await tester.pump(const Duration(milliseconds: 200));
            await mouse.up();
          } else {
            await tester.tapAt(center + const Offset(0, 44));
          }
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        if (date) {
          expect(selectedDate?.month, greaterThan(1));
          expect(selectedDate?.day, greaterThan(1));
          expect(selectedDate?.year, greaterThan(2026));
        } else {
          expect(selectedTime?['hour'], greaterThan(8));
          expect(selectedTime?['minute'], greaterThan(0));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final drag in [false, true]) {
    testWidgets('time wheels accept ${drag ? "mouse dragging" : "clicks"} and apply the selected time', (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () async {
          result = await showWheelTimePicker(context, 8, 0, 'AM');
        }, child: const Text('Open')),
      ))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final wheels = find.byType(ListWheelScrollView);
      for (var i = 0; i < 2; i++) {
        final center = tester.getCenter(wheels.at(i));
        if (drag) {
          final mouse = await tester.startGesture(center, kind: PointerDeviceKind.mouse);
          await mouse.moveBy(const Offset(0, -20));
          await tester.pump();
          await mouse.moveBy(const Offset(0, -50));
          await tester.pump(const Duration(milliseconds: 200));
          await mouse.up();
        } else {
          await tester.tapAt(center + const Offset(0, 44));
        }
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result?['hour'], greaterThan(8));
      expect(result?['minute'], greaterThan(0));
      expect(result?['amPm'], 'PM');
      if (!drag) {
        expect(result?['hour'], 9);
        expect(result?['minute'], 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
