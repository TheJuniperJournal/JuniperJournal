import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/project_timeline_tab.dart';

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
      'journal-stage link stays on current entry (nested log: $child)',
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
        final selector = tester.widget<JournalEntryLinkSelector>(
          find.byType(JournalEntryLinkSelector),
        );
        expect(selector.selected?.id, 'current');
        expect(selector.entries.first.id, 'current');
        final fields = find.byType(TextField);
        for (var i = 0; i < fields.evaluate().length; i++) {
          await tester.enterText(fields.at(i), 'Event details');
        }
        await tester.ensureVisible(find.byType(JournalEntryLinkSelector));
        await tester.tap(find.byType(JournalEntryLinkSelector));
        await tester.pumpAndSettle();
        expect(selector.selectable, isFalse);
        expect(selector.entries, hasLength(1));
        expect(find.text('Other entry'), findsNothing);
        await tester.ensureVisible(find.text('Create'));
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(result?['journalEntryId'], 'current');
        expect(result?['journalEntryTitle'], 'Current entry');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'timeline selector offers a field-width dropdown and changes entries',
    (tester) async {
      final entries = await _Repo().getJournalEntries(projectId: 'p');
      JournalEntry? selected = entries!.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (_, setState) => JournalEntryLinkSelector(
                    entries: entries,
                    selected: selected,
                    onSelected: (entry) => setState(() => selected = entry),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(JournalEntryLinkSelector));
      await tester.pumpAndSettle();
      final item = find.widgetWithText(
        PopupMenuItem<JournalEntry>,
        'Current entry',
      );
      expect(tester.getSize(item).width, closeTo(320, 1));
      await tester.tap(item);
      await tester.pumpAndSettle();
      expect(selected?.id, 'current');
      expect(tester.takeException(), isNull);
    },
  );
}
