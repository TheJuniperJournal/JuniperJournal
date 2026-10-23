import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:juniper_journal/src/backend/db/models/comment.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';

class CommentsRepo {
  static const _table = 'project_comments';
  static const _profilesTable = 'profiles';

  SupabaseClient get _client => SupabaseDatabase.instance.client;

  Future<List<Comment>?> getComments({required String projectId}) async {
    try {
      final rows = await _client
          .from(_table)
          .select('id, project_id, user_id, content, created_at')
          .eq('project_id', projectId)
          .order('created_at', ascending: true);

      if (rows.isEmpty) return [];

      final userIds = rows
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profiles = await _client
          .from(_profilesTable)
          .select('id, display_name, username, avatar_url')
          .inFilter('id', userIds);

      final profileById = {
        for (final p in profiles)
          p['id']?.toString() ?? '': Map<String, dynamic>.from(p),
      };

      return rows.map<Comment>((row) {
        final userId = row['user_id']?.toString() ?? '';
        final profile = profileById[userId] ?? const <String, dynamic>{};
        return Comment(
          id: row['id']?.toString() ?? '',
          projectId: row['project_id']?.toString() ?? '',
          userId: userId,
          authorDisplayName: profile['display_name']?.toString(),
          authorUsername: profile['username']?.toString(),
          authorAvatarUrl: profile['avatar_url']?.toString(),
          content: row['content']?.toString() ?? '',
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
        );
      }).toList();
    } catch (e, st) {
      debugPrint('getComments error: $e\n$st');
      return null;
    }
  }

  Future<Comment?> postComment({
    required String projectId,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.length > 5000) return null;

    try {
      final row = await _client
          .from(_table)
          .insert({
            'project_id': projectId,
            'user_id': user.id,
            'content': trimmed,
          })
          .select('id, project_id, user_id, content, created_at')
          .single();

      final profiles = await _client
          .from(_profilesTable)
          .select('id, display_name, username, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      return Comment(
        id: row['id']?.toString() ?? '',
        projectId: row['project_id']?.toString() ?? '',
        userId: user.id,
        authorDisplayName: profiles?['display_name']?.toString(),
        authorUsername: profiles?['username']?.toString(),
        authorAvatarUrl: profiles?['avatar_url']?.toString(),
        content: row['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      );
    } catch (e, st) {
      debugPrint('postComment error: $e\n$st');
      return null;
    }
  }

  Future<bool> deleteComment({required String commentId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', commentId)
          .eq('user_id', user.id);
      return true;
    } catch (e, st) {
      debugPrint('deleteComment error: $e\n$st');
      return false;
    }
  }
}
