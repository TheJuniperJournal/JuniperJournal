import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';

void main() {
  for (final sheet in [false, true]) {
    testWidgets(
      'dirty ${sheet ? 'sheet' : 'dialog'} requires explicit discard and ignores outside taps',
      (tester) async {
        final text = TextEditingController();
        addTearDown(text.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Open'),
                  onPressed: () {
                    Widget builder(BuildContext c) => Material(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: text),
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Close form'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Save form'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (sheet)
                      showAppModalBottomSheet<bool>(
                        context: context,
                        builder: builder,
                      );
                    else
                      showAppDialog<bool>(
                        context: context,
                        builder: (c) => Dialog(child: builder(c)),
                      );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Unsaved');
        await tester.pump();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close form'));
        await tester.pumpAndSettle();
        expect(find.text('Discard changes?'), findsOneWidget);
        await tester.tap(find.text('Keep Editing'));
        await tester.pumpAndSettle();
        expect(text.text, 'Unsaved');
        await tester.tap(find.text('Save form'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
