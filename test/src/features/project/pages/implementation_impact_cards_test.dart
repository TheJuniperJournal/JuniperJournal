import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';

class _Repo extends ProjectsRepo {
  bool empty = false;
  int creates = 0;
  @override
  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    creates++;
    return null;
  }

  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => empty
      ? []
      : [
          const ImpactEntry(
            id: 'i',
            projectId: 'p',
            title: 'Growth',
            metric: 'Biological Growth',
            impactScale: 'Sapling (Small)',
            patternType: 'Regeneration',
            evidenceType: 'Photo',
            confidenceScore: 'High',
            measurement: 12,
            measurementUnit: 'units',
            ecoPoints: 120,
            linkedJournalEntryId: 'e',
          ),
        ];

  List<dynamic>? saved;
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'zero impacts can advance and adding an impact first syncs a local draft',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo()..empty = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ImplementationEntryPage(
            projectId: 'p',
            projectsRepo: repo,
            entry: const JournalEntry(
              id: 'recovery-test',
              projectId: 'p',
              title: 'Draft',
              progress: 'implementation',
              content: [
                {'stage': 'overview', 'summary': 'Implemented a garden'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assessment').first);
      await tester.pumpAndSettle();
      expect(find.text('Your Impacts (0)'), findsOneWidget);
      expect(find.text('Add at least one impact assessment.'), findsNothing);
      await tester.tap(find.text('+ Add Impact'));
      await tester.pumpAndSettle();
      expect(repo.creates, 1);
      expect(
        find.text('Could not save draft. Your work is still here.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Your Impacts (0)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'completed implementation autosaves edits without clearing submission',
    (tester) async {
      final repo = _Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: ImplementationEntryPage(
            projectId: 'p',
            projectsRepo: repo,
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Entry',
              content: [
                {'stage': 'overview', 'summary': 'Original'},
                {'stage': 'reflection', 'submitted': true},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.minLines == 5).first,
        'Updated summary',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        (repo.saved!.whereType<Map>().firstWhere(
          (row) => row['stage'] == 'reflection',
        ))['submitted'],
        isTrue,
      );
      expect(
        (repo.saved!.whereType<Map>().firstWhere(
          (row) => row['stage'] == 'overview',
        ))['summary'],
        'Updated summary',
      );
    },
  );

  testWidgets('implementation summary and reflection expect longer responses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ImplementationEntryPage(
          projectId: 'p',
          projectsRepo: _Repo(),
          entry: const JournalEntry(
            id: 'e',
            projectId: 'p',
            title: 'Entry',
            content: [
              {'stage': 'overview', 'summary': 'Implemented a garden'},
              {
                'stage': 'learning',
                'dci': ['Life'],
                'sep': ['Investigate'],
                'ccc': ['Patterns'],
                'inquiryLens': 'Observe',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.minLines == 5 && field.maxLines == null),
      isTrue,
    );
    await tester.tap(find.text('Assessment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reflection').first);
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.minLines == 5)
        .toList();
    expect(fields, hasLength(4));
    for (final field in fields) {
      expect(field.minLines, 5);
      expect(field.maxLines, isNull);
      expect(field.textAlignVertical, TextAlignVertical.top);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'implementation cards show metric, scale, measurement, and green totals without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ImplementationEntryPage(
            projectId: 'p',
            projectsRepo: _Repo(),
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Entry',
              progress: 'implementation',
              content: [
                {'stage': 'overview', 'summary': 'Implemented a garden'},
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assessment').first);
      await tester.pumpAndSettle();
      expect(find.text('Biological Growth'), findsNWidgets(2));
      expect(find.text('Sapling'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('units'), findsOneWidget);
      expect(find.text('120 EcoPoints'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
