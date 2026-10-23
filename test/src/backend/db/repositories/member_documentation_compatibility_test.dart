import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

class MemberRepo extends ProjectsRepo {
  MemberRepo(SupabaseClient client, this.memberships) : super(client: client);
  final Set<String> memberships;
  @override
  Future<bool> canViewInternalProjectLogs(String projectId) async =>
      memberships.contains(projectId);
}

void main() {
  for (final authorized in [true, false]) {
    test(
      'missing view ${authorized ? 'restores verified member project' : 'does not expose nonmember project'}',
      () async {
        final rawReads = <Uri>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          httpClient: MockClient((request) async {
            final missing = request.url.path.endsWith('/project_documentation');
            if (!missing) rawReads.add(request.url);
            return http.Response(
              jsonEncode(
                missing
                    ? {'code': 'PGRST205', 'message': 'Missing view'}
                    : [
                        {
                          'id': 'mine',
                          'user_id': 'owner',
                          'project_name': 'Existing project',
                        },
                      ],
              ),
              missing ? 404 : 200,
              headers: {'content-type': 'application/json'},
              request: request,
              reasonPhrase: missing ? 'Not Found' : 'OK',
            );
          }),
        );
        addTearDown(client.dispose);
        final project = await MemberRepo(
          client,
          authorized ? {'mine'} : {},
        ).getProjectById('mine');
        expect(project?.id, authorized ? 'mine' : null);
        if (authorized) {
          expect(rawReads.single.path.endsWith('/projects'), isTrue);
          expect(rawReads.single.queryParameters['id'], 'in.("mine")');
        } else {
          expect(rawReads, isEmpty);
        }
      },
    );
  }
  test(
    'mixed journal batch retries only IDs with verified membership',
    () async {
      Uri? raw;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((request) async {
          final missing = request.url.path.endsWith('/journal_documentation');
          if (!missing) raw = request.url;
          return http.Response(
            jsonEncode(
              missing
                  ? {'code': 'PGRST205', 'message': 'Missing view'}
                  : [
                      {
                        'id': 'entry',
                        'project_id': 'mine',
                        'title': 'Draft',
                        'content': [],
                      },
                    ],
            ),
            missing ? 404 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      final counts = await MemberRepo(client, {
        'mine',
      }).getJournalEntryCounts(['mine', 'someone-else']);
      expect(counts, {'mine': 1});
      expect(raw!.path.endsWith('/journal_entries'), isTrue);
      expect(raw!.queryParameters['project_id'], 'in.("mine")');
    },
  );
  test('permission failures never trigger a stored-row retry', () async {
    final reads = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      httpClient: MockClient((request) async {
        reads.add(request.url.path);
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'Permission denied'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
          reasonPhrase: 'Forbidden',
        );
      }),
    );
    addTearDown(client.dispose);
    expect(await MemberRepo(client, {'mine'}).getProjectById('mine'), isNull);
    expect(reads, ['/rest/v1/project_documentation']);
  });
  test(
    'a completed-feed read failure propagates instead of showing no projects',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'code': 'PGRST205', 'message': 'Missing view'}),
            404,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'Not Found',
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        MemberRepo(client, {}).getJournalEntryCounts(['someone-else']),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
