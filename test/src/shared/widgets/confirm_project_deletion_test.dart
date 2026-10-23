import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/confirm_project_deletion.dart';

void main() {
  testWidgets(
    'deletion requires warning acceptance and typed delete submission',
    (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await confirmProjectDeletion(context);
                },
                child: const Text('Delete Project'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete Project'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Project?'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Yes, continue'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Submit');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'yes');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(result, isNull);
      await tester.enterText(find.byType(TextField), 'DeLeTe');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(result, isNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(result, isTrue);
    },
  );
  testWidgets('canceling typed confirmation does not authorize deletion', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await confirmProjectDeletion(context);
              },
              child: const Text('Delete Project'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Delete Project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
