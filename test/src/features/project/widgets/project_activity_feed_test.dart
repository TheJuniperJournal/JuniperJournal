import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project_activity_event.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/widgets/project_activity_feed.dart';

class FeedRepo extends ProjectsRepo {
  FeedRepo(this.events);
  final List<ProjectActivityEvent>? events;
  final calls = <String>[];
  @override
  Future<List<ProjectActivityEvent>?> getProjectActivity(
    String projectId, {
    int offset = 0,
    int limit = 15,
  }) async {
    calls.add('$offset:$limit');
    return events?.skip(offset).take(limit).toList();
  }
}

List<ProjectActivityEvent> events(int count) => List.generate(
  count,
  (i) => ProjectActivityEvent(
    id: 'event-$i',
    kind: i == 0 ? 'timeline_updated' : 'journal_updated',
    description: 'updated item $i',
    sourceId: 'source-$i',
    actorName: 'Member $i',
    createdAt: DateTime(2026, 10, 21, 12, i),
  ),
);
void main() {
  testWidgets('overview shows three items and opens a selected activity', (
    tester,
  ) async {
    final repo = FeedRepo(events(8));
    ProjectActivityEvent? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectActivityFeed(
            projectId: 'p',
            repo: repo,
            entries: const [],
            onOpen: (e) => selected = e,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActivityFeedTile), findsNWidgets(3));
    expect(find.text('View more activity'), findsOneWidget);
    expect(repo.calls, ['0:4']);
    await tester.tap(find.byKey(const ValueKey('activity-event-0')));
    expect(selected?.sourceId, 'source-0');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'history loads batches and selecting closes back to the project',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FeedRepo(events(18));
      ProjectActivityEvent? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectActivityFeed(
              projectId: 'p',
              repo: repo,
              entries: const [],
              onOpen: (e) => selected = e,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View more activity'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectActivityHistory), findsOneWidget);
      expect(repo.calls, contains('0:15'));
      await tester.ensureVisible(find.text('Load more activity'));
      await tester.tap(find.text('Load more activity'));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('15:15'));
      expect(find.text('Load more activity'), findsNothing);
      final tile = find.byKey(const ValueKey('activity-event-17'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectActivityHistory), findsNothing);
      expect(selected?.id, 'event-17');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty history does not show View more', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectActivityFeed(
            projectId: 'p',
            repo: FeedRepo([]),
            entries: const [],
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No activity yet.'), findsOneWidget);
    expect(find.text('View more activity'), findsNothing);
  });
  testWidgets(
    'existing entries remain accessible when feed backend is unavailable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectActivityFeed(
              projectId: 'p',
              repo: FeedRepo(null),
              entries: [
                JournalEntry(
                  id: 'e',
                  title: 'Old entry',
                  projectId: 'p',
                  content: const [],
                  createdAt: DateTime(2026),
                ),
              ],
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-entry-e')), findsOneWidget);
      expect(find.textContaining('Old entry'), findsOneWidget);
    },
  );
}
