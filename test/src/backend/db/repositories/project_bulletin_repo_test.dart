import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/project_bulletin_repo.dart';

void main() {
  test(
    'loads populated bulletin with resolved authors and comment counts',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final table = request.url.pathSegments.last;
          final rows = switch (table) {
            'project_bulletin_posts' => [
              {
                'id': 'post',
                'project_id': 'project',
                'user_id': 'author',
                'title': 'Design',
                'body': 'Please review',
                'category': 'Design Feedback',
                'created_at': '2026-10-15T12:00:00Z',
                'image_urls': ['https://example.com/photo.png'],
              },
            ],
            'profiles' => [
              {'id': 'author', 'display_name': 'Amelia', 'username': 'amelia'},
            ],
            'project_bulletin_comments' => [
              {
                'id': 'comment',
                'post_id': 'post',
                'user_id': 'author',
                'body': 'Looks good',
                'created_at': '2026-10-15T12:00:00Z',
              },
            ],
            _ => [],
          };
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = ProjectBulletinRepo(client: client);
      final posts = await repo.posts('project');
      expect(posts.single.authorLabel, 'Amelia');
      expect(posts.single.commentCount, 1);
      expect(posts.single.imageUrls, ['https://example.com/photo.png']);
      final comments = await repo.comments('post');
      expect(comments.single.authorLabel, 'Amelia');
      expect(comments.single.body, 'Looks good');
    },
  );
}
