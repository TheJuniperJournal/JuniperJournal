import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  testWidgets(
    'launch configuration hides assessments without clearing saved data',
    (tester) async {
      const data = AssessmentBlockData(
        type: AssessmentType.numeric,
        data: {
          'question': 'Saved question',
          'correct_answer': '5',
          'min_value': '0',
          'max_value': '10',
        },
      );
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentBlockSection(
              value: data,
              onChanged: (_) => changes++,
            ),
          ),
        ),
      );
      expect(assessmentFeaturesEnabled, isFalse);
      expect(find.text('Save Assessment'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(changes, 0);
      expect(data.data['question'], 'Saved question');
    },
  );
}
