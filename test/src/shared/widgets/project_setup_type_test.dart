import 'package:juniper_journal/src/shared/widgets/creation_page_layout.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/backend/security/input_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';

class SetupRepo extends ProjectsRepo {
  @override
  Future<bool> canManageProject(String id) async => true;
  @override
  Future<Map<String, String>> getProjectMemberRoles(String id) async => {
    'amelia': 'project_member',
  };

  @override
  Future<List<UserProfile>> getProjectInvitees({
    required String projectId,
  }) async => const [UserProfile(id: 'amelia', displayName: 'Amelia Yang')];
}

class SavingSetupRepo extends SetupRepo {
  List<String>? savedTags;
  @override
  Future<bool> updateProjectMetadata({
    required String id,
    required String projectName,
    required String problemStatement,
    required List<String> tags,
    List<Map<String, dynamic>>? learningObjectives,
    String? projectImageUrl,
    String? difficulty,
    String? projectScale,
    String? visibility,
    String? projectType,
    List<Map<String, dynamic>>? communityLinks,
    bool? shareFriends,
    List<String>? sharedCommunityIds,
  }) async {
    if (InputValidator.tags(tags) != null) return false;
    savedTags = tags;
    return true;
  }
}

void main() {
  for (final legacy in [true, false]) {
    testWidgets(
      'settings saves ${legacy ? 'legacy' : 'current'} tags and returns to dashboard',
      (tester) async {
        final repo = SavingSetupRepo();
        final project = Project(
          id: 'p',
          userId: 'owner',
          projectName: 'Juniper Journal Learning Kits',
          problemStatement: 'Create a readable booklet about hydroponics.',
          tags: legacy
              ? [
                  'Engineering & Design|Designing Solutions and Prototyping',
                  'Environment & Sustainability|Ecosystems & Biodiversity',
                ]
              : ['Engineering & Design'],
          projectType: 'collaborative',
          difficulty: 'Easy',
          projectScale: 'Small',
          visibility: 'Public',
          learningObjectives: [
            {
              'action': 'Analyze',
              'subject': 'Environment & Sustainability',
              'description': 'Create a readable booklet about hydroponics.',
            },
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateProjectScreen(
                        existingProject: project,
                        projectsRepo: repo,
                      ),
                    ),
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open settings'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(repo.savedTags, [
          'Engineering & Design',
          if (legacy) 'Environment & Sustainability|Ecosystems & Biodiversity',
        ]);
        expect(find.byType(CreateProjectScreen), findsNothing);
        expect(find.text('Open settings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saving requires at least one complete learning objective but no community',
    (tester) async {
      final project = Project.fromMap({
        'id': 'p',
        'project_name': 'Test project',
        'problem_statement': 'A problem to solve',
        'tags': ['Environment & Sustainability'],
        'project_type': 'solo',
        'difficulty': 'Easy',
        'project_scale': 'Small',
        'visibility': 'Private',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CreateProjectScreen(
            existingProject: project,
            projectsRepo: SetupRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        find.text('Add at least one complete learning objective.'),
        findsOneWidget,
      );
      final explanation = tester.getRect(
        find.text('Add at least one learning objective (up to four).'),
      );
      final error = tester.getRect(
        find.text('Add at least one complete learning objective.'),
      );
      expect(error.top, greaterThan(explanation.bottom));
      expect(find.byType(ProjectCommunitiesSection), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submit marks every missing requirement and clears corrected fields',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateProjectScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      for (final message in [
        'Project name is required',
        'Choose a project type.',
        'Problem statement is required',
        'Select a subject.',
        'Select a difficulty level.',
        'Select a project scale.',
        'Select a visibility setting.',
        'Add at least one complete learning objective.',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
      final nameField = find.byType(TextField).first;
      final field = tester.widget<TextField>(nameField);
      expect(
        (field.decoration!.enabledBorder as OutlineInputBorder)
            .borderSide
            .color,
        const Color(0xFFFD1212),
      );
      expect(tester.getRect(nameField).top, greaterThanOrEqualTo(0));
      expect(
        tester.getRect(nameField).bottom,
        lessThan(tester.view.physicalSize.height),
      );
      final editable = find.descendant(
        of: nameField,
        matching: find.byType(EditableText),
      );
      final inputBorder = InputDecorator.containerOf(tester.element(editable))!;
      final borderBottom =
          inputBorder.localToGlobal(Offset.zero).dy + inputBorder.size.height;
      final errorTop = tester
          .getRect(find.text('Project name is required'))
          .top;
      expect(errorTop - borderBottom, inInclusiveRange(4, 8));
      final privateCard = find.widgetWithText(CreationOptionCard, 'Private');
      RoundedRectangleBorder privateShape() =>
          tester
                  .widget<Material>(
                    find
                        .descendant(
                          of: privateCard,
                          matching: find.byType(Material),
                        )
                        .first,
                  )
                  .shape!
              as RoundedRectangleBorder;
      expect(privateShape().side.color, AppColors.error);
      await tester.enterText(nameField, 'River restoration');
      await tester.pump();
      expect(find.text('Project name is required'), findsNothing);
      expect(find.text('Problem statement is required'), findsOneWidget);
      await tester.ensureVisible(find.text('Solo'));
      await tester.tap(find.text('Solo'));
      await tester.pump();
      expect(find.text('Choose a project type.'), findsNothing);
      expect(find.text('Select a subject.'), findsOneWidget);
      await tester.ensureVisible(find.text('Private'));
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      expect(find.text('Select a visibility setting.'), findsNothing);
      expect(privateShape().side.color, AppColors.primary);
      expect(
        find.text('Add at least one complete learning objective.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project type is explicit and collaborative requires another member',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateProjectScreen()));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProjectTypeSelector>(find.byType(ProjectTypeSelector))
            .value,
        isNull,
      );
      expect(find.text(' (Optional)', findRichText: true), findsOneWidget);
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Choose a project type.'), findsOneWidget);
      await tester.ensureVisible(find.text('Collaborative'));
      await tester.tap(find.text('Collaborative'));
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Choose a project type.'), findsNothing);
      expect(
        find.text('Add at least one other member for a collaborative project.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Solo'));
      await tester.tap(find.text('Solo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add at least one other member for a collaborative project.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'community rows fit content and home role moves to only one community',
    (tester) async {
      final project = Project.fromMap({
        'id': 'p',
        'project_name': 'Project',
        'project_type': 'collaborative',
        'community_links': [
          {'id': 'a', 'name': 'First Community', 'role': 'home'},
          {'id': 'b', 'name': 'Second Community', 'role': 'collaborator'},
        ],
      });
      var links = project.communityLinks;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ProjectCommunitiesSection(
                links: links,
                onAdd: () {},
                onRemove: (_) {},
                onHome: (id) => update(
                  () => links = [
                    for (final link in links)
                      {
                        ...link,
                        'role': link['id'] == id ? 'home' : 'collaborator',
                      },
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.byType(ProjectCommunitiesSection);
      await tester.ensureVisible(section);
      final menus = find.descendant(
        of: section,
        matching: find.byType(PopupMenuButton<String>),
      );
      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Home Community').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      final roles = find.descendant(
        of: section,
        matching: find.byType(DropdownButton<String>),
      );
      expect(roles, findsNWidgets(2));
      await tester.tap(roles.last);
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsNothing);
      await tester.tap(find.text('Home Community').last);
      await tester.pumpAndSettle();
      links = tester.widget<ProjectCommunitiesSection>(section).links;
      expect(links.where((link) => link['role'] == 'home').length, 1);
      expect(links.last['role'], 'home');
      expect(links.first['role'], 'collaborator');
      final panel = find
          .descendant(of: section, matching: find.byType(Material))
          .last;
      expect(tester.getSize(panel).height, lessThan(180));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('member picker is compact and confirms staged people with Add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<UserProfile>? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  confirmed = await showDialog<List<UserProfile>>(
                    context: context,
                    builder: (_) => ProjectMemberPicker(
                      existingMembers: const [],
                      loadFriends: () async => const [
                        UserProfile(id: 'friend', displayName: 'Zoe Friend'),
                      ],
                      searchPeople: (_) async => const [
                        UserProfile(id: 'other', displayName: 'Aaron Other'),
                        UserProfile(id: 'friend', displayName: 'Zoe Friend'),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(ProjectMemberPicker),
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .width,
      lessThanOrEqualTo(400),
    );
    expect(find.text('Zoe Friend'), findsOneWidget);
    expect(find.text('Aaron Other'), findsNothing);
    await tester.enterText(find.byType(TextField), 'o');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Zoe Friend')).dy,
      lessThan(tester.getTopLeft(find.text('Aaron Other')).dy),
    );
    await tester.tap(find.text('Zoe Friend'));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);
    expect(find.text('Zoe Friend'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.text('Aaron Other'), findsNothing);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(confirmed!.map((person) => person.id), ['friend']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'initial setup shows member controls only for collaborative projects',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateProjectScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Members'), findsNothing);
      expect(find.text('Communities'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Shared'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Community Members Only'), findsNothing);
      await tester.ensureVisible(find.text('Collaborative'));
      await tester.tap(find.text('Collaborative'));
      await tester.pump();
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('No members added yet.'), findsOneWidget);
      await tester.tap(find.text('Solo'));
      await tester.pump();
      expect(find.text('Members'), findsNothing);
      expect(find.text('Communities'), findsOneWidget);
    },
  );

  testWidgets(
    'settings restores type and communities and has only bottom save',
    (tester) async {
      final project = Project.fromMap({
        'id': 'project',
        'project_name': 'Test',
        'project_type': 'collaborative',
        'community_links': [
          {'id': 'eco', 'name': 'EcoSociety', 'role': 'home'},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CreateProjectScreen(
            existingProject: project,
            projectsRepo: SetupRepo(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Project Settings'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(
        tester
            .widget<ProjectTypeSelector>(find.byType(ProjectTypeSelector))
            .value,
        'collaborative',
      );
      expect(find.byType(ProjectMembersSection), findsNothing);
      expect(find.byType(ProjectCommunitiesSection), findsNothing);
    },
  );

  test(
    'project metadata preserves setup options with a compatible legacy default',
    () {
      final project = Project.fromMap({
        'id': 'p',
        'project_name': 'Solo',
        'project_type': 'solo',
        'community_links': [
          {'id': 'c', 'role': 'home', 'name': 'Community'},
        ],
      });
      expect(project.projectType, 'solo');
      expect(project.communityLinks.single['id'], 'c');
      expect(Project.fromMap({'id': 'old'}).projectType, 'collaborative');
    },
  );
}
