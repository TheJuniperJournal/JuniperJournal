import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/challenge_participant.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';

class ChallengesRepo {
  SupabaseClient get _client => SupabaseDatabase.instance.client;

  static const _participantsSelect =
      'challenge_participants(id, user_id, project_id, profiles(avatar_url))';

  // ── Challenges CRUD ─────────────────────────────────────────────────────────

  Future<DesignChallenge?> createChallenge({
    required String communityId,
    required String type,
    required String name,
    String? prompt,
    String? imageUrl,
    String? scale,
    String? difficulty,
    DateTime? startsAt,
    DateTime? endsAt,
    bool allDay = false,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('design_challenges')
          .insert({
            'community_id': communityId,
            'creator_id': userId,
            'type': type,
            'name': name,
            'prompt': prompt,
            'image_url': imageUrl,
            'scale': scale,
            'difficulty': difficulty,
            'starts_at': startsAt?.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'all_day': allDay,
          })
          .select()
          .single();
      return DesignChallenge.fromMap(row);
    } catch (e) {
      debugPrint('createChallenge error: $e');
      return null;
    }
  }

  Future<bool> updateChallengeSettings({
    required String id,
    required String type,
    required String name,
    String? prompt,
    String? imageUrl,
    String? scale,
    String? difficulty,
    DateTime? startsAt,
    DateTime? endsAt,
    bool allDay = false,
  }) async {
    try {
      await _client
          .from('design_challenges')
          .update({
            'type': type,
            'name': name,
            'prompt': prompt,
            'image_url': imageUrl,
            'scale': scale,
            'difficulty': difficulty,
            'starts_at': startsAt?.toUtc().toIso8601String(),
            'ends_at': endsAt?.toUtc().toIso8601String(),
            'all_day': allDay,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateChallengeSettings error: $e');
      return false;
    }
  }

  Future<bool> updateRequirements({
    required String id,
    required int requiredJournalEntries,
    required bool measurementRequired,
    required List<String> requiredMetrics,
    required List<String> requiredPatterns,
    required int minGroupMembers,
    String? externalLink,
  }) async {
    try {
      await _client
          .from('design_challenges')
          .update({
            'required_journal_entries': requiredJournalEntries,
            'measurement_required': measurementRequired,
            'required_metrics': requiredMetrics,
            'required_patterns': requiredPatterns,
            'min_group_members': minGroupMembers,
            'external_link': externalLink,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateRequirements error: $e');
      return false;
    }
  }

  Future<bool> updateFundingAndMaterials({
    required String id,
    required int budgetMin,
    int? budgetMax,
    required List<String> materials,
  }) async {
    if (budgetMin < 0) return false;
    if (budgetMax != null && budgetMax < budgetMin) return false;
    try {
      await _client
          .from('design_challenges')
          .update({
            'budget_min': budgetMin,
            'budget_max': budgetMax,
            'materials': materials,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('updateFundingAndMaterials error: $e');
      return false;
    }
  }

  Future<bool> launchChallenge(String id) async {
    try {
      await _client
          .from('design_challenges')
          .update({'is_published': true})
          .eq('id', id);
      return true;
    } catch (e) {
      debugPrint('launchChallenge error: $e');
      return false;
    }
  }

  Future<bool> deleteChallenge(String id) async {
    try {
      await _client.from('design_challenges').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('deleteChallenge error: $e');
      return false;
    }
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  Future<DesignChallenge?> getChallengeById(String id) async {
    try {
      final row = await _client
          .from('design_challenges')
          .select('*, $_participantsSelect')
          .eq('id', id)
          .single();
      return DesignChallenge.fromMap(row);
    } catch (e) {
      debugPrint('getChallengeById error: $e');
      return null;
    }
  }

  Future<List<DesignChallenge>> getCommunityChallenges(
    String communityId,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _client
          .from('design_challenges')
          .select('*, $_participantsSelect')
          .eq('community_id', communityId)
          .or('is_published.eq.true,creator_id.eq.$userId')
          .order('created_at', ascending: false);
      return (rows as List).map((r) => DesignChallenge.fromMap(r)).toList();
    } catch (e) {
      debugPrint('getCommunityChallenges error: $e');
      return [];
    }
  }

  Future<List<DesignChallenge>> getUserJoinedChallenges() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      // Get challenge IDs the user is a participant of
      final participantRows = await _client
          .from('challenge_participants')
          .select('challenge_id')
          .eq('user_id', userId);
      final ids = (participantRows as List)
          .map((r) => r['challenge_id']?.toString())
          .whereType<String>()
          .toList();
      if (ids.isEmpty) return [];

      final rows = await _client
          .from('design_challenges')
          .select('*, $_participantsSelect')
          .inFilter('id', ids)
          .order('created_at', ascending: false);
      return (rows as List).map((r) => DesignChallenge.fromMap(r)).toList();
    } catch (e) {
      debugPrint('getUserJoinedChallenges error: $e');
      return [];
    }
  }

  // ── Participants ─────────────────────────────────────────────────────────────

  Future<ChallengeParticipant?> getMyParticipation(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      final row = await _client
          .from('challenge_participants')
          .select(
            '*, profiles(display_name, username, avatar_url), projects(project_name)',
          )
          .eq('challenge_id', challengeId)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return ChallengeParticipant.fromMap(row);
    } catch (e) {
      debugPrint('getMyParticipation error: $e');
      return null;
    }
  }

  Future<ChallengeParticipant?> getParticipationByProjectId(
    String projectId,
  ) async {
    try {
      final row = await _client
          .from('challenge_participants')
          .select(
            '*, profiles(display_name, username, avatar_url), projects(project_name)',
          )
          .eq('project_id', projectId)
          .maybeSingle();
      if (row == null) return null;
      return ChallengeParticipant.fromMap(row);
    } catch (e) {
      debugPrint('getParticipationByProjectId error: $e');
      return null;
    }
  }

  Future<List<ChallengeParticipant>> getParticipants(String challengeId) async {
    try {
      final rows = await _client
          .from('challenge_participants')
          .select(
            '*, profiles(display_name, username, avatar_url), projects(project_name)',
          )
          .eq('challenge_id', challengeId)
          .order('joined_at', ascending: true);
      return (rows as List)
          .map((r) => ChallengeParticipant.fromMap(r))
          .toList();
    } catch (e) {
      debugPrint('getParticipants error: $e');
      return [];
    }
  }

  Future<bool> joinChallenge({
    required String challengeId,
    required String projectId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client.from('challenge_participants').insert({
        'challenge_id': challengeId,
        'user_id': userId,
        'project_id': projectId,
      });
      return true;
    } catch (e) {
      debugPrint('joinChallenge error: $e');
      return false;
    }
  }

  /// Removes the current user's participation record for the challenge linked
  /// to [projectId]. Called when the user deletes their project.
  Future<void> leaveChallenge({required String projectId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('challenge_participants')
          .delete()
          .eq('project_id', projectId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('leaveChallenge error: $e');
    }
  }

  /// Marks a participant's submission as not submitted (creator use only).
  /// Authorization is enforced by RLS — only the challenge creator's policy
  /// allows updating rows they don't own.
  Future<bool> unsubmitParticipant(String participantId) async {
    if (_client.auth.currentUser == null) return false;
    try {
      await _client
          .from('challenge_participants')
          .update({'has_submitted': false, 'submitted_at': null})
          .eq('id', participantId);
      return true;
    } catch (e) {
      debugPrint('unsubmitParticipant error: $e');
      return false;
    }
  }

  Future<bool> submitToChallenge(String challengeId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _client
          .from('challenge_participants')
          .update({
            'has_submitted': true,
            'submitted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('challenge_id', challengeId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('submitToChallenge error: $e');
      return false;
    }
  }
}
