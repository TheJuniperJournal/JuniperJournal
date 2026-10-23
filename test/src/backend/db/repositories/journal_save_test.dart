import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

class _MemberRepo extends ProjectsRepo {
  _MemberRepo(SupabaseClient client) : super(client: client);
  @override
  String? get currentUserId => 'member';
}

void main() {
  ProjectsRepo repoFor(Future<http.Response> Function(http.Request) handler) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient(handler),
    );
    addTearDown(client.dispose);
    return _MemberRepo(client);
  }

  test('member creates entry without an owner-only preflight', () async {
    final repo = repoFor((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/journal_entries');
      final body = jsonDecode(request.body) as Map;
      expect(body['user_id'], 'member');
      return http.Response(
        jsonEncode({'id': 'entry', ...body}),
        201,
        request: request,
        reasonPhrase: 'Response',
        headers: {'content-type': 'application/json'},
      );
    });
    final entry = await repo.createJournalEntry(
      projectId: 'project',
      title: 'Observation',
      content: [],
      progress: 'Ideation',
    );
    expect(entry?.id, 'entry');
    expect(repo.lastJournalSaveError, isNull);
  });

  test('missing title never sends a save request', () async {
    final repo = repoFor((_) async => throw StateError('Unexpected request'));
    expect(
      await repo.createJournalEntry(
        projectId: 'project',
        title: '',
        content: [],
      ),
      isNull,
    );
    expect(repo.lastJournalSaveError, isNotNull);
  });

  test('permission rejection is surfaced', () async {
    final repo = repoFor(
      (request) async => http.Response(
        jsonEncode({'code': '42501', 'message': 'permission denied'}),
        403,
        request: request,
        reasonPhrase: 'Response',
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(
      await repo.createJournalEntry(
        projectId: 'project',
        title: 'Notes',
        content: [],
      ),
      isNull,
    );
    expect(repo.lastJournalSaveError, contains('accepted project member'));
  });

  for (final hasRow in [false, true]) {
    test('update reports success only with a returned row: $hasRow', () async {
      final repo = repoFor((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.queryParameters['id'], 'eq.entry');
        expect(request.url.queryParameters.containsKey('user_id'), false);
        return http.Response(
          jsonEncode(hasRow ? {'id': 'entry'} : null),
          200,
          request: request,
          reasonPhrase: 'Response',
          headers: {'content-type': 'application/json'},
        );
      });
      expect(
        await repo.updateJournalEntry(entryId: 'entry', title: 'Notes'),
        hasRow,
      );
      expect(repo.lastJournalSaveError == null, hasRow);
    });
  }
}
