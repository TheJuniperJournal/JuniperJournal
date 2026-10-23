import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';

void main() {
  testWidgets('back arrow exits and the centered title cannot intercept it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        body: EvidenceBlockHeader(
                          title: 'Sketch Block',
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final arrow = find.byTooltip('Back');
    final point = tester.getCenter(arrow);
    await tester.tapAt(Offset(point.dx - 19, point.dy));
    await tester.pumpAndSettle();
    expect(find.text('Sketch Block'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });
}
