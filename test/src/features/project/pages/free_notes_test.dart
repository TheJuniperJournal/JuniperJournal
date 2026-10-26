import 'package:flutter/services.dart';
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
  testWidgets('clicking the canvas focuses text without an Add text tool', (
    tester,
  ) async {
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
    expect(find.byTooltip('Add text'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('free-notes-write-area')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('free-notes-body-1')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('free-notes-body-0')),
      'Observation',
    );
    await tester.pumpAndSettle();
    expect(find.text('Write something…'), findsNothing);
    expect(find.text('Observation'), findsOneWidget);
  });
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
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
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
      await tester.tap(find.byKey(const ValueKey('notes-formula-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move formula up'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.updates, greaterThanOrEqualTo(1));
      expect((repo.saved![2] as Map)['type'], 'math');
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
  testWidgets('free notes retain the creation phase without a phase selector', (
    tester,
  ) async {
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
    expect(find.text('Phase'), findsNothing);
    expect(
      find.text('This entry appears in the Ideation dashboard.'),
      findsNothing,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextField),
      ),
      'Prototype',
    );
    await tester.enterText(
      find.byKey(const ValueKey('free-notes-body-0')),
      'Prototype notes',
    );
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(normalizePhase(repo.phase), 'ideating');
    expect(repo.creates, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'paragraph formatting saves and renders identically in read-only canvas',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEntryEditorScreen(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            entryId: 'e',
            initialTitle: 'Formatting',
            freeNotes: true,
            projectsRepo: repo,
            initialContent: const [
              {'stage': 'free_notes', 'submitted': false},
              {
                'type': 'body',
                'text': 'A formatted paragraph',
                'fontFamily': 'Manrope',
              },
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('free-notes-body-0')));
      expect(find.byKey(const ValueKey('notes-Font')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('notes-Font size')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bold'));
      await tester.tap(find.byTooltip('Italic'));
      await tester.tap(find.byTooltip('Underline'));
      await tester.tap(find.byTooltip('Align center'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final saved = repo.saved!.whereType<Map>().firstWhere(
        (r) => r['type'] == 'body',
      );
      expect(saved['fontFamily'], 'Manrope');
      expect(saved['fontSize'], 24);
      expect(saved['alignment'], 'center');
      expect(saved['bold'], true);
      expect(saved['italic'], true);
      expect(saved['underline'], true);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEntryEditorScreen(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            entryId: 'e',
            initialTitle: 'Formatting',
            initialContent: repo.saved!,
            freeNotes: true,
            readOnly: true,
            canvasOnly: true,
            projectsRepo: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'A formatted paragraph',
        ),
      );
      expect(text.textAlign, TextAlign.center);
      expect(text.style!.fontFamily, 'Manrope');
      expect(text.style!.fontSize, 24);
      expect(text.style!.fontStyle, FontStyle.italic);
      expect(text.style!.decoration, TextDecoration.underline);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('saved table fits the canvas and long text stays inside cells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryEditorScreen(
          projectId: 'p',
          projectName: 'Project',
          tags: const [],
          entryId: 'e',
          initialTitle: 'Existing table',
          freeNotes: true,
          projectsRepo: repo,
          initialContent: [
            {'stage': 'free_notes'},
            {
              'type': 'table',
              'headerRow': true,
              'rows': List.generate(2, (_) => List.filled(6, '')),
            },
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final table = find.byKey(const ValueKey('notes-table-0'));
    expect(tester.getRect(table).right, lessThanOrEqualTo(390));
    final field = find.descendant(
      of: find.byKey(const ValueKey('notes-cell-0-0-0')),
      matching: find.byType(TextField),
    );
    await tester.enterText(
      field,
      'A longer observation that must wrap within its cell.',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).style!.fontWeight, FontWeight.w400);
    expect(
      tester.widget<TextField>(field).decoration!.enabledBorder,
      InputBorder.none,
    );
    expect(
      tester.getRect(field).left,
      greaterThanOrEqualTo(tester.getRect(table).left),
    );
    expect(
      tester.getRect(field).right,
      lessThanOrEqualTo(
        tester.getRect(table).left + tester.getSize(table).width / 6 + .1,
      ),
    );
    expect(tester.getSize(field).height, greaterThan(44));
    await tester.tap(find.byTooltip('Bold'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final saved = repo.saved!.whereType<Map>().firstWhere(
      (r) => r['type'] == 'table',
    );
    expect(saved['cellFormatting']['0:0']['bold'], true);
    final other = find.descendant(
      of: find.byKey(const ValueKey('notes-cell-0-0-1')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(other).style!.fontWeight, FontWeight.w400);
    expect(find.byTooltip('Add text'), findsNothing);
    expect(find.byKey(const ValueKey('notes-Font')), findsNothing);
    expect(find.byTooltip('Insert table'), findsNothing);
    expect(find.byTooltip('Insert formula'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['math', 'table', 'image']) {
    testWidgets('selected $kind can be deleted on canvas with Backspace', (
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
            initialTitle: 'Delete element',
            freeNotes: true,
            projectsRepo: _Repo(),
            initialContent: [
              {'stage': 'free_notes'},
              if (kind == 'math') {'type': 'math', 'latex': 'x=2'},
              if (kind == 'table')
                {
                  'type': 'table',
                  'rows': [
                    ['Value'],
                  ],
                },
              if (kind == 'image')
                {'type': 'image', 'url': 'https://qa.invalid/image.png'},
              {'type': 'body', 'text': 'Keep this text'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final text = find.byKey(const ValueKey('free-notes-body-1'));
      await tester.tap(text);
      final controller = tester.widget<TextField>(text).controller!;
      controller.selection = const TextSelection.collapsed(offset: 0);
      // First Backspace selects the preceding element, the next deletes it.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.text('Keep this text'), findsOneWidget);
      expect(
        find.byTooltip('Delete ${kind == 'math' ? 'formula' : kind}'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('free-notes-body-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'clicking below an image creates a typing area and Submit stays last',
    (tester) async {
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
            initialTitle: 'Canvas',
            freeNotes: true,
            projectsRepo: _Repo(),
            initialContent: const [
              {'stage': 'free_notes'},
              {'type': 'math', 'latex': 'x=2'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('free-notes-write-area')));
      await tester.pumpAndSettle();
      final text = find.byKey(const ValueKey('free-notes-body-1'));
      await tester.enterText(
        text,
        List.filled(40, 'A line of notes').join('\n'),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Submit'),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('free-notes-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsNothing);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Submit'), findsOneWidget);
      final submit = tester.getRect(find.text('Submit'));
      expect(submit.bottom, greaterThan(1300));
      expect(submit.bottom, lessThan(1400));
      expect(tester.takeException(), isNull);
    },
  );
}
