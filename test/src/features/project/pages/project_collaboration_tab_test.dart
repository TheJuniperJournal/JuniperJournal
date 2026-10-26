import 'package:juniper_journal/src/features/site/pages/site_information_page.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/models/bulletin_post.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/project_bulletin_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_collaboration_tab.dart';

class _Projects extends ProjectsRepo {
  @override
  Future<bool> canViewInternalProjectLogs(String id) async => true;
  _Projects({this.solo = false, this.manage = true});
  final bool solo, manage;
  @override
  Future<Project?> getProjectById(String id) async => Project(
    id: id,
    projectName: 'Project',
    tags: [],
    projectType: solo ? 'solo' : 'collaborative',
    communityLinks: const [
      {'id': 'c', 'name': 'Garden Club', 'role': 'home'},
    ],
  );
  @override
  Future<List<UserProfile>?> getProjectInvitees({
    required String projectId,
  }) async => [
    const UserProfile(id: 'me', displayName: 'Amelia', username: 'amelia_y'),
  ];
  @override
  Future<Map<String, String>> getProjectMemberRoles(String id) async => {
    'me': 'project_member',
  };
  @override
  Future<bool> canManageProject(String id) async => manage;
}

class _Bulletin extends ProjectBulletinRepo {
  _Bulletin({this.images = const []});
  final List<String> images;
  String? savedCategory;
  String? savedId, savedTitle;
  @override
  String? get currentUserId => 'me';
  @override
  Future<List<BulletinPost>> posts(String id) async => [
    BulletinPost(
      id: '1',
      communityId: '',
      userId: 'me',
      title: 'My design',
      imageUrls: images,
      body: 'Feedback requested',
      category: 'Design Feedback',
      createdAt: DateTime(2026, 10, 15),
    ),
    BulletinPost(
      id: '2',
      communityId: '',
      userId: 'me',
      title: 'My question',
      body: 'Help requested',
      category: 'Question / Help',
      createdAt: DateTime(2026, 10, 15),
    ),
  ];
  @override
  Future<List<Map<String, dynamic>>> reactions(List<String> ids) async => [];
  @override
  Future<void> save({
    required String projectId,
    String? id,
    required String title,
    required String body,
    required String category,
    required List<String> images,
  }) async {
    savedCategory = category;
    savedId = id;
    savedTitle = title;
  }
}

class _ManyPosts extends _Bulletin {
  @override
  Future<List<BulletinPost>> posts(String id) async => List.generate(
    20,
    (i) => BulletinPost(
      id: '$i',
      communityId: '',
      userId: 'me',
      title: 'Post $i',
      body: 'A discussion',
      category: 'Design Feedback',
      createdAt: DateTime(2026, 10, 15),
    ),
  );
}

class _EmptyPosts extends _Bulletin {
  @override
  Future<List<BulletinPost>> posts(String id) async => [];
}

class _PendingProjects extends _Projects {
  @override
  Future<Map<String, String>> getProjectMemberStatuses(String id) async => {
    'me': 'pending',
  };
  @override
  Future<List<Map<String, dynamic>>> getCommunityProjectInvitations({
    String? communityId,
    String? projectId,
  }) async => [
    {
      'id': 'invite',
      'community_id': 'pending-community',
      'community_name': 'Pending Club',
      'status': 'pending',
    },
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  bool solo = false,
  bool desktop = false,
  bool withFooter = false,
  bool manage = true,
  _Bulletin? bulletin,
  ProjectsRepo? projects,
  Future<String?> Function()? pickImage,
}) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: desktop ? const AppScrollBehavior() : null,
      theme: ThemeData(
        platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
      builder: withFooter ? (_, child) => SiteFooterScope(child: child!) : null,
      home: Scaffold(
        body: ProjectCollaborationTab(
          projectId: 'p',
          projectsRepo: projects ?? _Projects(solo: solo, manage: manage),
          bulletinRepo: bulletin ?? _Bulletin(),
          pickImage: pickImage,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('create-forum-post')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'create post stays above the feed and never overlays the footer',
    (tester) async {
      await _pump(tester, bulletin: _EmptyPosts(), withFooter: true);
      final button = find.byKey(const ValueKey('create-forum-post'));
      final filters = find.byKey(const ValueKey('forum-category-filters'));
      final footer = find.byKey(const ValueKey('page-end-footer'));
      final heading = find.byKey(const ValueKey('forum-heading'));
      expect(
        tester.getCenter(heading).dy,
        closeTo(tester.getCenter(button).dy, 1),
      );
      expect(tester.getRect(button).width, lessThan(200));
      expect(
        tester.getRect(button).left - tester.getRect(heading).right,
        closeTo(12, 1),
      );
      expect(tester.getRect(button).height, lessThanOrEqualTo(32));
      expect(button.hitTestable(), findsOneWidget);
      expect(footer, findsOneWidget);
      expect(
        tester.getRect(button).bottom,
        lessThan(tester.getRect(filters).top),
      );
      expect(tester.getRect(button).overlaps(tester.getRect(footer)), isFalse);
      expect(
        find.ancestor(of: button, matching: find.byType(Positioned)),
        findsNothing,
      );
      await _openCreate(tester);
      expect(
        find.byKey(const ValueKey('project-forum-editor')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('project filters use tags without checkboxes', (tester) async {
    await _pump(tester);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Design Feedback'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Design Feedback'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, 'Design Feedback'),
          )
          .selected,
      isTrue,
    );
  });
  testWidgets(
    'pending member and community invitations occupy their role rows',
    (tester) async {
      await _pump(tester, projects: _PendingProjects());
      await tester.tap(find.text('Communities').first);
      await tester.pumpAndSettle();
      final directory = find.byType(ProjectCommunitiesSection);
      expect(
        find.descendant(of: directory, matching: find.text('Pending Club')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: directory, matching: find.text('Pending')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: directory,
          matching: find.byIcon(Icons.groups_outlined),
        ),
        findsWidgets,
      );
      expect(
        find.textContaining('awaiting community administrator'),
        findsNothing,
      );
      expect(find.text('No communities added yet.'), findsNothing);
      await tester.tap(find.text('Members').first);
      await tester.pumpAndSettle();
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byType(ProjectRoleDropdown), findsNothing);
      expect(find.text('Invitation pending'), findsNothing);
    },
  );

  testWidgets(
    'directory search filters members and communities independently and clears',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Members').first);
      await tester.pumpAndSettle();
      final members = find.widgetWithText(
        TextField,
        'Search members by name or username',
      );
      expect(members, findsOneWidget);
      await tester.enterText(members, '@AMELIA_y');
      await tester.pumpAndSettle();
      expect(find.text('Amelia'), findsOneWidget);
      await tester.enterText(members, 'nobody');
      await tester.pumpAndSettle();
      expect(find.text('Amelia'), findsNothing);
      expect(find.text('No matching members.'), findsOneWidget);
      expect(find.text('Add People'), findsOneWidget);
      await tester.tap(find.text('Communities').first);
      await tester.pumpAndSettle();
      final communities = find.widgetWithText(TextField, 'Search communities');
      expect(communities, findsOneWidget);
      expect(find.text('Garden Club'), findsOneWidget);
      await tester.enterText(communities, 'GARDEN');
      await tester.pumpAndSettle();
      expect(find.text('Garden Club'), findsOneWidget);
      await tester.enterText(communities, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching communities.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Garden Club'), findsOneWidget);
      await tester.tap(find.text('Members').first);
      await tester.pumpAndSettle();
      expect(find.text('No matching members.'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Amelia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'post menu is centered without a gutter and edit dropdown matches field width',
    (tester) async {
      await _pump(tester, desktop: true);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      for (final label in ['Edit Post', 'Delete Post']) {
        final text = find.text(label);
        final surface = tester
            .element(text)
            .findAncestorWidgetOfExactType<Material>()!;
        final rect = tester.getRect(find.byWidget(surface));
        expect(rect.width, 160);
        expect(tester.getCenter(text).dx, closeTo(rect.center.dx, .01));
      }
      await tester.tap(find.text('Edit Post'));
      await tester.pumpAndSettle();
      final menu = find.byType(ProjectChipMenu);
      final fieldWidth = tester.getSize(menu).width;
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(PopupMenuItem<String>).first).width,
        closeTo(fieldWidth, .01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty post highlights message in red without a bottom notification',
    (tester) async {
      await _pump(tester, bulletin: _EmptyPosts());
      await _openCreate(tester);
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('forum-post-body'));
      expect(
        tester
            .widget<TextField>(field)
            .decoration!
            .enabledBorder!
            .borderSide
            .color,
        Colors.red,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.enterText(field, 'A message');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field)
            .decoration!
            .enabledBorder!
            .borderSide
            .color,
        const Color(0xFFD0D0D0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'photo pair is centered with space above actions and limit feedback',
    (tester) async {
      var picks = 0;
      await _pump(
        tester,
        bulletin: _Bulletin(
          images: [
            'https://example.com/one.png',
            'https://example.com/two.png',
          ],
        ),
        pickImage: () async {
          picks++;
          return 'https://example.com/three.png';
        },
      );
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Post'));
      await tester.pumpAndSettle();
      final editor = find.byKey(const ValueKey('inline-post-editor-1'));
      final first = tester.getRect(
        find.byKey(const ValueKey('inline-photo-https://example.com/one.png')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('inline-photo-https://example.com/two.png')),
      );
      expect(
        (first.center.dx + second.center.dx) / 2,
        closeTo(tester.getCenter(editor).dx, .5),
      );
      final fields = find.descendant(
        of: editor,
        matching: find.byType(TextField),
      );
      final bodyBounds = tester.getRect(fields.at(1));
      expect(first.left, closeTo(bodyBounds.left, .5));
      expect(second.right, closeTo(bodyBounds.right, .5));
      expect(first.width, closeTo(second.width, .5));
      final cancel = find.descendant(
        of: editor,
        matching: find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(
        tester.getTopLeft(cancel).dy - first.bottom,
        greaterThanOrEqualTo(24),
      );
      final add = find.byTooltip('Add image to post');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.text('Maximum of two photos per post. Remove one to add another.'),
        findsOneWidget,
      );
      expect(picks, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new-post editor explains the photo limit instead of disabling add',
    (tester) async {
      var picks = 0;
      await _pump(
        tester,
        bulletin: _EmptyPosts(),
        pickImage: () async => 'https://example.com/${++picks}.png',
      );
      await _openCreate(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Add photo (up to 2)'));
        await tester.pumpAndSettle();
      }
      expect(picks, 2);
      expect(
        find.text('Maximum of two photos per post. Remove one to add another.'),
        findsOneWidget,
      );
      final first = tester.getRect(
        find.byKey(
          const ValueKey('forum-image-preview-https://example.com/1.png'),
        ),
      );
      final second = tester.getRect(
        find.byKey(
          const ValueKey('forum-image-preview-https://example.com/2.png'),
        ),
      );
      final body = tester.getRect(
        find.byKey(const ValueKey('forum-post-body')),
      );
      expect(
        (first.center.dx + second.center.dx) / 2,
        closeTo(body.center.dx, .5),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inline edits stay separate from the new-post popup draft', (
    tester,
  ) async {
    final repo = _Bulletin();
    await _pump(tester, bulletin: repo);
    await _openCreate(tester);
    final composer = find.byKey(const ValueKey('project-forum-editor'));
    var fields = find.descendant(
      of: composer,
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(1), 'Keep this message');
    await tester.tap(find.byTooltip('Close new post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Post'));
    await tester.pumpAndSettle();
    final inline = find.byKey(const ValueKey('inline-post-editor-1'));
    expect(inline, findsOneWidget);
    expect(composer, findsNothing);
    final editFields = find.descendant(
      of: inline,
      matching: find.byType(TextField),
    );
    await tester.enterText(editFields.first, 'Edited design');
    final save = find.descendant(
      of: inline,
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.savedId, '1');
    expect(repo.savedTitle, 'Edited design');
    await _openCreate(tester);
    fields = find.descendant(of: composer, matching: find.byType(TextField));
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, '');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'editor uses a light title border, normal dropdown text and expandable image previews',
    (tester) async {
      await _pump(
        tester,
        desktop: true,
        bulletin: _EmptyPosts(),
        pickImage: () async => 'https://example.com/attachment.png',
      );
      await _openCreate(tester);
      final titleRect = tester.getRect(
        find.byKey(const ValueKey('forum-post-title')),
      );
      final bodyRect = tester.getRect(
        find.byKey(const ValueKey('forum-post-body')),
      );
      final editorRect = tester.getRect(
        find.byKey(const ValueKey('project-forum-editor')),
      );
      final dialogRect = tester.getRect(find.byType(Dialog));
      expect(editorRect.center.dx, closeTo(dialogRect.center.dx, .5));
      expect(titleRect.left, closeTo(editorRect.left, .5));
      expect(titleRect.right, closeTo(editorRect.right, .5));
      expect(bodyRect.width, closeTo(titleRect.width, .5));
      expect(bodyRect.top - titleRect.bottom, lessThan(50));
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Post body'), findsOneWidget);
      final title = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere(
            (f) => f.decoration?.hintText == 'Give your post a title',
          );
      for (final border in [
        title.decoration!.enabledBorder,
        title.decoration!.focusedBorder,
      ]) {
        expect(border!.borderSide.color, const Color(0xFFD0D0D0));
        expect(border.borderSide.width, 1);
      }
      expect(
        tester.widget<ProjectChipMenu>(find.byType(ProjectChipMenu)).fontWeight,
        FontWeight.w400,
      );
      await tester.tap(find.byTooltip('Add photo (up to 2)'));
      await tester.pumpAndSettle();
      final thumbnail = find.byKey(
        const ValueKey(
          'forum-image-preview-https://example.com/attachment.png',
        ),
      );
      expect(thumbnail, findsOneWidget);
      expect(tester.getSize(thumbnail).width, greaterThan(100));
      expect(tester.getSize(thumbnail).width, tester.getSize(thumbnail).height);
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('expanded-forum-image')),
        findsOneWidget,
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Close image'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove attached image'));
      await tester.pumpAndSettle();
      expect(thumbnail, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subtabs are centered and empty message is centered above a raised editor',
    (tester) async {
      await _pump(tester, bulletin: _EmptyPosts());
      expect(
        tester
            .getCenter(find.byKey(const ValueKey('collaboration-subtabs')))
            .dx,
        closeTo(250, .5),
      );
      final feed = tester.getRect(
        find.byKey(const ValueKey('forum-empty-space')),
      );
      final message = tester.getRect(
        find.text('No discussions yet. Start one with “New post”.'),
      );
      expect(message.center.dx, closeTo(feed.center.dx, .5));
      expect(message.center.dy, closeTo(feed.center.dy, .5));
      expect(find.byKey(const ValueKey('project-forum-editor')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category filters scroll horizontally to the last post type', (
    tester,
  ) async {
    await _pump(tester);
    final filters = find.byKey(const ValueKey('forum-category-filters'));
    await tester.drag(filters, const Offset(-1200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Project Update'));
    await tester.pumpAndSettle();
    expect(find.text('No posts match your filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the full bulletin page scrolls as posts grow and create button remains accessible',
    (tester) async {
      await _pump(tester, bulletin: _ManyPosts());
      final feed = find.byKey(const ValueKey('project-forum-feed'));
      final button = find.byKey(const ValueKey('create-forum-post'));
      final before = tester.getRect(button);
      expect(tester.getSize(feed).height, greaterThan(600));
      await tester.drag(feed, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CustomScrollView>(feed).controller!.offset,
        greaterThan(0),
      );
      expect(tester.getRect(button), before);
      expect(find.byKey(const ValueKey('project-forum-editor')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('empty feed offers top action to open new-post editor', (
    tester,
  ) async {
    await _pump(tester, bulletin: _EmptyPosts());
    expect(
      find.text('No discussions yet. Start one with “New post”.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('project-forum-editor')), findsNothing);
    await _openCreate(tester);
    expect(find.text('Create Forum Post'), findsOneWidget);
    expect(find.byKey(const ValueKey('project-forum-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bulletin filters categories and renders blue post tags', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('My design'), findsOneWidget);
    final tag = tester.widget<Container>(
      find.byKey(const ValueKey('post-category-1')),
    );
    expect((tag.decoration as BoxDecoration).color, const Color(0xFF438BC0));
    await tester.tap(find.widgetWithText(FilterChip, 'Design Feedback'));
    await tester.pumpAndSettle();
    expect(find.text('My design'), findsOneWidget);
    expect(find.text('My question'), findsNothing);
    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('project-forum-feed')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(find.text('My question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('solo members are empty and communities remain visible', (
    tester,
  ) async {
    await _pump(tester, solo: true);
    await tester.tap(find.text('Members').first);
    await tester.pumpAndSettle();
    expect(find.text('No members added yet.'), findsOneWidget);
    expect(find.text('Add People'), findsOneWidget);
    await tester.tap(find.text('Communities').first);
    await tester.pumpAndSettle();
    expect(find.text('Garden Club'), findsOneWidget);
    expect(find.text('Home Community'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'post editor provides all six categories and saves the chosen tag',
    (tester) async {
      final bulletin = _Bulletin();
      await _pump(tester, bulletin: bulletin);
      await _openCreate(tester);
      final editor = find.byKey(const ValueKey('project-forum-editor'));
      await tester.ensureVisible(editor);
      await tester.tap(find.byType(ProjectChipMenu));
      await tester.pumpAndSettle();
      for (final category in projectPostCategories) {
        expect(find.text(category), findsWidgets);
      }
      await tester.tap(find.text('Calculations').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('forum-post-title')),
        'Calculation result',
      );
      await tester.enterText(
        find.byKey(const ValueKey('forum-post-body')),
        'The result is 42',
      );
      await tester.tap(find.text('Post', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(bulletin.savedCategory, 'Calculations');
      expect(bulletin.savedTitle, 'Calculation result');
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('non-admin members cannot change roles or add people', (
    tester,
  ) async {
    await _pump(tester, manage: false);
    await tester.tap(find.text('Members').first);
    await tester.pumpAndSettle();
    expect(find.text('Add People'), findsNothing);
    expect(
      tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
