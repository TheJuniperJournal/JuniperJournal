import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';

const entry = JournalEntry(
  id: 'entry',
  projectId: 'project',
  title: 'Food waste',
  progress: 'discover',
  content: [
    {
      'stage': 'analyze',
      'rootCauses': [
        {
          'title': 'Overproduction',
          'description': 'More food than needed',
          'reason': 'Demand varies',
          'evidence': [
            {
              'type': 'Images',
              'data': {
                'title': 'Lunch photos',
                'caption': 'Leftover food',
                'images': [
                  {'description': 'After lunch'},
                ],
              },
            },
            {
              'type': 'Sketch',
              'data': {
                'title': 'Kitchen sketch',
                'caption': 'Kitchen flow',
                'strokes': [],
              },
            },
            {
              'type': 'Link',
              'data': {
                'title': 'Source article',
                'url': 'https://example.com',
                'description': 'Research source',
              },
            },
            {
              'type': 'Video',
              'data': {
                'title': 'Food video',
                'source_mode': 'url',
                'external_url': 'https://example.com/video',
                'description': 'Video description',
              },
            },
            {
              'type': 'Graph',
              'data': {
                'title': 'Waste trend',
                'graph_type': 'bar',
                'x_axis_label': 'Day',
                'y_axis_label': 'Waste',
                'rows': [
                  {'x': '1', 'y': '3'},
                ],
                'caption': 'Graph caption',
              },
            },
            {
              'type': 'Table',
              'data': {
                'title': 'Measurements',
                'columns': [
                  {'id': 'c1', 'name': 'Day', 'order_index': 0},
                  {'id': 'c2', 'name': 'Waste', 'order_index': 1},
                ],
                'rows': [
                  {'c1': 'Monday', 'c2': '3 kg'},
                ],
              },
            },
          ],
        },
      ],
    },
  ],
);

void main() {
  testWidgets(
    'viewer renders all six saved evidence types without editing controls',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: JournalEntryEditorScreen(
            projectId: entry.projectId,
            projectName: 'Project',
            tags: const [],
            entryId: entry.id,
            initialTitle: entry.title,
            initialContent: entry.content,
            initialProgress: entry.progress,
            readOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryEntryPreviewPage), findsOneWidget);
      await tester.tap(find.text('Overproduction'));
      await tester.pumpAndSettle();
      for (final type in [
        'Images',
        'Sketch',
        'Link',
        'Video',
        'Graph',
        'Table',
      ]) {
        expect(find.text(type), findsOneWidget);
      }
      expect(find.byType(GraphEvidencePreview), findsOneWidget);
      expect(find.byType(SketchEvidencePreview), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('Leftover food'), findsOneWidget);
      expect(find.text('Watch video'), findsOneWidget);
      expect(find.text('Open link'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Collapse root cause'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
    },
  );
}
