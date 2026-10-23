import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/journal_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/journal_publication.dart';
import 'package:juniper_journal/src/shared/widgets/web_navigation_host.dart';

void main() {
  for (final complete in [false, true]) {
    testWidgets(
      'restored journal ${complete ? "completion" : "back"} retains Home',
      (tester) async {
        JournalPublication.onPublished = null;
        await tester.pumpWidget(
          MaterialApp(
            home: WebNavigationHost(
              initialLocation: '/page',
              navigatorKey: GlobalKey<NavigatorState>(),
              parentPage: const Scaffold(body: Text('Home destination')),
              initialPage: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () {
                      if (complete) {
                        JournalPublication.returnHome(context);
                      } else {
                        exitJournalRoute(context);
                      }
                    },
                    child: const Text('Exit journal'),
                  ),
                ),
              ),
              observers: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Exit journal'));
        await tester.pumpAndSettle();
        expect(find.text('Home destination'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a sole journal route is replaced instead of leaving a blank screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => exitJournalRoute(
                  context,
                  fallback: const Scaffold(body: Text('Fallback Home')),
                ),
                child: const Text('Back'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Fallback Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('opening a shared URL keeps the bootstrap page mounted once', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: WebNavigationHost(
          initialLocation: '/explore',
          navigatorKey: GlobalKey<NavigatorState>(),
          initialPage: _StartupProbe(onStart: () => starts++),
          observers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resolved destination'), findsOneWidget);
    expect(starts, 1);
  });
}

class _StartupProbe extends StatefulWidget {
  const _StartupProbe({required this.onStart});
  final VoidCallback onStart;
  @override
  State<_StartupProbe> createState() => _StartupProbeState();
}

class _StartupProbeState extends State<_StartupProbe> {
  @override
  void initState() {
    super.initState();
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Resolved destination'));
}
