import 'package:flutter/material.dart';
import '../../backend/db/models/journal_entry.dart';
import '../../backend/db/models/project.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../../features/project/pages/journal_entry_view.dart';
import 'app_navigation.dart';
import 'item_action_menu.dart';
import 'modal_actions.dart';
import 'journal_draft_session.dart';

Future<bool> confirmDeleteJournalEntry(
  BuildContext context,
  ProjectsRepo repo,
  JournalEntry entry,
) async {
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete entry?'),
      content: Text('Delete “${entry.title}”? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final deleted = await repo.deleteJournalEntry(entryId: entry.id);
  if (!context.mounted) return deleted;
  if (!deleted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not delete this entry. Please try again.'),
      ),
    );
    return false;
  }
  await JournalDraftSession.forgetEntry(repo, entry.id);
  return true;
}

/// Shared preview action menu, authorized by entry authorship or project ownership.
class JournalEntryMenu extends StatefulWidget {
  const JournalEntryMenu({
    super.key,
    required this.entry,
    this.repo,
    this.project,
    this.onDeleted,
  });
  final JournalEntry entry;
  final ProjectsRepo? repo;
  final Project? project;
  final VoidCallback? onDeleted;
  @override
  State<JournalEntryMenu> createState() => _JournalEntryMenuState();
}

class _JournalEntryMenuState extends State<JournalEntryMenu> {
  late final _repo = widget.repo ?? ProjectsRepo();
  late final _access = _loadAccess();
  Future<(Project?, bool, bool)> _loadAccess() async {
    final project =
        widget.project ?? await _repo.getProjectById(widget.entry.projectId);
    String? user;
    try {
      user = _repo.currentUserId;
    } catch (_) {}
    if (project == null || user == null) return (project, false, false);
    if (!await _repo.canViewInternalProjectLogs(widget.entry.projectId))
      return (project, false, false);
    final manages = project.userId == user || widget.entry.authorId == user;
    final participant =
        !manages &&
        widget.entry.participantIds.contains(user) &&
        await _repo.canViewInternalProjectLogs(widget.entry.projectId);
    return (project, manages || participant, manages);
  }

  bool _busy = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<(Project?, bool, bool)>(
    future: _access,
    builder: (context, snapshot) {
      final access = snapshot.data;
      final project = access?.$1;
      if (project == null || access?.$2 != true) return const SizedBox.shrink();
      return IgnorePointer(
        ignoring: _busy,
        child: ItemActionMenu(
          icon: const Icon(
            Icons.edit_outlined,
            size: 20,
            color: Color(0xFF5DB075),
          ),
          onEdit: () => pushAppRoute(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  editableJournalEntryPage(widget.entry, project, _repo),
            ),
          ),
          onDelete: access!.$3
              ? () async {
                  if (_busy) return;
                  setState(() => _busy = true);
                  final deleted = await confirmDeleteJournalEntry(
                    context,
                    _repo,
                    widget.entry,
                  );
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (deleted) {
                    if (widget.onDeleted != null) {
                      widget.onDeleted!();
                    } else {
                      Navigator.of(context).pop(true);
                    }
                  }
                }
              : null,
        ),
      );
    },
  );
}
