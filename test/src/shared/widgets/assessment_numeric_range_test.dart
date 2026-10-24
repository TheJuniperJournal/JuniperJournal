import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  group(
    'Assessment feature configuration',
    () {
      Future<void> mount(
        WidgetTester tester,
        String answer,
        String min,
        String max,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentBlockSection(
                  value: AssessmentBlockData(
                    type: AssessmentType.numeric,
                    data: {
                      'question': 'How much?',
                      'correct_answer': answer,
                      'min_value': min,
                      'max_value': max,
                    },
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final answer in ['10', '20000']) {
        testWidgets(
          'out of range answer $answer explains the conflict and clears after correction',
          (tester) async {
            await mount(tester, answer, '100', '10000');
            expect(
              find.textContaining('is outside the acceptable range'),
              findsOneWidget,
            );
            await tester.enterText(find.byType(TextField).at(1), '100');
            await tester.pumpAndSettle();
            expect(
              find.textContaining('is outside the acceptable range'),
              findsNothing,
            );
            await tester.enterText(find.byType(TextField).at(2), '101');
            await tester.pumpAndSettle();
            expect(
              find.textContaining('is outside the acceptable range'),
              findsOneWidget,
            );
            await tester.enterText(find.byType(TextField).at(2), '100');
            await tester.pumpAndSettle();
            expect(
              find.textContaining('is outside the acceptable range'),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets(
        'reversed range explains bounds and supports negative decimal boundaries',
        (tester) async {
          await mount(tester, '-2.5', '10', '-2.5');
          expect(
            find.text('The minimum must be less than or equal to the maximum.'),
            findsOneWidget,
          );
          await tester.enterText(find.byType(TextField).at(2), '-2.5');
          await tester.pumpAndSettle();
          expect(find.textContaining('The minimum must'), findsNothing);
          expect(
            find.textContaining('is outside the acceptable range'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    },
    skip: assessmentFeaturesEnabled
        ? false
        : 'Assessments are intentionally disabled for launch.',
  );
}
