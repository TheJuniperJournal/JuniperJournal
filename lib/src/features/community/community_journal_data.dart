import '../../shared/widgets/journal_preview_image.dart';
import '../../backend/db/models/journal_entry.dart';
import '../../backend/db/models/project.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../project/utils/journal_completion.dart';

class CommunityJournalRecord {
  const CommunityJournalRecord({
    required this.project,
    required this.entry,
    this.ecoPoints = 0,
  });
  final Project project;
  final JournalEntry entry;
  final double ecoPoints;
}

/// Uses the existing audience rules and excludes drafts, including the viewer's own.
Future<List<CommunityJournalRecord>> loadCommunityJournal(
  ProjectsRepo repo,
  String communityId,
) async {
  final projects = await repo.getAudienceFeedProjects(communityId: communityId);
  final groups = await Future.wait(
    projects.map((project) async {
      final entries = (await repo.getCommunityJournalEntries(
        projectId: project.id,
        communityId: communityId,
      )).where(journalEntryIsComplete).toList();
      if (entries.isEmpty) return <CommunityJournalRecord>[];
      final impacts = await repo.getImpactEntries(projectId: project.id) ?? [];
      return [
        for (final entry in entries)
          CommunityJournalRecord(
            project: project,
            entry: entry,
            ecoPoints: impacts
                .where((impact) => impact.linkedJournalEntryId == entry.id)
                .fold<double>(0, (sum, impact) => sum + impact.ecoPoints),
          ),
      ];
    }),
  );
  return groups.expand((group) => group).toList()..sort(
    (a, b) => (b.entry.createdAt ?? DateTime(1970)).compareTo(
      a.entry.createdAt ?? DateTime(1970),
    ),
  );
}

List<String> communityJournalImages(List<dynamic> content) =>
    journalPreviewImageSources(content);
