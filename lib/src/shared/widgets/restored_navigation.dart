import '../../backend/db/repositories/projects_repo.dart';
import '../../features/project/pages/project_dashboard.dart';
import '../../features/project/pages/project_development_flow.dart';
import '../../features/project/pages/journal_entry_editor.dart';
import '../../features/project/pages/journal_entry_view.dart';
import 'package:flutter/material.dart';

/// A restored detail page keeps its parent underneath it, just as normal
/// navigation does, so closing the page cannot empty the navigator.
List<Route<dynamic>> restoredNavigationStack({
  required Widget home,
  required Widget restored,
}) => [
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => home,
  ),
  for (final parent in projectNavigationParents(restored))
    restoredDetailRoute(parent),
  restoredDetailRoute(restored),
];

/// Build the parent on a cold start so it can configure the persistent shell.
/// Detail screens provide their own opaque Scaffold inside the route.
Route<void> restoredDetailRoute(Widget page, {RouteSettings? settings}) =>
    RestoredDetailRoute(page, settings: settings);

class RestoredDetailRoute extends PageRouteBuilder<void> {
  RestoredDetailRoute(this.page, {RouteSettings? settings})
    : super(
        settings: settings ?? const RouteSettings(name: '/restored'),
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      );
  final Widget page;
}

/// Every application detail/form needs the shared parent; public destinations do not.
bool destinationNeedsAppParent(String? kind) =>
    kind != null &&
    !const {
      'home',
      'explore',
      'login',
      'signup',
      'about',
      'support',
      'privacy',
      'safety',
      'password-recovery',
    }.contains(kind);

/// Cold starts restore the same project hierarchy as in-app navigation.
List<Widget> projectNavigationParents(Widget page) {
  final (String, String?, ProjectsRepo, bool)? target = switch (page) {
    DiscoveryDashboardPage p => (p.projectId, null, p.projectsRepo, p.isOwner),
    IdeatingDashboardPage p => (p.projectId, null, p.projectsRepo, p.isOwner),
    PrototypingDashboardPage p => (
      p.projectId,
      null,
      p.projectsRepo,
      p.isOwner,
    ),
    ImplementationDashboardPage p => (
      p.projectId,
      null,
      p.projectsRepo,
      p.isOwner,
    ),
    DiscoveryObservationEntryPage p => (
      p.projectId,
      'discover',
      p.projectsRepo,
      true,
    ),
    IdeatingEntryPage p => (p.projectId, 'ideating', p.projectsRepo, true),
    ImplementationEntryPage p => (
      p.projectId,
      'implementation',
      p.projectsRepo,
      true,
    ),
    PrototypingJournalEntryPage p => (
      p.projectId,
      'prototyping',
      p.projectsRepo,
      !p.readOnly,
    ),
    JournalEntryEditorScreen p => (
      p.projectId,
      normalizePhase(p.initialProgress),
      p.projectsRepo ?? ProjectsRepo(),
      !p.readOnly,
    ),
    JournalEntryView p => (
      p.project.id,
      normalizePhase(p.entry.progress),
      p.projectsRepo,
      p.projectsRepo.currentUserId == p.project.userId,
    ),
    _ => null,
  };
  if (target == null) return const [];
  final (id, phase, repo, owner) = target;
  return [
    ProjectDashboard(
      projectId: id,
      projectName: '',
      tags: const [],
      projectsRepo: repo,
      isOwner: owner,
      initialSection: ProjectDashboardSection.development,
    ),
    if (phase != null)
      switch (phase) {
        'discover' => DiscoveryDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        'ideating' => IdeatingDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        'prototyping' => PrototypingDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        _ => ImplementationDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
      },
  ];
}
