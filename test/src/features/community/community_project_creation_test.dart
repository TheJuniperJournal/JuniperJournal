import 'package:flutter/material.dart';
import 'package:juniper_journal/src/features/project/pages/journal_add_to_sheet.dart';
import 'package:juniper_journal/src/shared/widgets/create_menu_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/community/widgets/community_create_menu.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';

const community = Community(
  id: 'community',
  name: 'Community Garden',
  visibility: 'private',
  createdBy: 'owner',
);

class _Repo extends ProjectsRepo {
  List<Map<String, dynamic>>? links;
  Project? saved;
  @override
  Future<List<Project>> getLinkedCommunityProjects(String id) async => [
    Project(id: 'writable', projectName: 'Community project', tags: []),
    Project(id: 'readonly', projectName: 'Read only project', tags: []),
  ];
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => id == 'writable';
  @override
  Future<Project?> createProject({
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    String? difficulty,
    String? projectScale,
    String? visibility,
    String? projectType,
    List<Map<String, dynamic>>? communityLinks,
    bool? shareFriends,
    List<String>? sharedCommunityIds,
    List<Map<String, dynamic>>? learningObjectives,
    String? projectImageUrl,
  }) async {
    links = communityLinks;
    return saved = Project(
      id: 'new',
      projectName: projectName,
      tags: tags,
      communityLinks: communityLinks ?? [],
      projectType: projectType ?? 'solo',
    );
  }

  @override
  Future<Project?> getProjectById(String id) async => saved;
  @override
  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'community journal picker scopes writable projects and supports search',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalAddToSheet(
              community: community,
              projectsRepo: _Repo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('For Community Garden'), findsOneWidget);
      expect(find.text('Community project'), findsOneWidget);
      expect(find.text('Read only project'), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('Community project'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'community create menu states its destination and returns project action',
    (tester) async {
      CommunityCreateAction? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showCreateMenu<CommunityCreateAction>(
                    context: context,
                    builder: (_) => const CommunityCreateMenu(
                      communityName: 'Community Garden',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, 'Open');
      expect(find.text('Create for Community Garden'), findsOneWidget);
      expect(
        find.text('New projects will be linked to this community.'),
        findsOneWidget,
      );
      expect(find.text('JOURNAL'), findsOneWidget);
      await tapText(tester, 'NEW PROJECT');
      expect(result, CommunityCreateAction.project);
    },
  );

  testWidgets(
    'community is preselected, persisted, and remains the return destination',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateProjectScreen(
                      initialCommunity: community,
                      projectsRepo: repo,
                    ),
                  ),
                ),
                child: const Text('Community home'),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, 'Community home');
      expect(find.text('Community Garden'), findsOneWidget);
      expect(find.text('Home Community'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Garden beds');
      await tapText(tester, 'Solo');
      await tester.ensureVisible(find.byType(TextField).at(1));
      await tester.enterText(
        find.byType(TextField).at(1),
        'Improve access to growing space.',
      );
      await tapText(tester, 'Environment & Sustainability');
      await tapText(tester, 'Easy');
      await tapText(tester, 'Small');
      await tapText(tester, 'Private');
      await tapText(tester, '+ Add Objective');
      await tapText(tester, 'Subject');
      await tapText(tester, 'Environment & Sustainability');
      await tapText(tester, 'Objective');
      await tapText(tester, 'Analyze');
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(
        find.byType(TextField).last,
        'Compare growing methods',
      );
      await tapText(tester, 'Create');
      expect(repo.links, [
        {
          'id': 'community',
          'name': 'Community Garden',
          'imageUrl': null,
          'description': null,
          'role': 'home',
        },
      ]);
      expect(find.byType(ProjectDashboard), findsOneWidget);
      Navigator.of(tester.element(find.byType(ProjectDashboard))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Community home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'picker browses community and friends and searches all sources without duplicates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const member = UserProfile(id: 'member', displayName: 'Alice Community');
      const friend = UserProfile(id: 'friend', displayName: 'Alice Friend');
      const other = UserProfile(id: 'other', displayName: 'Alice Search');
      const existing = UserProfile(
        id: 'existing',
        displayName: 'Already Selected',
      );
      List<UserProfile>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<List<UserProfile>>(
                    context: context,
                    builder: (_) => ProjectMemberPicker(
                      existingMembers: const [existing],
                      loadCommunityMembers: () async => [member, existing],
                      loadFriends: () async => [friend, member],
                      searchPeople: (_) async => [member, other],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tapText(tester, 'Open');
      expect(find.text('Community members'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Alice Community'), findsOneWidget);
      expect(find.text('Alice Friend'), findsOneWidget);
      expect(find.text('Already Selected'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      for (final text in ['Alice Community', 'Alice Friend', 'Alice Search']) {
        expect(find.text(text), findsOneWidget);
      }
      await tapText(tester, 'Alice Community');
      expect(find.text('View profile'), findsOneWidget);
      expect(find.byTooltip('Add Alice Search'), findsOneWidget);
      // Dismiss profile options without adding the person.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      for (final name in ['Alice Search', 'Alice Community', 'Alice Friend']) {
        await tester.ensureVisible(find.byTooltip('Add $name'));
        await tester.tap(find.byTooltip('Add $name'));
        await tester.pumpAndSettle();
      }
      await tapText(tester, 'Add');
      expect(result!.map((person) => person.id).toSet(), {
        'existing',
        'other',
        'member',
        'friend',
      });
      expect(result!.length, 4);
      expect(tester.takeException(), isNull);
    },
  );
}
