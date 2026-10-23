import '../services/project_activity.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../backend/auth/auth_service.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../../backend/db/models/project.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import 'journal_entry_editor.dart';
import 'project_dashboard.dart';
import 'project_development_flow.dart';

/// Re-fetch through the audience projection before displaying a passed entry.
class JournalEntryView extends StatefulWidget {
  const JournalEntryView({
    super.key,
    required this.entry,
    required this.project,
    required this.projectsRepo,
  });
  final JournalEntry entry;
  final Project project;
  final ProjectsRepo projectsRepo;
  @override
  State<JournalEntryView> createState() => _JournalEntryViewState();
}

class _JournalEntryViewState extends State<JournalEntryView> {
  bool _participant = false;
  late final Future<JournalEntry?> _entry = _resolve();
  Future<JournalEntry?> _resolve() async {
    if (widget.entry.projectId != widget.project.id) return null;
    try {
      _participant = await widget.projectsRepo.canViewInternalProjectLogs(
        widget.project.id,
      );
      final entries = await widget.projectsRepo.getJournalEntries(
        projectId: widget.project.id,
      );
      return entries?.where((entry) => entry.id == widget.entry.id).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<JournalEntry?>(
    future: _entry,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final entry = snapshot.data;
      if (entry == null)
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Text('This entry is unavailable or is not shared with you.'),
          ),
        );
      return _JournalEntryViewContent(
        participant: _participant,
        entry: entry,
        project: widget.project,
        projectsRepo: widget.projectsRepo,
      );
    },
  );
}

/// Opens the selected journal format without adding project navigation to it.
class _JournalEntryViewContent extends StatelessWidget {
  const _JournalEntryViewContent({
    required this.entry,
    required this.participant,
    required this.project,
    required this.projectsRepo,
  });
  final bool participant;
  final JournalEntry entry;
  final Project project;
  final ProjectsRepo projectsRepo;

  @override
  Widget build(BuildContext context) {
    final page = entry.isFreeNotes
        ? freeNotesEntryPage(entry, projectsRepo)
        : switch (normalizePhase(entry.progress)) {
            'discover' => DiscoveryEntryPreviewPage(entry: entry),
            'ideating' => IdeatingEntryPreviewPage(entry: entry),
            'prototyping' when entry.prototypingTypeLabel != null =>
              PrototypingJournalEntryPage(
                projectId: entry.projectId,
                projectsRepo: projectsRepo,
                entry: entry,
                readOnly: true,
              ),
            'implementation' => ImplementationPreviewPage(
              entry: entry,
              projectId: entry.projectId,
              projectsRepo: projectsRepo,
            ),
            _ => JournalEntryEditorScreen(
              projectId: entry.projectId,
              projectName: project.projectName,
              tags: project.tags,
              entryId: entry.id,
              entryAuthorId: entry.authorId,
              initialTitle: entry.title,
              initialContent: entry.content,
              initialProgress: entry.progress,
              readOnly: true,
            ),
          };
    String? userId;
    try {
      userId = AuthService.instance.currentUser?.id;
    } catch (_) {}
    bool included(dynamic node) {
      if (node is Map) {
        for (final value in node.entries) {
          if (value.key == 'involved' &&
              value.value is List &&
              (value.value as List).whereType<Map>().any(
                (p) => p['id'] == userId,
              ))
            return true;
          if (included(value.value)) return true;
        }
      }
      if (node is List) return node.any(included);
      return false;
    }

    if (participant &&
        userId != null &&
        userId != entry.authorId &&
        included(entry.content))
      return ProjectActivityScope(
        projectId: project.id,
        repo: projectsRepo,
        child: Column(
          children: [
            Material(
              child: SafeArea(
                bottom: false,
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await projectsRepo.confirmJournalContribution(entry.id);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Contribution confirmed. Entry rewards use participation confirmed at completion.',
                            ),
                          ),
                        );
                    } catch (_) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not confirm your contribution. Please retry.',
                            ),
                          ),
                        );
                    }
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirm my contribution'),
                ),
              ),
            ),
            Expanded(child: page),
          ],
        ),
      );
    return ProjectActivityScope(
      projectId: project.id,
      repo: projectsRepo,
      child: page,
    );
  }
}

Future<void> openJournalProject(
  BuildContext context,
  Project project,
  ProjectsRepo repo,
) => pushAppRoute(
  context,
  MaterialPageRoute(
    builder: (_) => ProjectDashboard(
      projectId: project.id,
      projectName: project.projectName,
      tags: project.tags,
      isOwner: false,
      projectsRepo: repo,
    ),
  ),
);

/// Reopens the original entry format with its saved data for author editing.
Widget editableJournalEntryPage(
  JournalEntry entry,
  Project project,
  ProjectsRepo repo,
) {
  if (entry.isFreeNotes)
    return freeNotesEntryPage(entry, repo, readOnly: false);
  return switch (normalizePhase(entry.progress)) {
    'discover' => DiscoveryObservationEntryPage(
      projectId: project.id,
      projectsRepo: repo,
      entry: entry,
    ),
    'ideating' => IdeatingEntryPage(
      projectId: project.id,
      projectsRepo: repo,
      entry: entry,
    ),
    'prototyping' when entry.prototypingTypeLabel != null =>
      PrototypingJournalEntryPage(
        projectId: project.id,
        projectsRepo: repo,
        entry: entry,
      ),
    'implementation' => ImplementationEntryPage(
      projectId: project.id,
      projectsRepo: repo,
      entry: entry,
    ),
    _ => JournalEntryEditorScreen(
      projectId: project.id,
      projectName: project.projectName,
      tags: project.tags,
      entryId: entry.id,
      entryAuthorId: entry.authorId,
      initialTitle: entry.title,
      initialContent: entry.content,
      initialProgress: entry.progress,
      projectsRepo: repo,
    ),
  };
}
