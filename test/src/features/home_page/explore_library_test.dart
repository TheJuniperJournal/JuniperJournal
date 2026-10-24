import 'package:juniper_journal/src/shared/widgets/page_refresh_state.dart';
import '../../../support/fake_backend.dart';
import 'package:juniper_journal/src/shared/widgets/public_site_frame.dart';
import 'package:juniper_journal/src/shared/widgets/explore_project_card.dart';
import 'package:juniper_journal/src/features/home_page/pages/public_explore.dart';
import 'package:juniper_journal/src/features/home_page/pages/login.dart';
import 'package:juniper_journal/src/features/home_page/pages/signup.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/explore_page.dart';
import 'package:juniper_journal/src/features/project/pages/journal_add_to_sheet.dart';

const garden = Project(
  id: 'p',
  userId: 'owner',
  projectName: 'Terrarium Garden',
  tags: ['Environment & Sustainability|Biodiversity'],
  difficulty: 'Easy',
  projectScale: 'Small',
  progress: 'Implementation',
  journalEntryCount: 3,
);
const energy = Project(
  id: 'e',
  projectName: 'Solar Panel',
  tags: ['Energy & Systems'],
  difficulty: 'Hard',
  projectScale: 'Large',
);

class _Repo extends ProjectsRepo {
  String viewer = 'owner';
  @override
  String? get currentUserId => viewer;
  int deletes = 0;
  @override
  Future<bool> deleteProject({required String id}) async {
    deletes++;
    return true;
  }

  @override
  Future<List<Project>> getLinkedCommunityProjects(String id) async => [
    garden,
    energy,
  ];
  bool bookmarked = false;
  @override
  Future<Map<String, Map<String, Set<String>>>> getProjectImpactFilterValues(
    List<String> ids,
  ) async => {
    'p': {
      'Metrics': {'Education'},
      'Impact': {'Seed'},
      'Pattern': {'Capacity Building'},
    },
  };
  @override
  Future<List<Project>> getBookmarkedProjects() async => [];
  @override
  Future<List<Project>> getLibraryProjects() async => [garden, energy];
  @override
  Future<List<Project>> getExploreProjects() async => [garden, energy];
  @override
  Future<List<Project>> projectsWithCompletedJournalEntries(
    List<Project> projects,
  ) async => projects;
  @override
  Future<Map<String, int>> getJournalEntryCounts(
    List<String> ids, {
    bool completedOnly = false,
  }) async => {'p': 3, 'e': 2};
  @override
  Future<Set<String>> getBookmarkedProjectIds({
    required List<String> projectIds,
  }) async => {};
  @override
  Future<Map<String, List<UserProfile>>> getCollaboratorsForProjects({
    required List<String> projectIds,
  }) async => {};
  @override
  Future<bool> bookmarkProject({required String id}) async {
    bookmarked = true;
    return true;
  }
}

class _Communities extends CommunitiesRepo {
  @override
  Future<List<Community>> getAllCommunities() async => const [
    Community(
      id: 'c1',
      name: 'Gardeners',
      visibility: 'public',
      createdBy: 'owner',
    ),
    Community(
      id: 'c2',
      name: 'Solar Friends',
      visibility: 'public',
      createdBy: 'owner',
    ),
    Community(
      id: 'c3',
      name: 'Private group',
      visibility: 'private',
      createdBy: 'owner',
    ),
  ];
}

void main() {
  setUpAll(() => initializeFakeBackend());
  testWidgets(
    'sidebar subject selection filters the regular library and can be changed',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<ProjectBrowsePageState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(
              key: key,
              library: true,
              projectsRepo: _Repo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.selectSubject('Energy & Systems');
      await tester.pumpAndSettle();
      expect(find.text('Solar Panel'), findsOneWidget);
      expect(find.text('Terrarium Garden'), findsNothing);
      expect(find.text('Subject (1)'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(BackButton), findsNothing);
      key.currentState!.selectSubject('Environment & Sustainability');
      await tester.pumpAndSettle();
      expect(find.text('Terrarium Garden'), findsOneWidget);
      expect(find.text('Solar Panel'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'community projects reuse Explore cards without the landing hero',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(
              communityId: 'c1',
              publicLanding: true,
              projectsRepo: _Repo(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExploreProjectCard), findsNWidgets(2));
      expect(find.text('Community projects'), findsOneWidget);
      expect(
        find.text('Innovate Ideas. Projects built together.'),
        findsNothing,
      );
      expect(find.text('Terrarium Garden'), findsOneWidget);
      expect(find.text('Solar Panel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'public landing browses both collections without personal chrome',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      final navigation = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigation,
          navigatorObservers: [PageRefreshState.instance],
          builder: (_, child) =>
              PublicSiteFrame(navigatorKey: navigation, child: child!),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/signup': (_) => const SignupScreen(),
          },
          home: PublicExploreScreen(
            projectsRepo: repo,
            communitiesRepo: _Communities(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Innovate Ideas. Projects built together.'),
        findsOneWidget,
      );
      expect(find.text('Terrarium Garden'), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.tap(find.text('Communities'));
      await tester.pumpAndSettle();
      expect(find.text('Gardeners'), findsOneWidget);
      expect(find.text('Private group'), findsNothing);
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sign up'));
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.byType(SignupScreen), findsOneWidget);
      expect(repo.bookmarked, isFalse);
    },
  );

  test('project type filtering combines with search and other filters', () {
    const solo = Project(
      id: 'solo',
      projectName: 'Solo Garden',
      projectType: 'solo',
      tags: [],
      difficulty: 'Easy',
    );
    expect(projectMatchesBrowse(solo, projectTypes: {'solo'}), isTrue);
    expect(
      projectMatchesBrowse(solo, projectTypes: {'collaborative'}),
      isFalse,
    );
    expect(
      projectMatchesBrowse(garden, projectTypes: {'collaborative'}),
      isTrue,
    );
    expect(
      projectMatchesBrowse(solo, projectTypes: {'solo', 'collaborative'}),
      isTrue,
    );
    expect(
      projectMatchesBrowse(
        solo,
        projectTypes: {},
        query: 'garden',
        difficulties: {'Easy'},
      ),
      isTrue,
    );
    expect(
      projectMatchesBrowse(solo, projectTypes: {'solo'}, query: 'solar'),
      isFalse,
    );
  });
  testWidgets(
    'seven project filters scroll horizontally without a phase filter',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [360.0, 1000.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProjectBrowsePage(key: UniqueKey(), projectsRepo: _Repo()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ActionChip), findsNWidgets(7));
        expect(find.text('Phase'), findsNothing);
        final firstY = tester.getCenter(find.byType(ActionChip).first).dy;
        for (final chip in find.byType(ActionChip).evaluate()) {
          expect(tester.getCenter(find.byWidget(chip.widget)).dy, firstY);
        }
        await tester.ensureVisible(find.text('Pattern'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('Pattern')).right,
          lessThanOrEqualTo(width),
        );
        expect(find.text('Pattern'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'only owner can delete from preview and cancellation preserves project',
    (tester) async {
      final repo = _Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(library: true, projectsRepo: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('More options'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Project'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Project?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.deletes, 0);
      expect(find.text('Terrarium Garden'), findsOneWidget);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'delete');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(repo.deletes, 1);
      expect(find.text('Terrarium Garden'), findsNothing);
      repo.viewer = 'viewer';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(
              key: UniqueKey(),
              library: true,
              projectsRepo: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('More options'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  test(
    'project filtering combines search and all dimensions, normalizes phases',
    () {
      expect(
        projectMatchesBrowse(
          garden,
          query: 'garden biodiversity',
          subjects: {'Environment & Sustainability'},
          phases: {'Implemented'},
          scales: {'Small'},
          difficulties: {'Easy'},
        ),
        isTrue,
      );
      expect(projectMatchesBrowse(garden, query: 'solar'), isFalse);
      expect(
        projectMatchesBrowse(garden, subjects: {'Energy & Systems'}),
        isFalse,
      );
      expect(projectMatchesBrowse(garden, phases: {'Ideating'}), isFalse);
      expect(projectMatchesBrowse(garden, scales: {'Large'}), isFalse);
      expect(projectMatchesBrowse(garden, difficulties: {'Hard'}), isFalse);
    },
  );
  testWidgets('library search and bookmark filter update real project cards', (
    tester,
  ) async {
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectBrowsePage(library: true, projectsRepo: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 Journal Entries'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'terrarium');
    await tester.pumpAndSettle();
    expect(find.text('Solar Panel'), findsNothing);
    await tester.tap(find.byTooltip('Bookmark project'));
    await tester.pumpAndSettle();
    expect(repo.bookmarked, isTrue);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bookmarked projects'));
    await tester.pumpAndSettle();
    expect(find.text('Terrarium Garden'), findsOneWidget);
    expect(find.text('Solar Panel'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Explore horizontal cards fit a phone and search shows matching results',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProjectBrowsePage(projectsRepo: _Repo())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Explore by subject'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recent public projects'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Recent public projects'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'solar');
      await tester.pumpAndSettle();
      expect(find.text('Solar Panel'), findsOneWidget);
      expect(find.text('Terrarium Garden'), findsNothing);
      await tester.enterText(find.byType(TextField), 'no matching project');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No matching projects. Try another search or adjust your filters.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('subject cards open a scoped library and back restores Explore', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProjectBrowsePage(projectsRepo: _Repo())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('View projects'), findsNWidgets(4));
    await tester.tap(find.text('Energy & Systems'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text('Subject (1)'), findsNothing);
    expect(find.text('Solar Panel'), findsOneWidget);
    expect(find.text('Terrarium Garden'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Explore by subject'), findsOneWidget);
    expect(find.text('Recent public projects'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Explore communities searches public communities without project filters',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(
              projectsRepo: _Repo(),
              communitiesRepo: _Communities(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Communities'));
      await tester.pumpAndSettle();
      expect(find.text('Gardeners'), findsOneWidget);
      expect(find.text('Private group'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      await tester.enterText(find.byType(TextField), 'solar');
      await tester.pumpAndSettle();
      expect(find.text('Solar Friends'), findsOneWidget);
      expect(find.text('Gardeners'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'impact filters match projects and the option sheet fits a phone',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectBrowsePage(library: true, projectsRepo: _Repo()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Metrics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metrics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Education'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Terrarium Garden'), findsOneWidget);
      expect(find.text('Solar Panel'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quick journal Add to lists owned and collaborative projects and searches',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JournalAddToSheet(projectsRepo: _Repo())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent Projects'), findsOneWidget);
      expect(find.text('Terrarium Garden'), findsOneWidget);
      expect(find.text('Solar Panel'), findsOneWidget);
      expect(find.text('Create Project'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'solar');
      await tester.pumpAndSettle();
      expect(find.text('Terrarium Garden'), findsNothing);
      expect(find.text('Solar Panel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'quick journal cancellation returns one step and allows another project',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: JournalAddToSheet(projectsRepo: _Repo())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'terrarium');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terrarium Garden'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Phase'), findsOneWidget);
      expect(find.text('Recent Projects'), findsNothing);
      final phaseSize = tester.getSize(
        find.byKey(const ValueKey('journal-choice-frame')),
      );
      await tester.tap(find.text('Ideation'));
      await tester.pumpAndSettle();
      expect(find.text('Journal Type'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('journal-choice-frame'))),
        phaseSize,
      );
      expect(find.text('Recent Projects'), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Phase'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pumpAndSettle();
      expect(find.text('Recent Projects'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'terrarium',
      );
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solar Panel'));
      await tester.pumpAndSettle();
      expect(find.text('Choose Phase'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pumpAndSettle();
      expect(find.text('Recent Projects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick journal phase selection opens matching types and canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JournalAddToSheet(projectsRepo: _Repo())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terrarium Garden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prototyping'));
    await tester.pumpAndSettle();
    for (final label in [
      'Building',
      'Testing',
      'Technical Analysis',
      'Free Notes',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Free Notes'));
    await tester.pumpAndSettle();
    final editor = tester.widget<JournalEntryEditorScreen>(
      find.byType(JournalEntryEditorScreen),
    );
    expect(editor.projectId, 'p');
    expect(editor.initialProgress, 'prototyping');
    expect(
      find.text('This entry appears in the Prototyping dashboard.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
