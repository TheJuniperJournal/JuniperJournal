import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';

class _Repo extends ProjectsRepo {
  _Repo(this.entries, {this.members = const []});
  final List<UserProfile> members;
  List<JournalEntry> entries;
  List<dynamic>? saved;
  String? deleted;
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => members;
  @override
  Future<List<ImpactEntry>?> getImpactEntries({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => entries;
  @override
  Future<bool> deleteJournalEntry({required String entryId}) async {
    deleted = entryId;
    entries = entries.where((e) => e.id != entryId).toList();
    return true;
  }

  @override
  Future<JournalEntry?> createJournalEntry({
    required String projectId,
    required String title,
    required List<dynamic> content,
    String? progress,
  }) async {
    final entry = JournalEntry(
      id: 'new-${entries.length}',
      projectId: projectId,
      title: title,
      content: content,
      progress: progress,
    );
    entries.add(entry);
    saved = content;
    return entry;
  }

  @override
  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    saved = content;
    entries = entries
        .map(
          (entry) => entry.id != entryId
              ? entry
              : JournalEntry(
                  id: entry.id,
                  projectId: entry.projectId,
                  title: title ?? entry.title,
                  content: content ?? entry.content,
                  progress: progress ?? entry.progress,
                ),
        )
        .toList();
    return true;
  }
}

class _StageRouteObserver extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}

Future<void> _open(
  WidgetTester tester,
  Widget page, {
  bool desktop = false,
  NavigatorObserver? observer,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [if (observer != null) observer],
      scrollBehavior: desktop ? const AppScrollBehavior() : null,
      theme: ThemeData(
        platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(.7)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _createBuildingComponent(
  WidgetTester tester, {
  String name = 'Lid Panel',
}) async {
  await tester.ensureVisible(find.text('+ Create New Component'));
  await tester.tap(find.text('+ Create New Component'));
  await tester.pumpAndSettle();
  final sheet = find.byType(BottomSheet);
  final fields = find.descendant(of: sheet, matching: find.byType(TextField));
  await tester.enterText(fields.at(0), name);
  await tester.enterText(fields.at(1), 'Protect the prototype');
  await tester.tap(find.text('+ Feature'));
  await tester.pumpAndSettle();
  await tester.enterText(fields.at(2), 'Durable panel');
  await tester.ensureVisible(find.text('Create').last);
  await tester.tap(find.text('Create').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'completion colors, final validation, preview and owner editing follow required content',
    (tester) async {
      const entry = JournalEntry(
        id: 'complete-test',
        projectId: 'p',
        title: 'Panel test',
        progress: 'prototyping',
        content: [
          {
            'stage': 'prototyping',
            'entryType': 'testing',
            'testingWorkflow': true,
            'title': 'Panel test',
            'question': 'Does it open?',
            'method': 'Open repeatedly',
            'expectedOutcome': 'No wear',
            'outcome': 'Validated',
            'feedback': 'Useful notes',
            'component': {
              'id': 'panel',
              'name': 'Lid Panel',
              'description': 'Keep contents inside',
              'features': ['Strong'],
            },
          },
          {
            'stage': 'learning',
            'inquiryLens': 'Design',
            'dci': ['DCI'],
            'sep': ['SEP'],
            'ccc': ['CCC'],
          },
          {
            'stage': 'nextAction',
            'learned': 'Hinge holds',
            'challenges': 'Alignment',
            'nextSteps': 'Test longer',
            'submitted': false,
          },
          {
            'stage': '_navigation',
            'visitedStages': [0, 1, 2, 3],
          },
        ],
      );
      final repo = _Repo([entry]);
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
        desktop: true,
      );
      await tester.tap(find.text('Panel test'));
      await tester.pumpAndSettle();
      Color? dot(int index) =>
          (tester
                      .widget<Container>(
                        find.byKey(ValueKey('stage-visited-$index')),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(dot(1), const Color(0xFF5DB075));
      await tester.tap(find.byKey(const ValueKey('stage-label-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.pump();
      expect(dot(1), Colors.white);
      await tester.tap(find.text('Next Action').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit').last);
      await tester.tap(find.text('Submit').last);
      await tester.pumpAndSettle();
      expect(find.text('Complete your journal'), findsOneWidget);
      expect(find.textContaining('• Test'), findsOneWidget);
      expect(find.textContaining('• Learning'), findsNothing);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      expect(
        (repo.entries.last.content.whereType<Map>().firstWhere(
          (row) => row['stage'] == 'nextAction',
        ))['submitted'],
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('stage-label-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'Does it open?');
      await tester.pump();
      expect(dot(1), const Color(0xFF5DB075));
      await tester.tap(find.text('Next Action').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit').last);
      await tester.tap(find.text('Submit').last);
      await tester.pumpAndSettle();
      expect(find.byType(PrototypingDashboardPage), findsOneWidget);
      expect(
        (repo.entries.last.content.whereType<Map>().firstWhere(
          (row) => row['stage'] == 'nextAction',
        ))['submitted'],
        isTrue,
      );
      await tester.tap(find.text('Panel test'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.runtimeType.toString() == '_CompletePrototypePreview',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Component'), findsOneWidget);
      expect(find.text('Expected Outcome'), findsOneWidget);
      expect(find.text('Hinge holds'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ItemActionMenu).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      expect(find.text('Select Component'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'evidence menu edits in the original editor and deletes from saved draft',
    (tester) async {
      const entry = JournalEntry(
        id: 'evidence',
        projectId: 'p',
        title: 'A test',
        progress: 'prototyping',
        content: [
          {
            'stage': 'prototyping',
            'entryType': 'testing',
            'testingWorkflow': true,
            'title': 'A test',
            'component': {
              'id': 'c',
              'name': 'Panel',
              'features': ['Strong'],
            },
            'evidence': [
              {
                'type': 'Link',
                'data': {
                  'id': 'link-1',
                  'title': 'Original link',
                  'url': 'https://example.com',
                  'description': 'Original description',
                },
              },
            ],
          },
        ],
      );
      final repo = _Repo([entry]);
      await _open(
        tester,
        PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: entry,
        ),
        desktop: true,
      );
      await tester.tap(find.byKey(const ValueKey('stage-label-1')));
      await tester.pumpAndSettle();
      Finder card() => find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_EvidenceSummaryCard',
      );
      Finder menu() =>
          find.descendant(of: card(), matching: find.byType(ItemActionMenu));
      await tester.ensureVisible(menu());
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      expect(find.text('Link Block'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      expect(find.text('Select Evidence Block'), findsNothing);
      expect(card(), findsOneWidget);
      await tester.ensureVisible(menu());
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Original link',
      );
      await tester.enterText(find.byType(TextField).first, 'Updated link');
      await tester.ensureVisible(find.text('Save').last);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      var data = repo.entries.last.content.whereType<Map>().firstWhere(
        (row) => row['stage'] == 'prototyping',
      );
      expect(
        ((data['evidence'] as List).single as Map)['data']['title'],
        'Updated link',
      );
      expect(
        ((data['evidence'] as List).single as Map)['data']['url'],
        'https://example.com',
      );
      await tester.ensureVisible(menu());
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(card(), findsNothing);
      expect(find.text('Add your first block'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      data = repo.entries.last.content.whereType<Map>().firstWhere(
        (row) => row['stage'] == 'prototyping',
      );
      expect(data['evidence'], isEmpty);
      await tester.ensureVisible(find.text('+ Add Evidence Block'));
      await tester.tap(find.text('+ Add Evidence Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link').last);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      expect(find.text('Select Evidence Block'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discovery title saves, updates the header and survives reopening',
    (tester) async {
      final repo = _Repo([]);
      await _open(
        tester,
        DiscoveryObservationEntryPage(projectId: 'p', projectsRepo: repo),
      );
      expect(find.text('Discovery Title', findRichText: true), findsWidgets);
      final title = find.byType(TextField).first;
      expect(tester.getSize(title).height, greaterThanOrEqualTo(64));
      await tester.enterText(title, 'Campus waste observations');
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('prototype-entry-title')))
            .data,
        'Journal Entry: Discovery',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'Students sort food scraps.',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.entries.last.title, 'Campus waste observations');
      final observation = repo.entries.last.content.whereType<Map>().firstWhere(
        (row) => row['stage'] == 'observations',
      );
      expect(observation['title'], 'Campus waste observations');
      expect(observation['observed'], 'Students sort food scraps.');
      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        DiscoveryObservationEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: repo.entries.last,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Campus waste observations',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('journal stage headings share the same position and typography', (
    tester,
  ) async {
    const entry = JournalEntry(
      id: 'layout',
      projectId: 'p',
      title: 'Build entry',
      progress: 'prototyping',
      content: [
        {
          'stage': 'prototyping',
          'entryType': 'building',
          'buildingWorkflow': true,
          'title': 'Build entry',
          'summary': 'Description',
          'component': {
            'id': 'c',
            'name': 'Panel',
            'features': ['Strong'],
          },
        },
      ],
    );
    await _open(
      tester,
      PrototypingJournalEntryPage(
        projectId: 'p',
        projectsRepo: _Repo([entry]),
        entry: entry,
      ),
      desktop: true,
    );
    final firstHeader = find.byType(JournalSectionHeader).first;
    final origin = tester.getTopLeft(firstHeader);
    for (final stage in ['Build', 'Learning', 'Next Action', 'Component']) {
      await tester.tap(find.text(stage).first);
      await tester.pumpAndSettle();
      final header = stage == 'Build'
          ? find.byKey(const ValueKey('build-stage-heading'))
          : find.byType(JournalSectionHeader).first;
      expect(tester.getTopLeft(header).dx, closeTo(origin.dx, .01));
      expect(tester.getTopLeft(header).dy, closeTo(origin.dy, .01));
      final title = find
          .descendant(of: header, matching: find.byType(Text))
          .first;
      expect(
        tester.widget<Text>(title).style!.fontFamily,
        JournalSectionHeader.titleStyle.fontFamily,
      );
      expect(
        tester.widget<Text>(title).style!.fontSize,
        JournalSectionHeader.titleStyle.fontSize,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'build defaults to its creator and evidence picker stays centered on desktop',
    (tester) async {
      const entry = JournalEntry(
        id: 'build',
        projectId: 'p',
        authorId: 'creator',
        title: 'Build',
        progress: 'prototyping',
        content: [
          {
            'stage': 'prototyping',
            'entryType': 'building',
            'buildingWorkflow': true,
            'title': 'Build',
            'summary': 'Notes',
            'component': {
              'id': 'c',
              'name': 'Panel',
              'features': ['Strong'],
            },
            'involved': [],
          },
        ],
      );
      final repo = _Repo(
        [entry],
        members: const [
          UserProfile(id: 'creator', displayName: 'Entry Creator'),
        ],
      );
      await _open(
        tester,
        PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: entry,
        ),
        desktop: true,
      );
      await tester.tap(find.byKey(const ValueKey('stage-label-1')));
      await tester.pumpAndSettle();
      expect(find.text('Objective', findRichText: true), findsOneWidget);
      expect(find.text('Build Process', findRichText: true), findsOneWidget);
      expect(find.text('Description'), findsNothing);
      expect(find.text('Add your first block'), findsOneWidget);
      final people = tester.widget<JournalInvolvedPeopleField>(
        find.byType(JournalInvolvedPeopleField),
      );
      expect(people.selectedIds, contains('creator'));
      expect(find.text('Entry Creator'), findsOneWidget);
      final evidence = find.text('+ Add Evidence Block');
      await tester.ensureVisible(evidence);
      await tester.tap(evidence);
      await tester.pumpAndSettle();
      final dialogCenter = tester.getCenter(find.byType(Dialog)).dx;
      expect(
        tester.getCenter(find.text('Select Evidence Block')).dx,
        closeTo(dialogCenter, .01),
      );
      for (final pair in [
        ['Images', 'Sketch'],
        ['Link', 'Video'],
        ['Graph', 'Table'],
      ]) {
        expect(
          (tester.getCenter(find.text(pair[0])).dx +
                  tester.getCenter(find.text(pair[1])).dx) /
              2,
          closeTo(dialogCenter, .01),
        );
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      people.onToggle('creator');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect((repo.entries.first.content.first as Map)['involved'], isEmpty);
      final reopened = repo.entries.first;
      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: reopened,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('stage-label-1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<JournalInvolvedPeopleField>(
              find.byType(JournalInvolvedPeopleField),
            )
            .selectedIds,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new component is selected separately without repeats; features are required and stop at ten',
    (tester) async {
      final repo = _Repo([
        const JournalEntry(
          id: 'old',
          projectId: 'p',
          title: 'Earlier build',
          progress: 'prototyping',
          content: [
            {
              'stage': 'prototyping',
              'entryType': 'building',
              'buildingWorkflow': true,
              'createdComponents': [
                {
                  'id': '100',
                  'name': 'Earlier Component',
                  'description': 'Earlier purpose',
                  'features': [],
                },
              ],
            },
          ],
        ),
      ]);
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
        desktop: true,
      );
      await tester.tap(find.text('+ Journal Entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prototype-type-building')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('All Project Components')).dy,
        lessThan(tester.getTopLeft(find.text('+ Create New Component')).dy),
      );
      await tester.ensureVisible(find.text('+ Create New Component'));
      await tester.tap(find.text('+ Create New Component'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      final sheetCenter = tester.getCenter(find.byType(BottomSheet)).dx;
      expect(
        tester.getCenter(find.text('Create New Component')).dx,
        closeTo(sheetCenter, .01),
      );
      expect(tester.getCenter(fields.at(0)).dx, closeTo(sheetCenter, .01));
      expect(tester.getCenter(fields.at(1)).dx, closeTo(sheetCenter, .01));
      expect(tester.getSize(fields.at(0)).height, greaterThanOrEqualTo(64));
      await tester.enterText(fields.at(0), 'Current Component');
      await tester.enterText(fields.at(1), 'Current purpose');
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(find.text('Add at least one feature.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      for (var i = 0; i < 10; i++) {
        await tester.ensureVisible(find.text('+ Feature'));
        await tester.tap(find.text('+ Feature'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(fields.at(i + 2));
        await tester.enterText(fields.at(i + 2), 'Feature $i');
        final input = tester.widget<TextField>(fields.at(i + 2));
        expect(input.textAlign, TextAlign.left);
        expect(input.decoration?.counterText, '');
        expect(input.maxLines, isNull);
        expect(input.textAlignVertical, TextAlignVertical.top);
      }
      await tester.ensureVisible(find.text('+ Feature'));
      await tester.tap(find.text('+ Feature'));
      await tester.pumpAndSettle();
      expect(fields, findsNWidgets(12));
      await tester.ensureVisible(find.text('Create').last);
      await tester.tap(find.text('Create').last);
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);

      expect(find.text('Current Component'), findsOneWidget);
      expect(find.text('Recent Components'), findsNothing);
      expect(find.text('Created Component'), findsOneWidget);
      expect(find.text('+ Create New Component'), findsNothing);
      expect(find.text('Earlier Component'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved =
          (repo.entries.last.content.first as Map)['component'] as Map;
      expect(saved['features'], hasLength(10));
      expect(saved['name'], 'Current Component');
      expect(
        find.byKey(ValueKey('component-card-all-${saved['id']}')),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('component-card-created-${saved['id']}')),
        findsOneWidget,
      );

      expect(find.text('Current purpose'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Expand Current Component'));
      await tester.tap(find.byTooltip('Expand Current Component'));
      await tester.pumpAndSettle();
      final collapse = find.byTooltip('Collapse Current Component');
      final tileMaterial = find
          .ancestor(of: collapse, matching: find.byType(Material))
          .evaluate()
          .map((element) => element.widget as Material)
          .firstWhere(
            (material) =>
                material.color != null && material.color != Colors.transparent,
          );
      expect(tileMaterial.color, Colors.white);
      await tester.ensureVisible(collapse);
      final expandedHeight = tester
          .getSize(
            find
                .ancestor(of: collapse, matching: find.byType(AnimatedSize))
                .first,
          )
          .height;
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(find.text('Current purpose'), findsNothing);
      expect(find.text('Selected'), findsOneWidget);
      final expand = find.byTooltip('Expand Current Component').first;
      final compactHeight = tester
          .getSize(
            find
                .ancestor(of: expand, matching: find.byType(AnimatedSize))
                .first,
          )
          .height;
      expect(compactHeight, lessThan(expandedHeight));
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.text('Current purpose'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _open(
        tester,
        PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: repo,
          entry: repo.entries.last,
        ),
      );
      expect(find.byTooltip('Expand Current Component'), findsOneWidget);
      expect(find.byTooltip('Collapse Current Component'), findsNothing);
      expect(find.text('Current purpose'), findsNothing);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Recent Components'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Expand Current Component'));
      await tester.tap(find.byTooltip('Expand Current Component'));
      await tester.pumpAndSettle();
      final actions = find.descendant(
        of: find.byKey(ValueKey('component-card-created-${saved['id']}')),
        matching: find.byType(ItemActionMenu),
      );
      await tester.ensureVisible(actions);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('+ Create New Component'), findsOneWidget);
      expect(find.text('Current Component'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'component library search filters the single project list and selection can be edited or removed',
    (tester) async {
      final repo = _Repo([
        const JournalEntry(
          id: 'library',
          projectId: 'p',
          title: 'Prior build',
          progress: 'prototyping',
          content: [
            {
              'stage': 'prototyping',
              'entryType': 'building',
              'buildingWorkflow': true,
              'createdComponents': [
                {
                  'id': 'lid',
                  'name': 'Lid Panel',
                  'description': 'Protect the prototype',
                  'features': ['Opens smoothly'],
                },
                {
                  'id': 'hinge',
                  'name': 'Hinge Assembly',
                  'description': 'Connect panels',
                  'features': [],
                },
                {
                  'id': 'cover',
                  'name': 'Cover',
                  'description': 'Keep rain out',
                  'features': [],
                },
              ],
            },
          ],
        ),
      ]);
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
      );
      await tester.tap(find.text('+ Journal Entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prototype-type-building')));
      await tester.pumpAndSettle();
      expect(find.text('Use Last Component'), findsNothing);
      expect(find.text('Lid Panel'), findsOneWidget);
      final search = find.byKey(const ValueKey('project-component-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'rain');
      await tester.pumpAndSettle();
      expect(find.text('Lid Panel'), findsNothing);
      expect(find.text('Hinge Assembly'), findsNothing);
      expect(find.text('Cover'), findsOneWidget);
      await tester.tap(find.text('Cover'));
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Keep rain out'), findsNothing);
      expect(find.byTooltip('Expand Cover'), findsOneWidget);
      await tester.tap(find.byTooltip('Expand Cover'));
      await tester.pumpAndSettle();
      expect(find.text('Keep rain out'), findsOneWidget);
      await tester.tap(find.text('Cover'));
      await tester.pumpAndSettle();
      expect(find.text('Keep rain out'), findsOneWidget);
      expect(find.text('Selected'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect((repo.entries.last.content.first as Map)['component'], isNull);
      await tester.tap(find.text('Next').last);
      await tester.pumpAndSettle();
      expect(find.text('Select or create a component.'), findsOneWidget);
      await tester.ensureVisible(find.text('Cover'));
      await tester.tap(find.text('Cover'));
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Select or create a component.'), findsNothing);
      expect(find.text('Keep rain out'), findsOneWidget);

      await tester.ensureVisible(find.byType(ItemActionMenu).last);
      await tester.tap(find.byType(ItemActionMenu).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit').last);
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Weather Cover');
      await tester.tap(find.text('+ Feature'));
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(2), 'Water resistant');
      await tester.ensureVisible(find.text('Save').last);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Water resistant'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final savedComponent =
          (repo.entries.last.content.first as Map)['component'] as Map;
      expect(savedComponent['name'], 'Weather Cover');
      expect(savedComponent['features'], ['Water resistant']);
      await tester.tap(find.byType(ItemActionMenu).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('+ Create New Component'), findsOneWidget);
      expect(
        repo.entries.first.content.first['createdComponents'],
        hasLength(3),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop type picker centers its header and aligns option text consistently',
    (tester) async {
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: _Repo([]),
        ),
        desktop: true,
      );
      await tester.tap(find.text('+ Journal Entry'));
      await tester.pumpAndSettle();
      final title = find.text('New Prototyping Entry');
      final surface = tester
          .element(title)
          .findAncestorWidgetOfExactType<Material>()!;
      final center = tester.getCenter(find.byWidget(surface)).dx;
      expect(tester.getCenter(title).dx, closeTo(center, .01));
      expect(find.text('What are you working on today?'), findsNothing);
      for (final label in ['Building', 'Testing', 'Technical Analysis']) {
        expect(tester.widget<Text>(find.text(label)).textAlign, TextAlign.left);
        expect(tester.getCenter(find.text(label)).dx, closeTo(center, .01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new prototyping journals remain independent of each other', (
    tester,
  ) async {
    final repo = _Repo([]);
    await _open(
      tester,
      PrototypingDashboardPage(
        projectId: 'p',
        isOwner: true,
        projectsRepo: repo,
      ),
    );
    for (final type in ['building', 'testing']) {
      await tester.tap(find.text('+ Journal Entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('prototype-type-$type')));
      await tester.pumpAndSettle();
      if (type != 'technical_analysis') await _createBuildingComponent(tester);
      await tester.enterText(find.byType(TextField).first, '$type record');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop(true);
      await tester.pumpAndSettle();
    }
    expect(repo.entries, hasLength(2));
    expect(repo.entries.map((entry) => entry.id).toSet(), hasLength(2));
    expect(find.text('building record'), findsOneWidget);
    expect(find.text('testing record'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typed journal preview keeps non-editable content read only', (
    tester,
  ) async {
    final entry = const JournalEntry(
      id: 'e',
      projectId: 'p',
      title: 'Analysis',
      progress: 'prototyping',
      content: [
        {
          'stage': 'prototyping',
          'entryType': 'technical_analysis',
          'title': 'Analysis',
          'question': 'A technical question',
          'method': 'Data',
          'results': 'Results',
          'interpretation': 'Meaning',
        },
        {
          'stage': 'learning',
          'inquiryLens': 'Design',
          'dci': [],
          'sep': [],
          'ccc': [],
        },
      ],
    );
    await _open(
      tester,
      PrototypingJournalEntryPage(
        projectId: 'p',
        projectsRepo: _Repo([entry]),
        entry: entry,
        readOnly: true,
      ),
    );
    expect(find.text('A technical question'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Learning').first);
    await tester.pumpAndSettle();
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Assessment'), findsNothing);
    expect(find.text('No assessment type selected.'), findsNothing);
    expect(find.text('DCI'), findsNothing);
    expect(find.text('SEP'), findsNothing);
    expect(find.text('CCC'), findsNothing);
    expect(find.text('Not provided.'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'prototyping uses journal cards and a cancellable three-type picker',
    (tester) async {
      final repo = _Repo([]);
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
      );
      expect(find.text('Add your first entry'), findsOneWidget);
      expect(find.text('+ Iteration'), findsNothing);
      await tester.tap(find.text('+ Journal Entry'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('New Prototyping Entry'), findsOneWidget);
      for (final label in ['Building', 'Testing', 'Technical Analysis']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Close entry type picker'));
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in ['building', 'testing', 'technical_analysis']) {
    testWidgets(
      '$type creates its own journal, saves fields, reopens and navigates stages',
      (tester) async {
        final repo = _Repo([]);
        final observer = _StageRouteObserver();
        await _open(
          tester,
          PrototypingDashboardPage(
            projectId: 'p',
            isOwner: true,
            projectsRepo: repo,
          ),
          observer: observer,
        );
        await tester.tap(find.text('+ Journal Entry'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('prototype-type-$type')));
        await tester.pumpAndSettle();
        if (type != 'technical_analysis')
          await _createBuildingComponent(tester);
        final title = 'New $type prototype';
        final fields = find.byType(TextField);
        for (var index = 0; index < fields.evaluate().length; index++) {
          await tester.enterText(
            fields.at(index),
            index == 0 ? title : 'Work details $index',
          );
        }
        if (type == 'testing') {
          final options = find.byWidgetPredicate(
            (widget) =>
                widget.runtimeType.toString() == '_PrototypeOutcomeOption',
          );
          expect(options, findsNWidgets(5));
          final optionSize = tester.getSize(options.first);
          for (var i = 1; i < 5; i++) {
            expect(tester.getSize(options.at(i)), optionSize);
            expect(
              tester.getTopLeft(options.at(i)).dy,
              greaterThan(tester.getBottomLeft(options.at(i - 1)).dy),
            );
          }
          expect(find.byIcon(Icons.link_off_outlined), findsOneWidget);
          expect(
            find.byIcon(Icons.local_fire_department_outlined),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
          expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
          expect(find.textContaining(RegExp(r'^\d+/\d+$')), findsNothing);
          expect(find.text('Objective', findRichText: true), findsOneWidget);
          expect(find.text('Method', findRichText: true), findsOneWidget);
          expect(
            find.text('Expected Outcome', findRichText: true),
            findsOneWidget,
          );
          await tester.ensureVisible(find.text('Validated'));
          await tester.tap(find.text('Validated'));
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(repo.entries, hasLength(1));
        final data = repo.saved!.whereType<Map>().firstWhere(
          (row) => row['stage'] == 'prototyping',
        );
        expect(data['entryType'], type);
        expect(data['title'], title);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('prototype-entry-title')))
              .data,
          'Journal Entry: Prototyping',
        );
        if (type == 'testing') {
          expect(data['outcome'], 'Validated');
          expect(data['component'], isA<Map>());
          expect(data['testingWorkflow'], true);
        }
        expect(data.containsKey('iterations'), isFalse);
        final routeCount = observer.pushes;
        await tester.tap(find.text('Learning').first);
        await tester.pumpAndSettle();
        expect(find.text('Inquiry Lens'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('prototype-entry-title')))
              .data,
          'Journal Entry: Prototyping',
        );
        expect(observer.pushes, routeCount);
        await tester.tap(find.text('Next Action').first);
        await tester.pumpAndSettle();
        expect(observer.pushes, routeCount);
        final firstLabel = type == 'building'
            ? 'Build'
            : type == 'testing'
            ? 'Test'
            : 'Technical Analysis';
        await tester.tap(find.text(firstLabel).first);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          title,
        );
        expect(observer.pushes, routeCount);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop(true);
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        if (type != 'technical_analysis') {
          await tester.tap(
            find.text(type == 'testing' ? 'Test' : 'Build').first,
          );
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          title,
        );
        expect(repo.entries, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final phase in [
    'discover',
    'ideating',
    'prototyping',
    'implementation',
  ]) {
    testWidgets('$phase journal menu deletes and reloads the list', (
      tester,
    ) async {
      final repo = _Repo([
        JournalEntry(
          id: 'entry',
          projectId: 'p',
          title: 'My journal',
          progress: phase,
          content: const [],
        ),
      ]);
      final page = switch (phase) {
        'discover' => DiscoveryDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
        'prototyping' => PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
        'ideating' => IdeatingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
        _ => ImplementationDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
      };
      await _open(tester, page);
      await tester.ensureVisible(find.byType(ItemActionMenu));
      await tester.tap(find.byType(ItemActionMenu));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repo.deleted, 'entry');
      expect(find.text('My journal'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final kind in ['Build', 'Test']) {
    testWidgets('$kind log menu deletes and persists the change', (
      tester,
    ) async {
      final repo = _Repo([
        JournalEntry(
          id: 'prototype',
          projectId: 'p',
          title: 'Prototype',
          progress: 'prototyping',
          content: [
            {
              'stage': 'prototyping',
              'iterations': [
                {
                  'id': 'iteration',
                  'title': 'Iteration alpha',
                  'components': [
                    {
                      'id': 'component',
                      'name': 'Component alpha',
                      'status': 'In Progress',
                      'buildLogs': [
                        {'id': 'build', 'title': 'Build alpha'},
                      ],
                      'testEntries': [
                        {'id': 'test', 'title': 'Test alpha'},
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        ),
      ]);
      await _open(
        tester,
        PrototypingDashboardPage(
          projectId: 'p',
          isOwner: true,
          projectsRepo: repo,
        ),
      );
      for (final label in ['Prototype', 'Component alpha', kind]) {
        await tester.ensureVisible(find.text(label).first);
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byType(ItemActionMenu).last);
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Action').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Learning').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(kind).first);
      await tester.pumpAndSettle();
      for (var index = 0; index < 3; index++) {
        final dot = tester.widget<Container>(
          find.byKey(ValueKey('stage-visited-$index')),
        );
        expect((dot.decoration as BoxDecoration).color, Colors.white);
      }
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ItemActionMenu).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('$kind alpha'), findsNothing);
      final component =
          (repo.saved!.first as Map)['iterations'][0]['components'][0];
      expect(component[kind == 'Build' ? 'buildLogs' : 'testEntries'], isEmpty);
      expect(
        component[kind == 'Build' ? 'testEntries' : 'buildLogs'],
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
