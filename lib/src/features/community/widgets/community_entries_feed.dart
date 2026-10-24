import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../../shared/widgets/journal_project_link.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/journal_log_entry_card.dart';
import '../../project/pages/project_development_flow.dart';
import '../../project/pages/journal_entry_view.dart';
import '../community_journal_data.dart';

class CommunityEntriesFeed extends StatefulWidget {
  const CommunityEntriesFeed({
    super.key,
    required this.communityId,
    this.projectsRepo,
  });
  final String communityId;
  final ProjectsRepo? projectsRepo;
  @override
  State<CommunityEntriesFeed> createState() => CommunityEntriesFeedState();
}

class CommunityEntriesFeedState extends State<CommunityEntriesFeed> {
  late final _repo = widget.projectsRepo ?? ProjectsRepo();
  late Future<List<CommunityJournalRecord>> _records = loadCommunityJournal(
    _repo,
    widget.communityId,
  );
  Future<void> reload() async {
    setState(() => _records = loadCommunityJournal(_repo, widget.communityId));
    await _records;
  }

  Future<void> _open(CommunityJournalRecord record) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEntryView(
          entry: record.entry,
          project: record.project,
          projectsRepo: _repo,
        ),
      ),
    );
    if (mounted) await reload();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<CommunityJournalRecord>>(
    future: _records,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = snapshot.data ?? [];
      return AppRefreshIndicator(
        onRefresh: reload,
        child: PageScrollWithFooter(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Could not load entries. Pull down to try again.',
                  ),
                ),
              if (!snapshot.hasError && records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'No journal entries yet. Completed entries from community projects will appear here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.helper,
                  ),
                ),
              for (final record in records) ...[
                JournalLogEntryCard(
                  entry: record.entry,
                  projectLink: JournalProjectLink(
                    projectName: record.project.projectName,
                    onTap: () =>
                        openJournalProject(context, record.project, _repo),
                  ),
                  phaseLabel:
                      record.entry.prototypingTypeLabel ??
                      switch (normalizePhase(record.entry.progress)) {
                        'discover' => 'Discovery',
                        'ideating' => 'Ideation',
                        'prototyping' => 'Prototyping',
                        'implementation' => 'Implementation',
                        _ => 'Journal',
                      },
                  status: const SizedBox.shrink(),
                  ecoPoints: record.ecoPoints,
                  imageUrls: communityJournalImages(record.entry.content),
                  onTap: () => _open(record),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
