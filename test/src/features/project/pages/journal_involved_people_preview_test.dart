import 'package:juniper_journal/src/features/home_page/pages/public_user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/shared/widgets/journal_involved_people_preview.dart';

class _Repo extends UsersRepo {
  @override
  Future<List<UserProfile>> getProfilesByIds(List<String> ids) async => [
    const UserProfile(id: 'u', displayName: 'Amelia Yang', username: 'amelia'),
  ];
}

void main() {
  testWidgets('involved person shows an avatar and opens their profile card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalInvolvedPeoplePreview(
            people: const [
              {'id': 'u', 'name': 'Amelia'},
            ],
            usersRepo: _Repo(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CircleAvatar), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    await tester.tap(find.text('Amelia Yang'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(
      tester
          .widget<PublicUserProfilePage>(find.byType(PublicUserProfilePage))
          .userId,
      'u',
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
