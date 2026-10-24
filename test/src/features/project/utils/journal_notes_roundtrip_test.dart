import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';

class _Repo extends ProjectsRepo {
  List<dynamic>? saved;
  @override
  String? get currentUserId => 'author';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    saved = content;
    return true;
  }
}

// Exercises the current block format through the real editor rather than the
// retired URL codec. Edits must retain neighboring formula/table evidence.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('formula and table survive editing, saving and reopening notes', (
    tester,
  ) async {
    final repo = _Repo();
    const formula = r'x = \frac{1}{2}';
    const rows = [
      ['Trial', 'Result'],
      ['A', '10'],
      ['B', '20'],
    ];
    final blocks = <dynamic>[
      {'stage': 'free_notes', 'submitted': false},
      {'type': 'body', 'text': 'Observation'},
      {'type': 'math', 'latex': formula},
      {'type': 'table', 'rows': rows},
    ];
    Widget editor(List<dynamic> content) => MaterialApp(
      home: JournalEntryEditorScreen(
        projectId: 'p',
        projectName: 'QA',
        tags: const [],
        entryId: 'entry',
        entryAuthorId: 'author',
        initialTitle: 'Mixed notes',
        initialContent: content,
        initialProgress: 'discover',
        freeNotes: true,
        projectsRepo: repo,
      ),
    );
    await tester.pumpWidget(editor(blocks));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('free-notes-body-0')),
      'Updated observation',
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(repo.saved, isNotNull);
    final saved = repo.saved!;
    expect(
      saved.whereType<Map>().singleWhere((b) => b['type'] == 'math')['latex'],
      formula,
    );
    expect(
      saved.whereType<Map>().singleWhere((b) => b['type'] == 'table')['rows'],
      rows,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(editor(saved));
    await tester.pumpAndSettle();
    expect(find.text('Updated observation'), findsOneWidget);
    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
