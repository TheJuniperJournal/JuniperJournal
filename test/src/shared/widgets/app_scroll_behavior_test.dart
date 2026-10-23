import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';

void main() {
  testWidgets('desktop scrollbar reserves space outside form content', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      theme: ThemeData(platform: TargetPlatform.macOS),
      home: Scaffold(body: SizedBox(width: 320, height: 200,
        child: SingleChildScrollView(controller: controller, child: Column(
          children: [
            const TextField(key: ValueKey('field')),
            const SizedBox(height: 500),
            TextButton(onPressed: () {}, child: const Text('Create')),
          ],
        )),
      )),
    ));
    final scrollbar = tester.getRect(find.byType(Scrollbar));
    final field = tester.getRect(find.byKey(const ValueKey('field')));
    expect(scrollbar.right - field.right, 16);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
