import 'package:juniper_journal/src/shared/widgets/page_refresh_state.dart';
import '../../../support/fake_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/public_site_frame.dart';
import 'package:juniper_journal/src/features/site/pages/site_information_page.dart';

void main() {
  setUpAll(() => initializeFakeBackend());
  setUp(() {
    PageRefreshState.currentDestination = null;
    PageRefreshState.destinationKind.value = null;
  });
  for (final wide in [false, true]) {
    for (final long in [false, true]) {
      testWidgets(
        'shared footer stays below ${long ? 'scrolling' : 'short'} content at ${wide ? 'desktop' : 'mobile'} size',
        (tester) async {
          final size = wide ? const Size(1440, 900) : const Size(390, 844);
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final navigation = GlobalKey<NavigatorState>();
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigation,
              builder: (_, child) =>
                  PublicSiteFrame(navigatorKey: navigation, child: child!),
              home: Scaffold(
                key: const ValueKey('page-body'),
                body: long
                    ? ListView(
                        children: [
                          for (var i = 0; i < 60; i++)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Row $i'),
                            ),
                          const SiteFooter(),
                        ],
                      )
                    : const Center(child: Text('Short page')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final footer = find.byKey(const ValueKey('global-site-footer'));
          final footerBounds = tester.getRect(footer);
          expect(footerBounds.bottom, size.height);
          expect(
            tester.getRect(find.byKey(const ValueKey('page-body'))).bottom,
            lessThanOrEqualTo(footerBounds.top),
          );
          expect(
            find.descendant(of: footer, matching: find.text('Privacy')),
            findsOneWidget,
          );
          if (long) {
            await tester.drag(find.byType(ListView), const Offset(0, -12000));
            await tester.pumpAndSettle();
            // The page-local footer yields to the shared footer.
            expect(find.text('Privacy'), findsOneWidget);
            expect(tester.getRect(footer), footerBounds);
          }
          await tester.tap(
            find.descendant(of: footer, matching: find.text('Privacy')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SiteInformationPage), findsOneWidget);
          expect(
            tester
                .widget<SiteInformationPage>(find.byType(SiteInformationPage))
                .page,
            'privacy',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
