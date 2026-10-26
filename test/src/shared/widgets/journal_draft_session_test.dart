import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/widgets/journal_draft_session.dart';

class _Repo extends ProjectsRepo {
  int creates = 0, updates = 0;
  bool fail = false;
  String? lastId;
  @override
  String? get currentUserId => 'user';
  @override
  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    creates++;
    if (fail) return null;
    return JournalEntry(
      id: 'saved',
      projectId: projectId,
      title: title,
      content: content,
      progress: progress,
    );
  }

  @override
  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    updates++;
    lastId = entryId;
    return !fail;
  }
}

Future<JournalEntry> _write(JournalDraftSession session) async =>
    (await session.createJournalEntry(
      projectId: 'p',
      title: 'My draft',
      progress: 'discovery',
      content: [
        {'stage': 'observe', 'notes': 'Work'},
      ],
    ))!;

void main() {
  testWidgets(
    'copied journal URL restores its explicit step without creating data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      var section = 'observe';
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/': (_) => const SizedBox()},
          onGenerateInitialRoutes: (_) => [
            MaterialPageRoute(
              settings: const RouteSettings(arguments: {'step': 'learning'}),
              builder: (_) => StatefulBuilder(
                builder: (context, update) => JournalDraftGuard(
                  session: session,
                  flush: () async => true,
                  section: section,
                  sections: const {
                    'observe': 'Observe',
                    'learning': 'Learning',
                  },
                  onSectionSelected: (value) => update(() => section = value),
                  child: Scaffold(body: Text('Current step: $section')),
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Current step: learning'), findsOneWidget);
      expect(repo.creates, 0);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  test(
    'a failed cloud update still protects current edits for refresh',
    () async {
      final repo = _Repo()..fail = true;
      final session = JournalDraftSession(
        repo,
        'p',
        initial: const JournalEntry(
          id: 'saved',
          title: 'Original',
          projectId: 'p',
          content: [],
        ),
      );
      expect(
        await session.updateJournalEntry(
          entryId: 'saved',
          title: 'Latest edit',
        ),
        false,
      );
      expect(session.locallyProtected, true);
      expect(session.failureLabel, contains('Saved on this device'));
      expect(
        (await JournalDraftSession.interruptedEntry(repo))?.title,
        'Latest edit',
      );
      repo.fail = false;
      expect(
        await session.updateJournalEntry(
          entryId: 'saved',
          title: 'Latest edit',
        ),
        true,
      );
      expect(repo.creates, 0);
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'new work is local; keep creates once; subsequent edits update the same entry',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      final local = await _write(session);
      expect(repo.creates, 0);
      expect(
        (await JournalDraftSession.recoveries(repo, 'p')).single.id,
        local.id,
      );
      expect(await session.keep(), isTrue);
      expect(await session.keep(), isTrue);
      expect(repo.creates, 1);
      expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
      await session.updateJournalEntry(entryId: local.id, title: 'Edited');
      expect(repo.updates, 1);
      expect(repo.lastId, 'saved');
    },
  );
  test(
    'discard removes recovery without creating or deleting a project entry',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      await _write(session);
      await session.discard();
      expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
      expect(repo.creates, 0);
      expect(repo.updates, 0);
    },
  );
  test(
    'recovered work resumes its local identity and is isolated by user',
    () async {
      final repo = _Repo();
      await _write(JournalDraftSession(repo, 'p'));
      final recovered = (await JournalDraftSession.recoveries(
        repo,
        'p',
      )).single;
      final resumed = JournalDraftSession(repo, 'p', initial: recovered);
      await resumed.updateJournalEntry(entryId: recovered.id, title: 'Resumed');
      expect(repo.creates, 0);
      expect(
        (await JournalDraftSession.recoveries(repo, 'p')).single.title,
        'Resumed',
      );
      await resumed.keep();
      expect(repo.creates, 1);
    },
  );
  test('failed save preserves recovery and stays unkept', () async {
    final repo = _Repo()..fail = true;
    final session = JournalDraftSession(repo, 'p');
    await _write(session);
    expect(await session.keep(), isFalse);
    expect(session.kept, isFalse);
    expect(await JournalDraftSession.recoveries(repo, 'p'), hasLength(1));
  });
  for (final choice in ['Save Draft & Exit', 'Discard', 'Keep Editing']) {
    testWidgets('leave prompt: $choice', (tester) async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      await _write(session);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JournalDraftGuard(
                      session: session,
                      flush: () async => true,
                      child: Scaffold(
                        appBar: AppBar(title: const Text('Editor')),
                        body: const SizedBox(),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save this draft?'), findsOneWidget);
      await tester.tap(find.text(choice).last);
      await tester.pumpAndSettle();
      if (choice == 'Keep Editing') {
        expect(find.text('Editor'), findsOneWidget);
        expect(repo.creates, 0);
      } else {
        expect(find.text('Editor'), findsNothing);
        expect(repo.creates, choice == 'Save Draft & Exit' ? 1 : 0);
        expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
      }
    });
  }
  testWidgets('untouched editor exits silently without a database entry', (
    tester,
  ) async {
    final repo = _Repo();
    final session = JournalDraftSession(repo, 'p');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JournalDraftGuard(
                    session: session,
                    flush: () async => true,
                    child: Scaffold(
                      appBar: AppBar(title: const Text('Editor')),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Save this draft?'), findsNothing);
    expect(find.text('Editor'), findsNothing);
    expect(repo.creates, 0);
  });
  test(
    'submitting new notes publishes one entry and clears recovery',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      final local = await _write(session);
      await session.updateJournalEntry(
        entryId: local.id,
        content: [
          {'stage': 'free_notes', 'submitted': true},
          {'type': 'body', 'text': 'Finished notes'},
        ],
      );
      expect(session.kept, isTrue);
      expect(repo.creates, 1);
      expect(session.current!.id, 'saved');
      expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
    },
  );
  test('existing drafts update directly without recovery copies', () async {
    final repo = _Repo();
    final session = JournalDraftSession(
      repo,
      'p',
      initial: const JournalEntry(
        id: 'existing',
        title: 'Draft',
        content: [],
        projectId: 'p',
      ),
    );
    await session.updateJournalEntry(entryId: 'existing', title: 'Updated');
    expect(repo.creates, 0);
    expect(repo.lastId, 'existing');
    expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
  });
  testWidgets('external navigation waits for the draft decision', (
    tester,
  ) async {
    final repo = _Repo();
    final session = JournalDraftSession(repo, 'p');
    await _write(session);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (rootContext) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(rootContext).push(
                MaterialPageRoute(
                  builder: (_) => JournalDraftGuard(
                    session: session,
                    flush: () async => true,
                    child: Scaffold(
                      body: TextButton(
                        onPressed: () => pushAppRoute(
                          rootContext,
                          MaterialPageRoute(
                            builder: (_) =>
                                const Scaffold(body: Text('Other page')),
                          ),
                        ),
                        child: const Text('Navigate'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();
    expect(find.text('Save this draft?'), findsOneWidget);
    expect(find.text('Other page'), findsNothing);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Other page'), findsOneWidget);
    expect(repo.creates, 0);
    expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
  });

  test('stage browsing and automatic defaults are not journal input', () {
    expect(
      journalHasUserInput('Entry 3: Discovery', [
        {
          'stage': '_navigation',
          'visitedStages': [0, 1, 2, 3, 4],
        },
        {
          'stage': 'observations',
          'title': ' ',
          'observed': '',
          'involved': [
            {'id': 'user', 'name': 'Author'},
          ],
        },
        {
          'stage': 'learning',
          'inquiryLens': 'None',
          'inquiryLensData': {'selected_lens': 'None', 'lens_states': {}},
          'dci': [],
          'sep': [],
          'ccc': [],
          'assessment': {},
        },
        {
          'stage': 'decisionMatrix',
          'criteria': [
            {'id': 'auto', 'name': '', 'weight': '', 'ratings': {}},
          ],
          'scores': [],
          'formula': 'Generated formula',
        },
        {
          'stage': 'prototyping',
          'entryType': 'building',
          'buildingWorkflow': true,
          'materialsWorkflow': true,
          'evidence': [],
        },
        {
          'stage': 'nextAction',
          'submitted': false,
          'notes': '',
          'updated_at': 'timestamp',
        },
      ], authorId: 'user'),
      isFalse,
    );
    expect(
      journalHasUserInput('', [
        {'stage': 'free_notes', 'submitted': false},
        {'type': 'body', 'text': ' '},
      ]),
      isFalse,
    );
    expect(journalHasUserInput('My title', []), isTrue);
    expect(
      journalHasUserInput('', [
        {'stage': 'observations', 'observed': 'A finding'},
      ]),
      isTrue,
    );
    expect(
      journalHasUserInput('', [
        {
          'stage': 'learning',
          'dci': ['Ecosystems'],
        },
      ]),
      isTrue,
    );
  });
  test(
    'clearing new work removes its recovery; saved entries stay intact',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      expect(await session.skipEmpty('Entry 1: Discovery', []), isTrue);
      expect(session.current, isNull);
      expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
      await _write(session);
      expect(await session.skipEmpty('Entry 1: Discovery', []), isTrue);
      expect(session.current, isNull);
      expect(await JournalDraftSession.recoveries(repo, 'p'), isEmpty);
      expect(repo.creates, 0);
      final saved = JournalDraftSession(
        repo,
        'p',
        initial: const JournalEntry(
          id: 'saved',
          title: 'Entry 1: Discovery',
          projectId: 'p',
          content: [],
        ),
      );
      expect(await saved.skipEmpty('Entry 1: Discovery', []), isFalse);
    },
  );
  test(
    'reload restores temporary work without creating a kept draft',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(repo, 'p');
      final original = await _write(session);
      final restored = await JournalDraftSession.interruptedEntry(repo);
      expect(restored!.id, original.id);
      expect(restored.content, original.content);
      expect(repo.creates, 0);
      final reopened = JournalDraftSession(repo, 'p', initial: restored);
      await reopened.updateJournalEntry(
        entryId: restored.id,
        title: 'Continued',
      );
      expect(
        (await JournalDraftSession.interruptedEntry(repo))!.title,
        'Continued',
      );
      expect(await reopened.keep(), isTrue);
      expect(repo.creates, 1);
      await reopened.finishEditing();
      expect(await JournalDraftSession.interruptedEntry(repo), isNull);
    },
  );
  test(
    'saved draft reload retains identity and normal exit clears interruption',
    () async {
      final repo = _Repo();
      final session = JournalDraftSession(
        repo,
        'p',
        initial: const JournalEntry(
          id: 'existing',
          title: 'Kept draft',
          projectId: 'p',
          content: [],
        ),
      );
      await session.updateJournalEntry(
        entryId: 'existing',
        title: 'Recent edit',
      );
      final restored = (await JournalDraftSession.interruptedEntry(repo))!;
      expect(restored.id, 'existing');
      expect(restored.title, 'Recent edit');
      final reopened = JournalDraftSession(repo, 'p', initial: restored);
      await reopened.updateJournalEntry(
        entryId: restored.id,
        title: 'More edits',
      );
      expect(repo.creates, 0);
      expect(repo.lastId, 'existing');
      await reopened.finishEditing();
      expect(await JournalDraftSession.interruptedEntry(repo), isNull);
    },
  );
  test('discard and blank attempts never reopen after reload', () async {
    final repo = _Repo();
    final session = JournalDraftSession(repo, 'p');
    await _write(session);
    await session.discard();
    expect(await JournalDraftSession.interruptedEntry(repo), isNull);
    await session.skipEmpty('Entry 1: Discovery', []);
    expect(await JournalDraftSession.interruptedEntry(repo), isNull);
  });
}
