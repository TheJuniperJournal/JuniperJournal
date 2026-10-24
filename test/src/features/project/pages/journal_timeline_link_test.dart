import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class _Repo extends ProjectsRepo {
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => const [
    JournalEntry(
      id: 'other',
      projectId: 'p',
      title: 'Other entry',
      content: [],
    ),
    JournalEntry(
      id: 'current',
      projectId: 'p',
      title: 'Current entry',
      content: [
        {
          'iterations': [
            {
              'buildLogs': [
                {'id': 'build-log'},
              ],
            },
          ],
        },
      ],
    ),
  ];
}

void main() {
  for (final child in [false, true]) {
    testWidgets(
      'journal creates standalone timeline event (nested log: $child)',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, String>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<Map<String, String>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CreateJournalTimelineEventSheet(
                        projectId: 'p',
                        projectsRepo: _Repo(),
                        members: const [],
                        entryId: child ? null : 'current',
                        entryChildId: child ? 'build-log' : null,
                        entryTitle: 'Draft title',
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Link Journal Entry'), findsNothing);
        final fields = find.byType(TextField);
        for (var i = 0; i < fields.evaluate().length; i++) {
          await tester.enterText(fields.at(i), 'Event details');
        }
        await tester.ensureVisible(find.text('Create'));
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(result?.containsKey('journalEntryId'), isFalse);
        expect(result?.containsKey('journalEntryTitle'), isFalse);
        expect(result?['name'], 'Event details');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
