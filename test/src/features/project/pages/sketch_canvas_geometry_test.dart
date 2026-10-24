import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';

void main() {
  test('canvas dimensions survive storage round trip', () {
    const data = SketchBlockData(canvasSize: Size(672, 206));
    expect(
      SketchBlockData.fromJson(data.toJson()).effectiveCanvasSize,
      const Size(672, 206),
    );
  });
  test('legacy annotations expand the canvas rather than clipping at 345', () {
    final data = SketchBlockData.fromJson({
      'text_items': [
        {'x': 336, 'y': 103, 'text': 'QA annotated measurement'},
      ],
    });
    expect(data.effectiveCanvasSize.width, greaterThan(500));
    expect(data.effectiveCanvasSize.height, 206);
  });
  test('invalid dimensions fall back to content bounds', () {
    final data = SketchBlockData.fromJson({
      'canvas_width': -1,
      'canvas_height': 0,
      'strokes': [
        {
          'points': [
            {'x': 700, 'y': 300},
          ],
        },
      ],
    });
    expect(data.effectiveCanvasSize, const Size(716, 316));
  });
  testWidgets('preview preserves logical coordinates at different widths', (
    tester,
  ) async {
    const data = SketchBlockData(
      canvasSize: Size(672, 206),
      textItems: [
        SketchTextItem(
          text: 'QA annotated measurement',
          position: Offset(336, 103),
          color: Colors.black,
        ),
      ],
    );
    for (final width in [320.0, 800.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const SketchEvidencePreview(data: data),
              ),
            ),
          ),
        ),
      );
      final canvas = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((box) => box.width == 672)
          .single;
      expect(canvas.height, 206);
      expect(tester.takeException(), isNull);
    }
  });
}
