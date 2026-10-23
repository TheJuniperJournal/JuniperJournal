import 'package:flutter/material.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../backend/db/repositories/project_bulletin_repo.dart';
import '../../../backend/db/repositories/communities_repo.dart';
import '../../project/pages/project_dashboard.dart';
import '../../project/pages/project_collaboration_tab.dart';
import '../../community/pages/community_home_screen.dart';

/// Enter the normal community/project flow, keeping its navigation available.
Future<Widget> projectNotificationDestination(
  Map<String, dynamic> notification,
  ProjectsRepo repo, {
  ProjectBulletinRepo? bulletinRepo,
  CommunitiesRepo? communitiesRepo,
}) async {
  final communityId = notification['community_id']?.toString();
  if (communityId != null && communityId.isNotEmpty) {
    final community = await (communitiesRepo ?? CommunitiesRepo())
        .getCommunityById(communityId);
    if (community == null)
      throw StateError('This community is no longer available to you.');
    return CommunityHomeScreen(community: community, initialTab: 1);
  }
  final project = await repo.getProjectById(
    notification['project_id'].toString(),
  );
  if (project == null)
    throw StateError('This project is no longer available to you.');
  final kind = notification['activity_type']?.toString() ?? '';
  final source = notification['source_id']?.toString();
  final manage = await repo.canManageProject(project.id);
  var section = ProjectDashboardSection.overview;
  var collaboration = CollaborationSection.bulletin;
  String? postId;
  if (kind.startsWith('journal_')) {
    final entries = await repo.getJournalEntries(projectId: project.id) ?? [];
    final entry = entries.where((item) => item.id == source).firstOrNull;
    if (entry == null)
      throw StateError(
        'This journal entry was removed or is no longer available to you.',
      );
    return ProjectDashboard(
      projectId: project.id,
      projectName: project.projectName,
      tags: project.tags,
      isOwner: manage,
      projectsRepo: repo,
      initialSection: ProjectDashboardSection.development,
      initialJournalEntry: entry,
    );
  }
  if (kind.startsWith('timeline_')) section = ProjectDashboardSection.timeline;
  if (kind.startsWith('forum_') || kind.startsWith('member_')) {
    section = ProjectDashboardSection.collaboration;
    collaboration = kind.startsWith('member_')
        ? CollaborationSection.members
        : CollaborationSection.bulletin;
    postId = kind == 'forum_post' ? source : null;
    if (kind == 'forum_reply' && source != null) {
      postId = await (bulletinRepo ?? ProjectBulletinRepo()).postIdForComment(
        source,
      );
      if (postId == null)
        throw StateError('This discussion is no longer available.');
    }
  }
  return ProjectDashboard(
    projectId: project.id,
    projectName: project.projectName,
    tags: project.tags,
    isOwner: manage,
    projectsRepo: repo,
    initialSection: section,
    initialCollaborationSection: collaboration,
    initialPostId: postId,
    initialCommentId: kind == 'forum_reply' ? source : null,
    initialEventId: kind.startsWith('timeline_') ? source : null,
    openMaterialsOnLoad:
        kind == 'materials_updated' || kind == 'budget_updated',
    bulletinRepo: bulletinRepo,
  );
}
