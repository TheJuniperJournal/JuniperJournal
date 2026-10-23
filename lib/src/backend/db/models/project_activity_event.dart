import 'journal_entry.dart';

class ProjectActivityEvent {
  const ProjectActivityEvent({
    required this.id,
    required this.kind,
    required this.description,
    required this.actorName,
    required this.createdAt,
    this.sourceId,
    this.journalEntryId,
    this.avatarUrl,
  });
  final String id, kind, description, actorName;
  final String? sourceId, journalEntryId, avatarUrl;
  final DateTime createdAt;
  factory ProjectActivityEvent.fromJson(Map<String, dynamic> row) =>
      ProjectActivityEvent(
        id: row['id'].toString(),
        kind: row['kind'] as String,
        description: row['description'] as String,
        actorName: row['actor_name'] as String? ?? 'A project member',
        createdAt: DateTime.parse(row['created_at'] as String),
        sourceId: row['source_id'] as String?,
        journalEntryId: row['journal_entry_id'] as String?,
        avatarUrl: row['avatar_url'] as String?,
      );

  /// Existing entries provide a useful baseline before activity history is deployed.
  factory ProjectActivityEvent.fromEntry(
    JournalEntry entry,
  ) => ProjectActivityEvent(
    id: 'entry-${entry.id}',
    kind: 'journal_updated',
    sourceId: entry.id,
    journalEntryId: entry.id,
    description:
        '${entry.updatedAt != null && entry.updatedAt != entry.createdAt ? 'updated' : 'added'} journal entry “${entry.title.isEmpty ? 'Untitled entry' : entry.title}”',
    actorName: entry.authorDisplayName ?? 'A project member',
    avatarUrl: entry.authorAvatarUrl,
    createdAt:
        entry.updatedAt ??
        entry.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}
