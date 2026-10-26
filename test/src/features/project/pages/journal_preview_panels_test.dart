import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

void main() {
  testWidgets(
    'Discovery preview groups each stage and includes filled optional inputs',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: DiscoveryEntryPreviewPage(
            entry: JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Garden journal',
              progress: 'discovery',
              content: [
                {
                  'stage': 'observations',
                  'observed': 'Plants need water',
                  'known': 'Water supports growth',
                  'location': 'School garden',
                },
                {
                  'stage': 'analyze',
                  'patternChange': 'Reduction',
                  'patternExplanation': 'Less wasted water',
                  'rootCauses': [],
                },
                {
                  'stage': 'question',
                  'questions': [
                    {'type': 'How', 'text': 'How can we save water?'},
                  ],
                },
                {
                  'stage': 'learning',
                  'inquiryLens': 'Investigate',
                  'dci': ['Natural Resources & Conservation'],
                  'sep': ['Constructing Explanations'],
                  'ccc': ['Cause and Effect'],
                },
                {
                  'stage': 'nextAction',
                  'learned': 'Water carefully',
                  'challenges': 'Uneven flow',
                  'nextSteps': 'Test drip irrigation',
                  'notes': 'Bring a measuring cup',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in [
        'Observe',
        'Analyze',
        'Question',
        'Learning',
        'Next Action',
        'School garden',
        'Bring a measuring cup',
        'How can we save water?',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Investigate'), findsOneWidget);
      expect(find.text('What I learned'), findsOneWidget);
      expect(find.text('Water carefully'), findsOneWidget);
      // Connections are part of the preview without an expansion action.
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.text('Disciplinary Core Ideas'), findsOneWidget);
      expect(find.text('Science and Engineering Practices'), findsOneWidget);
      expect(find.text('Crosscutting Concepts'), findsOneWidget);
      expect(find.text('Challenges and open questions'), findsNothing);
      expect(find.text('What I’ll try next'), findsOneWidget);
      expect(find.text('Learning connections'), findsOneWidget);
      expect(
        find.text('Use fewer resources or reduce waste and harmful impacts.'),
        findsOneWidget,
      );
      expect(find.text('Not provided.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
