import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

Map<String, dynamic> row(String id, {bool submitted = true}) => {
  'id': id,
  'project_id': 'p',
  'title': id,
  'feed_ready': true,
  'feed_published_at': '2026-10-21T12:00:00Z',
  'updated_at': id == 'draft' ? '2026-10-21T13:00:00Z' : '2026-10-21T12:00:00Z',
  'content': [
    {'stage': 'free_notes', 'submitted': submitted},
    {'type': 'body', 'text': 'Notes'},
  ],
};
void main() {
  test(
    'Home feed skips a newer draft and retains the last completed entry',
    () {
      final items = completedJournalFeedEntries([
        JournalEntry.fromMap(row('completed')),
        JournalEntry.fromMap(row('draft', submitted: false)),
      ]);
      expect(items.map((e) => e.id), ['completed']);
      expect(
        completedJournalFeedEntries([
          JournalEntry.fromMap(row('draft', submitted: false)),
        ]),
        isEmpty,
      );
    },
  );
  test(
    'published query rechecks completion rather than trusting feed_ready',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.endsWith('/journal_documentation')
                  ? [row('completed'), row('draft', submitted: false)]
                  : [],
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          ),
        ),
      );
      addTearDown(client.dispose);
      final items = await ProjectsRepo(
        client: client,
      ).getPublishedJournalEntries('p');
      expect(items.map((e) => e.id), ['completed']);
    },
  );
}
