import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';

class _Repo extends ProjectsRepo {
  _Repo(SupabaseClient client, this.userId) : super(client: client);
  final String? userId;
  @override
  String? get currentUserId => userId;
}

void main() {
  for (final failure in [false, true]) {
    test('create project reports database outcome: failure=$failure', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient((r) async {
          expect(r.method, 'POST');
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          expect(body['user_id'], 'owner');
          return http.Response(
            jsonEncode(
              failure
                  ? {
                      'code': '42501',
                      'message': 'new row violates row-level security policy',
                    }
                  : {'id': 'saved', ...body},
            ),
            failure ? 403 : 201,
            request: r,
            reasonPhrase: 'Response',
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = _Repo(client, 'owner');
      final result = await repo.createProject(
        projectName: 'Test project',
        problemStatement: 'A problem',
        tags: ['Engineering & Design'],
        projectType: 'solo',
        visibility: 'private',
      );
      expect(result?.id, failure ? null : 'saved');
      if (failure) {
        expect(repo.lastProjectSaveError, contains('database permission'));
      } else {
        expect(repo.lastProjectSaveError, isNull);
      }
    });
  }
  test(
    'signed out creation returns actionable feedback without a request',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'key',
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected request'),
        ),
      );
      addTearDown(client.dispose);
      final repo = _Repo(client, null);
      expect(
        await repo.createProject(
          projectName: 'Test',
          problemStatement: 'Problem',
          tags: [],
        ),
        isNull,
      );
      expect(repo.lastProjectSaveError, contains('Sign in again'));
    },
  );
}
