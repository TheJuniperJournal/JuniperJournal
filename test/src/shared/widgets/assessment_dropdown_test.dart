import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  testWidgets(
    'assessment dropdown closes with the same arrow without selecting',
    (tester) async {
      var value = const AssessmentBlockData();
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentBlockSection(
                value: value,
                onChanged: (next) {
                  value = next;
                  changes++;
                },
              ),
            ),
          ),
        ),
      );
      final barriers = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.byTooltip('Choose assessment type'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessment-type-dropdown')),
        findsOneWidget,
      );
      expect(find.text('Numeric Response'), findsOneWidget);
      expect(find.byType(ModalBarrier), findsNWidgets(barriers));
      await tester.tap(find.byTooltip('Close assessment types'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessment-type-dropdown')),
        findsNothing,
      );
      expect(value.type, isNull);
      expect(changes, 0);
      await tester.tap(find.byTooltip('Choose assessment type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Numeric Response'));
      await tester.pumpAndSettle();
      expect(value.type, AssessmentType.numeric);
      expect(
        find.byKey(const ValueKey('assessment-type-dropdown')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing the dropdown preserves an existing assessment draft', (
    tester,
  ) async {
    const initial = AssessmentBlockData(
      type: AssessmentType.paragraph,
      data: {'question': 'Keep this question', 'response_length': 'short'},
    );
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssessmentBlockSection(
              value: initial,
              onChanged: (_) => changes++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Choose assessment type'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close assessment types'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this question'), findsOneWidget);
    expect(changes, 0);
    expect(tester.takeException(), isNull);
  });
}
