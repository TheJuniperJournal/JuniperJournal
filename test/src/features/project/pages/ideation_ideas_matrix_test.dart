import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/app_scroll_behavior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class _Repo extends ProjectsRepo {
  @override
  String? get currentUserId => 'qa-owner';
  @override
  Future<Project?> getProjectById(String id) async =>
      Project(id: id, projectName: 'QA', tags: const [], userId: 'qa-owner');
  @override
  Future<bool> canViewInternalProjectLogs(String projectId) async => true;

  List<dynamic>? saved;
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<bool> updateJournalEntry({
    required String entryId,
    String? title,
    List<dynamic>? content,
    String? progress,
  }) async {
    saved = content;
    return true;
  }
}

Future<void> _openIdeas(
  WidgetTester tester,
  _Repo repo, {
  List<Map<String, dynamic>> ideas = const [],
  double textScale = .7,
  bool desktop = false,
  List<int>? visitedStages,
}) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: desktop ? const AppScrollBehavior() : null,
      theme: ThemeData(
        platform: desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: IdeatingEntryPage(
        projectId: 'p',
        projectsRepo: repo,
        entry: JournalEntry(
          id: 'e',
          projectId: 'p',
          title: 'Session',
          progress: 'ideating',
          content: [
            if (visitedStages != null)
              {'stage': '_navigation', 'visitedStages': visitedStages},
            {
              'stage': 'challenge',
              'title': 'Challenge',
              'problem': 'Problem',
              'objectives': [
                {'id': 'objective', 'text': 'Reduce waste'},
              ],
            },
            {
              'stage': 'ideas',
              'items': [
                for (final idea in ideas)
                  {
                    'description': 'Description',
                    'rationale': 'Reduces waste',
                    ...idea,
                  },
              ],
            },
            {
              'stage': 'decisionMatrix',
              'criteria': [
                {'id': 'c1', 'criterion': '', 'weight': ''},
              ],
            },
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Next'));
  await tester.ensureVisible(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('stage underlines match the width of short and wrapped labels', (
    tester,
  ) async {
    await _openIdeas(tester, _Repo(), textScale: 1);
    for (var index = 0; index < 5; index++) {
      final label = tester.getRect(find.byKey(ValueKey('stage-label-$index')));
      final underline = tester.getRect(
        find.byKey(ValueKey('stage-current-$index')),
      );
      expect(underline.width, closeTo(label.width, .01));
      expect(underline.center.dx, closeTo(label.center.dx, .01));
      expect(underline.top - label.bottom, closeTo(4, .01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unscored ideas show NA in cards and matrix', (tester) async {
    await _openIdeas(
      tester,
      _Repo(),
      ideas: [
        {'id': 'i1', 'title': 'First idea'},
      ],
    );
    expect(find.text('Idea Score: NA'), findsOneWidget);
    await tester.tap(find.text('Decision Matrix').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('matrix-score-i1'))).data,
      'NA',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visiting incomplete sections never marks them complete, including after reopening',
    (tester) async {
      final repo = _Repo();
      await _openIdeas(tester, repo);
      await tester.tap(find.text('Learning').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Challenge').first);
      await tester.pumpAndSettle();
      Color? dot(int index) =>
          (tester
                      .widget<Container>(
                        find.byKey(ValueKey('stage-visited-$index')),
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(dot(0), AppColors.primary);
      expect(dot(1), Colors.white);
      expect(dot(3), Colors.white);
      final navigation = repo.saved!.whereType<Map>().firstWhere(
        (row) => row['stage'] == '_navigation',
      );
      expect(navigation['visitedStages'], [0, 1]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await _openIdeas(
        tester,
        _Repo(),
        visitedStages: List<int>.from(navigation['visitedStages']),
      );
      expect(dot(1), Colors.white);
      expect(dot(3), Colors.white);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop Saved aligns with the first-stage Next button', (
    tester,
  ) async {
    await _openIdeas(tester, _Repo(), desktop: true);
    await tester.tap(find.text('Challenge').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Changed challenge');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.text('Saved')).dx,
      closeTo(tester.getCenter(find.text('Next')).dx, 8.01),
    );
    final headerCenter = tester
        .getCenter(find.text('Journal Entry: Ideation'))
        .dx;
    for (final label in ['+ Add Objective', '+ Add File', 'Next']) {
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo(headerCenter, 8.01),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('matrix fits four ideas, caps criteria at five, and clears all', (
    tester,
  ) async {
    final repo = _Repo();
    await _openIdeas(
      tester,
      repo,
      ideas: [
        for (var i = 1; i <= 4; i++) {'id': 'i$i', 'title': 'Idea $i'},
      ],
    );
    await tester.tap(find.text('Decision Matrix').first);
    await tester.pumpAndSettle();
    final table = tester.getSize(
      find.byKey(const ValueKey('decision-matrix-table')),
    );
    expect(table.width, greaterThan(364));
    expect(find.text('Scroll sideways to compare all ideas.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Clear All'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text('Total weight: 0% · Must total 100%'))
          .style!
          .color,
      AppColors.textSecondary,
    );
    for (var i = 1; i < 5; i++) {
      await tester.ensureVisible(find.text('+ Add Criterion'));
      await tester.tap(find.text('+ Add Criterion'));
      await tester.pumpAndSettle();
    }
    expect(find.text('5 criteria maximum'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear All'));
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();
    expect(find.text('Criterion name'), findsOneWidget);
    expect(find.text('+ Add Criterion'), findsOneWidget);
    await tester.tap(find.text('Learning').first);
    await tester.pumpAndSettle();
    expect(find.text('Inquiry Lens'), findsNothing);
    expect(
      find.text(
        'Add criteria, set weights to 100%, and rate every idea from 1 to 5.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ideas').first);
    await tester.pumpAndSettle();
    expect(find.text('Idea 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('idea popup title and fields share a center and Save is inset', (
    tester,
  ) async {
    await _openIdeas(tester, _Repo(), desktop: true);
    await tester.tap(find.text('+ Add Idea'));
    await tester.pumpAndSettle();
    final title = find.text('Add Idea');
    final field = find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
        .first;
    expect(
      tester.getCenter(title).dx,
      closeTo(tester.getCenter(field).dx, .01),
    );
    final surface = tester
        .element(title)
        .findAncestorWidgetOfExactType<Material>()!;
    final popup = tester.getRect(find.byWidget(surface));
    expect(tester.getCenter(title).dx, closeTo(popup.center.dx, .01));
    final save = tester.getRect(find.widgetWithText(TextButton, 'Save'));
    expect(popup.right - save.right, greaterThanOrEqualTo(24));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'idea popup saves all sections, edits them, and limits ideas to four',
    (tester) async {
      final repo = _Repo();
      await _openIdeas(tester, repo);
      for (var idea = 1; idea <= 4; idea++) {
        await tester.tap(find.text('+ Add Idea'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        for (final label in [
          'Title',
          'Describe the Idea',
          'How would it work?',
          'What are the strengths of this idea?',
          'What are the challenges of this idea?',
        ]) {
          expect(find.text(label, findRichText: true), findsOneWidget);
        }
        final fields = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        expect(fields, findsNWidgets(5));
        for (var field = 0; field < 5; field++) {
          await tester.ensureVisible(fields.at(field));
          await tester.enterText(
            fields.at(field),
            field == 0 ? 'Idea $idea' : 'Idea $idea section $field',
          );
        }
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('Idea $idea'), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('+ Add Idea')).dy,
        lessThan(tester.getTopLeft(find.text('Idea 1')).dy),
      );
      await tester.tap(find.text('+ Add Idea'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.tap(find.text('Idea 1'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Idea'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(fields.at(3)).controller!.text,
        'Idea 1 section 3',
      );
      expect(
        tester.widget<TextField>(fields.at(4)).controller!.text,
        'Idea 1 section 4',
      );
      await tester.tap(find.byTooltip('Close idea'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      final items =
          repo.saved!.whereType<Map>().firstWhere(
                (item) => item['stage'] == 'ideas',
              )['items']
              as List;
      expect(items, hasLength(4));
      expect(items.first['strengths'], 'Idea 1 section 3');
      expect(items.first['challenges'], 'Idea 1 section 4');
      expect(find.byType(DropdownButton<int>), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('four long idea names fit the matrix headers', (tester) async {
    await _openIdeas(
      tester,
      _Repo(),
      textScale: 1,
      ideas: [
        for (var i = 1; i <= 4; i++)
          {
            'id': 'i$i',
            'title': 'Smart Compost System $i',
            'description': 'Description',
          },
      ],
    );
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<int>), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'matrix gives actionable validation, live scores and advances with complete ratings',
    (tester) async {
      final repo = _Repo();
      await _openIdeas(
        tester,
        repo,
        ideas: [
          for (var i = 1; i <= 2; i++)
            {
              'id': 'i$i',
              'title': 'Design $i',
              'description': 'Description',
              'rationale': 'How it works',
            },
        ],
      );
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('matrix-criterion-c1')),
        'Effectiveness',
      );
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Weight (%) · Must total 100%'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('matrix-weight-c1')),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Select 1–5'), findsNWidgets(2));
      for (var i = 1; i <= 2; i++) {
        await tester.tap(find.byKey(ValueKey('matrix-rating-c1-i$i')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(i == 1 ? '5' : '2').last);
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('matrix-score-i1'))).data,
        '100.0',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('matrix-score-i2'))).data,
        '40.0',
      );
      final table = tester.getRect(
        find.byKey(const ValueKey('decision-matrix-table')),
      );
      final title = tester.getRect(find.text('Decision Matrix').last);
      expect(table.left, closeTo(title.left, 1));
      await tester.ensureVisible(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Inquiry Lens'), findsOneWidget);
      final matrix = repo.saved!.whereType<Map>().firstWhere(
        (item) => item['stage'] == 'decisionMatrix',
      );
      expect(matrix['criteria'][0]['ratings'], {'i1': 5, 'i2': 2});
      await tester.ensureVisible(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('matrix-weight-c1')))
            .controller!
            .text,
        '100',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
