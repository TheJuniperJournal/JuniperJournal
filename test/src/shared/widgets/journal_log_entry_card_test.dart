import 'package:juniper_journal/src/shared/widgets/journal_project_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/shared/widgets/journal_log_entry_card.dart';

void main() {
  testWidgets(
    'project footer routes separately from entry and aligns with card content',
    (tester) async {
      var entries = 0;
      var projects = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 367,
              child: JournalLogEntryCard(
                entry: const JournalEntry(
                  id: 'e',
                  projectId: 'p',
                  title: 'Observations',
                  content: [],
                ),
                phaseLabel: 'Discovery',
                status: const SizedBox.shrink(),
                onTap: () => entries++,
                projectLink: JournalProjectLink(
                  projectName: 'Terrarium',
                  onTap: () => projects++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View Project'));
      expect(projects, 1);
      expect(entries, 0);
      expect(find.text('Terrarium'), findsNothing);
      await tester.tap(find.text('Observations'));
      expect(entries, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'activity counts stay horizontal and cards display EcoPoints totals',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 367,
                child: JournalLogEntryCard(
                  entry: const JournalEntry(
                    id: 'e',
                    title: 'Workshop',
                    content: [],
                    projectId: 'p',
                    authorDisplayName: 'Ricky Rios',
                  ),
                  phaseLabel: 'PROTOTYPING',
                  status: const Text('COMPLETED'),
                  ecoPoints: 25,
                  likeCount: 30,
                  commentCount: 5,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('30')).dy,
        tester.getTopLeft(find.text('5')).dy,
      );
      expect(find.text('EcoPoints'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('contributors and comments open separately from entry', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 367,
              child: JournalLogEntryCard(
                entry: const JournalEntry(
                  id: 'entry',
                  projectId: 'project',
                  title: 'Test',
                  authorId: 'author',
                  content: [
                    {
                      'involved': [
                        {'id': 'member', 'name': 'Ricky Rios'},
                      ],
                    },
                  ],
                ),
                phaseLabel: 'DISCOVERY',
                status: const Text('COMPLETED'),
                onTap: () => opened++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('+ 1 contributor'));
    await tester.pumpAndSettle();
    expect(find.text('Contributors'), findsOneWidget);
    expect(find.text('Ricky Rios'), findsOneWidget);
    expect(opened, 0);
    await tester.tap(find.byTooltip('Close contributors'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Comments'));
    await tester.pumpAndSettle();
    expect(find.text('Write a comment…'), findsOneWidget);
    expect(opened, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('log cards grow to contain status, long title and date', (
    tester,
  ) async {
    for (final width in [300.0, 367.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.4),
                    ),
                    child: JournalLogEntryCard(
                      entry: JournalEntry(
                        id: 'test',
                        title:
                            'Journal Entry: Assembly of the Hinge with a longer title',
                        content: const [
                          {
                            'involved': [
                              {'id': 'amelia', 'name': 'Amelia'},
                            ],
                          },
                        ],
                        projectId: 'test',
                        authorId: 'poster',
                        authorDisplayName: 'Ricky Rios',
                        createdAt: DateTime(2026, 10, 14),
                      ),
                      phaseLabel: 'DISCOVERY',
                      status: const Text('COMPLETED'),
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.text('Post by'), findsOneWidget);
      expect(find.text('+ 1 contributor'), findsOneWidget);
      expect(find.text('Journal Entry • Wednesday, Oct 14'), findsOneWidget);
    }
  });
}
