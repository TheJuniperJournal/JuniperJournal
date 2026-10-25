import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';

class _Repo extends ProjectsRepo {
  List<dynamic>? saved;
  @override
  String? get currentUserId => 'author';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => const [
    UserProfile(id: 'author', displayName: 'Alex'),
    UserProfile(id: 'member', displayName: 'Morgan'),
  ];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
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

const _entry = JournalEntry(
  id: 'e',
  authorId: 'author',
  projectId: 'p',
  title: 'Discovery',
  progress: 'discover',
  content: [
    {
      'stage': 'observations',
      'title': 'A challenge',
      'observed': 'Uneven water access',
      'known': 'Different locations have different needs',
    },
    {
      'stage': 'analyze',
      'rootCauses': [
        {
          'title': 'Existing cause',
          'description': 'A possible contributor',
          'reason': 'A reason to investigate',
        },
      ],
      'patternChange': 'Reduction',
      'patternExplanation': 'Reduce avoidable use',
    },
  ],
);
Future<void> _open(
  WidgetTester tester,
  _Repo repo, {
  double width = 1100,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: DiscoveryObservationEntryPage(
        projectId: 'p',
        projectsRepo: repo,
        entry: _entry,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'root cause popup adds, edits and cancels without changing a saved cause',
    (tester) async {
      final repo = _Repo();
      await _open(tester, repo);
      await tester.tap(find.text('Analyze').first);
      await tester.pumpAndSettle();
      expect(find.text('Root Cause'), findsNothing);
      await tester.tap(find.text('+ Add Root Cause'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'New cause');
      await tester.enterText(fields.at(1), 'Possible explanation');
      await tester.enterText(
        fields.at(2),
        'Observed differences support investigating this',
      );
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('New cause'), findsOneWidget);
      await tester.tap(find.text('New cause'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(0), 'Updated cause');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Updated cause'), findsOneWidget);
      await tester.tap(find.text('Updated cause'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(0), 'Cancelled edit');
      await tester.tap(find.byTooltip('Close root cause'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard').last);
      await tester.pumpAndSettle();
      expect(find.text('Updated cause'), findsOneWidget);
      expect(find.text('Cancelled edit'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final data = repo.saved!.whereType<Map>().firstWhere(
        (s) => s['stage'] == 'analyze',
      );
      expect((data['rootCauses'] as List).length, 2);
      expect(find.text('Saved'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Saved')).dy,
        greaterThan(tester.getCenter(find.text('Next').last).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [390.0, 1100.0]) {
    testWidgets('question choices wrap without clipping at width $width', (
      tester,
    ) async {
      await _open(tester, _Repo(), width: width);
      await tester.tap(find.text('Question').first);
      await tester.pumpAndSettle();
      final how = tester.getRect(find.text('How').first);
      final where = tester.getRect(find.text('Where').first);
      if (width >= 640) expect((how.top - where.top).abs(), lessThan(1));
      expect(how.left, greaterThanOrEqualTo(0));
      expect(where.right, lessThanOrEqualTo(width));
      final cards = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_QuestionTypeTile',
      );
      expect(cards, findsNWidgets(4));
      final heights = [
        for (final element in cards.evaluate())
          tester.getSize(find.byWidget(element.widget)).height,
      ];
      expect(
        heights.every((height) => (height - heights.first).abs() < 1),
        isTrue,
      );
      // The composer has explicit inset space above its first line.
      final composer = find.byType(TextField).last;
      final decoration = tester.widget<TextField>(composer).decoration!;
      expect(decoration.contentPadding, const EdgeInsets.all(14));
      await tester.ensureVisible(composer);
      await tester.enterText(composer, 'How could this improve access?');
      await tester.pumpAndSettle();
      expect(find.text('How could this improve access?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
