import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  group(
    'Assessment feature configuration',
    () {
      testWidgets('blank saved assessment shows only dropdown until selected', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentBlockSection(
                  value: const AssessmentBlockData(
                    type: AssessmentType.numeric,
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Select Assessment'), findsOneWidget);
        expect(find.text('Numeric Response'), findsNothing);
        expect(find.text('Correct Answer'), findsNothing);
        await tester.tap(find.text('Select Assessment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Numeric Response').last);
        await tester.pumpAndSettle();
        expect(find.text('Correct Answer'), findsOneWidget);
      });
      testWidgets('saved assessment content retains its selected type', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentBlockSection(
                  value: const AssessmentBlockData(
                    type: AssessmentType.numeric,
                    data: {'question': 'How many?', 'correct_answer': '2'},
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Numeric Response'), findsOneWidget);
        expect(find.text('Select Assessment'), findsNothing);
        expect(find.text('Correct Answer'), findsOneWidget);
      });
    },
    skip: assessmentFeaturesEnabled
        ? false
        : 'Assessments are intentionally disabled for launch.',
  );
}
