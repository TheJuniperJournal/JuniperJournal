import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/search.dart';

class _Users extends UsersRepo {
  @override
  Future<List<UserProfile>?> searchPublicUsers({required String query}) async =>
      [UserProfile(id: 'u', displayName: 'Public User')];
}

class _Friends extends FriendsRepo {
  @override
  Future<List<UserProfile>?> getFriends() async => [
    UserProfile(id: 'f', displayName: 'My Friend'),
  ];
  @override
  Future<Map<String, String>> getRelationshipStatuses(
    List<String> userIds,
  ) async => {'f': 'friends'};
}

void main() {
  testWidgets(
    'Home search separates friends and users without project search',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeSearchScreen(usersRepo: _Users(), friendsRepo: _Friends()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Projects'), findsNothing);
      await tester.enterText(find.byType(TextField), 'public');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Public User'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.text('My Friend'), findsOneWidget);
      expect(find.text('Public User'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
