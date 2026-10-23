import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../../backend/db/models/journal_entry.dart';
import '../../features/project/utils/journal_completion.dart';

class JournalCompletionTag extends StatefulWidget {
  const JournalCompletionTag({super.key, required this.entry});
  final JournalEntry entry;
  @override
  State<JournalCompletionTag> createState() => _JournalCompletionTagState();
}

class _JournalCompletionTagState extends State<JournalCompletionTag> {
  late final Future<bool> _allowed = ProjectsRepo().canViewInternalProjectLogs(
    widget.entry.projectId,
  );
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (_, snapshot) =>
        snapshot.data == true ? _tag(context) : const SizedBox.shrink(),
  );
  Widget _tag(BuildContext context) {
    final entry = widget.entry;
    final completed = journalEntryIsComplete(entry);
    final color = completed ? const Color(0xFF5DB075) : const Color(0xFFFFA500);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed ? Icons.check_circle_outline : Icons.access_time,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            completed ? 'COMPLETED' : 'DRAFT',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: color,
              fontSize: AppTypography.captionSize,
              fontWeight: FontWeight.w400,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
