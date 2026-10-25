import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';
import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';

void main() {
  testWidgets(
    'project workspace keeps global Create available across nested routes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => PersistentDesktopShell(child: child!),
          home: AdaptiveAppShell(
            selectedIndex: 0,
            onSelect: (_) {},
            onCreate: () {},
            mobileNavigation: const SizedBox(),
            body: const Text('Home page'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute(
          builder: (_) => const ProjectWorkspaceChrome(
            child: Scaffold(body: Text('Project')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      navigator.currentState!.push(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Phase'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'desktop chrome stays mounted across creation routes and resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => PersistentDesktopShell(child: child!),
          home: Builder(
            builder: (context) => AdaptiveAppShell(
              selectedIndex: 0,
              onSelect: (_) {},
              onCreate: () {},
              mobileNavigation: const Text('Mobile nav'),
              desktopSidebar: const Text('Profile progress'),
              body: Center(
                child: TextButton(
                  child: const Text('Open creation'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        body: TextField(
                          decoration: InputDecoration(
                            labelText: 'Project name',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Mobile nav'), findsNothing);
      final rail = tester.element(find.byType(NavigationRail));
      await tester.tap(find.text('Open creation'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(NavigationRail)), same(rail));
      expect(find.text('Profile progress'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Draft project');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Draft project'), findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.text('Draft project'), findsOneWidget);
      expect(find.text('Profile progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
