import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

class _Repo extends ProjectsRepo {
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
  test(
    'build completion includes materials without changing testing stages',
    () {
      final data = <String, dynamic>{
        'stage': 'prototyping',
        'entryType': 'building',
        'materialsWorkflow': true,
        'title': 'Build',
        'objective': 'Build a lid',
        'summary': 'Assemble',
        'component': {'id': 'c', 'name': 'Lid'},
      };
      expect(completedJournalStageIndices([data]), {0, 1});
      data['materials'] = [
        {'name': 'Wood', 'cost': 0.0},
      ];
      expect(completedJournalStageIndices([data]), {0, 1, 2});
      data['materials'] = [
        {'name': 'Wood', 'cost': -1},
      ];
      expect(completedJournalStageIndices([data]), {0, 1});
      data['materials'] = [];
      data['noMaterials'] = true;
      expect(completedJournalStageIndices([data]), {0, 1, 2});
      final content = [
        data,
        {
          'stage': 'learning',
          'inquiryLens': 'Design',
          'dci': ['DCI'],
          'sep': ['SEP'],
          'ccc': ['CCC'],
        },
        {
          'stage': 'nextAction',
          'learned': 'Learning',
          'challenges': 'Challenge',
          'nextSteps': 'Next',
          'submitted': true,
        },
      ];
      expect(completedJournalStageIndices(content), {0, 1, 2, 3, 4});
      expect(
        journalEntryIsComplete(
          JournalEntry(
            id: 'e',
            projectId: 'p',
            title: 'Build',
            progress: 'prototyping',
            content: content,
          ),
        ),
        isTrue,
      );
    },
  );
  testWidgets('build materials stage saves items and advances to Learning', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: const JournalEntry(
            id: 'e',
            projectId: 'p',
            title: 'Build',
            progress: 'prototyping',
            content: [
              {
                'stage': 'prototyping',
                'entryType': 'building',
                'buildingWorkflow': true,
                'materialsWorkflow': true,
                'title': 'Build',
                'objective': 'Make lid',
                'summary': 'Assemble',
                'component': {'id': 'c', 'name': 'Lid'},
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Materials & Cost').first);
    await tester.pumpAndSettle();
    expect(find.text('Itemized Budget List'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add the materials used or select No materials needed.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Wood');
    await tester.enterText(find.byType(TextFormField).at(1), '26.97');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('USD 26.97'), findsNWidgets(2));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Inquiry Lens'), findsOneWidget);
    await tester.tap(find.text('Materials & Cost').first);
    await tester.pumpAndSettle();
    expect(find.text('Wood'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final data = repo.saved!.whereType<Map>().firstWhere(
      (row) => row['stage'] == 'prototyping',
    );
    expect((data['materials'] as List).single['cost'], 26.97);
    expect(tester.takeException(), isNull);
  });
}
