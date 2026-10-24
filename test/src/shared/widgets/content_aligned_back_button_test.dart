import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/content_aligned_back_button.dart';

void main() {
  testWidgets('arrow and hover target stay centered with a full tap area', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentAlignedBackButton(onPressed: () => taps++),
                Container(
                  key: const ValueKey('input'),
                  width: double.infinity,
                  height: 100,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final arrow = find.descendant(
      of: find.byType(ContentAlignedBackButton),
      matching: find.byKey(const ValueKey('content-back-chevron')),
    );
    expect(
      (tester.getCenter(arrow) -
              tester.getCenter(find.byType(ContentAlignedBackButton)))
          .distance,
      lessThan(.01),
    );
    expect(
      tester.getSize(find.byType(ContentAlignedBackButton)).width,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.byTooltip('Back'));
    expect(taps, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 72,
            leadingWidth: 88,
            leading: ContentAlignedBackButton(onPressed: () => taps++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byType(SizedBox).evaluate().where((element) {
      final box = element.widget as SizedBox;
      return box.width == 44 && box.height == 44;
    }).first;
    expect(
      (tester.getCenter(arrow) - tester.getCenter(find.byWidget(target.widget)))
          .distance,
      lessThan(.01),
    );
    await tester.tap(arrow);
    expect(taps, 2);
  });
}
