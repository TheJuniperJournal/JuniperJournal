import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/image_resize_frame.dart';

void main() {
  testWidgets('corner drag changes width proportionally and clamps to canvas', (
    tester,
  ) async {
    double fraction = .75;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => Align(
              alignment: Alignment.topLeft,
              child: ImageResizeFrame(
                width: 400 * fraction,
                maxWidth: 400,
                selected: true,
                onResize: (v) => update(() => fraction = v),
                child: const AspectRatio(
                  aspectRatio: 2,
                  child: ColoredBox(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final handle = find.byKey(const ValueKey('image-resize-1.0-1.0'));
    await tester.drag(handle, const Offset(-80, -40));
    await tester.pump();
    expect(fraction, closeTo(.55, .02));
    final size = tester.getSize(find.byType(ImageResizeFrame));
    expect(size.width / size.height, closeTo(2, .001));
    await tester.drag(handle, const Offset(600, 300));
    await tester.pump();
    expect(fraction, 1);
    await tester.drag(handle, const Offset(-600, -300));
    await tester.pump();
    expect(fraction, .25);
  });

  testWidgets('unselected and read-only images have no resize handles', (
    tester,
  ) async {
    for (final selected in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageResizeFrame(
            width: 300,
            maxWidth: 400,
            selected: selected,
            onResize: null,
            child: const SizedBox(height: 150),
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
      expect(find.byType(Slider), findsNothing);
    }
  });
}
