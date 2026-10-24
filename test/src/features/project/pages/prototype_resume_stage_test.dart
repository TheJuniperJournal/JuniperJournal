import '../../../../support/fake_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/shared/widgets/progress_tracker.dart';

class _Repo extends ProjectsRepo {
  @override
  String? get currentUserId => 'author';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
}

void main() {
  setUpAll(() => initializeFakeBackend(userId: 'author'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final type in ['building', 'testing', 'technical_analysis']) {
    final stages = type == 'building'
        ? 5
        : type == 'testing'
        ? 4
        : 3;
    for (var section = 0; section < stages; section++) {
      testWidgets(
        '$type reopens saved section $section in its matching editor',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              home: PrototypingJournalEntryPage(
                projectId: 'p',
                projectsRepo: _Repo(),
                entry: JournalEntry(
                  id: 'entry',
                  projectId: 'p',
                  authorId: 'author',
                  title: 'Retained title',
                  progress: 'prototyping',
                  content: [
                    {
                      'stage': 'prototyping',
                      'entryType': type,
                      'title': 'Retained title',
                      'buildingWorkflow': true,
                      'testingWorkflow': true,
                      'analysisWorkflow': true,
                      'materialsWorkflow': type == 'building',
                      'noComponent': true,
                      'noMaterials': true,
                      'objective': 'Build objective',
                      'question': 'Test objective',
                      'summary': 'Build notes',
                      'method': 'Test method',
                      'expectedOutcome': 'Expected result',
                      'outcome': 'Validated',
                      'baseline': 'Baseline',
                      'dataSources': [
                        {'label': 'Field Measurements'},
                      ],
                    },
                    {
                      'stage': 'learning',
                      'inquiryLens': 'Design',
                      'dci': ['DCI'],
                      'sep': ['SEP'],
                      'ccc': ['CCC'],
                    },
                    {
                      'stage': 'nextAction',
                      'challenges': 'Challenge',
                      'nextSteps': 'Next',
                      'learned': 'Learning',
                      'submitted': false,
                    },
                    {
                      'stage': '_navigation',
                      'currentStage': section,
                      'visitedStages': List.generate(stages, (i) => i),
                    },
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ProgressTracker>(find.byType(ProgressTracker).first)
                .currentIndex,
            section,
          );
          if (section == 0 && type == 'technical_analysis') {
            expect(
              find.text('Baseline Description', findRichText: true),
              findsOneWidget,
            );
          } else if (section == 0) {
            expect(find.text('Select Component'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
