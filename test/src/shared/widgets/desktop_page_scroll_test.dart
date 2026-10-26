import 'package:juniper_journal/src/shared/widgets/popup_route_observer.dart';
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/shared/widgets/persistent_desktop_shell.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/desktop_page_scroll.dart';

void main() {
  testWidgets('nested centered shells keep one scrollbar at the window edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPageScroll(
            child: Center(
              child: SizedBox(
                width: 700,
                child: DesktopPageScroll(
                  child: ListView(children: const [SizedBox(height: 2400)]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollbar = find.byKey(const ValueKey('desktop-page-scrollbar'));
    expect(scrollbar, findsOneWidget);
    expect(tester.getRect(scrollbar).right, 1400);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page keys scroll while text field arrows keep editing', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPageScroll(
            child: ListView(
              controller: controller,
              children: const [TextField(), SizedBox(height: 2500)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Editing text');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel over either side drives the page and profile follows it', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPageScroll(
            child: Row(
              children: [
                const SizedBox(
                  width: 200,
                  child: Center(child: Text('Navigation')),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: page,
                    itemExtent: 100,
                    itemCount: 30,
                    itemBuilder: (_, i) => Text('Entry $i'),
                  ),
                ),
                const SizedBox(
                  width: 280,
                  child: DesktopSideScroll(
                    child: SizedBox(
                      height: 1500,
                      child: Column(
                        children: [
                          Text('Profile top'),
                          Spacer(),
                          Text('Profile bottom'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(1050, 300),
        scrollDelta: Offset(0, 250),
      ),
    );
    await tester.pumpAndSettle();
    expect(page.offset, 250);
    final side = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(DesktopSideScroll),
        matching: find.byType(Scrollable),
      ),
    );
    expect(side.position.pixels, 250);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(100, 300),
        scrollDelta: Offset(0, 150),
      ),
    );
    await tester.pumpAndSettle();
    expect(page.offset, 400);
    expect(side.position.pixels, 400);
    expect(find.byType(RawScrollbar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('short pages reveal the bottom of a taller sidebar', (
    tester,
  ) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopPageScroll(
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: page,
                    child: const SizedBox(height: 800),
                  ),
                ),
                const SizedBox(
                  width: 200,
                  child: DesktopSideScroll(
                    child: SizedBox(
                      height: 1400,
                      child: Column(
                        children: [Spacer(), Text('EcoPoints by subject')],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    page.jumpTo(page.position.maxScrollExtent);
    await tester.pumpAndSettle();
    final side = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(DesktopSideScroll),
        matching: find.byType(Scrollable),
      ),
    );
    expect(side.position.pixels, side.position.maxScrollExtent);
    expect(find.text('EcoPoints by subject').hitTestable(), findsOneWidget);
  });
  testWidgets(
    'dropdown routes preserve the profile offset and page scroll target',
    (tester) async {
      final page = ScrollController();
      addTearDown(page.dispose);
      final popups = PopupRouteObserver();
      addTearDown(popups.dispose);
      var selection = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [desktopRouteObserver, popups],
          builder: (_, child) => DesktopPageScroll(child: child!),
          home: StatefulBuilder(
            builder: (context, update) => Scaffold(
              appBar: AppBar(
                title: DropdownButton<int>(
                  value: selection,
                  items: [
                    for (var i = 0; i < 20; i++)
                      DropdownMenuItem(value: i, child: Text('Option $i')),
                  ],
                  onChanged: (value) => update(() => selection = value!),
                ),
              ),
              body: Row(
                children: [
                  Expanded(
                    child: ListView(
                      controller: page,
                      children: const [SizedBox(height: 2500)],
                    ),
                  ),
                  const SizedBox(
                    width: 180,
                    child: DesktopSideScroll(child: SizedBox(height: 1800)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      page.jumpTo(250);
      await tester.pumpAndSettle();
      final side = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(DesktopSideScroll),
          matching: find.byType(Scrollable),
        ),
      );
      final route = desktopRouteObserver.current;
      final offset = side.position.pixels;
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      expect(desktopRouteObserver.current, same(route));
      expect(side.position.pixels, offset);
      final bar = tester.widget<RawScrollbar>(
        find.byKey(const ValueKey('desktop-page-scrollbar')),
      );
      expect(bar.controller!.position, same(page.position));
      // Wheel input outside the menu must not move its page anchor.
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: const Offset(700, 500),
          scrollDelta: const Offset(0, 160),
        ),
      );
      await tester.pumpAndSettle();
      expect(page.offset, 250);
      expect(PopupRouteObserver.hasOpenPopup, isTrue);
      await tester.tap(find.text('Option 2').last);
      await tester.pumpAndSettle();
      expect(selection, 2);
      expect(PopupRouteObserver.hasOpenPopup, isFalse);
      expect(side.position.pixels, offset);
      expect(page.offset, 250);
      expect(desktopRouteObserver.current, same(route));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
