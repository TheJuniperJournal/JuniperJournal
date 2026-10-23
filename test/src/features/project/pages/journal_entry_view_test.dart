import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_view.dart';

class _Repo extends ProjectsRepo {
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => true;
  @override
  Future<Project?> getProjectById(String id) async => project;
  @override
  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [
    const JournalEntry(
      id: 'e',
      projectId: 'p',
      title: 'Observation',
      progress: 'discover',
      content: [
        {'stage': 'free_notes', 'submitted': true},
        {'type': 'body', 'text': 'Our terrarium observations'},
      ],
    ),
  ];
}

const project = Project(id: 'p', projectName: 'Terrarium', tags: []);
void main() {
  testWidgets('entry opens read only without project navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryView(
          entry: const JournalEntry(
            id: 'e',
            projectId: 'p',
            title: 'Observation',
            progress: 'discover',
            content: [
              {'stage': 'free_notes', 'submitted': true},
              {'type': 'body', 'text': 'Our terrarium observations'},
            ],
          ),
          project: project,
          projectsRepo: _Repo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<JournalEntryEditorScreen>(
            find.byType(JournalEntryEditorScreen),
          )
          .readOnly,
      isTrue,
    );
    expect(find.text('Our terrarium observations'), findsOneWidget);
    expect(find.text('View Project'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
