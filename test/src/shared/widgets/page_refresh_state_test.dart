import 'package:juniper_journal/src/features/home_page/pages/public_user_profile.dart';
import 'package:juniper_journal/src/features/home_page/pages/search.dart';
import 'package:juniper_journal/src/features/home_page/pages/explore_page.dart';
import 'package:juniper_journal/src/features/project/pages/project_collaboration_tab.dart';
import 'package:juniper_journal/src/features/site/pages/site_information_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/features/home_page/pages/home.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class RefreshRepo extends ProjectsRepo {
  @override
  String? get currentUserId => 'user';
  @override
  Future<Project?> getProjectById(String id) async =>
      Project(id: id, projectName: 'Project', tags: const []);
  @override
  Future<bool> canManageProject(String id) async => true;
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('restores dashboard collaboration subtab and linked post', () async {
    final page =
        await PageRefreshState.restore({
              'kind': 'project',
              'project': 'p',
              'section': 2,
              'collaboration': 'members',
              'post': 'post-id',
            }, RefreshRepo())
            as ProjectDashboard;
    expect(page.initialSection, ProjectDashboardSection.collaboration);
    expect(page.initialCollaborationSection, CollaborationSection.members);
    expect(page.initialPostId, 'post-id');
  });
  test('profile, search and subject URLs restore the selected view', () async {
    final profile =
        await PageRefreshState.restore({
              'kind': 'profile',
              'user': 'u',
              'tab': 2,
              'subject': 'Energy & Systems',
            }, RefreshRepo())
            as PublicUserProfilePage;
    expect(profile.initialSection, 2);
    expect(profile.initialSubject, 'Energy & Systems');
    final search =
        await PageRefreshState.restore({
              'kind': 'people-search',
              'scope': 'friends',
            }, RefreshRepo())
            as HomeSearchScreen;
    expect(search.initialScope, SearchScope.friends);
    final subject =
        await PageRefreshState.restore({
              'kind': 'subject-projects',
              'subject': 'Energy & Systems',
              'public': true,
            }, RefreshRepo())
            as SubjectProjectsPage;
    expect(subject.subject, 'Energy & Systems');
  });
  test(
    'restores home subtabs without reopening an interrupted journal',
    () async {
      final home =
          await PageRefreshState.restore({
                'kind': 'home',
                'section': 2,
                'profileTab': 'friends',
                'exploreTab': 'communities',
                'subject': 'Energy & Systems',
              }, RefreshRepo())
              as HomeShellScreen;
      expect(home.initialProfileFriends, true);
      expect(home.initialExploreCommunities, true);
      expect(home.initialLibrarySubject, 'Energy & Systems');
      expect(home.restoreJournal, false);
    },
  );

  test('root refresh keeps Explore instead of sending the user Home', () async {
    final page = await PageRefreshState.restore({
      'kind': 'home',
      'section': 3,
    }, RefreshRepo());
    expect(page, isA<HomeShellScreen>());
    expect((page as HomeShellScreen).initialSection, 3);
    expect(page.restoreJournal, false);
  });
  test(
    'public information pages restore without loading project data',
    () async {
      for (final kind in sitePageTitles.keys) {
        final page = await PageRefreshState.restore({
          'kind': kind,
        }, RefreshRepo());
        expect(page, isA<SiteInformationPage>());
        expect((page as SiteInformationPage).page, kind);
      }
    },
  );
  test('project refresh keeps the selected timeline tab', () async {
    final page = await PageRefreshState.restore({
      'kind': 'project',
      'project': 'p',
      'section': 3,
    }, RefreshRepo());
    expect(
      (page as ProjectDashboard).initialSection,
      ProjectDashboardSection.timeline,
    );
  });
  test('phase refresh reopens that phase', () async {
    final page = await PageRefreshState.restore({
      'kind': 'phase',
      'project': 'p',
      'phase': 'discover',
    }, RefreshRepo());
    expect(page, isA<DiscoveryDashboardPage>());
  });
  test(
    'empty journal refresh opens an editor without inserting a draft',
    () async {
      final page = await PageRefreshState.restore({
        'kind': 'journal',
        'project': 'p',
        'phase': 'discover',
      }, RefreshRepo());
      expect(page, isA<DiscoveryObservationEntryPage>());
      expect((page as DiscoveryObservationEntryPage).entry, isNull);
    },
  );
  test('restores stage safely across missing or changed stage layouts', () {
    expect(
      restoredJournalStage([
        {'stage': '_navigation', 'currentStage': 3},
      ], 5),
      3,
    );
    expect(
      restoredJournalStage([
        {'stage': '_navigation', 'currentStage': 9},
      ], 4),
      3,
    );
    expect(restoredJournalStage([], 5), 0);
  });
  test('completed journal entries always reopen at the first stage', () {
    for (final length in [3, 4, 5]) {
      expect(
        restoredJournalStage(
          [
            {
              'stage': '_navigation',
              'currentStage': length - 1,
              'visitedStages': List.generate(length, (i) => i),
            },
          ],
          length,
          completed: true,
        ),
        0,
      );
    }
  });
  test('draft resumes furthest stage even after navigating back', () {
    expect(
      restoredJournalStage([
        {
          'stage': '_navigation',
          'currentStage': 1,
          'visitedStages': [0, 1, 2, 3],
        },
      ], 5),
      3,
    );
    expect(
      restoredJournalStage([
        {
          'stage': '_navigation',
          'currentStage': 4,
          'visitedStages': [0, 1],
        },
      ], 5),
      4,
    );
    expect(
      restoredJournalStage([
        {
          'stage': '_navigation',
          'currentStage': -2,
          'visitedStages': ['invalid', -1, 9],
        },
      ], 4),
      3,
    );
  });
}
