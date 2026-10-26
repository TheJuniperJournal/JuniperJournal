import '../../../../support/fake_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/shared/widgets/journal_draft_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class _Repo extends ProjectsRepo {
  List<Map<String, String>> timeline = [];
  List<dynamic>? saved;
  @override
  Future<List<Map<String, String>>?> getTimeline(String id) async => timeline;
  @override
  Future<bool> updateTimeline({
    required String id,
    required List<Map<String, String>> timeline,
  }) async {
    this.timeline = timeline;
    return true;
  }

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
  setUpAll(() => initializeFakeBackend(userId: 'creator'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  testWidgets('created event preview persists without a journal link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    const entry = JournalEntry(
      id: 'current',
      projectId: 'p',
      title: 'Test entry',
      content: [
        {
          'stage': 'prototyping',
          'entryType': 'testing',
          'testingWorkflow': true,
        },
        {
          'stage': 'nextAction',
          'learned': 'Learning',
          'challenges': 'Challenge',
          'nextSteps': 'Next',
        },
        {
          'stage': '_navigation',
          'currentStage': 3,
          'visitedStages': [0, 1, 2, 3],
        },
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: entry,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Timeline Event (Optional)'), findsOneWidget);
    expect(find.text('Link to Existing Event'), findsNothing);
    await tester.ensureVisible(find.text('Create New Timeline Event'));
    await tester.tap(find.text('Create New Timeline Event'));
    await tester.pumpAndSettle();
    for (final field
        in find
            .byType(TextField)
            .evaluate()
            .where(
              (element) =>
                  element
                      .findAncestorWidgetOfExactType<
                        CreateJournalTimelineEventSheet
                      >() !=
                  null,
            )
            .map((element) => find.byWidget(element.widget))
            .toList()) {
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Research sensors');
    }
    await tester.ensureVisible(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(repo.timeline, hasLength(1));
    expect(repo.timeline.single.containsKey('journalEntryId'), isFalse);
    expect(repo.timeline.single.containsKey('journalEntryTitle'), isFalse);
    expect(
      find.byKey(const ValueKey('created-timeline-event-preview')),
      findsOneWidget,
    );
    final next = repo.saved!.whereType<Map>().firstWhere(
      (row) => row['stage'] == 'nextAction',
    );
    expect((next['createdTimelineEvent'] as Map)['name'], 'Research sensors');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: JournalEntry(
            id: 'current',
            projectId: 'p',
            title: 'Test entry',
            content: repo.saved!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('created-timeline-event-preview')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
