import '../../../backend/db/models/project.dart';
import '../../../backend/db/models/journal_entry.dart';
import '../../project/utils/journal_completion.dart';

/// Keep each entry paired with its project; multiple entries may share a project.
List<(Project, JournalEntry)> homeJournalFeed(
  List<Project> projects,
  List<List<JournalEntry>> entries,
) {
  final feed = <(Project, JournalEntry)>[
    for (var i = 0; i < projects.length; i++)
      for (final entry in completedJournalFeedEntries(entries[i]))
        (projects[i], entry),
  ];
  DateTime activity(JournalEntry entry) =>
      entry.updatedAt ?? entry.createdAt ?? DateTime(1970);
  feed.sort((a, b) => activity(b.$2).compareTo(activity(a.$2)));
  return feed;
}
