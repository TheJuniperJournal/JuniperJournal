import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/home_page/pages/login.dart';

void main() {
  testWidgets('explicit Explore exit is available even without a back stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: {
          '/explore': (_) => const Scaffold(body: Text('Explore landing')),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('login-back-to-explore')));
    await tester.pumpAndSettle();
    expect(find.text('Explore landing'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sign in brand returns to public Explore', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: {
          '/explore': (_) =>
              const Scaffold(body: Text('Public Explore landing')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('login-explore-link')));
    await tester.pumpAndSettle();
    expect(find.text('Public Explore landing'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to sign in removes desktop navigation and profile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [desktopRouteObserver],
        builder: (_, child) => PersistentDesktopShell(child: child!),
        home: AdaptiveAppShell(
          selectedIndex: 0,
          onSelect: (_) {},
          onCreate: () {},
          mobileNavigation: const SizedBox.shrink(),
          desktopSidebar: const Text('Signed in profile'),
          body: const Text('Dashboard'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed in profile'), findsOneWidget);
    navigator.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Signed in profile'), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floral login adapts and preserves inputs across window sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    final art = find.byKey(const ValueKey('login-floral-artwork'));
    final identity = find.byKey(const ValueKey('login-identity'));
    expect(find.text('Document your sustainability journey.'), findsOneWidget);
    expect(tester.getCenter(art).dx, lessThan(tester.getCenter(identity).dx));
    await tester.enterText(identity, 'gardener');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.getCenter(art).dy, lessThan(tester.getCenter(identity).dy));
    expect(find.text('gardener'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('login retains validation and sign up navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        routes: {
          '/signup': (_) => const Scaffold(body: Text('Signup destination')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email or username'), findsNWidgets(2));
    expect(find.text('Enter your password'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Signup destination'), findsOneWidget);
  });
}
