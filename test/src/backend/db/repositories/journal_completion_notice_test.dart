import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/widgets/eco_reward_notice_host.dart';

class _Repo extends ProjectsRepo {
  _Repo(SupabaseClient client) : super(client: client);
  @override
  String get currentUserId => 'owner';
}

void main() {
  test(
    'completion announces once and later saves do not claim new impact notices',
    () async {
      var journalClaims = 0;
      var impactClaims = 0;
      var published = false;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          Object response;
          if (request.url.path.endsWith('claim_eco_reward_notice')) {
            final body = jsonDecode(request.body);
            if (body['p_source'] == 'journal') {
              response = ++journalClaims == 1 ? 20 : 0;
            } else {
              impactClaims++;
              response = body['p_id'] == 'entry:water' ? 13 : 29;
            }
          } else if (request.method == 'GET' &&
              request.url.path.endsWith('journal_entries')) {
            response = {
              'id': 'entry',
              'feed_ready': published,
              'feed_published_at': published ? '2026-10-19T20:00:00Z' : null,
            };
          } else if (request.url.path.endsWith('impact_entries')) {
            response = [
              {'metric': 'Water'},
              {'metric': 'Water'},
              {'metric': 'Biological Growth'},
            ];
          } else {
            response = {'id': 'entry'};
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      addTearDown(() => journalCompletionNotice.value = null);
      final repo = _Repo(client);
      const content = [
        {'stage': 'free_notes', 'submitted': true},
        {'type': 'body', 'text': 'Observation'},
      ];
      expect(
        await repo.updateJournalEntry(
          entryId: 'entry',
          title: 'Notes',
          content: content,
          progress: 'ideating',
        ),
        isTrue,
      );
      expect(journalCompletionNotice.value?.points, 62);
      journalCompletionNotice.value = null;
      published = true;
      expect(
        await repo.updateJournalEntry(
          entryId: 'entry',
          title: 'Updated notes',
          content: content,
          progress: 'ideating',
        ),
        isTrue,
      );
      expect(journalCompletionNotice.value, isNull);
      expect(impactClaims, 2);
      expect(journalClaims, 1);
    },
  );
}
