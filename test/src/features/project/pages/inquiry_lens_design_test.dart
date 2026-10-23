import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

void main() {
  for (final width in [240.0, 332.0, 700.0]) {
    testWidgets('all inquiry descriptions remain visible at width $width', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Center(
                child: SizedBox(
                  width: width,
                  child: InquiryLensChoiceGrid(
                    data: const InquiryLensData(),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final option in InquiryLensConfig.values) {
        final description = tester.widget<Text>(find.text(option.description));
        expect(description.maxLines, isNull);
        expect(description.overflow, isNot(TextOverflow.ellipsis));
      }
      final design = tester.getTopLeft(find.text('Design'));
      final observe = tester.getTopLeft(find.text('Observe'));
      if (width >= 300) {
        expect(design.dy, closeTo(observe.dy, 0.1));
        final cards = find.byType(GestureDetector);
        expect(
          tester.getSize(cards.at(0)).height,
          closeTo(tester.getSize(cards.at(1)).height, .01),
        );
        expect(observe.dx, greaterThan(design.dx));
      } else {
        expect(observe.dy, greaterThan(design.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'shared selector uses cards and preserves the selected lens data',
    (tester) async {
      var value = const InquiryLensData();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: StatefulBuilder(
                  builder: (context, setState) => InquiryLensSelector(
                    data: value,
                    onChanged: (next) => setState(() => value = next),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(InquiryLensChoiceGrid), findsOneWidget);
      await tester.tap(find.text('Design'));
      await tester.pumpAndSettle();
      expect(value.selectedLens, 'Design');
      await tester.ensureVisible(find.text('Observe'));
      await tester.tap(find.text('Observe'));
      await tester.pumpAndSettle();
      expect(value.selectedLens, 'Observe');
      expect(tester.takeException(), isNull);
    },
  );
}
