import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/app_tab_transition.dart';
import 'package:juniper_journal/src/shared/widgets/navigation_scroll_reset.dart';

Widget items(ScrollController controller) => ListView.builder(
  controller: controller,
  itemExtent: 60,
  itemCount: 50,
  itemBuilder: (_, i) => Text('Item $i'),
);

void main() {
  testWidgets(
    'sidebar content tabs preserve both panel and center feed positions',
    (tester) async {
      final feed = ScrollController();
      final panel = ScrollController();
      addTearDown(feed.dispose);
      addTearDown(panel.dispose);
      var friends = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Scaffold(
                body: Row(
                  children: [
                    Expanded(child: items(feed)),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: panel,
                        child: Column(
                          children: [
                            const SizedBox(height: 300),
                            const Text('Progress / Friends'),
                            AppContentTransition(
                              index: friends,
                              child: SizedBox(
                                height: 1800,
                                child: Text(friends ? 'Friends' : 'Progress'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      feed.jumpTo(480);
      panel.jumpTo(240);
      update(() => friends = true);
      await tester.pumpAndSettle();
      expect(feed.offset, 480);
      expect(panel.offset, 240);
      update(() => friends = false);
      await tester.pumpAndSettle();
      expect(feed.offset, 480);
      expect(panel.offset, 240);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('in-page tabs retain their individual scroll positions', (
    tester,
  ) async {
    final first = ScrollController();
    final second = ScrollController();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var index = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Scaffold(
              body: AppTabStack(
                index: index,
                children: [items(first), items(second)],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    first.jumpTo(500);
    update(() => index = 1);
    await tester.pumpAndSettle();
    second.jumpTo(700);
    update(() => index = 0);
    await tester.pumpAndSettle();
    expect(first.offset, 500);
    update(() => index = 1);
    await tester.pumpAndSettle();
    expect(second.offset, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'returning from a page resets the previous page but closing a dialog does not',
    (tester) async {
      final controller = ScrollController();
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [NavigationScrollResetObserver()],
          home: Scaffold(body: items(controller)),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(400);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Detail')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      controller.jumpTo(300);
      showDialog<void>(
        context: navigator.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(title: Text('Dialog')),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(controller.offset, 300);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'section switches preserve the surrounding vertical page',
    (tester) async {
      final vertical = ScrollController();
      final horizontal = ScrollController();
      addTearDown(vertical.dispose);
      addTearDown(horizontal.dispose);
      late StateSetter update;
      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Scaffold(
                body: ListView(
                  controller: vertical,
                  children: [
                    AppContentTransition(
                      index: index,
                      child: SizedBox(
                        height: 1000,
                        child: Column(
                          children: [
                            Text('Section $index'),
                            SizedBox(
                              height: 100,
                              child: ListView(
                                controller: horizontal,
                                scrollDirection: Axis.horizontal,
                                children: const [SizedBox(width: 2000)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      horizontal.jumpTo(100);
      vertical.jumpTo(200);
      update(() => index = 1);
      await tester.pumpAndSettle();
      expect(vertical.offset, 200);
      expect(tester.takeException(), isNull);
    },
  );
}
