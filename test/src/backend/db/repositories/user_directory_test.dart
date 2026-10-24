import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';

void main() {
  for (final invite in [false, true]) {
    test(
      'private accounts appear in ${invite ? 'invitation' : 'people'} search using identity directory',
      () async {
        final client = SupabaseClient(
          'https://qa.invalid',
          'test',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/rest/v1/rpc/search_user_directory');
            expect(jsonDecode(request.body), {'p_query': 'Private gardener'});
            return http.Response(
              jsonEncode([
                {
                  'id': 'private',
                  'display_name': 'Private Gardener',
                  'username': 'garden',
                  'is_public_profile': false,
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
              reasonPhrase: 'OK',
            );
          }),
        );
        addTearDown(client.dispose);
        final repo = UsersRepo(client: client);
        final people = invite
            ? await repo.searchProjectInvitees(query: 'Private gardener')
            : await repo.searchPublicUsers(query: 'Private gardener');
        expect(people!.single.id, 'private');
        expect(people.single.isPublicProfile, isFalse);
        expect(people.single.bio, isEmpty);
        expect(people.single.birthday, isNull);
      },
    );
  }
  test(
    'profile lookup uses redacted cards instead of raw profile rows',
    () async {
      final client = SupabaseClient(
        'https://qa.invalid',
        'test',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/user_profile_cards');
          expect(jsonDecode(request.body), {
            'p_ids': ['private'],
          });
          return http.Response(
            '[{"id":"private","display_name":"Private Gardener","is_public_profile":false,"bio":""}]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
            reasonPhrase: 'OK',
          );
        }),
      );
      addTearDown(client.dispose);
      final person = (await UsersRepo(
        client: client,
      ).getProfilesByIds(['private'])).single;
      expect(person.resolvedDisplayName, 'Private Gardener');
      expect(person.bio, isEmpty);
      expect(person.isPublicProfile, isFalse);
    },
  );
}
