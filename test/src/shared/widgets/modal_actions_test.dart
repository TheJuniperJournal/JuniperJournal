import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';

void main() {
  for (final sheet in [false, true]) {
    testWidgets(
      '${sheet ? "sheet" : "dialog"} without an exit gets a working close button',
      (tester) async {
        late BuildContext pageContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: Text('Page'));
              },
            ),
          ),
        );
        final popup = sheet
            ? showAppModalBottomSheet<void>(
                context: pageContext,
                isDismissible: false,
                builder: (_) => const SizedBox(
                  height: 100,
                  child: Center(child: Text('No exit supplied')),
                ),
              )
            : showAppDialog<void>(
                context: pageContext,
                barrierDismissible: false,
                builder: (_) =>
                    const AlertDialog(content: Text('No exit supplied')),
              );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close popup'), findsOneWidget);
        await tester.tap(find.byTooltip('Close popup'));
        await tester.pumpAndSettle();
        await popup;
        expect(find.text('No exit supplied'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('existing close control is not duplicated', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );
    final popup = showAppDialog<void>(
      context: pageContext,
      builder: (context) => AlertDialog(
        title: const Text('Information'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close popup'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await popup;
  });

  for (final sheet in [false, true]) {
    testWidgets(
      'empty ${sheet ? "sheet" : "dialog"} closes by tapping outside',
      (tester) async {
        late BuildContext pageContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: Text('Page'));
              },
            ),
          ),
        );
        final popup = sheet
            ? showAppModalBottomSheet<void>(
                context: pageContext,
                builder: (_) => const SizedBox(
                  height: 100,
                  child: Center(child: Text('Dismissible popup')),
                ),
              )
            : showAppDialog<void>(
                context: pageContext,
                builder: (_) =>
                    const AlertDialog(content: Text('Dismissible popup')),
              );
        await tester.pumpAndSettle();
        expect(find.text('Dismissible popup'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await popup;
        expect(find.text('Dismissible popup'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'action locks before loading and unlocks after completion or failure',
    () async {
      final owner = Object();
      final loading = Completer<void>();
      var count = 0;
      final first = runActionOnce(owner, 'event', () async {
        count++;
        await loading.future;
      });
      await runActionOnce(owner, 'event', () async {
        count++;
      });
      expect(count, 1);
      loading.complete();
      await first;
      await expectLater(
        runActionOnce(owner, 'event', () async {
          throw StateError('failed');
        }),
        throwsStateError,
      );
      await runActionOnce(owner, 'event', () async {
        count++;
      });
      expect(count, 2);
    },
  );

  for (final sheet in [false, true]) {
    testWidgets(
      'repeated ${sheet ? "sheet" : "dialog"} opens once and can reopen',
      (tester) async {
        late BuildContext pageContext;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                pageContext = context;
                return const Scaffold(body: Text('Page'));
              },
            ),
          ),
        );
        Future<void> open() async {
          Widget builder(BuildContext context) => Material(
            child: TextButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('Nested')),
              ),
              child: const Text('Popup'),
            ),
          );
          if (sheet) {
            await showAppModalBottomSheet<void>(
              context: pageContext,
              builder: builder,
            );
          } else {
            await showAppDialog<void>(context: pageContext, builder: builder);
          }
        }

        final first = open();
        final duplicate = open();
        await tester.pumpAndSettle();
        await duplicate;
        expect(find.text('Popup'), findsOneWidget);
        await tester.tap(find.text('Popup'));
        await tester.pumpAndSettle();
        expect(find.text('Nested'), findsOneWidget);
        Navigator.of(tester.element(find.text('Nested'))).pop();
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.text('Popup'))).pop();
        await tester.pumpAndSettle();
        await first;
        expect(find.text('Popup'), findsNothing);
        final reopened = open();
        await tester.pumpAndSettle();
        expect(find.text('Popup'), findsOneWidget);
        Navigator.of(tester.element(find.text('Popup'))).pop();
        await tester.pumpAndSettle();
        await reopened;
        expect(tester.takeException(), isNull);
      },
    );
  }
}
