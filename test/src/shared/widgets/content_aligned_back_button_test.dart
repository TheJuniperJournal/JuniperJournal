import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/content_aligned_back_button.dart';

void main() {
  testWidgets(
    'visible arrow shares the content inset and keeps a full tap target',
    (tester) async {
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
        tester.getTopLeft(arrow).dx,
        tester.getTopLeft(find.byKey(const ValueKey('input'))).dx,
      );
      expect(
        tester.getSize(find.byType(ContentAlignedBackButton)).width,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byTooltip('Back'));
      expect(taps, 1);
    },
  );
}
