import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/styling/app_theme.dart';
import 'package:juniper_journal/src/shared/widgets/filter_checkbox.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_cell_field.dart';
import 'package:juniper_journal/src/features/learning_module/pages/table_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';

void main() {
  testWidgets('saved graph preview has finite responsive dimensions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 620,
                child: GraphEvidencePreview(
                  data: GraphBlockData(
                    id: 'preview',
                    createdAt: DateTime(2026),
                    updatedAt: DateTime(2026),
                    rows: const [GraphDataRow(x: '1', y: '2')],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GraphEvidencePreview)).width, 620);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('table cells fit and accept prose at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const TableBlockEditorScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EvidenceCellField), findsNWidgets(9));
      final field = find.descendant(
        of: find.byType(EvidenceCellField).first,
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Monday observations');
      await tester.pump();
      expect(find.text('Monday observations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [390.0, 768.0, 1440.0]) {
    for (final type in AssessmentType.values) {
      testWidgets('${type.name} inputs remain inside their card at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssessmentBlockSection(
                  value: AssessmentBlockData(
                    type: type,
                    data: const {'question': 'Explain your evidence'},
                  ),
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        for (final element in fields.evaluate()) {
          final field = find.byWidget(element.widget);
          final card = find
              .ancestor(
                of: field,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget.runtimeType.toString() == '_AssessmentFormCard',
                ),
              )
              .first;
          final bounds = tester.getRect(card);
          final input = tester.getRect(field);
          expect(input.left, greaterThanOrEqualTo(bounds.left));
          expect(input.right, lessThanOrEqualTo(bounds.right));
          expect(input.top, greaterThanOrEqualTo(bounds.top));
          expect(input.bottom, lessThanOrEqualTo(bounds.bottom));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('graph repaints immediately after editing data', (tester) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: GraphBlockEditorScreen(
          initialData: GraphBlockData(
            id: 'chart',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            rows: const [GraphDataRow(x: '1', y: '2')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(EvidenceCellField).last,
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, '12');
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '1: 12',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared square filter checkbox toggles independently', (
    tester,
  ) async {
    var first = false, second = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: Row(
              children: [
                FilterCheckbox(
                  value: first,
                  onChanged: (value) => update(() => first = value),
                ),
                FilterCheckbox(
                  value: second,
                  onChanged: (value) => update(() => second = value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(first, isTrue);
    expect(second, isFalse);
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).shape,
      isA<RoundedRectangleBorder>(),
    );
  });
}
