import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

class _Repo extends ProjectsRepo {
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
  }) async => true;
}

Future<void> _open(
  WidgetTester tester, {
  List<dynamic> content = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: IdeatingEntryPage(
        projectId: 'p',
        projectsRepo: _Repo(),
        entry: JournalEntry(
          id: 'entry',
          projectId: 'p',
          title: 'Notes',
          content: content,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Next').last);
  await tester.tap(find.text('Next').last);
  await tester.pumpAndSettle();
  expect(find.textContaining('Complete required items in:'), findsNothing);
}

const _challenge = {
  'stage': 'challenge',
  'title': 'Design',
  'problem': 'Reduce waste',
  'objectives': [
    {'id': 'objective', 'text': 'Use less material'},
  ],
};
const _idea = {
  'id': 'idea',
  'title': 'Reuse',
  'description': 'Reuse the frame',
  'rationale': 'Reduces material',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('phase title input and editable header stay synchronized', (
    tester,
  ) async {
    await _open(tester);
    final fields = find.byType(TextField);
    final header = tester.widget<TextField>(fields.at(0));
    final title = tester.widget<TextField>(fields.at(1));
    expect(identical(header.controller, title.controller), isTrue);
    expect(header.decoration?.hintText, 'Entry 1: Ideation');
    await tester.enterText(fields.at(1), 'A better water filter');
    await tester.pump();
    expect(header.controller!.text, 'A better water filter');
    await tester.enterText(fields.at(0), 'Updated title');
    await tester.pump();
    expect(title.controller!.text, 'Updated title');
    await tester.enterText(fields.at(1), '');
    await tester.pumpAndSettle();
    expect(header.controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('component selection is required even with no text inputs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrototypingJournalEntryPage(
          projectId: 'p',
          projectsRepo: _Repo(),
          entry: const JournalEntry(
            id: 'e',
            projectId: 'p',
            title: 'Build',
            content: [
              {'stage': 'prototyping', 'entryType': 'building'},
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _next(tester);
    expect(
      find.text('Select or create a component, or choose No component.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Select Components').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('No component'));
    await tester.tap(find.text('No component'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Use Selection'));
    await tester.tap(find.text('Use Selection'));
    await tester.pumpAndSettle();
    await _next(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'analysis marks root cause action and pattern selection together',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DiscoveryObservationEntryPage(
            projectId: 'p',
            projectsRepo: _Repo(),
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Discovery',
              content: [
                {
                  'stage': 'observations',
                  'title': 'Observation',
                  'observed': 'Waste',
                  'known': 'Needs improvement',
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _next(tester);
      await tester.tap(find.text('Question').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Add at least one complete root cause.'),
        findsOneWidget,
      );
      expect(find.text('Select a pattern change.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty challenge marks text and objectives together, then clears objective error when filled',
    (tester) async {
      await _open(tester);
      await _next(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Add at least one design objective.'), findsOneWidget);
      expect(find.textContaining('Supporting Context'), findsOneWidget);
      await tester.ensureVisible(find.text('+ Add Objective'));
      await tester.tap(find.text('+ Add Objective'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'We want to create a solution that…'),
        'Reduce material',
      );
      await tester.pumpAndSettle();
      expect(find.text('Add at least one design objective.'), findsNothing);
      final objectiveField = find.widgetWithText(
        TextField,
        'We want to create a solution that…',
      );
      final editable = find.descendant(
        of: objectiveField,
        matching: find.byType(EditableText),
      );
      final input = InputDecorator.containerOf(tester.element(editable))!;
      final inputCenter =
          input.localToGlobal(Offset.zero).dy + input.size.height / 2;
      expect(inputCenter, closeTo(tester.getCenter(find.text('1')).dy, 1));
      expect(
        inputCenter,
        closeTo(tester.getCenter(find.byTooltip('Remove')).dy, 1),
      );

      expect(find.text('Required'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty ideas marks the Add Idea action', (tester) async {
    await _open(tester, content: [_challenge]);
    await _next(tester);
    await _next(tester);
    expect(find.text('Add at least one complete idea.'), findsOneWidget);
    expect(find.text('+ Add Idea'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matrix tracker attempt marks criteria and rating requirements', (
    tester,
  ) async {
    await _open(
      tester,
      content: [
        _challenge,
        {
          'stage': 'ideas',
          'items': [_idea],
        },
      ],
    );
    await _next(tester);
    await _next(tester);
    await tester.tap(find.text('Learning').first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Add criteria, set weights to 100%, and rate every idea from 1 to 5.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning tracker attempt marks every required selection', (
    tester,
  ) async {
    await _open(
      tester,
      content: [
        _challenge,
        {
          'stage': 'ideas',
          'items': [_idea],
        },
        {
          'stage': 'decisionMatrix',
          'criteria': [
            {
              'id': 'criterion',
              'criterion': 'Waste',
              'weight': '100',
              'ratings': {'idea': 4},
            },
          ],
        },
      ],
    );
    await _next(tester);
    await _next(tester);
    await _next(tester);
    await tester.tap(find.text('Next Action').first);
    await tester.pumpAndSettle();
    for (final message in [
      'Select an inquiry lens.',
      'Select at least one DCI option.',
      'Select at least one SEP option.',
      'Select at least one CCCs option.',
    ]) {
      expect(find.text(message), findsOneWidget);
    }
    expect(
      find.text('Complete the selected assessment or remove its type.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
