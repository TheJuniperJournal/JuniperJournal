import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';

void main() {
  testWidgets('requires a lens and one choice in every learning dimension', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var lens = const InquiryLensData();
    final dci = <String>{}, sep = <String>{}, ccc = <String>{};
    var advances = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => JournalLearningStageBody(
                selectedDci: dci,
                selectedSep: sep,
                selectedCcc: ccc,
                inquiryLensData: lens,
                assessment: const AssessmentBlockData(
                  type: AssessmentType.numeric,
                ),
                isSaving: false,
                onToggleDci: (value) => update(() => dci.add(value)),
                onToggleSep: (value) => update(() => sep.add(value)),
                onToggleCcc: (value) => update(() => ccc.add(value)),
                onInquiryLensChanged: (value) => update(() => lens = value),
                onAssessmentChanged: (_) {},
                onBack: () {},
                onNext: () => advances++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Assessment Type (optional)'), findsNothing);
    expect(find.byType(AssessmentBlockSection), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(advances, 0);
    expect(find.text('Required: select an inquiry lens.'), findsOneWidget);
    expect(
      find.text('Required: select at least one option.'),
      findsNWidgets(3),
    );
    for (final label in [
      'Observe',
      'Ecosystems & Biodiversity',
      'Asking Questions & Defining Problems',
      'Patterns',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(advances, 1);
    expect(find.text('Required: select an inquiry lens.'), findsNothing);
    expect(find.text('Required: select at least one option.'), findsNothing);
  });
}
