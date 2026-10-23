import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/shared/widgets/journal_log_entry_card.dart';

void main() {
  for (final type in [
    ('building', 'BUILDING', Icons.build_outlined),
    ('testing', 'TESTING', Icons.science_outlined),
    ('technical_analysis', 'TECHNICAL ANALYSIS', Icons.bar_chart_outlined),
  ]) {
    testWidgets('${type.$1} preview tag shows its type and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 444,
                child: JournalLogEntryCard(
                  entry: JournalEntry(
                    id: 'entry',
                    projectId: 'project',
                    title: 'My journal',
                    progress: 'prototyping',
                    content: [
                      {'stage': 'prototyping', 'entryType': type.$1},
                    ],
                  ),
                  phaseLabel: 'PROTOTYPING',
                  status: const SizedBox.shrink(),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(type.$2), findsOneWidget);
      expect(find.byIcon(type.$3), findsOneWidget);
      expect(find.text('PROTOTYPING'), findsNothing);
      expect(find.text('My journal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('legacy entries keep their phase fallback', () {
    const entry = JournalEntry(
      id: 'legacy',
      projectId: 'p',
      title: 'Old journal',
      content: [
        {'stage': 'prototyping', 'iterations': []},
      ],
    );
    expect(entry.prototypingTypeLabel, isNull);
  });
}
