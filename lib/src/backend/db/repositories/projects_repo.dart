import '../models/project_activity_event.dart';
import '../../../shared/widgets/eco_reward_notice_host.dart'
    show ecoRewardNotice, journalCompletionNotice, JournalCompletionNotice;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../features/project/utils/journal_completion.dart';
import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/collaboration_request.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/security/input_validator.dart';

class ProjectsRepo {
  ProjectsRepo({SupabaseClient? client}) : _providedClient = client;
  final SupabaseClient? _providedClient;
  static const table = 'projects';
  static const journalEntriesTable = 'journal_entries';
  SupabaseClient get _client =>
      _providedClient ?? SupabaseDatabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;

  bool get journalCollaborationEnabled {
    // Enable only after the collaboration migration has been deployed.
    if (!const bool.fromEnvironment('JOURNAL_COLLABORATION_ENABLED'))
      return false;
    try {
      return _client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> journalCollaborationHeartbeat(
    String entryId,
    String sessionId,
    String section,
  ) async => Map<String, dynamic>.from(
    await _client.rpc(
          'journal_collaboration_heartbeat',
          params: {
            'p_entry_id': entryId,
            'p_session_id': sessionId,
            'p_section': section,
          },
        )
        as Map,
  );

  Future<JournalEntry> saveCollaborativeJournal(
    String entryId,
    String sessionId,
    Map<String, dynamic> base,
    Map<String, dynamic> desired,
    bool complete,
  ) async {
    final titleError = InputValidator.journalTitle(
      desired['title']?.toString() ?? '',
    );
    if (titleError != null) throw FormatException(titleError);
    final row = await _client.rpc(
      'save_collaborative_journal',
      params: {
        'p_entry_id': entryId,
        'p_session_id': sessionId,
        'p_base': base,
        'p_desired': desired,
        'p_complete': complete,
      },
    );
    final result = JournalEntry.fromMap(Map<String, dynamic>.from(row as Map));
    if (complete && !journalEntryIsComplete(JournalEntry.fromMap(base))) {
      await _announceJournalReward(entryId);
    }
    return result;
  }

  Future<void> releaseJournalCollaboration(
    String entryId,
    String sessionId,
  ) async {
    await _client.rpc(
      'release_journal_collaboration',
      params: {'p_entry_id': entryId, 'p_session_id': sessionId},
    );
  }

  bool _missingDocumentation(Object error) =>
      error is PostgrestException &&
      (error.code == 'PGRST205' || error.code == '42P01');

  /// Compatibility for a database that has not installed the public views yet.
  /// Stored rows are read ONLY for independently verified project participants;
  /// the query remains scoped to those IDs and existing database RLS still applies.
  Future<List<Map<String, dynamic>>> _journalRows(
    List<String> projectIds, {
    String columns = '*',
    String? orderBy,
    bool publishedOnly = false,
  }) async {
    if (projectIds.isEmpty) return [];
    Future<List<Map<String, dynamic>>> read(
      String source,
      List<String> ids,
    ) async {
      var query = _client
          .from(source)
          .select(columns)
          .inFilter('project_id', ids);
      if (publishedOnly)
        query = query
            .eq('feed_ready', true)
            .not('feed_published_at', 'is', null);
      final rows = orderBy == null
          ? await query
          : await query.order(orderBy, ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    }

    try {
      return await read('journal_documentation', projectIds);
    } catch (error) {
      if (!_missingDocumentation(error)) rethrow;
      final members = <String>[];
      for (final id in projectIds.toSet()) {
        if (await canViewInternalProjectLogs(id)) members.add(id);
      }
      if (members.isEmpty) rethrow;
      return read(journalEntriesTable, members);
    }
  }

  Future<List<Map<String, dynamic>>> _projectRows(
    List<String> projectIds, {
    String columns = '*',
  }) async {
    if (projectIds.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(
        await _client
            .from('project_documentation')
            .select(columns)
            .inFilter('id', projectIds),
      );
    } catch (error) {
      if (!_missingDocumentation(error)) rethrow;
      final members = <String>[];
      for (final id in projectIds.toSet()) {
        if (await canViewInternalProjectLogs(id)) members.add(id);
      }
      if (members.isEmpty) rethrow;
      return List<Map<String, dynamic>>.from(
        await _client.from(table).select(columns).inFilter('id', members),
      );
    }
  }

  /// RLS filters private activity before pagination, including journal drafts.
  /// Null means history is unavailable; an empty list means no visible events.
  Future<List<ProjectActivityEvent>?> getProjectActivity(
    String projectId, {
    int offset = 0,
    int limit = 15,
  }) async {
    if (!await canViewInternalProjectLogs(projectId)) return [];
    try {
      final rows = await _client
          .from('project_activity_feed')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit - 1);
      return rows.map((row) => ProjectActivityEvent.fromJson(row)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateProjectCommunities(
    String id,
    List<Map<String, dynamic>> links,
  ) async {
    try {
      final updated = await _client
          .from(table)
          .update({'community_links': links})
          .eq('id', id)
          .select('id')
          .maybeSingle();
      return updated != null;
    } catch (e) {
      debugPrint('updateProjectCommunities: $e');
      return false;
    }
  }

  /// Feed eligibility uses complete journal updates, independent of private drafts.
  Future<List<Project>> projectsWithCompletedJournalEntries(
    List<Project> projects,
  ) async {
    if (projects.isEmpty) return [];
    try {
      final rows = await _journalRows(
        projects.map((project) => project.id).toList(),
        columns: 'id, project_id, title, content, progress',
      );
      final completedIds = rows
          .where((row) => journalEntryIsComplete(JournalEntry.fromMap(row)))
          .map((row) => row['project_id'].toString())
          .toSet();
      return projects
          .where((project) => completedIds.contains(project.id))
          .toList();
    } catch (e) {
      debugPrint('Completed journal feed lookup failed: $e');
      rethrow;
    }
  }

  Future<List<Project>> getExploreProjects() async {
    final rows = await _client
        .from('project_documentation')
        .select()
        .ilike('visibility', 'public')
        .order('created_at', ascending: false);
    final projects = [for (final row in rows) Project.fromMap(row)];
    if (projects.isEmpty) return projects;
    final entries = await _client
        .from('journal_documentation')
        .select(
          'id, project_id, title, content, progress, created_at, feed_published_at',
        )
        .inFilter('project_id', projects.map((project) => project.id).toList());
    final latest = <String, DateTime>{};
    for (final row in entries) {
      if (!journalEntryIsComplete(JournalEntry.fromMap(row))) continue;
      final date = DateTime.tryParse(
        (row['feed_published_at'] ?? row['created_at'])?.toString() ?? '',
      );
      final id = row['project_id'].toString();
      if (date != null && (latest[id] == null || date.isAfter(latest[id]!))) {
        latest[id] = date;
      }
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    projects.sort((a, b) {
      final order = (latest[b.id] ?? b.createdAt ?? epoch).compareTo(
        latest[a.id] ?? a.createdAt ?? epoch,
      );
      return order != 0 ? order : a.id.compareTo(b.id);
    });
    return projects;
  }

  Future<List<JournalEntry>> getCommunityJournalEntries({
    required String projectId,
    required String communityId,
  }) async {
    final published = await _client.rpc(
      'community_journal_entry_ids',
      params: {'p_project_id': projectId, 'p_community_id': communityId},
    );
    final ids = (published as List).map((id) => id.toString()).toSet();
    if (ids.isEmpty) return [];
    return (await getJournalEntries(projectId: projectId) ?? [])
        .where(
          (entry) => ids.contains(entry.id) && journalEntryIsComplete(entry),
        )
        .toList();
  }

  Future<Map<String, Map<String, Set<String>>>> getProjectImpactFilterValues(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return {};
    final entries = await _journalRows(
      projectIds,
      columns: 'id, project_id, title, content, progress',
    );
    final officialIds = entries
        .where((row) => journalEntryIsComplete(JournalEntry.fromMap(row)))
        .map((row) => row['id'].toString())
        .toSet();
    final impacts = await _client
        .from(_impactEntriesTable)
        .select(
          'project_id, linked_journal_entry_id, metric, impact_scale, pattern_type',
        )
        .inFilter('project_id', projectIds);
    final values = <String, Map<String, Set<String>>>{};
    for (final row in entries) {
      if (!officialIds.contains(row['id'].toString())) continue;
      final project = values.putIfAbsent(
        row['project_id'].toString(),
        () => {'Phase': {}, 'Metrics': {}, 'Impact': {}, 'Pattern': {}},
      );
      final phase = row['progress']?.toString();
      if (phase != null && phase.isNotEmpty) project['Phase']!.add(phase);
    }
    for (final impact in impacts) {
      if (!officialIds.contains(impact['linked_journal_entry_id']?.toString()))
        continue;
      final project = values.putIfAbsent(
        impact['project_id'].toString(),
        () => {'Metrics': {}, 'Impact': {}, 'Pattern': {}},
      );
      for (final pair in [
        ('Metrics', 'metric'),
        ('Impact', 'impact_scale'),
        ('Pattern', 'pattern_type'),
      ]) {
        final value =
            impact[pair.$2]?.toString().split(' (').first.trim() ?? '';
        if (value.isNotEmpty) project[pair.$1]!.add(value);
      }
    }
    return values;
  }

  Future<Map<String, int>> getJournalEntryCounts(
    List<String> projectIds, {
    bool completedOnly = false,
  }) async {
    if (projectIds.isEmpty) return {};
    final rows = await _journalRows(
      projectIds,
      columns: 'id, project_id, title, content, progress',
    );
    final counts = <String, int>{};
    for (final row in rows) {
      if (completedOnly && !journalEntryIsComplete(JournalEntry.fromMap(row)))
        continue;
      final id = row['project_id'].toString();
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<UserProfile>> getPublicProjectDirectory(String projectId) async {
    try {
      final rows = await _client.rpc(
        'public_project_directory',
        params: {'p_project_id': projectId},
      );
      return [
        for (final row in rows as List)
          UserProfile.fromMap(Map<String, dynamic>.from(row)),
      ];
    } catch (e) {
      debugPrint('Project directory unavailable: $e');
      return [];
    }
  }

  Future<bool> canViewInternalProjectLogs(String projectId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || projectId.isEmpty) return false;
    try {
      final project = await _client
          .from(table)
          .select('user_id')
          .eq('id', projectId)
          .maybeSingle();
      if (project?['user_id'] == userId) return true;
      final membership = await _client
          .from(_collaboratorsTable)
          .select('user_id')
          .eq('project_id', projectId)
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .maybeSingle();
      return membership != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<Project>> getLinkedCommunityProjects(String communityId) async {
    try {
      final rows = await _client.rpc(
        'community_documentation_projects',
        params: {'p_community_id': communityId},
      );
      return [
        for (final row in rows as List)
          Project.fromMap(Map<String, dynamic>.from(row)),
      ];
    } catch (e) {
      debugPrint('Community library: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjectNotifications() async {
    try {
      final rows = await _client
          .from('project_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('Project notifications: $e');
      return [];
    }
  }

  Future<void> markProjectNotificationRead(String id) async {
    await _client
        .from('project_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<List<Project>> getLibraryProjects() async {
    final own = await getCurrentUserProjects() ?? [];
    final shared = await getCollaboratedProjects();
    final projects = {
      for (final project in [...own, ...shared]) project.id: project,
    };
    return projects.values.toList()..sort(
      (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      ),
    );
  }

  Future<List<Project>?> getCurrentUserProjects() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from(table)
          .select(
            'id, user_id, project_name, tags, project_image_url, created_at, '
            'likes, problem_statement, difficulty, project_scale, progress, '
            'journal_entries(progress)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        rows,
      ).map(Project.fromMap).toList();
    } catch (e, st) {
      debugPrint('getCurrentUserProjects error: $e\n$st');
      return null;
    }
  }

  Future<List<Project>?> getProjectsByUserId({required String userId}) async {
    try {
      final rows = await _client
          .from('project_documentation')
          .select('id, project_name, tags, project_image_url, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final maps = List<Map<String, dynamic>>.from(rows);
      final counts = await getJournalEntryCounts(
        maps.map((row) => row['id'].toString()).toList(),
        completedOnly: true,
      );
      return [
        for (final row in maps)
          Project.fromMap({
            ...row,
            'journal_entries': [
              {'count': counts[row['id']] ?? 0},
            ],
          }),
      ];
    } catch (e, st) {
      debugPrint('getProjectsByUserId error: $e\n$st');
      return null;
    }
  }

  Future<List<Project>?> getProjectsForFeed({
    required List<String> ownerIds,
  }) async {
    return getAudienceFeedProjects(ownerIds: ownerIds);
  }

  Future<List<Project>> getAudienceFeedProjects({
    List<String>? ownerIds,
    String? communityId,
  }) async {
    try {
      if (communityId != null) {
        return await projectsWithCompletedJournalEntries(
          await getLinkedCommunityProjects(communityId),
        );
      }
      if (currentUserId == null) {
        return await projectsWithCompletedJournalEntries(
          await getExploreProjects(),
        );
      }
      final rows = await _client.rpc(
        'project_feed_for_audience',
        params: {'p_owner_ids': ownerIds, 'p_community_id': communityId},
      );
      return [
        for (final row in rows as List)
          Project.fromMap(Map<String, dynamic>.from(row)),
      ];
    } catch (e) {
      debugPrint('Audience feed: $e');
      rethrow;
    }
  }

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
    lastProjectSaveError = null;
    final userId = currentUserId;
    if (userId == null) {
      lastProjectSaveError =
          'Your session has expired. Sign in again to create a project.';
      return null;
    }
    lastProjectSaveError =
        InputValidator.projectName(projectName) ??
        InputValidator.problemStatement(problemStatement) ??
        InputValidator.tags(tags);
    if (lastProjectSaveError != null) return null;

    try {
      final row = await _client
          .from('projects')
          .insert({
            if (learningObjectives != null)
              'learning_objectives': learningObjectives,
            if (projectType != null) 'project_type': projectType,
            if (communityLinks != null) 'community_links': communityLinks,
            if (shareFriends != null) 'share_friends': shareFriends,
            if (sharedCommunityIds != null)
              'shared_community_ids': sharedCommunityIds,
            'project_name': projectName,
            'problem_statement': problemStatement,
            'tags': tags.isEmpty ? null : tags,
            'user_id': userId,
            'difficulty': difficulty,
            'project_scale': projectScale,
            'visibility': visibility,
            'project_image_url': projectImageUrl,
          })
          .select()
          .single();
      return Project.fromMap(row);
    } on PostgrestException catch (e, st) {
      lastProjectSaveError = e.code == '42501'
          ? 'The project could not be created because of a database permission error. Please try again or contact support.'
          : 'Could not create the project. Please try again.';
      debugPrint('createProject error: $e\n$st');
      return null;
    } catch (e, st) {
      lastProjectSaveError =
          'Could not create the project. Check your connection and try again.';
      debugPrint('createProject error: $e\n$st');
      return null;
    }
  }

  /// Published entries only, including for the author reading their own feed.
  Future<List<JournalEntry>> getPublishedJournalEntries(
    String projectId,
  ) async {
    final rows = await _journalRows(
      [projectId],
      publishedOnly: true,
      orderBy: 'feed_published_at',
    );
    final entries = List<Map<String, dynamic>>.from(rows);
    if (entries.isNotEmpty) {
      try {
        await hydrateAssessmentDefinitions(entries);
      } catch (e) {
        debugPrint('Assessment definitions unavailable: $e');
      }
      await _hydrateEntryRewards(entries, projectId);
    }
    return completedJournalFeedEntries([
      for (final row in entries) JournalEntry.fromMap(row),
    ]);
  }

  Future<void> _hydrateEntryRewards(
    List<Map<String, dynamic>> entries,
    String projectId,
  ) async {
    try {
      final rewards =
          await _client.rpc(
                'journal_entry_rewards',
                params: {'p_project_id': projectId},
              )
              as Map;
      for (final entry in entries) {
        entry['eco_points'] = rewards[entry['id']?.toString()] ?? 0;
      }
    } catch (e) {
      debugPrint('Entry rewards unavailable: $e');
    }
  }

  Future<bool> likeProject({required String id}) async {
    try {
      await _client.rpc('like_project', params: {'p_project_id': id});
      return true;
    } catch (e, st) {
      debugPrint('likeProject error: $e\n$st');
      return false;
    }
  }

  Future<bool> unlikeProject({required String id}) async {
    try {
      await _client.rpc('unlike_project', params: {'p_project_id': id});
      return true;
    } catch (e, st) {
      debugPrint('unlikeProject error: $e\n$st');
      return false;
    }
  }

  // ── Bookmarks ───────────────────────────────────────────────────────────────

  Future<List<Project>> getBookmarkedProjects() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client
        .from('project_bookmarks')
        .select('projects(*)')
        .eq('user_id', userId);
    return [
      for (final row in rows)
        if (row['projects'] is Map)
          Project.fromMap(Map<String, dynamic>.from(row['projects'] as Map)),
    ];
  }

  Future<bool> bookmarkProject({required String id}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('project_bookmarks').upsert({
        'user_id': user.id,
        'project_id': id,
      });
      return true;
    } catch (e, st) {
      debugPrint('bookmarkProject error: $e\n$st');
      return false;
    }
  }

  Future<bool> unbookmarkProject({required String id}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client
          .from('project_bookmarks')
          .delete()
          .eq('user_id', user.id)
          .eq('project_id', id);
      return true;
    } catch (e, st) {
      debugPrint('unbookmarkProject error: $e\n$st');
      return false;
    }
  }

  Future<Set<String>> getBookmarkedProjectIds({
    required List<String> projectIds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || projectIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('project_bookmarks')
          .select('project_id')
          .eq('user_id', user.id)
          .inFilter('project_id', projectIds);
      return Set<String>.from(
        List<Map<String, dynamic>>.from(
          rows,
        ).map((r) => r['project_id'].toString()),
      );
    } catch (e, st) {
      debugPrint('getBookmarkedProjectIds error: $e\n$st');
      return {};
    }
  }

  Future<Set<String>> getLikedProjectIds({
    required List<String> projectIds,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || projectIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('project_likes')
          .select('project_id')
          .eq('user_id', user.id)
          .inFilter('project_id', projectIds);
      return Set<String>.from(
        List<Map<String, dynamic>>.from(
          rows,
        ).map((r) => r['project_id'].toString()),
      );
    } catch (e, st) {
      debugPrint('getLikedProjectIds error: $e\n$st');
      return {};
    }
  }

  Future<bool> updateProjectConfiguration({
    required String id,
    required String problemStatement,
    String? difficulty,
    List<String>? tags,
    String? projectScale,
    String? visibility,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from(table)
          .update({
            'problem_statement': problemStatement,
            'difficulty': difficulty,
            'tags': tags,
            'project_scale': projectScale,
            'visibility': visibility,
          })
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
      debugPrint('updateProjectConfiguration error: $e\n$st');
      return false;
    }
  }

  Future<Project?> getProject(int id) async {
    try {
      final row = (await _projectRows([id.toString()], columns: '*')).single;
      return Project.fromMap(row);
    } catch (e, st) {
      debugPrint('getProject error: $e\n$st');
      return null;
    }
  }

  Future<Project?> getProjectById(String id) async {
    try {
      final row = (await _projectRows([id.toString()], columns: '*')).single;
      return Project.fromMap(row);
    } catch (e, st) {
      debugPrint('getProjectById error: $e\n$st');
      return null;
    }
  }

  String? lastProjectSaveError;

  Future<bool> updateProjectMetadata({
    required String id,
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    List<Map<String, dynamic>>? learningObjectives,
    String? projectImageUrl,
    String? difficulty,
    String? projectScale,
    String? visibility,
    String? projectType,
    List<Map<String, dynamic>>? communityLinks,
    bool? shareFriends,
    List<String>? sharedCommunityIds,
  }) async {
    lastProjectSaveError = null;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      lastProjectSaveError =
          'Your session has expired. Sign in again to save changes.';
      return false;
    }
    lastProjectSaveError =
        InputValidator.projectName(projectName) ??
        InputValidator.problemStatement(problemStatement) ??
        InputValidator.tags(tags);
    if (lastProjectSaveError != null) return false;
    if (!await canManageProject(id)) {
      lastProjectSaveError =
          'Only the project owner or a project admin can save settings.';
      return false;
    }
    try {
      final updated = await _client
          .from(table)
          .update({
            if (learningObjectives != null)
              'learning_objectives': learningObjectives,
            if (projectType != null) 'project_type': projectType,
            if (communityLinks != null) 'community_links': communityLinks,
            if (shareFriends != null) 'share_friends': shareFriends,
            if (sharedCommunityIds != null)
              'shared_community_ids': sharedCommunityIds,
            'project_name': projectName,
            'problem_statement': problemStatement,
            'tags': tags,
            'project_image_url': projectImageUrl,
            'difficulty': difficulty,
            'project_scale': projectScale,
            'visibility': visibility,
          })
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        lastProjectSaveError =
            'This project is unavailable or you no longer have permission to edit it.';
        return false;
      }
      return true;
    } catch (e, st) {
      lastProjectSaveError =
          'Could not save project settings. Check your connection and try again.';
      debugPrint('updateProjectMetadata error: $e\n$st');
      return false;
    }
  }

  Future<bool> updateProjectImage({
    required String id,
    String? projectImageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      if (!await canManageProject(id)) return false;
      final updated = await _client
          .from(table)
          .update({'project_image_url': projectImageUrl})
          .eq('id', id)
          .select('id')
          .maybeSingle();
      return updated != null;
    } catch (e, st) {
      debugPrint('updateProjectImage error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteProject({required String id}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      // The database cascades project dependents in the same transaction.
      // Do not delete journals in a separate request before project deletion.
      final deletedRows = await _client
          .from(table)
          .delete()
          .eq('id', id)
          .eq('user_id', user.id)
          .select('id');

      return deletedRows.isNotEmpty;
    } catch (e, st) {
      debugPrint('deleteProject error: $e\n$st');
      return false;
    }
  }

  Future<bool> updateTimeline({
    required String id,
    required List<Map<String, String>> timeline,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from(table)
          .update({'timeline': timeline})
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
      debugPrint('updateTimeline error: $e\n$st');
      return false;
    }
  }

  Future<List<Map<String, String>>?> getTimeline(String id) async {
    if (!await canViewInternalProjectLogs(id)) return [];
    try {
      final result = (await _projectRows([
        id.toString(),
      ], columns: 'timeline')).single;
      final timeline = result['timeline'];
      if (timeline == null) return [];
      return (timeline as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('getTimeline error: $e\n$st');
      return null;
    }
  }

  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async {
    final user = _client.auth.currentUser;

    try {
      final result = await _journalRows(
        [projectId],
        columns:
            'id, user_id, title, content, created_at, updated_at, project_id, progress, tags',
        orderBy: 'created_at',
      );

      final entries = List<Map<String, dynamic>>.from(result);
      if (entries.isEmpty) return [];
      try {
        await hydrateAssessmentDefinitions(entries);
      } catch (e) {
        debugPrint("Assessment definitions unavailable: $e");
      }

      // Fetch author profiles separately (no FK from user_id → profiles)
      final authorIds = entries
          .map((e) => e['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      List<Map<String, dynamic>> profileRows = [];
      if (user != null) {
        try {
          profileRows = List<Map<String, dynamic>>.from(
            await _client
                .from('profiles')
                .select('id, avatar_url, display_name, username')
                .inFilter('id', authorIds),
          );
        } catch (_) {}
      }

      if (profileRows.length < authorIds.length) {
        for (final profile in await getPublicProjectDirectory(projectId)) {
          if (!profileRows.any((row) => row['id'] == profile.id)) {
            profileRows.add({
              'id': profile.id,
              'display_name': profile.displayName,
              'username': profile.username,
              'avatar_url': profile.avatarUrl,
            });
          }
        }
      }
      final profileMap = {
        for (final p in List<Map<String, dynamic>>.from(profileRows))
          p['id'].toString(): p,
      };

      if (user != null) await _hydrateEntryRewards(entries, projectId);
      final canViewDrafts = await canViewInternalProjectLogs(projectId);
      return entries
          .map((e) {
            final profile = profileMap[e['user_id']?.toString()];
            return JournalEntry.fromMap({...e, 'profiles': profile});
          })
          .where((entry) => canViewDrafts || journalEntryIsComplete(entry))
          .toList();
    } catch (e, st) {
      debugPrint('getJournalEntries error: $e\n$st');
      return null;
    }
  }

  String? lastJournalSaveError;

  Future<void> _announceJournalReward(String entryId) async {
    try {
      final points = await _client.rpc(
        'claim_eco_reward_notice',
        params: {'p_source': 'journal', 'p_id': entryId},
      );
      // The journal ledger claim is the one-time completion notification gate.
      // Later edits or newly added impact records must not repeat the popup.
      if (points is! num || points <= 0) return;
      var total = points.toInt();
      final impacts = await _client
          .from('impact_entries')
          .select('metric')
          .eq('linked_journal_entry_id', entryId);
      for (final metric
          in impacts
              .map((row) => row['metric'].toString().trim().toLowerCase())
              .toSet()) {
        final award = await _client.rpc(
          'claim_eco_reward_notice',
          params: {'p_source': 'impact', 'p_id': '$entryId:$metric'},
        );
        if (award is num) total += award.toInt();
      }
      if (total > 0) {
        journalCompletionNotice.value = JournalCompletionNotice(
          entryId: entryId,
          points: total,
        );
      }
    } catch (e) {
      debugPrint('Reward notice: $e');
    }
  }

  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    lastJournalSaveError = null;
    final userId = currentUserId;
    if (userId == null) {
      lastJournalSaveError = 'Sign in again to save this entry.';
      return null;
    }

    final titleErr = InputValidator.journalTitle(title);
    if (titleErr != null) {
      lastJournalSaveError = titleErr;
      return null;
    }

    // RLS authorizes owners and accepted project collaborators.
    try {
      final row = await _client
          .from(journalEntriesTable)
          .insert({
            'project_id': projectId,
            'user_id': userId,
            'title': title,
            'content': content,
            'feed_ready': journalEntryIsComplete(
              JournalEntry.fromMap({
                'content': content,
                'title': title,
                'progress': progress,
              }),
            ),
            'progress': progress,
          })
          .select(
            'id, title, content, created_at, updated_at, project_id, progress',
          )
          .single();

      if (journalEntryIsComplete(
        JournalEntry(
          projectId: projectId,
          id: row['id'].toString(),
          title: title,
          content: content,
          progress: progress,
        ),
      ))
        await _announceJournalReward(row['id'].toString());
      return JournalEntry.fromMap(row);
    } catch (e, st) {
      lastJournalSaveError = e is PostgrestException && e.code == '42501'
          ? 'You need to be an accepted project member to save an entry.'
          : 'Could not save this entry. Check your connection and try again.';
      debugPrint('createJournalEntry error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    lastJournalSaveError = null;
    final userId = currentUserId;
    if (userId == null) {
      lastJournalSaveError = 'Sign in again to save this entry.';
      return false;
    }
    if (title != null && InputValidator.journalTitle(title) != null) {
      lastJournalSaveError = InputValidator.journalTitle(title);
      return false;
    }

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) {
      updates['content'] = content;
      updates['feed_ready'] = journalEntryIsComplete(
        JournalEntry.fromMap({
          'content': content,
          'title': title,
          'progress': progress,
        }),
      );
    }
    updates['progress'] = progress; // always write (allows clearing)
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    try {
      var firstCompletion = false;
      if (updates['feed_ready'] == true) {
        final previous = await _client
            .from(journalEntriesTable)
            .select('feed_ready, feed_published_at')
            .eq('id', entryId)
            .maybeSingle();
        firstCompletion =
            previous != null &&
            previous['feed_ready'] != true &&
            previous['feed_published_at'] == null;
      }
      final updated = await _client
          .from(journalEntriesTable)
          .update(updates)
          .eq('id', entryId)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        lastJournalSaveError =
            'This entry is unavailable or you no longer have permission to edit it.';
        return false;
      }
      if (firstCompletion) await _announceJournalReward(entryId);
      return true;
    } catch (e, st) {
      lastJournalSaveError = e is PostgrestException && e.code == '42501'
          ? 'You no longer have permission to edit this entry.'
          : 'Could not save this entry. Check your connection and try again.';
      debugPrint('updateJournalEntry error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteJournalEntry({required String entryId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final deleted = await _client
          .from(journalEntriesTable)
          .delete()
          .eq('id', entryId)
          .select('id');
      return deleted.isNotEmpty;
    } catch (e, st) {
      debugPrint('deleteJournalEntry error: $e\n$st');
      return false;
    }
  }

  // ── Impact entries ─────────────────────────────────────────────────────────

  static const _impactEntriesTable = 'impact_entries';

  Future<Map<String, dynamic>> ecoPointsSummary(String userId) async =>
      Map<String, dynamic>.from(
        await _client.rpc('eco_points_summary', params: {'p_user_id': userId}),
      );
  Future<Map<String, double>> getCurrentUserSubjectEcoPoints() async {
    final id = currentUserId;
    if (id == null) return {};
    try {
      final data = await ecoPointsSummary(id);
      return (data['subjects'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    } catch (e) {
      debugPrint('EcoPoints: $e');
      return {};
    }
  }

  Future<double> getTotalEcoPointsForUser(String userId) async {
    try {
      return ((await ecoPointsSummary(userId))['total'] as num? ?? 0)
          .toDouble();
    } catch (e) {
      debugPrint('EcoPoints: $e');
      return 0;
    }
  }

  Future<double> getTotalEcoPoints() async {
    final id = currentUserId;
    return id == null ? 0 : getTotalEcoPointsForUser(id);
  }

  Future<void> confirmJournalContribution(String id) async {
    await _client.rpc(
      'confirm_journal_contribution',
      params: {'p_entry_id': id},
    );
  }

  Future<void> hydrateAssessmentDefinitions(
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    final definitions =
        await _client.rpc(
              'assessment_author_definitions',
              params: {
                'p_entry_ids': entries.map((e) => e['id'].toString()).toList(),
              },
            )
            as Map;
    dynamic hydrate(dynamic node) {
      if (node is Map) {
        final id = node['assessment_id'];
        if (id != null && definitions[id] is Map) return definitions[id];
        return node.map((k, v) => MapEntry(k, hydrate(v)));
      }
      if (node is List) return node.map(hydrate).toList();
      return node;
    }

    for (final entry in entries) entry['content'] = hydrate(entry['content']);
  }

  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async {
    try {
      final result = await _client
          .from(_impactEntriesTable)
          .select(
            'id, project_id, title, metric, impact_scale, pattern_type, '
            'evidence_type, confidence_score, measurement, measurement_unit, '
            'eco_points, linked_journal_entry_id, created_at, updated_at',
          )
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        result,
      ).map(ImpactEntry.fromMap).toList();
    } catch (e, st) {
      debugPrint('getImpactEntries error: $e\n$st');
      return null;
    }
  }

  Future<void> _announceImpactReward(Map<String, dynamic> row) async {
    final entry = row['linked_journal_entry_id'];
    if (entry == null) return;
    try {
      final source = '$entry:${row['metric'].toString().trim().toLowerCase()}';
      final points = await _client.rpc(
        'claim_eco_reward_notice',
        params: {'p_source': 'impact', 'p_id': source},
      );
      if (points is num && points > 0) {
        ecoRewardNotice.value = null;
        ecoRewardNotice.value =
            '+${points.toInt()} EcoPoints earned for documented impact.';
      }
    } catch (e) {
      debugPrint('Impact reward notice: $e');
    }
  }

  Future<ImpactEntry?> createImpactEntry({
    required String projectId,
    required String title,
    required String metric,
    required String impactScale,
    required String patternType,
    required String evidenceType,
    required String confidenceScore,
    double? measurement,
    String? measurementUnit,
    required double ecoPoints,
    String? linkedJournalEntryId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    // Verify the current user owns the target project before writing
    final owned = await _client
        .from('project_documentation')
        .select('id')
        .eq('id', projectId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (owned == null) throw Exception('Not authorized');

    try {
      final row = await _client
          .from(_impactEntriesTable)
          .insert({
            'project_id': projectId,
            'user_id': user.id,
            'title': title,
            'metric': metric,
            'impact_scale': impactScale,
            'pattern_type': patternType,
            'evidence_type': evidenceType,
            'confidence_score': confidenceScore,
            'measurement': measurement,
            'measurement_unit': measurementUnit,
            'eco_points': ecoPoints,
            'linked_journal_entry_id': linkedJournalEntryId,
          })
          .select(
            'id, project_id, title, metric, impact_scale, pattern_type, '
            'evidence_type, confidence_score, measurement, measurement_unit, '
            'eco_points, linked_journal_entry_id, created_at, updated_at',
          )
          .single();

      await _announceImpactReward(row);
      return ImpactEntry.fromMap(row);
    } catch (e, st) {
      debugPrint('createImpactEntry error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateImpactEntry({
    required String entryId,
    required String title,
    required String metric,
    required String impactScale,
    required String patternType,
    required String evidenceType,
    required String confidenceScore,
    double? measurement,
    String? measurementUnit,
    required double ecoPoints,
    String? linkedJournalEntryId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final saved = await _client
          .from(_impactEntriesTable)
          .update({
            'title': title,
            'metric': metric,
            'impact_scale': impactScale,
            'pattern_type': patternType,
            'evidence_type': evidenceType,
            'confidence_score': confidenceScore,
            'measurement': measurement,
            'measurement_unit': measurementUnit,
            'eco_points': ecoPoints,
            'linked_journal_entry_id': linkedJournalEntryId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', entryId)
          .eq('user_id', user.id)
          .select('id, metric, linked_journal_entry_id')
          .maybeSingle();
      if (saved == null) return false;
      await _announceImpactReward(saved);
      return true;
    } catch (e, st) {
      debugPrint('updateImpactEntry error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteImpactEntry({required String entryId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from(_impactEntriesTable)
          .delete()
          .eq('id', entryId)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('deleteImpactEntry error: $e\n$st');
      return false;
    }
  }

  /// Adds [tag] to a journal entry's tags array (no-op if already present).
  Future<void> addTagToJournalEntry({
    required String journalEntryId,
    required String tag,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Read current tags first
      final row = await _client
          .from('journal_documentation')
          .select('tags')
          .eq('id', journalEntryId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) return;
      final current = row['tags'] is List
          ? List<String>.from((row['tags'] as List).map((t) => t.toString()))
          : <String>[];
      if (current.contains(tag)) return;
      final updated = [...current, tag];
      await _client
          .from(journalEntriesTable)
          .update({'tags': updated})
          .eq('id', journalEntryId)
          .eq('user_id', user.id);
    } catch (e, st) {
      debugPrint('addTagToJournalEntry error: $e\n$st');
    }
  }

  Future<bool> updateSolution({
    required String id,
    required String solutionJson,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from(table)
          .update({'solution': solutionJson})
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
      debugPrint('updateSolution error: $e\n$st');
      return false;
    }
  }

  Future<String?> getSolution(String id) async {
    try {
      final result = (await _projectRows([
        id.toString(),
      ], columns: 'solution')).single;
      return result['solution'] as String?;
    } catch (e, st) {
      debugPrint('getSolution error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateMaterialsCost({
    required String id,
    required List<Map<String, dynamic>> materials,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from(table)
          .update({'materials_cost': materials})
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
      debugPrint('updateMaterialsCost error: $e\n$st');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async {
    try {
      final result = (await _projectRows([
        id.toString(),
      ], columns: 'materials_cost')).single;
      final materials = result['materials_cost'];
      if (materials == null) return [];
      return (materials as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      debugPrint('getMaterialsCost error: $e\n$st');
      return null;
    }
  }

  // ── Collaboration ──────────────────────────────────────────────────────────

  static const _collaboratorsTable = 'project_collaborators';
  static const _profilesTable = 'profiles';

  Future<Map<String, List<UserProfile>>> getCollaboratorsForProjects({
    required List<String> projectIds,
  }) async {
    if (projectIds.isEmpty) return {};
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('project_id, user_id')
          .inFilter('project_id', projectIds)
          .eq('status', 'accepted');

      final userIds = rows
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (userIds.isEmpty) return {};

      final profiles = await _client
          .from(_profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final profileById = {
        for (final p in profiles)
          p['id']?.toString() ?? '': UserProfile.fromMap(
            Map<String, dynamic>.from(p),
          ),
      };

      final result = <String, List<UserProfile>>{};
      for (final row in rows) {
        final projectId = row['project_id']?.toString() ?? '';
        final userId = row['user_id']?.toString() ?? '';
        final profile = profileById[userId];
        if (profile != null) {
          result.putIfAbsent(projectId, () => []).add(profile);
        }
      }
      return result;
    } catch (e, st) {
      debugPrint('getCollaboratorsForProjects error: $e\n$st');
      return {};
    }
  }

  String? lastProjectAccessError;

  Future<bool> canManageProject(String projectId) async {
    lastProjectAccessError = null;
    try {
      return await _client.rpc(
            'can_manage_project',
            params: {'p_project_id': projectId},
          ) ==
          true;
    } catch (e) {
      lastProjectAccessError =
          'Could not verify project access. Please try again.';
      debugPrint('canManageProject: $e');
      return false;
    }
  }

  Future<Map<String, String>> getProjectMemberRoles(String projectId) async {
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('user_id, role')
          .eq('project_id', projectId);
      return {
        for (final row in rows)
          row['user_id'].toString():
              row['role']?.toString() ?? 'project_member',
      };
    } catch (_) {
      return {};
    }
  }

  Future<bool> setProjectMemberRole(
    String projectId,
    String userId,
    String role,
  ) async {
    try {
      await _client.rpc(
        'set_project_member_role',
        params: {
          'p_project_id': projectId,
          'p_user_id': userId,
          'p_role': role,
        },
      );
      return true;
    } catch (e) {
      debugPrint('setProjectMemberRole: $e');
      return false;
    }
  }

  Future<Map<String, String>> getProjectMemberStatuses(String projectId) async {
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('user_id,status')
          .eq('project_id', projectId);
      return {
        for (final row in rows)
          row['user_id'].toString(): row['status'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getCommunityProjectInvitations({
    String? communityId,
    String? projectId,
  }) async {
    final data = await _client.rpc(
      'community_project_invitations',
      params: {'p_community_id': communityId, 'p_project_id': projectId},
    );
    return [for (final row in data as List) Map<String, dynamic>.from(row)];
  }

  Future<void> reviewCommunityProjectInvitation(String id, bool accept) async {
    await _client.rpc(
      'review_community_project_invitation',
      params: {'p_id': id, 'p_accept': accept},
    );
  }

  Future<void> cancelCommunityProjectInvitation(String id) async {
    await _client.rpc(
      'cancel_community_project_invitation',
      params: {'p_id': id},
    );
  }

  Future<bool> inviteCollaborator({
    required String projectId,
    required String userId,
    String role = 'project_member',
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    final project = await getProjectById(projectId);
    if (project == null) return false;
    try {
      await _client.rpc(
        'add_project_member',
        params: {
          'p_project_id': projectId,
          'p_user_id': userId,
          'p_role': role,
        },
      );
      return true;
    } catch (e, st) {
      debugPrint('inviteCollaborator error: $e\n$st');
      return false;
    }
  }

  Future<List<UserProfile>?> getProjectInvitees({
    required String projectId,
  }) async {
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('user_id')
          .eq('project_id', projectId)
          .inFilter('status', ['accepted', 'pending']);
      final ids = rows.map((row) => row['user_id'].toString()).toList();
      if (ids.isEmpty) return [];
      final profiles = await _client
          .from('profiles')
          .select()
          .inFilter('id', ids);
      return List<Map<String, dynamic>>.from(
        profiles,
      ).map(UserProfile.fromMap).toList();
    } catch (e) {
      debugPrint('getProjectInvitees: $e');
      return null;
    }
  }

  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async {
    final collaborators = await getProjectCollaborators(projectId: projectId);
    final members = {for (final person in collaborators) person.id: person};
    try {
      final project = (await _projectRows([
        projectId,
      ], columns: 'user_id, project_type')).firstOrNull;
      if (project?['project_type'] == 'solo') members.clear();
      final ownerId = project?['user_id']?.toString();
      if (ownerId != null && !members.containsKey(ownerId)) {
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', ownerId)
            .maybeSingle();
        if (profile != null) members[ownerId] = UserProfile.fromMap(profile);
      }
    } catch (e) {
      debugPrint('Project owner lookup failed: $e');
    }
    return members.values.toList();
  }

  Future<List<UserProfile>> getProjectCollaborators({
    required String projectId,
  }) async {
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('user_id')
          .eq('project_id', projectId)
          .eq('status', 'accepted');

      final userIds = rows
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toList();

      if (userIds.isEmpty) return [];

      final profiles = await _client
          .from(_profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      return List<Map<String, dynamic>>.from(
        profiles,
      ).map(UserProfile.fromMap).toList();
    } catch (e, st) {
      debugPrint('getProjectCollaborators error: $e\n$st');
      return [];
    }
  }

  Future<Set<String>> getPendingOutgoingInvites({
    required String projectId,
  }) async {
    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('user_id')
          .eq('project_id', projectId)
          .eq('status', 'pending');

      return rows
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet();
    } catch (e, st) {
      debugPrint('getPendingOutgoingInvites error: $e\n$st');
      return {};
    }
  }

  Future<List<CollaborationRequest>> getPendingCollaborationRequests() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final rows = await _client.rpc('pending_project_invitations') as List;
      return [
        for (final row in rows)
          CollaborationRequest(
            id: row['id'].toString(),
            projectId: row['project_id'].toString(),
            projectName: row['project_name']?.toString() ?? 'Project',
            invitedBy: row['invited_by'].toString(),
            inviterDisplayName: row['display_name']?.toString(),
            inviterUsername: row['username']?.toString(),
            inviterAvatarUrl: row['avatar_url']?.toString(),
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ),
      ];
    } catch (e, st) {
      debugPrint('getPendingCollaborationRequests error: $e\n$st');
      return [];
    }
  }

  Future<bool> respondToCollaborationRequest({
    required String id,
    required bool accept,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.rpc(
        'respond_project_invitation',
        params: {'p_id': id, 'p_accept': accept},
      );
      return true;
    } catch (e, st) {
      debugPrint('respondToCollaborationRequest error: $e\n$st');
      return false;
    }
  }

  Future<bool> removeCollaborator({
    required String projectId,
    required String userId,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.rpc(
        'remove_project_member',
        params: {'p_project_id': projectId, 'p_user_id': userId},
      );
      return true;
    } catch (e, st) {
      debugPrint('removeCollaborator error: $e\n$st');
      return false;
    }
  }

  Future<List<Project>> getCollaboratedProjects() async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final rows = await _client
          .from(_collaboratorsTable)
          .select('project_id')
          .eq('user_id', currentUserId)
          .eq('status', 'accepted');

      final projectIds = rows
          .map((r) => r['project_id']?.toString())
          .whereType<String>()
          .toList();

      if (projectIds.isEmpty) return [];

      final projectRows = await _projectRows(
        projectIds,
        columns:
            'id, user_id, project_name, problem_statement, tags, project_image_url, created_at, likes',
      );

      return List<Map<String, dynamic>>.from(
        projectRows,
      ).map(Project.fromMap).toList();
    } catch (e, st) {
      debugPrint('getCollaboratedProjects error: $e\n$st');
      return [];
    }
  }
}
