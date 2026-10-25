import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/creation_navigation_guard.dart';

void main() {
  for (final dirty in [false, true]) {
    testWidgets(
      'Create leaves ${dirty ? 'changed form only after discard' : 'blank form directly'}',
      (tester) async {
        final key = GlobalKey<NavigatorState>();
        var fingerprint = '';
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('Home')),
          ),
        );
        key.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => CreationNavigationGuard(
              fingerprint: () => fingerprint,
              child: const Scaffold(body: Text('Unfinished creation')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (dirty) fingerprint = 'selected subject';
        final leaving = CreationNavigationGuard.leaveCurrent(
          key.currentState!,
        ).then((v) => result = v);
        await tester.pumpAndSettle();
        if (dirty) {
          expect(find.text('Discard changes?'), findsOneWidget);
          await tester.tap(find.text('Keep Editing'));
          await tester.pumpAndSettle();
          await leaving;
          expect(result, isFalse);
          expect(find.text('Unfinished creation'), findsOneWidget);
          final retry = CreationNavigationGuard.leaveCurrent(key.currentState!);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard & Continue'));
          await tester.pumpAndSettle();
          expect(await retry, isTrue);
        } else {
          await leaving;
          expect(result, isTrue);
        }
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Unfinished creation'), findsNothing);
      },
    );
  }
}
