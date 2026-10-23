import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/features/community/pages/community_home_screen.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/project_bulletin_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/project_notification_destination.dart';
import 'package:juniper_journal/src/features/project/pages/project_collaboration_tab.dart';

class _Repo extends ProjectsRepo {
  bool available = true;
  @override
  Future<Project?> getProjectById(String id) async =>
      available ? Project(id: id, projectName: 'Project', tags: []) : null;
  @override
  Future<bool> canManageProject(String id) async => false;
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => [
    JournalEntry(
      id: 'other',
      projectId: projectId,
      title: 'Other entry',
      content: [],
    ),
    JournalEntry(
      id: 'target',
      projectId: projectId,
      title: 'Notified entry',
      content: [],
    ),
  ];
}

class _Bulletin extends ProjectBulletinRepo {
  @override
  Future<String?> postIdForComment(String id) async =>
      id == 'reply' ? 'parent-post' : null;
}

class _Communities extends CommunitiesRepo {
  @override
  Future<Community?> getCommunityById(String id) async => Community(
    id: id,
    name: 'Community',
    visibility: 'private',
    createdBy: 'owner',
  );
}

void main() {
  Map<String, dynamic> notice(String kind, String source) => {
    'project_id': 'p',
    'activity_type': kind,
    'source_id': source,
  };
  test(
    'journal notification enters the real dashboard with its exact entry',
    () async {
      final page =
          await projectNotificationDestination(
                notice('journal_updated', 'target'),
                _Repo(),
              )
              as ProjectDashboard;
      expect(page.initialJournalEntry!.id, 'target');
      expect(page.initialSection, ProjectDashboardSection.development);
    },
  );
  test(
    'removed journal cannot silently redirect to project overview',
    () async {
      await expectLater(
        projectNotificationDestination(
          notice('journal_updated', 'deleted'),
          _Repo(),
        ),
        throwsStateError,
      );
    },
  );
  for (final kind in [
    'journal_deleted',
    'journal_draft_deleted',
    'timeline_removed',
    'forum_post_deleted',
  ]) {
    test(
      '$kind opens the remaining section without a deleted target',
      () async {
        final page =
            await projectNotificationDestination(
                  notice(kind, 'deleted'),
                  _Repo(),
                )
                as ProjectDashboard;
        expect(page.initialJournalEntry, isNull);
        expect(page.initialEventId, isNull);
        expect(page.initialPostId, isNull);
        if (kind.startsWith('journal_'))
          expect(page.initialSection, ProjectDashboardSection.development);
      },
    );
  }
  test('inaccessible project does not open a target', () async {
    await expectLater(
      projectNotificationDestination(
        notice('journal_updated', 'target'),
        _Repo()..available = false,
      ),
      throwsStateError,
    );
  });
  test('community addition opens its community library', () async {
    final page =
        await projectNotificationDestination(
              {'project_id': 'p', 'community_id': 'community'},
              _Repo(),
              communitiesRepo: _Communities(),
            )
            as CommunityHomeScreen;
    expect(page.community.id, 'community');
    expect(page.initialTab, 1);
  });
  test('timeline notice carries the exact event to its detail view', () async {
    final page =
        await projectNotificationDestination(
              notice('timeline_rescheduled', 'event'),
              _Repo(),
            )
            as ProjectDashboard;
    expect(page.initialEventId, 'event');
    expect(page.initialSection, ProjectDashboardSection.timeline);
  });
  test('forum reply resolves its parent discussion', () async {
    final page =
        await projectNotificationDestination(
              notice('forum_reply', 'reply'),
              _Repo(),
              bulletinRepo: _Bulletin(),
            )
            as ProjectDashboard;
    expect(page.initialPostId, 'parent-post');
    expect(page.initialCommentId, 'reply');
    expect(page.initialSection, ProjectDashboardSection.collaboration);
  });
  test('removed reply gives an unavailable result', () async {
    await expectLater(
      projectNotificationDestination(
        notice('forum_reply', 'deleted'),
        _Repo(),
        bulletinRepo: _Bulletin(),
      ),
      throwsStateError,
    );
  });
  test(
    'member changes open Members, budget changes open read-only costs for viewers',
    () async {
      final page =
          await projectNotificationDestination(
                notice('member_role_updated', 'member'),
                _Repo(),
              )
              as ProjectDashboard;
      expect(page.initialCollaborationSection, CollaborationSection.members);
      final budget =
          await projectNotificationDestination(
                notice('budget_updated', 'p'),
                _Repo(),
              )
              as ProjectDashboard;
      expect(budget.projectId, 'p');
      expect(budget.isOwner, isFalse);
      expect(budget.openMaterialsOnLoad, isTrue);
    },
  );
}
