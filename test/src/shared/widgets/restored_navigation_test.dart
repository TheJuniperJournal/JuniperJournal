import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/restored_navigation.dart';

void main() {
  for (final phase in [
    'Discovery',
    'Ideation',
    'Prototyping',
    'Implementation',
  ]) {
    test('$phase direct link restores Development then phase before entry', () {
      final entry = JournalEntryEditorScreen(
        projectId: 'p',
        projectName: 'QA',
        tags: const [],
        entryId: 'e',
        initialTitle: 'QA',
        initialContent: const [],
        initialProgress: phase,
        freeNotes: true,
        projectsRepo: ProjectsRepo(),
      );
      final parents = projectNavigationParents(entry);
      expect(parents, hasLength(2));
      expect(
        (parents.first as ProjectDashboard).initialSection,
        ProjectDashboardSection.development,
      );
      expect(parents.last.runtimeType, switch (phase) {
        'Discovery' => DiscoveryDashboardPage,
        'Ideation' => IdeatingDashboardPage,
        'Prototyping' => PrototypingDashboardPage,
        _ => ImplementationDashboardPage,
      });
      expect(
        restoredNavigationStack(home: const SizedBox(), restored: entry),
        hasLength(4),
      );
    });
  }

  test('all application details and forms restore the shared parent', () {
    for (final kind in [
      'chat',
      'chats',
      'project',
      'phase',
      'journal',
      'journal-view',
      'create',
      'settings',
      'project-settings',
      'materials',
      'impact',
      'activity',
      'community',
      'community-profile',
      'community-settings',
      'profile',
    ]) {
      expect(destinationNeedsAppParent(kind), isTrue, reason: kind);
    }
    for (final kind in [
      null,
      'home',
      'explore',
      'login',
      'signup',
      'about',
      'privacy',
    ]) {
      expect(destinationNeedsAppParent(kind), isFalse, reason: kind);
    }
  });
  testWidgets(
    'closing a restored form returns to Home and preserves the root',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/': (_) => const Scaffold(body: Text('Fallback'))},
          onGenerateInitialRoutes: (_) => restoredNavigationStack(
            home: const Scaffold(body: Text('Home destination')),
            restored: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Close restored form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Close restored form'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isTrue);
      await tester.tap(find.text('Close restored form'));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(navigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
