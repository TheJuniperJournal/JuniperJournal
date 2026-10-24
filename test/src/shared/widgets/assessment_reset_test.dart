import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  group(
    'Assessment feature configuration',
    () {
      testWidgets(
        'empty multiple choice switches type and resets without warning',
        (tester) async {
          tester.view.physicalSize = const Size(900, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var value = const AssessmentBlockData();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AssessmentBlockSection(
                    value: value,
                    onChanged: (next) => value = next,
                  ),
                ),
              ),
            ),
          );
          Future<void> choose(String label) async {
            await tester.ensureVisible(
              find.byTooltip('Choose assessment type'),
            );
            await tester.tap(find.byTooltip('Choose assessment type'));
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text(label),
              label == 'Numeric Response' ? -100 : 100,
              scrollable: find
                  .descendant(
                    of: find.byKey(const ValueKey('assessment-type-dropdown')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
          }

          await choose('Multiple Choice');
          expect(value.type, AssessmentType.multipleChoice);
          expect(value.hasDraft, false);
          await choose('Numeric Response');
          expect(find.byType(AlertDialog), findsNothing);
          expect(value.type, AssessmentType.numeric);
          await choose('Multiple Choice');
          await tester.tap(find.byTooltip('Choose assessment type'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('no-assessment-option')));
          await tester.pumpAndSettle();
          expect(value.isEmpty, true);
          expect(find.text('Select Assessment'), findsOneWidget);
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('Remove assessment'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('removing entered content can be cancelled or confirmed', (
        tester,
      ) async {
        var value = const AssessmentBlockData(
          type: AssessmentType.paragraph,
          data: {
            'question': 'Keep my entered question',
            'response_length': 'short',
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentBlockSection(
                  value: value,
                  onChanged: (next) => value = next,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Remove assessment'));
        await tester.pumpAndSettle();
        expect(find.text('Remove assessment?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Keep my entered question'), findsOneWidget);
        await tester.tap(find.text('Remove assessment'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(value.toJson(), isEmpty);
        expect(find.text('Select Assessment'), findsOneWidget);
        expect(find.text('Keep my entered question'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
    skip: assessmentFeaturesEnabled
        ? false
        : 'Assessments are intentionally disabled for launch.',
  );
}
