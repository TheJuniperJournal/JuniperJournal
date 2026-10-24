import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/restored_navigation.dart';

void main() {
  test('all application details and forms restore the shared parent', () {
    for (final kind in [
      'chat',
      'chats',
      'project',
      'phase',
      'journal',
      'journal-view',
      'create',
      'settings',
      'project-settings',
      'materials',
      'impact',
      'activity',
      'community',
      'community-profile',
      'community-settings',
      'profile',
    ]) {
      expect(destinationNeedsAppParent(kind), isTrue, reason: kind);
    }
    for (final kind in [
      null,
      'home',
      'explore',
      'login',
      'signup',
      'about',
      'privacy',
    ]) {
      expect(destinationNeedsAppParent(kind), isFalse, reason: kind);
    }
  });
  testWidgets(
    'closing a restored form returns to Home and preserves the root',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/': (_) => const Scaffold(body: Text('Fallback'))},
          onGenerateInitialRoutes: (_) => restoredNavigationStack(
            home: const Scaffold(body: Text('Home destination')),
            restored: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Close restored form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Close restored form'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      await tester.tap(find.text('Close restored form'));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(navigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
