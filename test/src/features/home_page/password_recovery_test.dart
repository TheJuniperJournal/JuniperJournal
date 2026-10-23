import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/home_page/pages/password_recovery.dart';

void main() {
  testWidgets(
    'recovery email validates input and gives a non-enumerating response',
    (tester) async {
      String? sentTo;
      await tester.pumpWidget(
        MaterialApp(
          home: PasswordRecoveryScreen(
            sendEmail: (email) async {
              sentTo = email;
            },
          ),
        ),
      );
      await tester.tap(find.text('Send Recovery Email'));
      await tester.pumpAndSettle();
      expect(sentTo, isNull);
      await tester.enterText(find.byType(TextFormField), 'qa@example.com');
      await tester.tap(find.text('Send Recovery Email'));
      await tester.pumpAndSettle();
      expect(sentTo, 'qa@example.com');
      expect(find.textContaining('If an account exists'), findsOneWidget);
    },
  );

  testWidgets('matching new password is required after recovery', (
    tester,
  ) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryScreen(
          updatePassword: true,
          savePassword: (password) async {
            saved = password;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'UpdatedPassword123!',
    );
    await tester.enterText(find.byType(TextFormField).last, 'different');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).last,
      'UpdatedPassword123!',
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(saved, 'UpdatedPassword123!');
    expect(
      find.textContaining('Your password has been updated'),
      findsOneWidget,
    );
  });

  testWidgets(
    'unverified recovery callback cannot change a cached account password',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PasswordRecoveryScreen(updatePassword: true)),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'UpdatedPassword123!',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'UpdatedPassword123!',
      );
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not update your password'),
        findsOneWidget,
      );
      expect(find.text('Request a New Recovery Email'), findsOneWidget);
    },
  );
}
