import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';

class _Observer extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  testWidgets(
    'rapid repeated taps open one destination and allow reopening after back',
    (tester) async {
      final observer = _Observer();
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      Future<void> open() async => pushAppRoute<void>(
        pageContext,
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/profile/me'),
          builder: (_) => const Scaffold(body: Text('Profile')),
        ),
      );
      for (var i = 0; i < 5; i++) {
        open();
      }
      await tester.pumpAndSettle();
      expect(observer.pushes, 2);
      open();
      await tester.pumpAndSettle();
      expect(observer.pushes, 2);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      open();
      await tester.pumpAndSettle();
      expect(observer.pushes, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'distinct destinations remain navigable and an open destination is reused',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final observer = _Observer();
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      void open(String id) {
        pushAppRoute<void>(
          pageContext,
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/profile/$id'),
            builder: (_) => Scaffold(body: Text(id)),
          ),
        );
      }

      open('one');
      await tester.pumpAndSettle();
      open('two');
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      open('one');
      await tester.pumpAndSettle();
      expect(observer.pushes, 3);
      expect(find.text('one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
