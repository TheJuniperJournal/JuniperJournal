import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/restored_navigation.dart';

void main() {
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
