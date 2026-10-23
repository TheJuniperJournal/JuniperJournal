import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/widgets/journal_collaboration_panel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/services/journal_collaboration.dart';
import 'package:juniper_journal/src/features/project/services/journal_text_selection.dart';

JournalEntry entry(String text) => JournalEntry(
  id: 'e',
  projectId: 'p',
  title: 'Notes',
  content: [
    {'stage': 'free_notes'},
    {'id': 'body', 'type': 'body', 'text': text},
  ],
);

class Repo extends ProjectsRepo {
  bool offline = false, owned = true;
  Map<String, dynamic>? receivedBase;
  @override
  Future<Map<String, dynamic>> journalCollaborationHeartbeat(
    String id,
    String session,
    String section,
  ) async {
    if (offline) throw StateError('offline');
    final e = entry('Remote');
    return {
      'owns_section': owned,
      'entry': {'id': e.id, 'project_id': e.projectId, ...journalDocument(e)},
      'people': [
        {
          'session_id': 'other-tab',
          'user_id': 'other',
          'name': 'Maya',
          'section': section,
          'editing': !owned,
        },
      ],
    };
  }

  @override
  Future<JournalEntry> saveCollaborativeJournal(
    String id,
    String session,
    Map<String, dynamic> base,
    Map<String, dynamic> desired,
    bool complete,
  ) async {
    receivedBase = base;
    return entry('Merged');
  }

  @override
  Future<void> releaseJournalCollaboration(String id, String session) async {}
}

void main() {
  testWidgets('locked editor keeps presence and stage picker available', (
    tester,
  ) async {
    final repo = Repo()..owned = false;
    final live = JournalCollaboration(repo, 'e', entry('Original'));
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalCollaborationPanel(
            collaboration: live,
            flush: () async => true,
            section: 'overview',
            sections: const {'overview': 'Overview', 'learning': 'Learning'},
            onSectionSelected: (value) => selected = value,
            child: const TextField(
              decoration: InputDecoration(labelText: 'Entry summary'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Maya is editing this section'), findsOneWidget);
    expect(
      tester.widget<AbsorbPointer>(find.byType(AbsorbPointer).last).absorbing,
      isTrue,
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learning').last);
    await tester.pumpAndSettle();
    expect(selected, 'learning');
    expect(find.byTooltip('Leave entry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    live.dispose();
  });
  test('baseline is isolated from mutable editor content', () {
    final original = entry('Original');
    final live = JournalCollaboration(Repo(), 'e', original);
    (original.content.last as Map)['text'] = 'Changed outside service';
    expect((live.localBase['content'] as List).last['text'], 'Original');
    live.dispose();
  });
  test('tabs have unique UUID lease identities', () {
    final ids = List.generate(200, (_) => journalEditorSessionId());
    expect(ids.toSet(), hasLength(200));
    expect(
      ids.every(
        (id) => RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
      ),
      isTrue,
    );
  });
  test('guided section is read-only while another session owns it', () async {
    final repo = Repo()..owned = false;
    final live = JournalCollaboration(repo, 'e', entry('Original'));
    await live.start('learning');
    expect(live.canEdit, isFalse);
    expect(live.owner?.name, 'Maya');
    await expectLater(
      live.save(journalDocument(entry('Local')), false),
      throwsStateError,
    );
    live.dispose();
  });
  test(
    'disconnect stops writes; successful heartbeat restores editing',
    () async {
      final repo = Repo();
      final live = JournalCollaboration(repo, 'e', entry('Original'));
      await live.start('learning');
      expect(live.canEdit, isTrue);
      repo.offline = true;
      await live.poll();
      expect(live.canEdit, isFalse);
      repo.offline = false;
      await live.poll();
      expect(live.canEdit, isTrue);
      live.dispose();
    },
  );
  test('poll never advances the base past unhydrated local controls', () async {
    final repo = Repo();
    final original = entry('Original');
    final live = JournalCollaboration(repo, 'e', original);
    await live.start('free_notes');
    await live.save(journalDocument(entry('Local')), false);
    expect(repo.receivedBase, journalDocument(original));
    expect(live.base, journalDocument(entry('Merged')));
    expect(live.localBase, journalDocument(entry('Local')));
    live.dispose();
  });
  test('remote text insertion preserves selection relative to local text', () {
    final next = remoteJournalTextValue(
      const TextEditingValue(
        text: 'Hello world',
        selection: TextSelection.collapsed(offset: 11),
      ),
      'Maya: Hello world',
    );
    expect(next.selection.baseOffset, 17);
    expect(remoteJournalTextValue(next, 'Hi').selection.baseOffset, 2);
  });
}
