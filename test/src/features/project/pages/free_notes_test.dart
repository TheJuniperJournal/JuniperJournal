import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

class _Repo extends ProjectsRepo {
  @override
  String? get currentUserId => 'test-user';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];

  List<dynamic>? saved;
  String? phase;
  int creates = 0;
  int updates = 0;
  bool fail = false;
  @override
  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    if (fail) return null;
    creates++;
    saved = content;
    phase = progress;
    return JournalEntry(
      id: 'new',
      title: title,
      content: content,
      projectId: projectId,
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
    if (fail) return false;
    updates++;
    saved = content;
    phase = progress;
    return true;
  }
}

Widget _host(_Repo repo, String phase) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => openNewProjectJournal(
          context,
          projectId: 'p',
          phase: phase,
          projectsRepo: repo,
        ),
        child: const Text('New journal entry'),
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Add text reuses the empty canvas and typing removes its placeholder',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(_host(repo, 'ideating'));
      await tester.tap(find.text('New journal entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Write something…'), findsOneWidget);
      await tester.tap(find.byTooltip('Add text'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('free-notes-body-1')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('free-notes-body-0')),
        'Observation',
      );
      await tester.pumpAndSettle();
      expect(find.text('Write something…'), findsNothing);
      expect(find.text('Observation'), findsOneWidget);
    },
  );
  testWidgets('typing in another existing block hides the canvas placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryEditorScreen(
          projectId: 'p',
          projectName: 'Project',
          tags: const [],
          entryId: 'e',
          initialTitle: 'Notes',
          initialProgress: 'ideating',
          freeNotes: true,
          projectsRepo: _Repo(),
          initialContent: const [
            {'stage': 'free_notes', 'submitted': false},
            {'type': 'body', 'text': ''},
            {'type': 'body', 'text': ''},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Write something…'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('free-notes-body-1')),
      'Text below',
    );
    await tester.pumpAndSettle();
    expect(find.text('Write something…'), findsNothing);
    expect(find.text('Text below'), findsOneWidget);
  });

  test('free notes require a submitted, meaningful canvas', () {
    JournalEntry entry(List<dynamic> blocks, {bool submitted = true}) =>
        JournalEntry(
          id: 'e',
          title: 'Notes',
          projectId: 'p',
          content: [
            {'stage': 'free_notes', 'submitted': submitted},
            ...blocks,
          ],
        );
    expect(
      journalEntryIsComplete(
        entry([
          {'type': 'body', 'text': '  '},
        ]),
      ),
      isFalse,
    );
    expect(
      journalEntryIsComplete(
        entry([
          {
            'type': 'table',
            'rows': [
              ['', ''],
            ],
          },
        ]),
      ),
      isFalse,
    );
    expect(
      journalEntryIsComplete(
        entry([
          {'type': 'body', 'text': 'Observation'},
        ], submitted: false),
      ),
      isFalse,
    );
    for (final block in [
      {'type': 'body', 'text': 'Observation'},
      {'type': 'header', 'text': 'Idea'},
      {'type': 'image', 'url': 'https://example.com/photo.png'},
      {
        'type': 'table',
        'rows': [
          ['Result', '3'],
        ],
      },
      {'type': 'math', 'latex': 'x=2'},
    ]) {
      expect(journalEntryIsComplete(entry([block])), isTrue);
    }
  });

  for (final phase in [
    'discover',
    'ideating',
    'implementation',
    'prototyping',
  ]) {
    testWidgets('$phase offers free notes and saves under its phase', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(_host(repo, phase));
      await tester.tap(find.text('New journal entry'));
      await tester.pumpAndSettle();
      expect(find.text('Free Notes'), findsOneWidget);
      if (phase == 'prototyping') {
        expect(find.text('Building'), findsOneWidget);
        expect(find.text('Testing'), findsOneWidget);
        expect(find.text('Technical Analysis'), findsOneWidget);
      } else {
        expect(find.text('Guided'), findsOneWidget);
      }
      await tester.tap(find.text('Free Notes'));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      expect(find.byType(JournalEntryEditorScreen), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Entry Title (Optional)'),
        'Notes',
      );
      await tester.enterText(
        find.byKey(const ValueKey('free-notes-body-0')),
        'First observation\nSecond paragraph',
      );
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(normalizePhase(repo.phase), phase);
      expect(
        journalEntryIsComplete(
          JournalEntry(
            id: 'e',
            title: 'Notes',
            projectId: 'p',
            content: repo.saved!,
          ),
        ),
        isTrue,
      );
      expect(
        (repo.saved!.last as Map)['text'],
        'First observation\nSecond paragraph',
      );
      expect(find.text('New journal entry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('untitled meaningful notes submit with a generated title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(_host(repo, 'discover'));
    await tester.tap(find.text('New journal entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free Notes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('free-notes-body-0')),
      'Keep these notes',
    );
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(
      repo.saved!.whereType<Map>().any((r) => r['text'] == 'Keep these notes'),
      isTrue,
    );
  });

  testWidgets(
    'blank canvas creates nothing and cancelling the choice creates nothing',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(_host(repo, 'discover'));
      await tester.tap(find.text('New journal entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      await tester.tap(find.text('New journal entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free Notes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'reopened notes preserve blocks, can reorder, and preview is read only',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      final blocks = <dynamic>[
        {'stage': 'free_notes', 'submitted': true},
        {'type': 'header', 'text': 'My heading'},
        {'type': 'body', 'text': 'My observation'},
        {'type': 'math', 'latex': 'x=2'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalEntryEditorScreen(
                      projectId: 'p',
                      projectName: 'Project',
                      tags: const [],
                      entryId: 'existing',
                      initialTitle: 'Notes',
                      initialContent: blocks,
                      initialProgress: 'prototyping',
                      projectsRepo: repo,
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
      expect(find.text('My heading'), findsOneWidget);
      await tester.tap(find.text('My observation'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move or remove block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      expect(find.text('Submit'), findsNothing);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(repo.updates, greaterThanOrEqualTo(1));
      expect((repo.saved![1] as Map)['text'], 'My observation');
      await tester.pumpWidget(
        MaterialApp(
          home: freeNotesEntryPage(
            JournalEntry(
              id: 'e',
              title: 'Notes',
              projectId: 'p',
              progress: 'prototyping',
              content: repo.saved!,
            ),
            repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My heading'), findsOneWidget);
      expect(find.byTooltip('Add text'), findsNothing);
      expect(find.text('Submit'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'autosaved notes remain a draft and an image-only note can be saved',
    (tester) async {
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JournalEntryEditorScreen(
                      projectId: 'p',
                      projectName: 'Project',
                      tags: const [],
                      entryId: '',
                      initialTitle: 'Notes',
                      initialContent: const [],
                      initialProgress: 'discover',
                      freeNotes: true,
                      projectsRepo: repo,
                      uploadImage: (_) async =>
                          'https://example.com/test-photo.png',
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
      await tester.enterText(
        find.byKey(const ValueKey('free-notes-body-0')),
        'A draft observation',
      );
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(repo.creates, 0);
      expect(repo.saved, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('free-notes-body-0')),
        '',
      );
      await tester.tap(find.byTooltip('Add image from gallery'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(repo.updates, greaterThanOrEqualTo(1));
      expect(
        repo.saved!.whereType<Map>().any(
          (block) =>
              block['type'] == 'image' &&
              block['url'] == 'https://example.com/test-photo.png',
        ),
        true,
      );
      expect(
        journalEntryIsComplete(
          JournalEntry(
            id: 'e',
            title: 'Notes',
            projectId: 'p',
            content: repo.saved!,
          ),
        ),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'phase defaults to its dashboard and changing it explains and saves the destination',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(_host(repo, 'ideating'));
      await tester.tap(find.text('New journal entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free Notes'));
      await tester.pumpAndSettle();
      expect(
        find.text('This entry appears in the Ideation dashboard.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ideation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prototyping').last);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Saving moves this entry to the Prototyping dashboard instead of Ideation.',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Entry Title (Optional)'),
        'Prototype',
      );
      await tester.enterText(
        find.byKey(const ValueKey('free-notes-body-0')),
        'Prototype notes',
      );
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(normalizePhase(repo.phase), 'prototyping');
      expect(repo.creates, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
