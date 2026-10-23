import 'package:juniper_journal/src/shared/widgets/creation_page_layout.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/features/community/pages/create_community_screen.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';

void main() {
  testWidgets(
    'community validation marks all missing requirements inline and clears each correction',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateCommunityScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Community name is required'), findsOneWidget);
      expect(find.text('Select a subject.'), findsOneWidget);
      expect(find.text('Enter a community name'), findsNothing);
      final nameField = find.byType(TextField).first;
      expect(
        (tester.widget<TextField>(nameField).decoration!.enabledBorder
                as OutlineInputBorder)
            .borderSide
            .color,
        AppColors.error,
      );
      final input = InputDecorator.containerOf(
        tester.element(
          find.descendant(of: nameField, matching: find.byType(EditableText)),
        ),
      )!;
      final bottom = input.localToGlobal(Offset.zero).dy + input.size.height;
      expect(
        tester.getRect(find.text('Community name is required')).top - bottom,
        inInclusiveRange(4, 8),
      );
      final subject = find.widgetWithText(
        CreationOptionCard,
        'Engineering & Design',
      );
      RoundedRectangleBorder shape() =>
          tester
                  .widget<Material>(
                    find
                        .descendant(
                          of: subject,
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .shape!
              as RoundedRectangleBorder;
      expect(shape().side.color, AppColors.error);
      await tester.enterText(nameField, 'Community garden');
      await tester.pumpAndSettle();
      expect(find.text('Community name is required'), findsNothing);
      expect(find.text('Select a subject.'), findsOneWidget);
      await tester.ensureVisible(subject);
      await tester.tap(subject);
      await tester.pumpAndSettle();
      expect(find.text('Select a subject.'), findsNothing);
      expect(shape().side.color, AppColors.primary);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'community members use project picker and can be removed and added again',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const person = UserProfile(
        id: 'amelia',
        displayName: 'Amelia Yang',
        username: 'amelia',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CreateCommunityScreen(
            loadFriends: () async => [person],
            searchPeople: (_) async => [person],
          ),
        ),
      );
      await tester.ensureVisible(find.text('Add People'));
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.text('Add People'));
        await tester.pumpAndSettle();
        expect(find.byType(ProjectMemberPicker), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(ProjectMemberPicker),
            matching: find.byType(TextField),
          ),
          'Amelia',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Amelia Yang'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add', skipOffstage: true));
        await tester.pumpAndSettle();
        expect(find.text('Amelia Yang'), findsOneWidget);
        expect(find.text('Project Member'), findsNothing);
        expect(find.text('No members added yet.'), findsNothing);
        await tester.ensureVisible(find.byTooltip('More options'));
        await tester.tap(find.byTooltip('More options'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();
        expect(find.text('Amelia Yang'), findsNothing);
        expect(find.text('No members added yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
