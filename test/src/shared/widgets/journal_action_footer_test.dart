import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/journal_action_footer.dart';

void main() {
  testWidgets('footer repeats missing sections and clears corrected fields', (
    tester,
  ) async {
    final title = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextField(controller: title),
            bottomNavigationBar: JournalActionFooter(
              child: TextButton(
                onPressed: () => journalValidationIssues(context).value = [
                  JournalValidationIssue(
                    'Required: Journal title.',
                    () => title.text.trim().isEmpty,
                    changes: title,
                  ),
                  JournalValidationIssue('Select an inquiry lens.', () => true),
                ],
                child: const Text('Next'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('Required: Journal title.'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(
      find.text(
        'To continue:\nRequired: Journal title.\nSelect an inquiry lens.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'My journal');
    await tester.pump();
    expect(find.textContaining('Required: Journal title.'), findsNothing);
    expect(find.text('To continue:\nSelect an inquiry lens.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    title.dispose();
  });
}
