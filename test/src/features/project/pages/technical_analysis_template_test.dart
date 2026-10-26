import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/shared/widgets/journal_action_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/utils/journal_completion.dart';

class _Repo extends ProjectsRepo {
  List<dynamic>? saved;
  @override
  Future<List<UserProfile>> getProjectMembers({
    required String projectId,
  }) async => [];
  @override
  Future<List<JournalEntry>?> getJournalEntries({
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'technical analysis requires baseline and a data source but not optional fields',
    () {
      final data = <String, dynamic>{
        'stage': 'prototyping',
        'entryType': 'technical_analysis',
        'analysisWorkflow': true,
        'title': 'Analysis',
        'question': 'Objective',
        'baseline': 'Existing conditions',
        'dataSources': [
          {'label': 'Field Measurements'},
        ],
      };
      expect(completedJournalStageIndices([data]), contains(0));
      data['dataSources'] = [];
      expect(completedJournalStageIndices([data]), isNot(contains(0)));
      data['dataSources'] = [
        {'label': 'Field Measurements'},
      ];
      data['baseline'] = '';
      expect(completedJournalStageIndices([data]), isNot(contains(0)));
    },
  );
  testWidgets(
    'analysis sources support multiple selections and persist on save',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repo();
      await tester.pumpWidget(
        MaterialApp(
          home: PrototypingJournalEntryPage(
            projectId: 'p',
            projectsRepo: repo,
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Analysis',
              progress: 'prototyping',
              content: [
                {
                  'stage': 'prototyping',
                  'entryType': 'technical_analysis',
                  'title': 'Analysis',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Baseline Description', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Learning').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Required'), findsWidgets);
      expect(find.text('Select at least one data source.'), findsOneWidget);
      expect(
        find.textContaining('Choose the kind of calculation'),
        findsOneWidget,
      );
      expect(find.byType(JournalActionFooter), findsOneWidget);
      final footerY = tester.getCenter(find.text('Next')).dy;
      final add = find.text('+ Data Source');
      final scroller = tester.state<ScrollableState>(
        find.ancestor(of: add, matching: find.byType(Scrollable)).first,
      );
      scroller.position.jumpTo(100);
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Next')).dy, lessThan(footerY));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1000, 1000);
      await tester.pumpAndSettle();
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Field Measurements'));
      await tester.tap(find.text('Field Measurements'));
      await tester.ensureVisible(find.text('Equipment Specifications'));
      await tester.tap(find.text('Equipment Specifications'));
      await tester.pumpAndSettle();
      final sourceHeader = find.text('Add Data Source');
      final sourceScroll = tester.state<ScrollableState>(
        find
            .ancestor(of: sourceHeader, matching: find.byType(Scrollable))
            .first,
      );
      sourceScroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      final sourceHeaderPosition = tester.getTopLeft(sourceHeader);
      final customField = find.byType(TextField).last;
      sourceScroll.position.jumpTo(sourceScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(customField);
      expect(
        tester.getTopLeft(sourceHeader).dy,
        lessThan(sourceHeaderPosition.dy),
      );
      expect(
        tester.getBottomRight(sourceHeader).dy,
        lessThan(tester.getTopLeft(customField).dy),
      );
      await tester.enterText(customField, 'Lab notebook');
      final addCustom = find.text('Add Custom Source');
      await tester.ensureVisible(addCustom);
      await tester.tap(addCustom);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add Selected (3)'));
      await tester.tap(find.text('Add Selected (3)'));
      await tester.pumpAndSettle();
      expect(find.text('Field Measurements'), findsOneWidget);
      expect(find.text('Equipment Specifications'), findsOneWidget);
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final data = repo.saved!.whereType<Map>().firstWhere(
        (row) => row['stage'] == 'prototyping',
      );
      expect((data['dataSources'] as List).length, 3);
      expect(
        (data['dataSources'] as List).any(
          (source) => source['label'] == 'Lab notebook',
        ),
        isTrue,
      );
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(CheckboxListTile, 'Lab notebook'),
        findsOneWidget,
      );
      expect(find.text('Add Selected (3)'), findsOneWidget);
      await tester.ensureVisible(
        find.byTooltip('Edit custom source Lab notebook'),
      );
      await tester.tap(find.byTooltip('Edit custom source Lab notebook'));
      await tester.pumpAndSettle();
      final rename = find.byKey(const ValueKey('custom-source-name-editor'));
      expect(find.text('Cancel Rename'), findsNothing);
      expect(find.text('Save Source'), findsNothing);
      expect(find.text('Add Custom Source'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Source name'))
            .controller!
            .text,
        isEmpty,
      );
      await tester.ensureVisible(rename);
      await tester.enterText(rename, 'Lab record');
      await tester.ensureVisible(find.byTooltip('Finish editing source'));
      await tester.tap(find.byTooltip('Finish editing source'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Lab notebook'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byTooltip('Delete custom source Lab record'),
      );
      await tester.tap(find.byTooltip('Delete custom source Lab record'));
      await tester.pumpAndSettle();
      expect(find.text('Lab record'), findsNothing);
      await tester.ensureVisible(find.text('Add Selected (2)'));
      await tester.tap(find.text('Add Selected (2)'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final updated = repo.saved!.whereType<Map>().firstWhere(
        (row) => row['stage'] == 'prototyping',
      );
      expect(updated['customDataSources'], isEmpty);
      expect((updated['dataSources'] as List).length, 2);
      expect(find.text('Field Measurements'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('custom sources belong only to their journal entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    const original = JournalEntry(
      id: 'original',
      projectId: 'p',
      title: 'Original analysis',
      content: [
        {
          'stage': 'prototyping',
          'entryType': 'technical_analysis',
          'analysisWorkflow': true,
          'customDataSources': [
            {'label': 'Entry-specific lab notes'},
          ],
          'dataSources': [
            {'label': 'Entry-specific lab notes'},
          ],
        },
      ],
    );
    Future<void> open(Widget page) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('+ Data Source'));
      await tester.tap(find.text('+ Data Source'));
      await tester.pumpAndSettle();
    }

    await open(
      PrototypingJournalEntryPage(
        projectId: 'p',
        projectsRepo: repo,
        entry: original,
      ),
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Entry-specific lab notes'),
      findsOneWidget,
    );
    expect(find.text('Sources created in this entry'), findsOneWidget);
    await open(restoreEmptyPrototypingPage('p', repo, 'technical_analysis'));
    expect(find.text('Entry-specific lab notes'), findsNothing);
    expect(find.text('Add Selected (0)'), findsOneWidget);
    expect(
      find.widgetWithText(CheckboxListTile, 'Field Measurements'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Equipment Specifications'),
      findsOneWidget,
    );
    await open(
      PrototypingJournalEntryPage(
        projectId: 'p',
        projectsRepo: repo,
        entry: original,
      ),
    );
    expect(
      find.widgetWithText(CheckboxListTile, 'Entry-specific lab notes'),
      findsOneWidget,
    );
    expect(find.text('Add Selected (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
