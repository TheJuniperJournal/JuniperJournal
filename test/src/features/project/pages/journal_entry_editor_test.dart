import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('JournalEntryEditorScreen renders title and actions', (
    WidgetTester tester,
  ) async {
    final initialDoc =
        jsonDecode(jsonEncode(ParchmentDocument())) as List<dynamic>;

    await tester.pumpWidget(
      MaterialApp(
        home: JournalEntryEditorScreen(
          projectId: 'project-1',
          projectName: 'Test Project',
          tags: const ['WATER'],
          entryId: 'entry-1',
          initialTitle: 'Entry 1',
          initialContent: initialDoc,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Entry 1'), findsOneWidget);
    expect(find.text('Entry Title (Optional)'), findsNothing);
    expect(find.text('Who is involved?'), findsNothing);
    expect(find.text('Phase'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Submit'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Submit'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Submit')),
      findsNothing,
    );
    final title = find.byType(TextField).first;
    expect(tester.getCenter(title).dx, closeTo(400, 1));
    expect(
      tester.getCenter(find.widgetWithText(FilledButton, 'Submit')).dy,
      closeTo(
        tester.getCenter(find.widgetWithText(OutlinedButton, 'Back')).dy,
        1,
      ),
    );
  });
}
