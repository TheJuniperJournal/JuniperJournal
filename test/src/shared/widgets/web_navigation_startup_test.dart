import 'package:juniper_journal/src/shared/widgets/browser_history_stub.dart';
import 'package:juniper_journal/src/shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';
import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/journal_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/journal_publication.dart';
import 'package:juniper_journal/src/shared/widgets/web_navigation_host.dart';

class _History extends BrowserHistory {
  String path = '/explore';
  final writes = <String>[];
  @override
  String get location => path;
  @override
  void write(String value, {bool replace = false}) {
    path = value;
    writes.add(value);
  }
}

void main() {
  testWidgets('public navigation and wrapper changes update the actual URL', (
    tester,
  ) async {
    final history = _History();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: WebNavigationHost(
          history: history,
          initialLocation: '/explore',
          navigatorKey: nav,
          initialPage: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    PageRefreshState.remember(context, {'kind': 'login'}),
                child: const Text('Change wrapper destination'),
              ),
            ),
          ),
          observers: [PageRefreshState.instance],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change wrapper destination'));
    await tester.pumpAndSettle();
    expect(history.path, '/login');
    nav.currentState!.push(
      MaterialPageRoute(
        builder: (_) => Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted)
                PageRefreshState.remember(context, {'kind': 'about'});
            });
            return const Scaffold(body: Text('Public About'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(history.path, '/about');
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(history.path, '/login');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cold chat links build the parent shell before any navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => PersistentDesktopShell(child: child!),
        home: WebNavigationHost(
          initialLocation: '/page',
          navigatorKey: navigator,
          parentPage: AdaptiveAppShell(
            selectedIndex: 0,
            onSelect: (_) {},
            onCreate: () {},
            desktopSidebar: const Text('Profile sidebar'),
            mobileNavigation: const SizedBox(),
            body: const Scaffold(body: Text('Home destination')),
          ),
          initialPage: const Scaffold(body: Text('Direct chat')),
          observers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Direct chat'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Profile sidebar'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
    expect(find.text('Profile sidebar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
