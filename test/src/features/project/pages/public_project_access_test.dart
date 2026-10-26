import '../../../../support/fake_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project_activity_event.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/features/project/pages/project_collaboration_tab.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_view.dart';

class _AccessRepo extends ProjectsRepo {
  _AccessRepo({this.member = false, this.viewer});
  final bool member;
  final String? viewer;
  @override
  String? get currentUserId => viewer;
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => member;
  @override
  Future<bool> canManageProject(String id) async => false;
  @override
  Future<Project?> getProjectById(String id) async => Project(
    id: id,
    userId: 'owner',
    projectName: 'Public garden',
    problemStatement: 'Grow food while learning about soil.',
    tags: [],
    visibility: 'public',
  );
  @override
  Future<List<Map<String, String>>?> getTimeline(String id) async => [];
  @override
  Future<List<UserProfile>> getProjectCollaborators({
    required String projectId,
  }) async => [];
  @override
  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => [];
  @override
  Future<List<ProjectActivityEvent>?> getProjectActivity(
    String id, {
    int offset = 0,
    int limit = 15,
  }) async => [];
  @override
  Future<List<UserProfile>> getPublicProjectDirectory(String id) async =>
      const [
        UserProfile(id: 'owner', displayName: 'Garden owner'),
        UserProfile(id: 'member', displayName: 'Maya Chen'),
      ];
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
}

void main() {
  setUpAll(() => initializeFakeBackend(userId: 'viewer'));
  for (final viewer in [null, 'signed-in-nonmember']) {
    testWidgets(
      'nonmember $viewer can view public timeline without gaining creation or settings access',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _AccessRepo(viewer: viewer);
        await tester.pumpWidget(
          MaterialApp(
            home: ProjectDashboard(
              projectId: 'p',
              projectName: 'Public garden',
              tags: [],
              isOwner: true,
              initialSection: ProjectDashboardSection.timeline,
              projectsRepo: repo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Overview'), findsOneWidget);
        expect(find.text('Timeline'), findsOneWidget);
        expect(find.text('Add to timeline'), findsNothing);
        expect(
          find.byKey(const ValueKey('project-dashboard-settings')),
          findsNothing,
        );
        expect(find.text('Recent Activity'), findsNothing);
        await tester.tap(find.text('Overview'));
        await tester.pumpAndSettle();
        expect(
          find.text('Grow food while learning about soil.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Collaboration'));
        await tester.pumpAndSettle();
        expect(find.text('Bulletin'), findsNothing);
        expect(find.text('Maya Chen'), findsOneWidget);
        expect(find.text('Members'), findsWidgets);
        expect(find.text('Communities'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('accepted members retain Timeline even when isOwner is false', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Public garden',
          tags: [],
          isOwner: false,
          projectsRepo: _AccessRepo(member: true, viewer: 'member'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable entry passed in navigation is not displayed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryView(
          entry: const JournalEntry(
            id: 'draft',
            projectId: 'p',
            title: 'Private draft',
            content: [],
          ),
          project: const Project(
            id: 'p',
            projectName: 'Public garden',
            tags: [],
          ),
          projectsRepo: _AccessRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsNothing);
    expect(
      find.text('This entry is unavailable or is not shared with you.'),
      findsOneWidget,
    );
  });
}
