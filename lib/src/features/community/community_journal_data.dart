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

List<String> communityJournalImages(List<dynamic> content) {
  final urls = <String>{};
  void walk(dynamic node) {
    if (node is Map) {
      if (node['type'] == 'image' &&
          (node['url']?.toString().isNotEmpty ?? false)) {
        urls.add(node['url'].toString());
      }
      if (node['type'] == 'Images' && node['data'] is Map) {
        final images = (node['data'] as Map)['images'];
        if (images is List) {
          for (final image in images.whereType<Map>()) {
            final url =
                (image['public_url'] ?? image['publicUrl'])?.toString() ?? '';
            if (url.isNotEmpty) urls.add(url);
          }
        }
      }
      for (final value in node.values) {
        walk(value);
      }
    } else if (node is List) {
      for (final value in node) {
        walk(value);
      }
    }
  }

  walk(content);
  return urls.toList();
}
