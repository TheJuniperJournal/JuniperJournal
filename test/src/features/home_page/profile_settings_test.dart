import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/settings.dart';
import 'package:juniper_journal/src/shared/styling/app_theme.dart';

class _Users extends UsersRepo {
  bool public = true;
  bool succeed = true;
  String? avatar;
  String savedBio = '';

  @override
  Future<UserProfile?> getCurrentUserProfile() async => UserProfile(
    id: 'u',
    bio: savedBio,
    displayName: 'Amelia',
    username: 'amelia',
    isPublicProfile: public,
  );
  @override
  Future<bool> updateCurrentUserProfile({
    String? avatarUrl,
    String? bio,
    String? displayName,
    bool? isPublicProfile,
  }) async {
    if (!succeed) return false;
    if (isPublicProfile != null) public = isPublicProfile;
    if (avatarUrl != null) avatar = avatarUrl;
    if (bio != null) savedBio = bio.trim();
    return true;
  }
}

void main() {
  testWidgets('bio saves and reloads while failed saves keep the saved value', (
    tester,
  ) async {
    final users = _Users();
    Widget page() => MaterialApp(
      theme: buildAppTheme(),
      home: SettingsScreen(usersRepo: users, email: ''),
    );
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    final bio = find.widgetWithText(TextField, 'Bio');
    await tester.scrollUntilVisible(
      bio,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(bio, 'Building greener communities.');
    await tester.ensureVisible(find.text('Save bio'));
    await tester.tap(find.text('Save bio'));
    await tester.pumpAndSettle();
    expect(users.savedBio, 'Building greener communities.');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      bio,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<TextField>(bio).controller!.text, users.savedBio);
    users.succeed = false;
    await tester.enterText(bio, 'Unsaved replacement');
    await tester.ensureVisible(find.text('Save bio'));
    await tester.tap(find.text('Save bio'));
    await tester.pumpAndSettle();
    expect(users.savedBio, 'Building greener communities.');
    expect(find.text('Could not save bio. Please try again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'profile visibility persists and failed changes restore the saved value',
    (tester) async {
      final users = _Users();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(usersRepo: users, email: ''),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Private'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      expect(users.public, isFalse);
      await tester.scrollUntilVisible(
        find.text('Private'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
            .groupValue,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(usersRepo: users, email: ''),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Private'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
            .groupValue,
        isFalse,
      );
      users.succeed = false;
      await tester.ensureVisible(find.text('Public'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      expect(users.public, isFalse);
      await tester.scrollUntilVisible(
        find.text('Private'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
            .groupValue,
        isFalse,
      );
      expect(find.text('Could not update profile visibility'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'profile settings can change the photo through the shared source chooser',
    (tester) async {
      final users = _Users();
      ImageSource? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: SettingsScreen(
            usersRepo: users,
            email: '',
            uploadProfilePhoto: (source) async {
              selected = source;
              return 'https://example.com/avatar.jpg';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Change profile photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change profile photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      expect(selected, ImageSource.gallery);
      expect(users.avatar, 'https://example.com/avatar.jpg');
      expect(find.text('Profile photo updated'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );
}
