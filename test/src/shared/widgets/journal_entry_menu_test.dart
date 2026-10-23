import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/widgets/journal_entry_menu.dart';

class MenuRepo extends ProjectsRepo {
  String? user = 'owner';
  String? deleted;
  bool succeeds = true;
  bool member = true;
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => member;
  @override
  String? get currentUserId => user;
  @override
  Future<bool> deleteJournalEntry({required String entryId}) async {
    deleted = entryId;
    return succeeds;
  }
}

const entry = JournalEntry(
  id: 'entry',
  projectId: 'p',
  title: 'Prototype',
  content: [],
  authorId: 'author',
);
const project = Project(
  id: 'p',
  projectName: 'Project',
  tags: [],
  userId: 'owner',
);
void main() {
  testWidgets('selected accepted participants get Edit but not Delete', (
    tester,
  ) async {
    final repo = MenuRepo()..user = 'participant';
    const selectedEntry = JournalEntry(
      id: 'entry',
      projectId: 'p',
      title: 'Shared',
      authorId: 'author',
      content: [
        {
          'stage': 'overview',
          'involved': [
            {'id': 'participant'},
          ],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalEntryMenu(
            entry: selectedEntry,
            project: project,
            repo: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });
  testWidgets('removed project members lose participant editing access', (
    tester,
  ) async {
    final repo = MenuRepo()
      ..user = 'participant'
      ..member = false;
    const selectedEntry = JournalEntry(
      id: 'entry',
      projectId: 'p',
      title: 'Shared',
      authorId: 'author',
      content: [
        {
          'stage': 'overview',
          'involved': [
            {'id': 'participant'},
          ],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalEntryMenu(
            entry: selectedEntry,
            project: project,
            repo: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('More options'), findsNothing);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'project owner can delete another author entry after confirmation',
    (tester) async {
      final repo = MenuRepo();
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalEntryMenu(
              entry: entry,
              project: project,
              repo: repo,
              onDeleted: () => changed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isNull);
      expect(find.text('Delete entry?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isNull);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.deleted, 'entry');
      expect(changed, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unrelated viewer has no edit or delete menu', (tester) async {
    final repo = MenuRepo()..user = 'viewer';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalEntryMenu(entry: entry, project: project, repo: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('More options'), findsNothing);
  });
  testWidgets('failure keeps the preview open and reports the error', (
    tester,
  ) async {
    final repo = MenuRepo()..succeeds = false;
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalEntryMenu(
            entry: entry,
            project: project,
            repo: repo,
            onDeleted: () => changed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(changed, false);
    expect(
      find.text('Could not delete this entry. Please try again.'),
      findsOneWidget,
    );
  });
}
