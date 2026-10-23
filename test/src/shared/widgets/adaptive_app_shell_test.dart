import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/features/site/pages/site_information_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: () => setState(() => value++),
      child: Text('Count $value'),
    ),
  );
}

void main() {
  setUpAll(() {
    SupabaseDatabase.instance.client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
    );
  });
  testWidgets(
    'desktop navigation reuses sections and preserves content when resized to mobile',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selected = 0, creates = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveAppShell(
            selectedIndex: 0,
            onSelect: (value) => selected = value,
            onCreate: () => creates++,
            mobileNavigation: const SizedBox(
              height: 56,
              child: Text('Mobile navigation'),
            ),
            desktopSidebar: const SizedBox(
              key: ValueKey("sidebar"),
              child: Text("Progress sidebar"),
            ),
            body: const _Counter(),
          ),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
      expect(tester.getCenter(find.byType(_Counter)).dx, 720);
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('desktop-three-columns')))
            .dx,
        720,
      );
      expect(find.text('Progress sidebar'), findsOneWidget);
      expect(
        tester.getSize(find.byType(_Counter)).width,
        lessThanOrEqualTo(720),
      );
      tester.view.physicalSize = const Size(1000, 900);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('sidebar'))).width, 280);
      expect(tester.getCenter(find.byType(_Counter)).dx, 500);
      expect(tester.takeException(), isNull);
      expect(find.text('Mobile navigation'), findsNothing);
      await tester.tap(find.text('Journal Library'));
      expect(selected, 1);
      expect(find.text('About'), findsNothing);
      expect(find.text('Support'), findsNothing);
      await tester.tap(find.text('Juniper Journal'));
      await tester.pumpAndSettle();
      expect(find.byType(SiteInformationPage), findsOneWidget);
      expect(
        tester
            .widget<SiteInformationPage>(find.byType(SiteInformationPage))
            .page,
        'about',
      );
      Navigator.of(tester.element(find.byType(SiteInformationPage))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      expect(creates, 1);
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Mobile navigation'), findsOneWidget);
      expect(find.text('Progress sidebar'), findsNothing);
      expect(find.text('Count 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
