import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/achievement.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';

class AchievementsRepo {
  static const _table = 'achievements';

  SupabaseClient get _client => SupabaseDatabase.instance.client;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the current user's achievements ordered by most recent first.
  /// [limit] caps the result set (default 20 for the profile activity feed).
  /// Returns null on error, empty list when there are no rows.
  Future<List<Achievement>?> getCurrentUserAchievements({
    int limit = 20,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final rows = await _client
          .from(_table)
          .select('id, user_id, title, points, category, occurred_at')
          .eq('user_id', user.id)
          .order('occurred_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(
        rows,
      ).map(Achievement.fromMap).toList();
    } catch (e, st) {
      debugPrint('getCurrentUserAchievements error: $e\n$st');
      return null;
    }
  }

  /// Sums all points earned by the current user.
  /// Returns 0 on error or when no achievements exist.
  Future<int> getTotalPoints() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    try {
      final rows = await _client
          .from(_table)
          .select('points')
          .eq('user_id', user.id);

      return List<Map<String, dynamic>>.from(rows).fold<int>(
        0,
        (sum, row) => sum + ((row['points'] as num?)?.toInt() ?? 0),
      );
    } catch (e, st) {
      debugPrint('getTotalPoints error: $e\n$st');
      return 0;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Records a new achievement for the currently signed-in user.
  /// Returns the created [Achievement] on success, null on failure.
  Future<Achievement?> recordAchievement({
    required String title,
    required int points,
    String? category,
    DateTime? occurredAt,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final row = await _client
          .from(_table)
          .insert({
            'user_id': user.id,
            'title': title,
            'points': points,
            if (category != null) 'category': category,
            if (occurredAt != null)
              'occurred_at': occurredAt.toUtc().toIso8601String(),
          })
          .select('id, user_id, title, points, category, occurred_at')
          .single();

      return Achievement.fromMap(row);
    } catch (e, st) {
      debugPrint('recordAchievement error: $e\n$st');
      return null;
    }
  }
}
