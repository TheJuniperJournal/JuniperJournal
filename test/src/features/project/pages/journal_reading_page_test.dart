import '../../../../support/fake_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class _Repo extends ProjectsRepo {
  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => const [
    ImpactEntry(
      id: 'impact',
      projectId: 'p',
      title: 'Saved water impact',
      metric: 'Water',
      impactScale: 'Sapling (Small)',
      patternType: 'Reduction',
      evidenceType: 'Measurement',
      confidenceScore: 'Medium',
      measurement: 2,
      measurementUnit: 'kg',
      ecoPoints: 12,
      linkedJournalEntryId: 'e',
    ),
  ];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
}

void main() {
  setUpAll(() => initializeFakeBackend(userId: 'viewer'));
  final samples = <String, (String, List<Map<String, dynamic>>)>{
    'Discovery': (
      'discover',
      [
        {
          'stage': 'observations',
          'observed': 'Saved observation',
          'known': 'Known context',
        },
        {
          'stage': 'question',
          'questions': [
            {'type': 'How', 'text': 'Saved question'},
          ],
        },
      ],
    ),
    'Ideation': (
      'ideating',
      [
        {
          'stage': 'challenge',
          'problem': 'Saved challenge',
          'objectives': [
            {'text': 'Saved objective'},
          ],
        },
        {
          'stage': 'ideas',
          'items': [
            {
              'id': 'i',
              'title': 'Saved idea',
              'description': 'Saved explanation',
            },
          ],
        },
      ],
    ),
    'Building': (
      'prototyping',
      [
        {
          'stage': 'prototyping',
          'entryType': 'building',
          'title': 'Saved build',
          'summary': 'Saved build process',
          'materials': [
            {'name': 'Reused jar', 'cost': 3.5},
          ],
        },
      ],
    ),
    'Testing': (
      'prototyping',
      [
        {
          'stage': 'prototyping',
          'entryType': 'testing',
          'title': 'Saved test',
          'outcome': 'Promising',
          'feedback': 'Saved feedback',
        },
      ],
    ),
    'Technical Analysis': (
      'prototyping',
      [
        {
          'stage': 'prototyping',
          'entryType': 'technical_analysis',
          'title': 'Saved analysis',
          'dataSources': [
            {'label': 'Field Measurements'},
          ],
          'calculationType': 'Comparison',
        },
      ],
    ),
    'Implementation': (
      'implementation',
      [
        {'stage': 'overview', 'summary': 'Saved implementation'},
        {'stage': 'assessment'},
        {'stage': 'reflection', 'keyTakeaways': 'Saved takeaway'},
      ],
    ),
  };
  for (final sample in samples.entries) {
    testWidgets(
      '${sample.key} uses the production reading page with saved values',
      (tester) async {
        tester.view.physicalSize = const Size(900, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final content = [
          ...sample.value.$2,
          {
            'stage': 'learning',
            'inquiryLens': 'Design',
            'dci': ['Natural Resources & Conservation'],
            'sep': ['Designing Solutions'],
            'ccc': ['Systems & System Models'],
            'inquiryLensData': {
              'selected_lens': 'Design',
              'lens_states': {
                'Design': {'student_instruction': 'Hidden learner prompt'},
              },
            },
          },
          if (sample.key != 'Implementation')
            {
              'stage': 'nextAction',
              'learned': 'Saved learning',
              'nextSteps': 'Saved next step',
            },
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: JournalReadingPage(
              entry: JournalEntry(
                id: 'e',
                projectId: 'p',
                title: 'Actual saved title',
                progress: sample.value.$1,
                createdAt: DateTime(2026, 10, 26),
                content: content,
              ),
              projectsRepo: _Repo(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('journal-reading-paper')),
          findsOneWidget,
        );
        expect(find.text('Actual saved title'), findsOneWidget);
        expect(find.text('Learning lens'), findsOneWidget);
        expect(find.text('Natural Resources & Conservation'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.text('Hidden learner prompt'), findsNothing);
        expect(find.text('DESIGN EXAMPLE'), findsNothing);
        expect(tester.takeException(), isNull);
        if (sample.key == 'Implementation') {
          expect(find.text('Saved water impact'), findsOneWidget);
          expect(find.text('Measurement'), findsNWidgets(2));
          expect(find.text('Assessment notes'), findsNothing);
        }
        if (sample.key == 'Testing') {
          expect(find.text('Test Title'), findsOneWidget);
          expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
        }
      },
    );
  }
  testWidgets(
    'Free Notes renders the saved canvas without tools or editable cells',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: JournalReadingPage(
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Saved notes',
              content: [
                {'stage': 'free_notes'},
                {'type': 'body', 'text': 'Saved canvas text'},
                {
                  'type': 'table',
                  'rows': [
                    ['Heading', 'Value'],
                    ['Water', '2 kg'],
                  ],
                },
              ],
            ),
            projectsRepo: _Repo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Saved canvas text'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Write something…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
