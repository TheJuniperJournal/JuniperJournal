import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/app_refresh_indicator.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('$platform only native mobile supports pull-to-refresh', (
      tester,
    ) async {
      var refreshes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppRefreshIndicator(
              onRefresh: () async {
                refreshes++;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [Text('No projects yet')],
              ),
            ),
          ),
        ),
      );
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(ListView)),
          scrollDelta: const Offset(0, -200),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        refreshes,
        0,
        reason: 'Wheel scrolling must never trigger refresh',
      );
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pumpAndSettle();
      final mobile =
          platform == TargetPlatform.android || platform == TargetPlatform.iOS;
      expect(refreshes, mobile ? 1 : 0);
      expect(
        find.byType(RefreshIndicator),
        mobile ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('mobile scrolling within content does not refresh', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 300);
    addTearDown(controller.dispose);
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppRefreshIndicator(
            onRefresh: () async {
              refreshes++;
            },
            child: ListView(
              controller: controller,
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(refreshes, 0);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}
