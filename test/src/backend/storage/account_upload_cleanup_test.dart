import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';

void main() {
  test(
    'account cleanup collects paginated and nested uploads before removing bytes',
    () async {
      var completeImageListing = false;
      final removed = <String>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          Object response;
          if (request.method == 'POST') {
            final prefix = body['prefix'];
            if (request.url.path.endsWith('/images') &&
                prefix == '' &&
                body['offset'] == 0) {
              response = List.generate(
                100,
                (i) => {'id': 'id$i', 'name': 'photo$i.png'},
              );
            } else if (request.url.path.endsWith('/images') && prefix == '') {
              response = [
                {'name': 'nested'},
              ];
            } else if (prefix == 'nested') {
              completeImageListing = true;
              response = [
                {'id': 'nested-id', 'name': 'last.png'},
              ];
            } else {
              response = [];
            }
          } else {
            expect(request.method, 'DELETE');
            expect(completeImageListing, isTrue);
            removed.addAll((body['prefixes'] as List).cast<String>());
            response = [];
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await StorageService(client: client).deleteAccountUploads();
      expect(removed.toSet(), hasLength(101));
      expect(removed, contains('nested/last.png'));
      expect(removed, contains('photo99.png'));
    },
  );

  test(
    'storage failure aborts account upload cleanup instead of pretending it succeeded',
    () async {
      var deletes = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.method == 'DELETE') deletes++;
          return http.Response(
            '{"statusCode":"403","error":"Unauthorized","message":"Denied"}',
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await expectLater(
        StorageService(client: client).deleteAccountUploads(),
        throwsA(isA<StorageException>()),
      );
      expect(deletes, 0);
    },
  );
}
