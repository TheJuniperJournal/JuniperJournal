import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/materials_cost.dart';

class _MaterialsRepo extends ProjectsRepo {
  @override
  Future<bool> updateMaterialsCost({
    required String id,
    required List<Map<String, dynamic>> materials,
  }) async => true;
  @override
  Future<List<Map<String, dynamic>>?> getMaterialsCost(String id) async => [];
}

void main() {
  testWidgets(
    'material requires item and valid cost, optional links stay blank',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MaterialsCostPage(
            projectId: 'project',
            projectName: 'Test',
            tags: const [],
            projectsRepo: _MaterialsRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final save = find.descendant(
        of: sheet,
        matching: find.widgetWithText(TextButton, 'Save'),
      );
      expect(tester.widget<TextButton>(save).onPressed, isNotNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Check required fields'), findsOneWidget);
      expect(find.text('Item is required.\nCost is required.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: sheet,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Coco Fiber');
      await tester.pump();

      await tester.enterText(fields.at(1), 'invalid');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Cost is required.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.enterText(fields.at(1), '-1');
      await tester.pump();

      await tester.enterText(fields.at(1), '0');
      await tester.pump();

      expect(find.text('None'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(fields, findsNWidgets(2));
      expect(find.textContaining('Build Log'), findsNothing);
      await tester.enterText(fields.at(0), '   ');
      await tester.pump();

      await tester.enterText(fields.at(0), 'Coco Fiber');
      await tester.enterText(fields.at(1), '1.00');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Coco Fiber'), findsOneWidget);
    },
  );
}
