import '../../../support/fake_backend.dart';
import 'package:juniper_journal/src/features/home_page/pages/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/public_user_profile.dart';

class _Users extends UsersRepo {
  @override
  Future<List<UserProfile>> getProfilesByIds(List<String> ids) async => [
    const UserProfile(
      id: 'person',
      displayName: 'Ricky',
      bio: 'Learning through design',
      isPublicProfile: false,
    ),
  ];
}

class _Friends extends FriendsRepo {
  _Friends(this.allowed);
  final bool allowed;
  @override
  Future<bool> canViewUserProjects({required String targetUserId}) async =>
      allowed;
  @override
  Future<List<UserProfile>?> getVisibleFriendsForUser(String userId) async => [
    const UserProfile(id: 'friend', displayName: 'Amelia'),
  ];
}

class _Projects extends ProjectsRepo {
  _Projects([this.projects = const []]);
  final List<Project> projects;
  int reads = 0;
  @override
  Future<List<Project>?> getProjectsByUserId({required String userId}) async {
    reads++;
    return projects;
  }

  @override
  Future<Map<String, dynamic>> ecoPointsSummary(String userId) async {
    reads++;
    return {
      'total': 80,
      'subjects': {'Engineering & Design': 80},
    };
  }
}

void main() {
  setUpAll(() => initializeFakeBackend());
  testWidgets(
    'own profile has only progress and friends, with no library load',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final projects = _Projects();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicUserProfilePage(
            userId: 'person',
            currentUserId: 'person',
            usersRepo: _Users(),
            friendsRepo: _Friends(true),
            projectsRepo: projects,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Journal Library'), findsNothing);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('80 EcoPoints'), findsNWidgets(2));
      expect(projects.reads, 1);
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.text('Amelia'), findsOneWidget);
      expect(find.text('80 EcoPoints'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final allowed in [true, false]) {
    testWidgets('profile access allowed: $allowed', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final projects = _Projects();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicUserProfilePage(
            userId: 'person',
            usersRepo: _Users(),
            friendsRepo: _Friends(allowed),
            projectsRepo: projects,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ricky'), findsOneWidget);
      if (allowed) {
        expect(find.text('Learning through design'), findsOneWidget);
        expect(find.text('80 EcoPoints'), findsNWidgets(2));
        expect(find.text('Journal Library'), findsOneWidget);
        expect(projects.reads, 2);
        await tester.tap(find.text('Journal Library'));
        await tester.pumpAndSettle();
        expect(find.text('No projects to show yet.'), findsOneWidget);
      } else {
        expect(find.textContaining('This profile is private'), findsOneWidget);
        expect(find.text('Learning through design'), findsNothing);
        expect(find.text('Journal Library'), findsNothing);
        expect(projects.reads, 0);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expanded profile subjects open only matching visible projects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PublicUserProfilePage(
          userId: 'person',
          currentUserId: 'viewer',
          usersRepo: _Users(),
          friendsRepo: _Friends(true),
          projectsRepo: _Projects(const [
            Project(
              id: 'design',
              projectName: 'Reservoir design',
              tags: ['Engineering & Design'],
            ),
            Project(
              id: 'energy',
              projectName: 'Solar trial',
              tags: ['Energy & Systems'],
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    await tester.tap(find.text('Engineering & Design'));
    await tester.pumpAndSettle();
    expect(find.text('Reservoir design'), findsOneWidget);
    expect(find.text('Solar trial'), findsNothing);
    await tester.tap(find.byTooltip('Clear subject filter'));
    await tester.pumpAndSettle();
    expect(find.text('Solar trial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact sidebar subject cards have no project links or arrows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selections = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserProfilePage(
            compact: true,
            onSubjectSelected: (_) => selections++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await tester.tap(find.text('Engineering & Design'));
    await tester.pumpAndSettle();
    expect(selections, 0);
    expect(find.text('EcoPoints by subject'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
