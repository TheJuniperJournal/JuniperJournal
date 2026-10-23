import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/eco_reward_notice_host.dart';

void main() {
  testWidgets(
    'completion shows one final popup with points and explicit Done',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: ecoRewardNavigatorKey,
          builder: (_, child) => EcoRewardNoticeHost(child: child!),
          home: const Scaffold(body: Text('Project dashboard')),
        ),
      );
      journalCompletionNotice.value = const JournalCompletionNotice(
        entryId: 'entry',
        points: 23,
      );
      await tester.pumpAndSettle();
      expect(find.text('Journal entry completed'), findsOneWidget);
      expect(find.text('+23 EcoPoints'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Journal entry completed'), findsNothing);
      expect(find.text('Project dashboard'), findsOneWidget);
    },
  );
}
