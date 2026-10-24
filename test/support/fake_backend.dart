import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';

/// An authenticated, entirely local backend for widget tests. No live requests.
Future<SupabaseClient> initializeFakeBackend({String? userId}) async {
  final client = SupabaseClient(
    'https://qa.invalid',
    'test-key',
    httpClient: MockClient(
      (request) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  SupabaseDatabase.instance.client = client;
  if (userId != null) {
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'exp':
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch ~/
                  1000,
            }),
          ),
        )
        .replaceAll('=', '');
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'e30.$payload.test',
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_in': 86400,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  }
  return client;
}
