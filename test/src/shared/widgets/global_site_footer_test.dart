import 'package:juniper_journal/src/shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
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
  for (final custom in [false, true]) {
    testWidgets(
      '${custom ? 'custom slivers' : 'single child'} footer appears only after long content',
      (tester) async {
        final navigation = GlobalKey<NavigatorState>();
        final content = Container(
          height: 2400,
          child: const Text('Long content'),
        );
        final scroll = custom
            ? CustomScrollView(slivers: [SliverToBoxAdapter(child: content)])
            : SingleChildScrollView(child: content);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigation,
            builder: (_, child) =>
                PublicSiteFrame(navigatorKey: navigation, child: child!),
            home: Scaffold(body: PageScrollWithFooter(child: scroll)),
          ),
        );
        await tester.pumpAndSettle();
        final footer = find.byKey(const ValueKey('page-end-footer'));
        expect(footer, findsNothing);
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -6000),
        );
        await tester.pumpAndSettle();
        expect(footer, findsOneWidget);
        expect(
          tester.getRect(footer).bottom,
          closeTo(
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
            .1,
          ),
        );
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, 6000),
        );
        await tester.pumpAndSettle();
        expect(footer, findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final wide in [false, true]) {
    for (final long in [false, true]) {
      testWidgets(
        'footer scrolls after ${long ? 'long' : 'short'} content at ${wide ? 'desktop' : 'mobile'} size',
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
                body: PageScrollWithFooter(
                  child: ListView(
                    children: [
                      for (var i = 0; i < (long ? 60 : 1); i++)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Row $i'),
                        ),
                      const SiteFooter(),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final footer = find.byKey(const ValueKey('page-end-footer'));
          if (long) {
            expect(footer, findsNothing);
            await tester.drag(
              find.byType(CustomScrollView).first,
              const Offset(0, -12000),
            );
            await tester.pumpAndSettle();
          }
          expect(tester.getRect(footer).bottom, closeTo(size.height, .1));
          expect(find.text('Privacy'), findsOneWidget);
          await tester.tap(
            find.descendant(of: footer, matching: find.text('Privacy')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SiteInformationPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
