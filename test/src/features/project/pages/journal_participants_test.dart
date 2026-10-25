import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/shared/widgets/journal_draft_session.dart';

class ParticipantsRepo extends ProjectsRepo {
  @override
  String? get currentUserId => 'author';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [
    const UserProfile(id: 'author', displayName: 'Alex'),
    const UserProfile(id: 'participant', displayName: 'Morgan'),
  ];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
}

void main() {
  test(
    'loading project members cannot erase already selected participants',
    () {
      expect(
        journalParticipantRows(
          {'participant'},
          const [],
          previous: const [
            {
              'stage': 'overview',
              'involved': [
                {'id': 'participant', 'name': 'Morgan'},
              ],
            },
          ],
        ),
        [
          {'id': 'participant', 'name': 'Morgan'},
        ],
      );
    },
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Implementation Overview ends with participants and saves the selection',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ParticipantsRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: ImplementationEntryPage(projectId: 'p', projectsRepo: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Who is involved?'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Add People'));
      await tester.tap(find.byTooltip('Add People'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morgan'));
      await tester.tap(find.text('Save Contributors'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      final saved = await JournalDraftSession.interruptedEntry(repo);
      expect(saved?.participantIds, contains('participant'));
      expect(saved?.progress, 'implementation');
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'participant IDs come only from explicit involvement across entry formats',
    () {
      const entry = JournalEntry(
        id: 'e',
        projectId: 'p',
        title: 'Shared',
        content: [
          {
            'stage': 'overview',
            'involved': [
              {'id': 'one'},
            ],
          },
          {
            'stage': 'prototyping',
            'involved': [
              {'id': 'two'},
            ],
          },
          {
            'stage': 'free_notes',
            'involved': [
              {'id': 'three'},
            ],
          },
          {
            'unrelated': [
              {'id': 'not-a-participant'},
            ],
          },
        ],
      );
      expect(entry.participantIds, {'one', 'two', 'three'});
    },
  );
}
