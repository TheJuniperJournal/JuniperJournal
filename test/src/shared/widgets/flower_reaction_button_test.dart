import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/repositories/flower_reactions_repo.dart';
import 'package:juniper_journal/src/shared/widgets/flower_reaction_button.dart';

class FakeFlowers extends FlowerReactionsRepo {
  FlowerState value = const FlowerState(2, false);
  bool fail = false;
  int writes = 0;
  @override
  Future<FlowerState> load(FlowerTarget target, String id) async => value;
  @override
  Future<void> setSelected(
    FlowerTarget target,
    String id,
    bool selected,
  ) async {
    writes++;
    if (fail) throw StateError('offline');
    value = FlowerState(value.count + (selected ? 1 : -1), selected);
  }
}

void main() {
  testWidgets(
    'flower persists selection, removes it, and restores after failure',
    (tester) async {
      final repo = FakeFlowers();
      Widget page() => MaterialApp(
        home: Scaffold(
          body: FlowerReactionButton(
            target: FlowerTarget.message,
            targetId: 'message',
            repo: repo,
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(repo.value.selected, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(repo.value.selected, isFalse);
      expect(find.text('2'), findsOneWidget);
      repo.fail = true;
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(
        find.text('Could not update your flower. Please try again.'),
        findsOneWidget,
      );
    },
  );
}
