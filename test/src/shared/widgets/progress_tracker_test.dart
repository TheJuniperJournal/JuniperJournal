import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/progress_tracker.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';

void main() {
  testWidgets(
    'visual tracker is not clickable and journal tracker supports navigation',
    (tester) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ProgressTracker(
                  key: ValueKey('visual'),
                  currentIndex: 0,
                  showCurrentIndicator: false,
                  labels: ['Discover', 'Build'],
                  reachedIndices: {0},
                ),
                ProgressTracker(
                  key: const ValueKey('journal'),
                  labels: const ['Observe', 'Learning'],
                  reachedIndices: const {0},
                  currentIndex: 0,
                  onSelected: (index) => selected = index,
                ),
              ],
            ),
          ),
        ),
      );
      final visual = find.byKey(const ValueKey('visual'));
      expect(
        find.descendant(of: visual, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: visual,
          matching: find.byKey(const ValueKey('stage-current-0')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('journal')),
          matching: find.byKey(const ValueKey('stage-current-0')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Discover'));
      expect(selected, -1);
      await tester.tap(find.text('Learning'));
      expect(selected, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('evidence heading uses the larger green role', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              JournalSectionHeader(title: 'Build'),
              JournalSectionHeader(title: 'Evidence'),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Build')).style,
      AppTypography.sectionTitle,
    );
    expect(
      tester.widget<Text>(find.text('Evidence')).style,
      AppTypography.evidenceTitle,
    );
    expect(
      AppTypography.evidenceTitle.fontSize!,
      greaterThan(AppTypography.sectionTitle.fontSize!),
    );
  });
}
