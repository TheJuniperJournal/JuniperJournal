import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/features/project/pages/shared_visibility_picker.dart';

const communities = [
  Community(
    id: 'linked',
    name: 'Linked Community',
    visibility: 'public',
    createdBy: 'owner',
  ),
  Community(
    id: 'extra',
    name: 'Extra Community',
    visibility: 'public',
    createdBy: 'owner',
    subjectFocus: 'Local sustainability',
  ),
];

void main() {
  testWidgets('solo shared audience selects friends and joined communities', (
    tester,
  ) async {
    SharedProjectAudience? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showDialog<SharedProjectAudience>(
                  context: context,
                  builder: (_) => const SharedVisibilityPicker(
                    projectType: 'solo',
                    linkedCommunities: [],
                    initial: SharedProjectAudience(),
                    communities: communities,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Collaborating Communities'), findsNothing);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.ensureVisible(find.text('Extra Community'));
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result!.friends, isTrue);
    expect(result!.communityIds, {'extra'});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'collaborative linked communities stay locked and are not duplicated',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SharedVisibilityPicker(
              projectType: 'collaborative',
              linkedCommunities: [
                {'id': 'linked', 'name': 'Linked Community'},
              ],
              initial: SharedProjectAudience(friends: true),
              communities: communities,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Collaborating Communities'), findsOneWidget);
      expect(find.text('Linked Community'), findsOneWidget);
      expect(find.text('Additional Viewing Communities'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
        expect((checkbox.side as WidgetStateBorderSide).resolve({WidgetState.selected})?.width, 1.5);
      }
      expect(tester.takeException(), isNull);
    },
  );
  test('audience settings restore from persisted project metadata', () {
    final project = Project.fromMap({
      'id': 'p',
      'share_friends': true,
      'shared_community_ids': ['one', 'two'],
    });
    expect(project.shareFriends, isTrue);
    expect(project.sharedCommunityIds, ['one', 'two']);
    expect(Project.fromMap({'id': 'old'}).shareFriends, isFalse);
  });
}
