import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/learning_module/pages/image_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/link_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/video_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/table_block_editor.dart';

Future<void> openEditor(
  WidgetTester tester,
  Widget editor,
  ValueChanged<Object?> onClosed,
) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(
                context,
              ).push(MaterialPageRoute<Object?>(builder: (_) => editor));
              onClosed(result);
            },
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SupabaseDatabase.instance.client = SupabaseClient(
      'https://example.test',
      'test-key',
    );
  });
  tearDownAll(() async {
    await SupabaseDatabase.instance.client.dispose();
  });
  final editors = <String, Widget>{
    'image': const ImageBlockEditorScreen(moduleId: 'test'),
    'sketch': const SketchBlockEditorScreen(moduleId: 'test'),
    'link': const LinkBlockEditorScreen(),
    'video': const VideoBlockEditorScreen(moduleId: 'test'),
    'graph': const GraphBlockEditorScreen(),
    'table': const TableBlockEditorScreen(),
  };
  for (final entry in editors.entries) {
    testWidgets('${entry.key} cannot add blank required content', (
      tester,
    ) async {
      var closed = false;
      await openEditor(tester, entry.value, (_) => closed = true);
      final add = find.text('Add Block').last;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      expect(find.byWidget(entry.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'link saves valid content while optional title and description stay blank',
    (tester) async {
      Object? saved;
      await openEditor(
        tester,
        const LinkBlockEditorScreen(),
        (result) => saved = result,
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://example.com',
      );
      await tester.ensureVisible(find.text('Add Block').last);
      await tester.tap(find.text('Add Block').last);
      await tester.pumpAndSettle();
      expect(saved, isA<LinkBlockData>());
      expect((saved as LinkBlockData).title, isEmpty);
      expect((saved as LinkBlockData).description, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
