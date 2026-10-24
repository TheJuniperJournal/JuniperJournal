import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/shared/widgets/interactive_journal_assessment.dart';
import 'package:juniper_journal/src/backend/db/repositories/assessments_repo.dart';

class _Repo extends AssessmentsRepo {
  int submissions = 0;
  Map<String, dynamic> answer = {};
  @override
  Future<Map<String, dynamic>> session(String id) async => {
    'author_preview': false,
    'response': null,
  };
  @override
  Future<Map<String, dynamic>> save(
    String id,
    Map<String, dynamic> data, {
    required bool submit,
  }) async {
    answer = data;
    if (submit) submissions++;
    return {
      'response': {
        'answer': data,
        'status': submit ? 'evaluated' : 'in_progress',
        'correct': submit ? true : null,
      },
      'points': submit ? 10 : 0,
    };
  }
}

void main() {
  group(
    'Assessment feature configuration',
    () {
      testWidgets(
        'author numeric preview filters text, grades after submit and earns no reward',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: InteractiveJournalAssessment(
                  assessment: AssessmentBlockData(
                    type: AssessmentType.numeric,
                    data: {
                      'question': 'Count trees',
                      'correct_answer': '10',
                      'min_value': '9',
                      'max_value': '11',
                    },
                  ),
                ),
              ),
            ),
          );
          expect(find.textContaining('Answer: 10'), findsNothing);
          await tester.enterText(find.byType(TextField), 'wrong');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          await tester.enterText(find.byType(TextField), '10');
          await tester.tap(find.text('Submit Response'));
          await tester.pumpAndSettle();
          expect(find.text('Preview evaluated — correct'), findsOneWidget);
          expect(find.textContaining('EcoPoints earned!'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'published multiple choice saves response, locks submission and shows earned reward',
        (tester) async {
          final repo = _Repo();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: InteractiveJournalAssessment(
                  repo: repo,
                  assessment: const AssessmentBlockData(
                    assessmentId: 'assessment',
                    type: AssessmentType.multipleChoice,
                    data: {
                      'question': 'Choose one',
                      'options': ['Yes', 'No'],
                      'answer_key_redacted': true,
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Yes'));
          await tester.pump();
          await tester.tap(find.text('Submit Response'));
          await tester.pumpAndSettle();
          expect(repo.submissions, 1);
          expect(repo.answer, {'index': 0});
          expect(find.text('+10 EcoPoints earned!'), findsOneWidget);
          expect(find.text('Submit Response'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
      testWidgets(
        'short paragraph preview accepts written answer without automatic correctness',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: InteractiveJournalAssessment(
                  assessment: AssessmentBlockData(
                    type: AssessmentType.paragraph,
                    data: {'question': 'Reflect', 'response_length': 'short'},
                  ),
                ),
              ),
            ),
          );
          await tester.enterText(find.byType(TextField), 'My reflection');
          await tester.tap(find.text('Submit Response'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('written response is not automatically graded'),
            findsOneWidget,
          );
        },
      );
      testWidgets(
        'multiple selection uses checkboxes and exact selected answers',
        (tester) async {
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: InteractiveJournalAssessment(
                  assessment: AssessmentBlockData(
                    type: AssessmentType.multipleChoice,
                    data: {
                      'question': 'Pick two',
                      'allow_multiple': true,
                      'options': ['A', 'B', 'C'],
                      'correct_indices': [0, 2],
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('A'));
          await tester.pump();
          await tester.tap(find.text('C'));
          await tester.pump();
          await tester.tap(find.text('Submit Response'));
          await tester.pumpAndSettle();
          expect(find.text('Preview evaluated — correct'), findsOneWidget);
        },
      );
    },
    skip: assessmentFeaturesEnabled
        ? false
        : 'Assessments are intentionally disabled for launch.',
  );
}
