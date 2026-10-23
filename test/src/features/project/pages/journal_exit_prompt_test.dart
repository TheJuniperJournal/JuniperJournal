import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/shared/widgets/journal_draft_session.dart';

class _Repo extends ProjectsRepo {
  int creates = 0;
  @override
  String? get currentUserId => 'user';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
  @override
  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    creates++;
    return JournalEntry(
      id: 'kept',
      projectId: projectId,
      title: title,
      content: content,
      progress: progress,
    );
  }
}

Widget _editor(String type, _Repo repo) {
  final initial = JournalEntry(
    id: 'recovery-test',
    projectId: 'p',
    title: '',
    progress: type,
    content: type == 'prototyping'
        ? [
            {'stage': 'prototyping', 'entryType': 'technical_analysis'},
          ]
        : [],
  );
  return switch (type) {
    'discovery' => DiscoveryObservationEntryPage(
      projectId: 'p',
      projectsRepo: repo,
    ),
    'ideating' => IdeatingEntryPage(
      projectId: 'p',
      projectsRepo: repo,
      entry: initial,
    ),
    'implementation' => ImplementationEntryPage(
      projectId: 'p',
      projectsRepo: repo,
      entry: initial,
    ),
    'prototyping' => PrototypingJournalEntryPage(
      projectId: 'p',
      projectsRepo: repo,
      entry: initial,
    ),
    _ => JournalEntryEditorScreen(
      projectId: 'p',
      projectName: '',
      tags: const [],
      entryId: '',
      initialTitle: '',
      initialContent: const [],
      initialProgress: 'Discovery',
      freeNotes: true,
      projectsRepo: repo,
    ),
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final type in [
    'discovery',
    'ideating',
    'implementation',
    'prototyping',
    'notes',
  ]) {
    for (final choice in ['Discard', 'Save Draft & Exit', 'Keep Editing']) {
      testWidgets('$type green arrow offers exit choices: $choice', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(900, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _editor(type, repo)),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'Work to keep');
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        expect(repo.creates, 0);
        // Exercise the visible arrow, rather than the system-back test helper.
        await tester.tap(find.byKey(const ValueKey('content-back-chevron')));
        await tester.pumpAndSettle();
        expect(find.text('Save this draft?'), findsOneWidget);
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        if (choice == 'Keep Editing') {
          expect(find.byType(TextField), findsWidgets);
          expect(repo.creates, 0);
        } else {
          expect(find.byType(TextField), findsNothing);
          expect(repo.creates, choice == 'Save Draft & Exit' ? 1 : 0);
          expect(await JournalDraftSession.interruptedEntry(repo), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
