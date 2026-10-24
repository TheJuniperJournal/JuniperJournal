import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

class _Repo extends ProjectsRepo {
  _Repo(this.entry);
  JournalEntry entry;
  int saves = 0;
  @override
  String? get currentUserId => 'qa';
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<List<ImpactEntry>> getImpactEntries({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>> getJournalEntries({
    required String projectId,
  }) async => [entry];
  @override
  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    saves++;
    entry = JournalEntry(
      id: entryId,
      projectId: 'p',
      title: title ?? entry.title,
      content: content ?? entry.content,
      progress: progress ?? entry.progress,
    );
    return true;
  }
}

Widget editor(JournalEntry e, _Repo repo) => switch (e.progress) {
  'discover' => DiscoveryObservationEntryPage(
    projectId: 'p',
    projectsRepo: repo,
    entry: e,
  ),
  'ideating' => IdeatingEntryPage(projectId: 'p', projectsRepo: repo, entry: e),
  _ => ImplementationEntryPage(projectId: 'p', projectsRepo: repo, entry: e),
};
void main() {
  final rows =
      (jsonDecode(File('test/fixtures/guided_phase_qa.json').readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final row in rows) {
    testWidgets(
      '${row['progress']} guided stages save, preserve evidence and reopen',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final initial = JournalEntry.fromMap(row);
        expect(initial.isFreeNotes, isFalse);
        expect(journalEntryIsComplete(initial), isTrue);
        final repo = _Repo(initial);
        await tester.pumpWidget(MaterialApp(home: editor(initial, repo)));
        await tester.pumpAndSettle();
        final phases = switch (initial.progress) {
          'discover' => [
            'Observe',
            'Analyze',
            'Question',
            'Learning',
            'Next Action',
          ],
          'ideating' => [
            'Challenge',
            'Ideas',
            'Decision Matrix',
            'Learning',
            'Next Action',
          ],
          _ => ['Overview', 'Assessment', 'Learning', 'Reflection'],
        };
        // Edit the actual title controller to trigger normal autosave.
        final title = find.byType(TextField).first;
        await tester.enterText(title, '${initial.title} verified');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        for (final phase in phases) {
          final target = find.text(phase).first;
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
          final error = tester.takeException();
          expect(error, isNull, reason: phase);
        }
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(repo.saves, greaterThan(0));
        expect(repo.entry.title, contains('verified'));
        expect(journalEntryIsComplete(repo.entry), isTrue);
        final saved = jsonEncode(repo.entry.content);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home: editor(repo.entry, repo)));
        await tester.pumpAndSettle();
        expect(find.textContaining('verified'), findsWidgets);
        expect(jsonEncode(repo.entry.content), saved);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
