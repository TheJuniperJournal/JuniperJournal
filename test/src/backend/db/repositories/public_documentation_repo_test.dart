import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

void main() {
  test(
    'guests read completed journal documentation without raw rows or private profiles',
    () async {
      final requests = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          Object data = [];
          if (request.url.path.endsWith('/community_journal_entry_ids'))
            data = ['published'];
          if (request.url.path.endsWith('/journal_documentation'))
            data = [
              {
                'id': 'published',
                'project_id': 'p',
                'user_id': 'owner',
                'title': 'Public observations',
                'feed_ready': true,
                'content': [
                  {'stage': 'free_notes', 'submitted': true},
                  {'type': 'body', 'text': 'Our shared notes'},
                ],
              },
              {
                'id': 'stale-draft',
                'project_id': 'p',
                'title': 'Draft',
                'feed_ready': true,
                'content': [
                  {'stage': 'free_notes', 'submitted': false},
                  {'type': 'body', 'text': 'Not shared'},
                ],
              },
            ];
          if (request.url.path.endsWith('/public_project_directory'))
            data = [
              {'id': 'owner', 'display_name': 'Garden owner'},
            ];
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = ProjectsRepo(client: client);
      final entries = await repo.getCommunityJournalEntries(
        projectId: 'p',
        communityId: 'c',
      );
      expect(entries.map((entry) => entry.id), ['published']);
      expect(
        requests.any((path) => path.endsWith('/journal_documentation')),
        isTrue,
      );
      expect(
        requests.any((path) => path.endsWith('/journal_entries')),
        isFalse,
      );
      expect(requests.any((path) => path.endsWith('/profiles')), isFalse);
    },
  );
  test(
    'missing public projection fails closed rather than falling back to stored rows',
    () async {
      final requests = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request.url.path);
          return http.Response(
            jsonEncode({'code': 'PGRST205', 'message': 'View unavailable'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      expect(await ProjectsRepo(client: client).getProjectById('p'), isNull);
      expect(requests.where((path) => path.endsWith('/projects')), isEmpty);
    },
  );
}
