import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/shared/widgets/journal_publication.dart';
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final implementation in [false, true]) {
    testWidgets(
      'incomplete ${implementation ? 'Implementation' : 'Discovery'} blocks tracker and Next',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        const entry = JournalEntry(
          id: 'e',
          projectId: 'p',
          title: 'Entry',
          progress: 'discovery',
          content: [],
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(.7)),
              child: child!,
            ),
            home: implementation
                ? ImplementationEntryPage(
                    projectId: 'p',
                    projectsRepo: repo,
                    entry: entry,
                  )
                : DiscoveryObservationEntryPage(
                    projectId: 'p',
                    projectsRepo: repo,
                    entry: entry,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Learning').first);
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsWidgets);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Inquiry Lens'), findsNothing);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Required'), findsWidgets);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Inquiry Lens'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'journal header stays at the top when changing from long to short stages',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(.7)),
            child: child!,
          ),
          home: IdeatingEntryPage(
            projectId: 'p',
            projectsRepo: _Repo(),
            entry: const JournalEntry(
              id: 'e',
              projectId: 'p',
              title: 'Idea',
              progress: 'ideating',
              content: [
                {
                  'stage': 'challenge',
                  'title': 'A challenge',
                  'problem': 'A problem',
                  'objectives': [
                    {'id': 'o', 'text': 'A clear objective'},
                  ],
                },
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == 'Entry 1: Ideation',
      );
      final before = tester.getRect(title);
      expect(before.top, lessThan(56));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Explore up to four approaches. Explain how each could work, then use evidence and shared criteria to compare them.',
        ),
        findsOneWidget,
      );
      expect(tester.getCenter(find.text('Back')).dy, greaterThan(2000));
      expect(
        tester.getCenter(find.text('Next')).dy,
        closeTo(tester.getCenter(find.text('Back')).dy, .01),
      );
      final after = tester.getRect(title);
      expect(after.top, closeTo(before.top, .01));
      expect(after.left, closeTo(before.left, .01));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(tester.getRect(title).top, closeTo(before.top, .01));
      expect(tester.takeException(), isNull);
    },
  );

  for (final legacy in [false, true]) {
    testWidgets(
      'ideation objectives start empty and the last objective can be removed (legacy: $legacy)',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(.7)),
              child: child!,
            ),
            home: IdeatingEntryPage(
              projectId: 'p',
              projectsRepo: _Repo(),
              entry: JournalEntry(
                id: 'e',
                projectId: 'p',
                title: 'Idea',
                progress: 'ideating',
                content: legacy
                    ? const [
                        {
                          'stage': 'challenge',
                          'objectives': [
                            {'id': 'blank', 'text': ''},
                          ],
                        },
                      ]
                    : const [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_indicator), findsNothing);
        await tester.ensureVisible(find.text('+ Add Objective'));
        await tester.tap(find.text('+ Add Objective'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_indicator), findsNothing);
        expect(
          find.widgetWithText(TextField, 'We want to create a solution that…'),
          findsOneWidget,
        );
        await tester.enterText(find.byType(TextField).at(0), 'A challenge');
        await tester.enterText(find.byType(TextField).at(1), 'A problem');
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Add at least one design objective.'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.enterText(
          find.widgetWithText(TextField, 'We want to create a solution that…'),
          'Use less material',
        );
        await tester.pumpAndSettle();
        expect(find.text('Add at least one design objective.'), findsNothing);
        expect(
          find.text('Add at least one design objective below.'),
          findsNothing,
        );
        await tester.tap(find.byTooltip('Remove'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_indicator), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final fromRecent in [false, true]) {
    testWidgets(
      'Discovery submit requests updated Home (recent: $fromRecent)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo();
        final navigator = GlobalKey<NavigatorState>();
        var publications = 0;
        JournalPublication.onPublished = () {
          publications++;
          navigator.currentState!.popUntil((route) => route.isFirst);
        };
        addTearDown(() => JournalPublication.onPublished = null);
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Project')),
          ),
        );
        if (!fromRecent) {
          navigator.currentState!.push(
            MaterialPageRoute(
              builder: (_) => DiscoveryDashboardPage(
                projectId: 'p',
                isOwner: true,
                projectsRepo: repo,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        navigator.currentState!.push(
          MaterialPageRoute(
            builder: (_) => DiscoveryObservationEntryPage(
              projectId: 'p',
              projectsRepo: repo,
              returnToPhaseDashboard: fromRecent,
              entry: const JournalEntry(
                id: 'e',
                projectId: 'p',
                title: 'Entry',
                content: [
                  {'stage': 'observations', 'observed': 'NA', 'known': 'NA'},
                  {
                    'stage': 'analyze',
                    'patternChange': 'NA',
                    'patternExplanation': 'NA',
                    'rootCauses': [
                      {'title': 'NA', 'description': 'NA', 'reason': 'NA'},
                    ],
                  },
                  {
                    'stage': 'question',
                    'questions': [
                      {'type': 'NA', 'text': 'NA'},
                    ],
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
                    'learned': 'NA',
                    'challenges': 'NA',
                    'nextSteps': 'NA',
                    'notes': 'NA',
                  },
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final stage in [
          '_ObserveStageBody',
          '_AnalyzeStageBody',
          '_QuestionStageBody',
          'JournalLearningStageBody',
        ]) {
          if (stage == '_AnalyzeStageBody') {
            final compact = find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_RootCauseCompactCard',
            );
            await tester.ensureVisible(compact);
            final collapsedArrow =
                tester.getCenter(find.byTooltip('Expand root cause')) -
                tester.getTopLeft(compact);
            final collapsedMenu =
                tester.getCenter(
                  find.descendant(
                    of: compact,
                    matching: find.byType(PopupMenuButton<String>),
                  ),
                ) -
                tester.getTopLeft(compact);
            expect(collapsedArrow.dy, closeTo(collapsedMenu.dy, 0.1));
            await tester.tap(find.byTooltip('Expand root cause'));
            await tester.pumpAndSettle();
            expect(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_RootCausePreviewCard',
              ),
              findsOneWidget,
            );
            expect(find.text('Why does this occur?'), findsWidgets);
            final dynamic preview = tester.widget(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_RootCausePreviewCard',
              ),
            );
            expect(preview.onEdit, isNotNull);
            expect(preview.onDelete, isNotNull);
            final collapse = find.byTooltip('Collapse root cause');
            final expandedArrow =
                tester.getCenter(collapse) - tester.getTopLeft(compact);
            final expandedMenu =
                tester.getCenter(
                  find.descendant(
                    of: compact,
                    matching: find.byType(PopupMenuButton<String>),
                  ),
                ) -
                tester.getTopLeft(compact);
            expect(expandedArrow.dx, closeTo(collapsedArrow.dx, 0.1));
            expect(expandedArrow.dy, closeTo(collapsedArrow.dy, 0.1));
            expect(expandedMenu.dy, closeTo(expandedArrow.dy, 0.1));
            await tester.ensureVisible(collapse);
            await tester.tap(collapse);
            await tester.pumpAndSettle();
            expect(
              find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_RootCausePreviewCard',
              ),
              findsNothing,
            );
          }
          for (final field in tester.widgetList<TextField>(
            find.byType(TextField),
          )) {
            if (field.controller != null && field.controller!.text.isEmpty)
              field.controller!.text = 'NA';
          }
          final dynamic body = tester.widget(
            find.byWidgetPredicate((w) => w.runtimeType.toString() == stage),
          );
          body.onNext();
          await tester.pumpAndSettle();
        }
        final dynamic body = tester.widget(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_NextActionStageBody',
          ),
        );
        body.onSubmit();
        await tester.pumpAndSettle();
        expect(publications, 1);
        expect(find.byType(DiscoveryObservationEntryPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
