import 'package:juniper_journal/src/shared/widgets/progress_tracker.dart';
import 'package:juniper_journal/src/shared/widgets/desktop_content_width.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';
import 'package:juniper_journal/src/features/project/pages/project_collaboration_tab.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/challenge_participant.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';

class _FakeProjectsRepo extends ProjectsRepo {
  @override
  String? get currentUserId => 'owner';
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => true;
  @override
  Future<bool> canManageProject(String id) async => true;
  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => [];
  _FakeProjectsRepo({this.includeImage = true, this.entries = const []});
  final List<JournalEntry> entries;
  final bool includeImage;
  String? updatedImageUrl;
  @override
  Future<List<Map<String, String>>?> getTimeline(String id) async => [];
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => entries;

  @override
  Future<Project?> getProjectById(String id) async {
    return Project(
      id: id,
      projectName: 'Test Project',
      userId: 'owner',
      tags: const ['WATER', 'WASTE'],
      imageUrl: includeImage ? 'https://example.com/project-cover.jpg' : null,
      problemStatement: 'A river restoration project.',
    );
  }

  @override
  Future<bool> updateProjectImage({
    required String id,
    String? projectImageUrl,
  }) async {
    updatedImageUrl = projectImageUrl;
    return true;
  }
}

class _CountingProjectsRepo extends _FakeProjectsRepo {
  _CountingProjectsRepo() : super(includeImage: false);
  int memberLoads = 0;
  @override
  Future<List<UserProfile>?> getProjectInvitees({
    required String projectId,
  }) async {
    memberLoads++;
    return [];
  }

  @override
  Future<Map<String, String>> getProjectMemberRoles(String id) async => {};
  @override
  Future<bool> canManageProject(String id) async => false;
}

class _RefreshProjectsRepo extends _CountingProjectsRepo {
  Project current = Project(
    id: 'p',
    projectName: 'Project',
    tags: const ['Engineering & Design'],
    difficulty: 'Easy',
    projectScale: 'Small',
    learningObjectives: const [
      {'description': 'Original objective'},
    ],
  );
  List<JournalEntry> currentEntries = const [
    JournalEntry(
      id: 'old',
      projectId: 'p',
      title: 'Original activity',
      content: [],
    ),
  ];
  @override
  Future<Project?> getProjectById(String id) async => current;
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => currentEntries;
}

class _FakeChallengesRepo extends ChallengesRepo {
  @override
  Future<ChallengeParticipant?> getParticipationByProjectId(
    String projectId,
  ) async {
    return null;
  }

  @override
  Future<DesignChallenge?> getChallengeById(String id) async {
    return null;
  }
}

class _LongTitleRepo extends _CountingProjectsRepo {
  @override
  Future<Project?> getProjectById(String id) async => Project(
    id: id,
    projectName: 'Juniper Journal Learning Kits',
    tags: const [],
  );
}

class _SettingsAccessRepo extends _CountingProjectsRepo {
  int projectLoads = 0;
  bool failFirstOpen = false;
  @override
  String? get currentUserId => 'owner';
  @override
  Future<Project?> getProjectById(String id) async {
    projectLoads++;
    if (failFirstOpen && projectLoads == 2) return null;
    return Project(
      id: id,
      userId: 'owner',
      projectName: 'Owned project',
      tags: const [],
      projectType: 'solo',
    );
  }
}

void main() {
  for (final phase in [
    'discover',
    'ideating',
    'prototyping',
    'implementation',
  ]) {
    testWidgets(
      '$phase dashboard Back opens project Development from a direct link',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _RefreshProjectsRepo();
        final page = switch (phase) {
          'discover' => DiscoveryDashboardPage(
            projectId: 'p',
            isOwner: false,
            projectsRepo: repo,
          ),
          'ideating' => IdeatingDashboardPage(
            projectId: 'p',
            isOwner: false,
            projectsRepo: repo,
          ),
          'prototyping' => PrototypingDashboardPage(
            projectId: 'p',
            isOwner: false,
            projectsRepo: repo,
          ),
          _ => ImplementationDashboardPage(
            projectId: 'p',
            isOwner: false,
            projectsRepo: repo,
          ),
        };
        await tester.pumpWidget(MaterialApp(home: page));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('content-back-chevron')));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectDashboard), findsOneWidget);
        expect(
          tester
              .widget<ProjectDashboard>(find.byType(ProjectDashboard))
              .initialSection,
          ProjectDashboardSection.development,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final wide in [false, true]) {
    testWidgets(
      'impact preview keeps breathing room and wraps categories at ${wide ? "desktop" : "mobile"} width',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = wide
            ? const Size(1440, 1000)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: ProjectDashboard(
              projectId: 'p',
              projectName: 'QA preview',
              tags: const [],
              isOwner: false,
              projectsRepo: _RefreshProjectsRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final impact = tester.getRect(
          find.byKey(const ValueKey('project-impact-preview')),
        );
        final title = tester.getRect(find.text('Impact Summary'));
        final objectives = tester.getRect(find.text('Learning Objectives'));
        expect(title.left - impact.left, greaterThanOrEqualTo(24));
        expect(objectives.top - impact.bottom, greaterThanOrEqualTo(32));
        final energy = tester.getTopLeft(find.text('Energy'));
        final growth = tester.getTopLeft(find.text('Biological Growth'));
        if (wide) {
          expect(growth.dy, closeTo(energy.dy, .1));
        } else {
          expect(growth.dy, greaterThan(energy.dy));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'hosted desktop dashboard keeps all tabs aligned without a second scrollbar gutter',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior().copyWith(scrollbars: false),
          theme: ThemeData(platform: TargetPlatform.macOS),
          builder: (context, child) =>
              DesktopContentWidth(width: 720, child: child!),
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            projectsRepo: _CountingProjectsRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('project-dashboard-label'));
      final original = tester.getRect(header);
      for (final tab in [
        'Development',
        'Collaboration',
        'Timeline',
        'Overview',
      ]) {
        await tester.tap(find.text(tab));
        await tester.pump(const Duration(milliseconds: 140));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.getRect(header), original, reason: tab);
      }
    },
  );

  testWidgets('owner can open settings through a viewer card route', (
    tester,
  ) async {
    final repo = _SettingsAccessRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Owned project',
          tags: const [],
          isOwner: false,
          projectsRepo: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final settings = find.byKey(const ValueKey('project-dashboard-settings'));
    expect(tester.getSize(settings), const Size(48, 48));
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.byType(CreateProjectScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings load failure is visible and a retry can open settings',
    (tester) async {
      final repo = _SettingsAccessRepo()..failFirstOpen = true;
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Owned project',
            tags: const [],
            projectsRepo: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final settings = find.byKey(const ValueKey('project-dashboard-settings'));
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not load project settings. Please try again.'),
        findsOneWidget,
      );
      expect(find.byType(CreateProjectScreen), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(CreateProjectScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wrapped project title keeps space above development progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Juniper Journal Learning Kits',
          tags: const [],
          projectsRepo: _LongTitleRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Juniper Journal Learning Kits'));
    final progress = tester.getRect(find.text('Development Progress'));
    expect(progress.top - title.bottom, greaterThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'delete from project settings opens confirmation on the visible route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            openSettingsOnLoad: true,
            projectsRepo: _CountingProjectsRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreateProjectScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Delete Project'));
      await tester.tap(find.text('Delete Project'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Project?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateProjectScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'overview refreshes saved basics, icons, objectives and recent activity',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _RefreshProjectsRepo();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(.7)),
            child: child!,
          ),
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            projectsRepo: repo,
            challengesRepo: _FakeChallengesRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Engineering & Design'), findsOneWidget);
      expect(find.text('Original objective'), findsOneWidget);
      expect(find.textContaining('Original activity'), findsOneWidget);
      await tester.tap(find.text('Development'));
      await tester.pumpAndSettle();
      repo.current = Project(
        id: 'p',
        projectName: 'Project',
        tags: const ['Energy & Systems'],
        difficulty: 'Hard',
        projectScale: 'Large',
        learningObjectives: const [
          {'description': 'Updated objective'},
        ],
      );
      repo.currentEntries = const [
        JournalEntry(
          id: 'new',
          projectId: 'p',
          title: 'Updated activity',
          content: [],
        ),
      ];
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      for (final text in [
        'Energy & Systems',
        'Hard',
        'Large',
        'Updated objective',
        'Updated activity',
      ]) {
        expect(
          text == 'Updated activity'
              ? find.textContaining(text)
              : find.text(text),
          findsOneWidget,
        );
      }
      expect(find.text('Original objective'), findsNothing);
      expect(find.textContaining('Original activity'), findsNothing);
      final icons = tester.widgetList<ProjectSettingIcon>(
        find.byType(ProjectSettingIcon),
      );
      expect(icons.map((icon) => icon.value), [
        'Energy & Systems',
        'Hard',
        'Large',
      ]);
      repo.current = Project(id: 'p', projectName: 'Project', tags: const []);
      repo.currentEntries = [];
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Not selected'), findsOneWidget);
      expect(find.text('No learning objectives selected.'), findsOneWidget);
      expect(find.text('Updated activity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'dashboard chrome stays identical across tabs at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const AppScrollBehavior(),
            theme: ThemeData(platform: TargetPlatform.macOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(.7)),
              child: child!,
            ),
            home: ProjectDashboard(
              projectId: 'p',
              projectName: 'Project',
              tags: const [],
              projectsRepo: _CountingProjectsRepo(),
              challengesRepo: _FakeChallengesRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final coverWidth = tester
            .getSize(find.byKey(const ValueKey('project-cover')))
            .width;
        if (width >= 1000) {
          expect(
            coverWidth,
            greaterThan(600),
            reason: 'Desktop cover must use the center column',
          );
        } else {
          expect(coverWidth, lessThanOrEqualTo(283));
        }
        final keys = [
          'project-dashboard-done',
          'project-dashboard-label',
          'project-dashboard-settings',
          'dashboard-tab-indicator-overview',
          'dashboard-tab-indicator-development',
          'dashboard-tab-indicator-collaboration',
          'dashboard-tab-indicator-timeline',
        ];
        final initial = {
          for (final key in keys)
            key: tester.getRect(find.byKey(ValueKey(key))),
        };
        for (final tab in [
          'Development',
          'Collaboration',
          'Timeline',
          'Overview',
        ]) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          for (final key in keys) {
            final actual = tester.getRect(find.byKey(ValueKey(key)));
            final expected = initial[key]!;
            expect(
              actual.left,
              closeTo(expected.left, .01),
              reason: '$tab $key left',
            );
            expect(
              actual.top,
              closeTo(expected.top, .01),
              reason: '$tab $key top',
            );
            expect(
              actual.width,
              closeTo(expected.width, .01),
              reason: '$tab $key width',
            );
            expect(
              actual.height,
              closeTo(expected.height, .01),
              reason: '$tab $key height',
            );
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('switching project tabs preserves loaded section state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _CountingProjectsRepo();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(.7)),
          child: child!,
        ),
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Project',
          tags: const [],
          projectsRepo: repo,
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collaboration'));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(ProjectCollaborationTab));
    expect(repo.memberLoads, 1);
    await tester.tap(find.text('Development'));
    await tester.pumpAndSettle();
    expect(find.text('Total Entries'), findsOneWidget);
    await tester.tap(find.text('Collaboration'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(ProjectCollaborationTab)), same(state));
    expect(repo.memberLoads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Collaboration header stays at top when content is short or unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(.7)),
            child: child!,
          ),
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            projectsRepo: _FakeProjectsRepo(includeImage: false),
            challengesRepo: _FakeChallengesRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collaboration'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('PROJECT DASHBOARD')).dy,
        lessThan(40),
      );
      expect(find.text('Bulletin'), findsOneWidget);
      final done = tester.getRect(
        find.byKey(const ValueKey('project-dashboard-done')),
      );
      final settings = tester.getRect(
        find.byKey(const ValueKey('project-dashboard-settings')),
      );
      final label = tester.getRect(
        find.byKey(const ValueKey('project-dashboard-label')),
      );
      expect(done.center.dy, closeTo(settings.center.dy, .5));
      expect(done.center.dy, closeTo(label.center.dy, .5));
      final indicators = [
        for (final tab in [
          'overview',
          'development',
          'collaboration',
          'timeline',
        ])
          tester.getRect(find.byKey(ValueKey('dashboard-tab-indicator-$tab'))),
      ];
      for (final indicator in indicators) {
        expect(indicator.width, closeTo(indicators.first.width, .5));
        expect(indicator.top, closeTo(indicators.first.top, .5));
      }

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'progress tracker sits slightly left of center and within section edges',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 411.0, 800.0]) {
        tester.view.physicalSize = Size(width, 1800);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(.7)),
              child: child!,
            ),
            home: ProjectDashboard(
              key: ValueKey(width),
              projectId: 'p',
              projectName: 'Project',
              tags: const [],
              projectsRepo: _FakeProjectsRepo(includeImage: false),
              challengesRepo: _FakeChallengesRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cover = tester.getRect(
          find.byKey(const ValueKey('project-cover')),
        );
        final tracker = tester.getRect(
          find.byKey(const ValueKey('project-development-tracker')),
        );
        expect(cover.center.dx, closeTo(width / 2, .5));
        expect(tracker.center.dx, lessThan(cover.center.dx));
        expect(cover.center.dx - tracker.center.dx, lessThanOrEqualTo(8.1));
        expect(tracker.left, greaterThanOrEqualTo(0));
        expect(tracker.right, lessThanOrEqualTo(width));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('project-development-tracker')),
            matching: find.byKey(const ValueKey('stage-current-0')),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Recent Activity opens the selected journal entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = JournalEntry(
      id: 'recent',
      projectId: 'p',
      title: 'Entry: Recent idea',
      progress: 'ideating',
      content: const [],
      updatedAt: DateTime(2026, 10, 15),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(.7)),
          child: child!,
        ),
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Project',
          tags: const [],
          projectsRepo: _FakeProjectsRepo(
            includeImage: false,
            entries: [entry],
          ),
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final recent = find.byKey(const ValueKey('activity-entry-recent'));
    await tester.ensureVisible(recent);
    await tester.tap(recent);
    await tester.pumpAndSettle();
    expect(find.byType(IdeatingEntryPreviewPage), findsOneWidget);
    expect(
      tester
          .widget<IdeatingEntryPreviewPage>(
            find.byType(IdeatingEntryPreviewPage),
          )
          .entry
          .id,
      'recent',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Done exits the project and clears the debug project shortcut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'debug.projectId': 'project-1',
      'debug.page': 'settings',
    });
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(.7)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Library'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDashboard(
                    projectId: 'project-1',
                    projectName: 'Test Project',
                    tags: const [],
                    projectsRepo: _FakeProjectsRepo(includeImage: false),
                    challengesRepo: _FakeChallengesRepo(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.byType(ProjectDashboard), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString('debug.projectId'),
      isNull,
    );
  });

  testWidgets(
    'ProjectDashboard renders current sections and settings control',
    (WidgetTester tester) async {
      final projectsRepo = _FakeProjectsRepo();

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDashboard(
            projectId: 'project-1',
            projectName: 'Test Project',
            tags: const ['WATER', 'WASTE'],
            projectsRepo: projectsRepo,
            challengesRepo: _FakeChallengesRepo(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Project'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('project-dashboard-settings')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('project-cover')), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);

      expect(find.text('Impact Summary'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Materials & Cost'), findsOneWidget);
      expect(find.text('Journal Entries'), findsOneWidget);
    },
  );

  testWidgets('dashboard cover has no inline editing controls', (
    WidgetTester tester,
  ) async {
    final projectsRepo = _FakeProjectsRepo();

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'project-1',
          projectName: 'Test Project',
          tags: const ['WATER', 'WASTE'],
          projectsRepo: projectsRepo,
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('project-cover')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('project-dashboard-settings')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.byTooltip('Change project cover'), findsNothing);
    expect(find.text('Tap to add a photo'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('project-cover')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('expanded-project-cover')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Upload photo'), findsNothing);
    await tester.tap(find.byTooltip('Close image'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank cover opens photo source choices directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'project-1',
          projectName: 'Test Project',
          tags: const [],
          projectsRepo: _FakeProjectsRepo(includeImage: false),
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tap to add a photo'), findsOneWidget);
    await tester.tap(find.text('Tap to add a photo'));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-owner cannot change the dashboard cover image', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'project-1',
          projectName: 'Test Project',
          tags: const ['WATER', 'WASTE'],
          isOwner: false,
          projectsRepo: _FakeProjectsRepo(),
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
  testWidgets(
    'notification entry closes back into the navigable project dashboard',
    (tester) async {
      const entry = JournalEntry(
        id: 'target',
        projectId: 'p',
        title: 'Target entry',
        progress: 'Discovery',
        content: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDashboard(
            projectId: 'p',
            projectName: 'Project',
            tags: const [],
            projectsRepo: _FakeProjectsRepo(
              includeImage: false,
              entries: [entry],
            ),
            initialSection: ProjectDashboardSection.development,
            initialJournalEntry: entry,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JournalReadingPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(JournalReadingPage))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Total Entries'), findsOneWidget);
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Development Progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('overview progress tracker opens each phase dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: ProjectDashboard(
          projectId: 'p',
          projectName: 'Project',
          tags: const [],
          projectsRepo: _FakeProjectsRepo(includeImage: false),
          challengesRepo: _FakeChallengesRepo(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pages = [
      DiscoveryDashboardPage,
      IdeatingDashboardPage,
      PrototypingDashboardPage,
      ImplementationDashboardPage,
    ];
    for (var index = 0; index < 4; index++) {
      final tracker = find.byKey(const ValueKey('project-development-tracker'));
      await tester.ensureVisible(tracker);
      await tester.tap(
        find.descendant(
          of: tracker,
          matching: find.byKey(ValueKey('stage-label-$index')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(pages[index]), findsOneWidget);
      Navigator.of(tester.element(find.byType(pages[index]))).pop();
      await tester.pumpAndSettle();
    }
  });
  for (final phase in ['ideating', 'prototyping', 'implementation']) {
    testWidgets(
      'progress through $phase lights earlier phases without entries',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ProjectDashboard(
              projectId: 'p',
              projectName: 'Project',
              tags: const [],
              projectsRepo: _FakeProjectsRepo(
                includeImage: false,
                entries: [
                  JournalEntry(
                    id: 'later',
                    projectId: 'p',
                    title: 'Later phase work',
                    content: const [],
                    progress: phase,
                  ),
                ],
              ),
              challengesRepo: _FakeChallengesRepo(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tracker = tester.widget<ProgressTracker>(
          find.byKey(const ValueKey('project-development-tracker')),
        );
        final index = [
          'discover',
          'ideating',
          'prototyping',
          'implementation',
        ].indexOf(phase);
        expect(tracker.reachedIndices, {for (var i = 0; i <= index; i++) i});
        expect(tracker.currentIndex, index);
      },
    );
  }
}
