import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/adaptive_app_shell.dart';
import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/widgets/desktop_modal_layer.dart';
import 'package:juniper_journal/src/shared/widgets/eco_reward_notice_host.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';

void main() {
  testWidgets(
    'desktop popup covers shell and editor returns to center navigator',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: ecoRewardNavigatorKey,
          builder: (_, child) =>
              DesktopModalLayer(child: PersistentDesktopShell(child: child!)),
          home: Builder(
            builder: (context) => AdaptiveAppShell(
              selectedIndex: 0,
              onSelect: (_) {},
              onCreate: () {},
              mobileNavigation: const SizedBox.shrink(),
              desktopSidebar: const Text('Profile sidebar'),
              body: Center(
                child: TextButton(
                  child: const Text('Open picker'),
                  onPressed: () => showAppModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => SizedBox(
                      key: const ValueKey('picker'),
                      height: 500,
                      width: double.infinity,
                      child: TextButton(
                        child: const Text('Open editor'),
                        onPressed: () => pushAppPage(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => const Scaffold(
                              body: SizedBox.expand(key: ValueKey('editor')),
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
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(const ValueKey('picker'))).width, 760);
      expect(tester.getCenter(find.byKey(const ValueKey('picker'))).dx, 720);
      final barriers = tester.getSize(find.byType(ModalBarrier).last);
      expect(barriers.width, 1440);
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('picker')), findsNothing);
      expect(find.text('Profile sidebar'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('editor'))).width,
        lessThan(760),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
