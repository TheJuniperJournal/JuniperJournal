import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

void main() {
  testWidgets(
    'picker searches supplied project members and adds only selected people',
    (tester) async {
      final selected = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => JournalInvolvedPeopleField(
                members: const [
                  UserProfile(id: 'amelia', displayName: 'Amelia Yang'),
                  UserProfile(id: 'ricky', displayName: 'Ricky Rios'),
                ],
                selectedIds: selected,
                onToggle: (id) => update(() {
                  if (!selected.add(id)) selected.remove(id);
                }),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amelia Yang'), findsNothing);
      await tester.tap(find.text('Add People'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Amelia');
      await tester.pump();
      expect(find.text('Amelia Yang'), findsOneWidget);
      expect(find.text('Ricky Rios'), findsNothing);
      await tester.tap(find.text('Amelia Yang'));
      await tester.pump();
      expect(selected, isEmpty);
      await tester.tap(find.text('Save Contributors'));
      await tester.pumpAndSettle();
      expect(find.text('Amelia Yang'), findsOneWidget);
      expect(find.text('Ricky Rios'), findsNothing);
    },
  );
  testWidgets(
    'author stays attributed and cannot be selected again or removed',
    (tester) async {
      final toggles = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JournalInvolvedPeopleField(
              creatorId: 'author',
              members: const [
                UserProfile(id: 'author', displayName: 'Original Author'),
                UserProfile(id: 'other', displayName: 'Collaborator'),
              ],
              selectedIds: const {'author'},
              onToggle: toggles.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original Author · Author'), findsOneWidget);
      await tester.tap(find.text('Add People'));
      await tester.pumpAndSettle();
      expect(find.text('Original Author'), findsNothing);
      expect(find.text('Collaborator'), findsOneWidget);
      await tester.tap(find.text('Collaborator'));
      await tester.pump();
      expect(toggles, isEmpty);
      await tester.tap(find.text('Save Contributors'));
      await tester.pumpAndSettle();
      expect(toggles, ['other']);
    },
  );
}
