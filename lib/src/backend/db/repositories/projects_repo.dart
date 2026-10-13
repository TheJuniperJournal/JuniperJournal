import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/collaboration_request.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/security/input_validator.dart';

class ProjectsRepo {
  static const table = 'projects';
  static const journalEntriesTable = 'journal_entries';
  get _client => SupabaseDatabase.instance.client;

  Future<List<Project>?> getCurrentUserProjects() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from(table)
          .select(
            'id, project_name, tags, project_image_url, created_at, '
            'likes, problem_statement, difficulty, project_scale, progress, '
            'journal_entries(progress)',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
    } catch (e, st) {
      debugPrint('getCurrentUserProjects error: $e\n$st');
      return null;
    }
  }

  Future<List<Project>?> getProjectsByUserId({
    required String userId,
  }) async {
    try {
      final rows = await _client
          .from(table)
          .select('id, project_name, tags, project_image_url, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
    } catch (e, st) {
      debugPrint('getProjectsByUserId error: $e\n$st');
      return null;
    }
  }

  Future<List<Project>?> getProjectsForFeed({
    required List<String> ownerIds,
  }) async {
    if (ownerIds.isEmpty) return [];

    try {
      final rows = await _client
          .from(table)
          .select(
            'id, user_id, project_name, problem_statement, tags, project_image_url, created_at, likes',
          )
          .inFilter('user_id', ownerIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
    } catch (e, st) {
      debugPrint('getProjectsForFeed error: $e\n$st');
      return null;
    }
  }

  Future<Project?> createProject({
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    String? difficulty,
    String? projectScale,
    String? visibility,
    String? projectImageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final nameErr = InputValidator.projectName(projectName);
    if (nameErr != null) throw Exception(nameErr);
    final stmtErr = InputValidator.problemStatement(problemStatement);
    if (stmtErr != null) throw Exception(stmtErr);
    final tagsErr = InputValidator.tags(tags);
    if (tagsErr != null) throw Exception(tagsErr);

    try {
      final row = await _client
          .from('projects')
          .insert({
            'project_name': projectName,
            'problem_statement': problemStatement,
            'tags': tags.isEmpty ? null : tags,
            'user_id': user.id,
            'difficulty': difficulty,
            'project_scale': projectScale,
            'visibility': visibility,
            'project_image_url': projectImageUrl,
          })
          .select()
          .single();
      return Project.fromMap(row);
    } catch (e, st) {
      debugPrint('createProject error: $e\n$st');
      return null;
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

  Future<Set<String>> getBookmarkedProjectIds(
      {required List<String> projectIds}) async {
    final user = _client.auth.currentUser;
    if (user == null || projectIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('project_bookmarks')
          .select('project_id')
          .eq('user_id', user.id)
          .inFilter('project_id', projectIds);
      return Set<String>.from(
        List<Map<String, dynamic>>.from(rows)
            .map((r) => r['project_id'].toString()),
      );
    } catch (e, st) {
      debugPrint('getBookmarkedProjectIds error: $e\n$st');
      return {};
    }
  }

  Future<Set<String>> getLikedProjectIds({required List<String> projectIds}) async {
    final user = _client.auth.currentUser;
    if (user == null || projectIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('project_likes')
          .select('project_id')
          .eq('user_id', user.id)
          .inFilter('project_id', projectIds);
      return Set<String>.from(
        List<Map<String, dynamic>>.from(rows).map((r) => r['project_id'].toString()),
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
      final row = await _client.from(table).select().eq('id', id).single();
      return Project.fromMap(row);
    } catch (e, st) {
      debugPrint('getProject error: $e\n$st');
      return null;
    }
  }

  Future<Project?> getProjectById(String id) async {
    try {
      final row = await _client
          .from(table)
          .select(
            'id, user_id, project_name, problem_statement, tags, project_image_url, created_at, difficulty, subject_domain, progress, project_scale, visibility',
          )
          .eq('id', id)
          .single();
      return Project.fromMap(row);
    } catch (e, st) {
      debugPrint('getProjectById error: $e\n$st');
      return null;
    }
  }

  Future<bool> updateProjectMetadata({
    required String id,
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    String? projectImageUrl,
    String? difficulty,
    String? projectScale,
    String? visibility,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final nameErr = InputValidator.projectName(projectName);
    if (nameErr != null) return false;
    final stmtErr = InputValidator.problemStatement(problemStatement);
    if (stmtErr != null) return false;
    final tagsErr = InputValidator.tags(tags);
    if (tagsErr != null) return false;

    try {
      await _client
          .from(table)
          .update({
            'project_name': projectName,
            'problem_statement': problemStatement,
            'tags': tags,
            'project_image_url': projectImageUrl,
            'difficulty': difficulty,
            'project_scale': projectScale,
            'visibility': visibility,
          })
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
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
      await _client
          .from(table)
          .update({'project_image_url': projectImageUrl})
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (e, st) {
      debugPrint('updateProjectImage error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteProject({required String id}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      // Clean dependent rows with user scoping for RLS-safe deletes.
      await _client
          .from(journalEntriesTable)
          .delete()
          .eq('project_id', id)
          .eq('user_id', user.id);

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
    try {
      final result = await _client
          .from(table)
          .select('timeline')
          .eq('id', id)
          .single();
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
    if (user == null) return [];

    try {
      final result = await _client
          .from(journalEntriesTable)
          .select('id, user_id, title, content, created_at, updated_at, project_id, progress, tags')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      final entries = List<Map<String, dynamic>>.from(result);
      if (entries.isEmpty) return [];

      // Fetch author profiles separately (no FK from user_id → profiles)
      final authorIds = entries
          .map((e) => e['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profileRows = await _client
          .from('profiles')
          .select('id, avatar_url, display_name, username')
          .inFilter('id', authorIds);

      final profileMap = {
        for (final p in List<Map<String, dynamic>>.from(profileRows))
          p['id'].toString(): p
      };

      return entries.map((e) {
        final profile = profileMap[e['user_id']?.toString()];
        return JournalEntry.fromMap({...e, 'profiles': profile});
      }).toList();
    } catch (e, st) {
      debugPrint('getJournalEntries error: $e\n$st');
      return null;
    }
  }

  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final titleErr = InputValidator.journalTitle(title);
    if (titleErr != null) throw Exception(titleErr);

    // Verify the current user owns the target project before writing
    final owned = await _client
        .from(table)
        .select('id')
        .eq('id', projectId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (owned == null) throw Exception('Not authorized');

    try {
      final row = await _client
          .from(journalEntriesTable)
          .insert({
            'project_id': projectId,
            'user_id': user.id,
            'title': title,
            'content': content,
            'progress': progress,
          })
          .select('id, title, content, created_at, updated_at, project_id, progress')
          .single();

      return JournalEntry.fromMap(row);
    } catch (e, st) {
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
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (content != null) updates['content'] = content;
    updates['progress'] = progress; // always write (allows clearing)
    if (updates.isEmpty) return true;

    try {
      await _client
          .from(journalEntriesTable)
          .update(updates)
          .eq('id', entryId)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('updateJournalEntry error: $e\n$st');
      return false;
    }
  }

  Future<bool> deleteJournalEntry({required String entryId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from(journalEntriesTable)
          .delete()
          .eq('id', entryId)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('deleteJournalEntry error: $e\n$st');
      return false;
    }
  }


  // ── Impact entries ─────────────────────────────────────────────────────────

  static const _impactEntriesTable = 'impact_entries';

  static const _progressBase = {
    'Discovering': 10.0,
    'Ideating': 20.0,
    'Prototyping': 50.0,
    'Testing & Iterating': 75.0,
    'Implemented': 100.0,
  };
  static const _scaleMult = {'Small': 1.00, 'Medium': 1.40, 'Large': 1.90};
  static const _diffMult = {'Easy': 1.00, 'Medium': 1.25, 'Hard': 1.50};

  double _calcProgressPts(String? progress, String? scale, String? diff) {
    final base = _progressBase[progress] ?? 0.0;
    if (base == 0) return 0.0;
    return double.parse(
      (base * (_scaleMult[scale] ?? 1.0) * (_diffMult[diff] ?? 1.0))
          .toStringAsFixed(2),
    );
  }

  Future<double> _sumEcoPoints(List<String> projectIds, List<Map<String, dynamic>> projects) async {
    if (projectIds.isEmpty) return 0;

    final results = await Future.wait<List<dynamic>>([
      _client
          .from(_impactEntriesTable)
          .select('eco_points')
          .inFilter('project_id', projectIds),
      _client
          .from(journalEntriesTable)
          .select('progress, project_id')
          .inFilter('project_id', projectIds),
    ]);

    final impactRows = List<Map<String, dynamic>>.from(results[0] as List);
    final journalRows = List<Map<String, dynamic>>.from(results[1] as List);

    final projectMeta = {
      for (final p in projects)
        p['id'] as String: (
          scale: p['project_scale'] as String?,
          diff: p['difficulty'] as String?,
        ),
    };

    double total = impactRows.fold<double>(
      0,
      (sum, row) => sum + ((row['eco_points'] as num?)?.toDouble() ?? 0),
    );

    for (final entry in journalRows) {
      final meta = projectMeta[entry['project_id'] as String?];
      total += _calcProgressPts(
        entry['progress'] as String?,
        meta?.scale,
        meta?.diff,
      );
    }

    return double.parse(total.toStringAsFixed(2));
  }

  /// Sums eco_points for a specific user (used for friend profiles).
  Future<double> getTotalEcoPointsForUser(String userId) async {
    try {
      final projectRows = await _client
          .from(table)
          .select('id, project_scale, difficulty')
          .eq('user_id', userId);

      final projects = List<Map<String, dynamic>>.from(projectRows);
      final projectIds = projects.map((p) => p['id'] as String).toList();

      return _sumEcoPoints(projectIds, projects);
    } catch (e, st) {
      debugPrint('getTotalEcoPointsForUser error: $e\n$st');
      return 0;
    }
  }

  /// Sums eco_points from all projects owned by the current user.
  Future<double> getTotalEcoPoints() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final projectRows = await _client
          .from(table)
          .select('id, project_scale, difficulty')
          .eq('user_id', user.id);

      final projects = List<Map<String, dynamic>>.from(projectRows);
      final projectIds = projects.map((p) => p['id'] as String).toList();

      return _sumEcoPoints(projectIds, projects);
    } catch (e, st) {
      debugPrint('getTotalEcoPoints error: $e\n$st');
      return 0;
    }
  }

  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

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

      return List<Map<String, dynamic>>.from(result)
          .map(ImpactEntry.fromMap)
          .toList();
    } catch (e, st) {
      debugPrint('getImpactEntries error: $e\n$st');
      return null;
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
        .from(table)
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
      await _client
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
          .eq('user_id', user.id);
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
          .from(journalEntriesTable)
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
      final result = await _client
          .from(table)
          .select('solution')
          .eq('id', id)
          .single();
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
      final result = await _client
          .from(table)
          .select('materials_cost')
          .eq('id', id)
          .single();
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
          p['id']?.toString() ?? '': UserProfile.fromMap(Map<String, dynamic>.from(p)),
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

  Future<bool> inviteCollaborator({
    required String projectId,
    required String userId,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    try {
      await _client.from(_collaboratorsTable).insert({
        'project_id': projectId,
        'user_id': userId,
        'invited_by': currentUserId,
        'status': 'pending',
      });
      return true;
    } catch (e, st) {
      debugPrint('inviteCollaborator error: $e\n$st');
      return false;
    }
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

      return List<Map<String, dynamic>>.from(profiles)
          .map(UserProfile.fromMap)
          .toList();
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
      final rows = await _client
          .from(_collaboratorsTable)
          .select('id, project_id, invited_by, created_at')
          .eq('user_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      if (rows.isEmpty) return [];

      final projectIds = rows
          .map((r) => r['project_id']?.toString())
          .whereType<String>()
          .toList();

      final inviterIds = rows
          .map((r) => r['invited_by']?.toString())
          .whereType<String>()
          .toList();

      final projectRows = await _client
          .from(table)
          .select('id, project_name')
          .inFilter('id', projectIds);

      final projectNamesById = {
        for (final p in projectRows)
          p['id']?.toString() ?? '': p['project_name']?.toString() ?? 'Project',
      };

      final profileRows = await _client
          .from(_profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', inviterIds);

      final profileById = {
        for (final p in profileRows)
          p['id']?.toString() ?? '': Map<String, dynamic>.from(p),
      };

      return rows.map<CollaborationRequest>((row) {
        final inviterId = row['invited_by']?.toString() ?? '';
        final profile = profileById[inviterId] ?? const <String, dynamic>{};
        final projectId = row['project_id']?.toString() ?? '';
        return CollaborationRequest(
          id: row['id']?.toString() ?? '',
          projectId: projectId,
          projectName: projectNamesById[projectId] ?? 'Project',
          invitedBy: inviterId,
          inviterDisplayName: profile['display_name']?.toString(),
          inviterUsername: profile['username']?.toString(),
          inviterAvatarUrl: profile['avatar_url']?.toString(),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        );
      }).toList();
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
      await _client
          .from(_collaboratorsTable)
          .update({'status': accept ? 'accepted' : 'declined'})
          .eq('id', id)
          .eq('user_id', currentUserId)
          .eq('status', 'pending');
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
      // Verify the caller owns the project before removing a collaborator
      final project = await _client
          .from(table)
          .select('user_id')
          .eq('id', projectId)
          .eq('user_id', currentUserId)
          .maybeSingle();
      if (project == null) return false;
      await _client
          .from(_collaboratorsTable)
          .delete()
          .eq('project_id', projectId)
          .eq('user_id', userId);
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

      final projectRows = await _client
          .from(table)
          .select(
            'id, user_id, project_name, problem_statement, tags, project_image_url, created_at, likes',
          )
          .inFilter('id', projectIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(projectRows)
          .map(Project.fromMap)
          .toList();
    } catch (e, st) {
      debugPrint('getCollaboratedProjects error: $e\n$st');
      return [];
    }
  }
}
