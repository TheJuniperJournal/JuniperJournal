import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_database.dart';
import '../models/bulletin_post.dart';
import '../models/bulletin_comment.dart';

const projectPostCategories = [
  'Idea / Brainstorm',
  'Design Feedback',
  'Question / Help',
  'Calculations',
  'Resources / Materials',
  'Project Update',
];

class ProjectBulletinRepo {
  ProjectBulletinRepo({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? SupabaseDatabase.instance.client;
  String? get currentUserId => _db.auth.currentUser?.id;

  Future<String?> postIdForComment(String id) async {
    final row = await _db
        .from('project_bulletin_comments')
        .select('post_id')
        .eq('id', id)
        .maybeSingle();
    return row?['post_id']?.toString();
  }

  Future<List<BulletinPost>> posts(String projectId) async {
    final rows = await _db
        .from('project_bulletin_posts')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);
    if (rows.isEmpty) return [];
    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', rows.map((r) => r['user_id']).toSet().toList());
    final comments = await _db
        .from('project_bulletin_comments')
        .select('post_id')
        .inFilter('post_id', rows.map((r) => r['id']).toList());
    return [
      for (final row in rows)
        BulletinPost.fromMap(
          {
            ...row,
            'comment_count': comments
                .where((c) => c['post_id'] == row['id'])
                .length,
          },
          profile: profiles
              .cast<Map<String, dynamic>>()
              .where((p) => p['id'] == row['user_id'])
              .firstOrNull,
        ),
    ];
  }

  Future<void> save({
    required String projectId,
    String? id,
    required String title,
    required String body,
    required String category,
    required List<String> images,
  }) async {
    final values = {
      'title': title.trim(),
      'body': body.trim(),
      'category': category,
      'image_urls': images,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await _db.from('project_bulletin_posts').insert({
        ...values,
        'project_id': projectId,
        'user_id': currentUserId,
      });
    } else {
      await _db.from('project_bulletin_posts').update(values).eq('id', id);
    }
  }

  Future<void> delete(String id) async =>
      await _db.from('project_bulletin_posts').delete().eq('id', id);
  Future<List<Map<String, dynamic>>> reactions(List<String> ids) async {
    if (ids.isEmpty) return [];
    return List<Map<String, dynamic>>.from(
      await _db
          .from('project_bulletin_reactions')
          .select()
          .inFilter('post_id', ids),
    );
  }

  Future<void> react(String id, bool selected) async {
    if (selected) {
      await _db
          .from('project_bulletin_reactions')
          .delete()
          .eq('post_id', id)
          .eq('user_id', currentUserId!);
    } else {
      await _db.from('project_bulletin_reactions').insert({
        'post_id': id,
        'user_id': currentUserId,
      });
    }
  }

  Future<List<BulletinComment>> comments(String id) async {
    final rows = await _db
        .from('project_bulletin_comments')
        .select()
        .eq('post_id', id)
        .order('created_at');
    if (rows.isEmpty) return [];
    final profiles = await _db
        .from('profiles')
        .select()
        .inFilter('id', rows.map((r) => r['user_id']).toSet().toList());
    return [
      for (final row in rows)
        BulletinComment.fromMap(
          row,
          profile: profiles
              .cast<Map<String, dynamic>>()
              .where((p) => p['id'] == row['user_id'])
              .firstOrNull,
        ),
    ];
  }

  Future<void> comment(String id, String body) async => await _db
      .from('project_bulletin_comments')
      .insert({'post_id': id, 'user_id': currentUserId, 'body': body.trim()});
}
