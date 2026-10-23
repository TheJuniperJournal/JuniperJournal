import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required bool correct,
    required Future<bool> Function() save,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssessmentBlockSection(
              value: AssessmentBlockData(
                type: AssessmentType.multipleChoice,
                data: {
                  'question': 'Which option?',
                  'options': ['First', 'Second'],
                  if (correct) 'correct_index': 0,
                },
              ),
              onChanged: (_) {},
              onSave: save,
            ),
          ),
        ),
      ),
    );
  }

  for (final type in AssessmentType.values) {
    testWidgets('save stays inside the ${type.name} assessment card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentBlockSection(
                value: AssessmentBlockData(
                  type: type,
                  data: const {'question': 'Assessment question'},
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'Save Assessment');
      final card = find.ancestor(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_AssessmentFormCard',
        ),
      );
      expect(card, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final cardRect = tester.getRect(card);
      final buttonRect = tester.getRect(button);
      expect(cardRect.contains(buttonRect.topLeft), isTrue);
      expect(cardRect.contains(buttonRect.bottomRight), isTrue);
      expect(buttonRect.center.dx, closeTo(cardRect.center.dx, 1));
    });
  }

  testWidgets(
    'save explains missing correct answer and does not persist invalid assessment',
    (tester) async {
      var calls = 0;
      await mount(
        tester,
        correct: false,
        save: () async {
          calls++;
          return true;
        },
      );
      await tester.ensureVisible(find.text('Save Assessment'));
      await tester.tap(find.text('Save Assessment'));
      await tester.pumpAndSettle();
      expect(find.text('Select the correct answer.'), findsOneWidget);
      expect(
        find.text(
          'Mark one option as the correct answer below. Learners will not see the answer key.',
        ),
        findsOneWidget,
      );
      expect(calls, 0);
    },
  );
  testWidgets(
    'explicit correct-answer action selects an option and allows saving',
    (tester) async {
      AssessmentBlockData value = const AssessmentBlockData(
        type: AssessmentType.multipleChoice,
        data: {
          'question': 'Choose',
          'options': ['First', 'Second'],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => AssessmentBlockSection(
                  value: value,
                  onChanged: (next) => update(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Mark as correct').first);
      await tester.tap(find.text('Mark as correct').first);
      await tester.pumpAndSettle();
      expect(value.data['correct_index'], 0);
      expect(value.isValid, isTrue);
      expect(find.text('Correct answer'), findsOneWidget);
    },
  );

  testWidgets('valid save persists through parent and confirms success', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      correct: true,
      save: () async {
        calls++;
        return true;
      },
    );
    await tester.ensureVisible(find.text('Save Assessment'));
    await tester.tap(find.text('Save Assessment'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Assessment saved'), findsOneWidget);
    expect(find.text('Save Assessment'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.ensureVisible(find.text('Edit Assessment'));
    await tester.tap(find.text('Edit Assessment'));
    await tester.pumpAndSettle();
    expect(find.text('Save Assessment'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
  });
  testWidgets('finalized assessment reopens as a saved card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssessmentBlockSection(
            value: const AssessmentBlockData(
              type: AssessmentType.numeric,
              data: {
                'question': 'How many?',
                'correct_answer': '22',
                'min_value': '22',
                'max_value': '222',
                'authoring_finalized': true,
              },
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('How many?'), findsOneWidget);
    expect(find.text('Edit Assessment'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('save failure keeps the assessment and offers retry', (
    tester,
  ) async {
    await mount(tester, correct: true, save: () async => false);
    await tester.ensureVisible(find.text('Save Assessment'));
    await tester.tap(find.text('Save Assessment'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the assessment. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Assessment saved'), findsNothing);
    expect(find.text('First'), findsOneWidget);
  });
}
