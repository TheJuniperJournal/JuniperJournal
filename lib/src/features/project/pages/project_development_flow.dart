import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import '../../../shared/widgets/journal_preview_image.dart';
import '../utils/eco_points_calculator.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/journal_entry_menu.dart';
import '../../../shared/widgets/page_refresh_state.dart'
    show restoredJournalStage, PageRefreshState;
import '../services/project_activity.dart';
import '../../../shared/widgets/journal_draft_session.dart';
import '../../../shared/widgets/journal_entry_title.dart';
import 'project_dashboard.dart';
import 'journal_entry_view.dart' show editableJournalEntryPage;
import '../../../shared/widgets/journal_action_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/compact_list_item.dart';
import '../../../shared/widgets/journal_publication.dart';
import '../../../shared/widgets/desktop_modal_layer.dart';
import '../../../shared/widgets/interactive_journal_assessment.dart';
import 'journal_choice_dialog.dart';
import 'journal_entry_editor.dart';
import 'journal_type_sheet.dart';
import '../../../shared/widgets/journal_involved_people_preview.dart';
import 'package:juniper_journal/src/shared/widgets/optional_field_label.dart';
import 'build_materials_stage.dart';
import '../utils/journal_completion.dart';
import '../../../shared/styling/app_metrics.dart';
import '../../../shared/widgets/progress_tracker.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import '../../../shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/app_scroll_behavior.dart';
import '../../../shared/widgets/evidence_media_source.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import '../../../shared/widgets/journal_log_entry_card.dart';
import 'package:juniper_journal/src/shared/widgets/draft_autosave.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/journal_completion_tag.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/image_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';
import 'package:juniper_journal/src/features/learning_module/pages/link_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/table_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/video_block_editor.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/features/project/pages/impact_entry_form.dart';
import 'package:juniper_journal/src/features/project/pages/materials_cost.dart';
import 'package:juniper_journal/src/features/project/pages/project_timeline_tab.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';

String? _journalCurrentUserId() {
  try {
    return AuthService.instance.currentUser?.id;
  } catch (_) {
    return null;
  }
}

const _devGreen = Color(0xFF5DB075);
const _devText = Color(0xFF1C1C1C);
const _devBorder = Color(0xFFDED7D7);
const _ideaGreen = Color(0xFF5DB075);
const _ideaYellow = Color(0xFFFFC933);
const _ideaRed = Color(0xFFFF2525);
const _ideaBlue = Color(0xFF2C70BF);
const _ideaColors = [_ideaGreen, _ideaYellow, _ideaRed, _ideaBlue];

Color _ideaColor(int index) => _ideaColors[index.clamp(0, 3)];

String _formatIdeaScore(double? score) =>
    score == null ? 'NA' : (score * 100).toStringAsFixed(1);

Future<bool> _confirmPrototypeDelete(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action, style: const TextStyle(color: Color(0xFFD64545))),
        ),
      ],
    ),
  );
  return result == true;
}

class DevelopmentSummary {
  const DevelopmentSummary({
    required this.entries,
    required this.phaseCounts,
    required this.totalEntries,
    required this.lastUpdated,
    required this.furthestPhase,
  });

  final List<JournalEntry> entries;
  final Map<String, int> phaseCounts;
  final int totalEntries;
  final DateTime? lastUpdated;
  final int furthestPhase;

  factory DevelopmentSummary.empty() {
    return const DevelopmentSummary(
      entries: [],
      phaseCounts: {
        'discover': 0,
        'ideating': 0,
        'prototyping': 0,
        'implementation': 0,
      },
      totalEntries: 0,
      lastUpdated: null,
      furthestPhase: 0,
    );
  }

  static DevelopmentSummary fromEntries(List<JournalEntry> entries) {
    final counts = {
      'discover': 0,
      'ideating': 0,
      'prototyping': 0,
      'implementation': 0,
    };
    DateTime? lastUpdated;

    for (final entry in entries) {
      final key = normalizePhase(entry.progress);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      final updated = entry.updatedAt ?? entry.createdAt;
      if (updated != null &&
          (lastUpdated == null || updated.isAfter(lastUpdated))) {
        lastUpdated = updated;
      }
    }

    var furthest = 0;
    for (var i = 0; i < phaseKeys.length; i++) {
      if ((counts[phaseKeys[i]] ?? 0) > 0) furthest = i + 1;
    }

    return DevelopmentSummary(
      entries: entries,
      phaseCounts: counts,
      totalEntries: entries.length,
      lastUpdated: lastUpdated,
      furthestPhase: furthest,
    );
  }
}

const phaseKeys = ['discover', 'ideating', 'prototyping', 'implementation'];
const phaseLabels = ['Discover', 'Ideating', 'Prototyping', 'Implementation'];

String normalizePhase(String? phase) {
  final normalized = (phase ?? '').trim().toLowerCase();
  if (normalized == 'discovery' || normalized == 'discovering')
    return 'discover';
  if (normalized == 'discover') return 'discover';
  if (normalized == 'ideation') return 'ideating';
  if (normalized == 'ideating') return 'ideating';
  if (normalized == 'prototype' || normalized == 'testing & iterating')
    return 'prototyping';
  if (normalized == 'prototyping') return 'prototyping';
  if (normalized == 'implementation' || normalized == 'implemented')
    return 'implementation';
  return normalized;
}

Widget freeNotesEntryPage(
  JournalEntry entry,
  ProjectsRepo repo, {
  bool readOnly = true,
}) => JournalEntryEditorScreen(
  projectId: entry.projectId,
  projectName: '',
  tags: const [],
  entryId: entry.id,
  entryAuthorId: entry.authorId,
  initialTitle: entry.title,
  initialContent: entry.content,
  initialProgress: entry.progress,
  projectsRepo: repo,
  freeNotes: true,
  readOnly: readOnly,
);

Future<bool> openFreeNotesIfNeeded(
  BuildContext context,
  JournalEntry entry,
  ProjectsRepo repo, {
  bool readOnly = true,
}) async {
  if (!entry.isFreeNotes) return false;
  await pushAppRoute(
    context,
    MaterialPageRoute(
      builder: (_) => freeNotesEntryPage(entry, repo, readOnly: readOnly),
    ),
  );
  return true;
}

/// Shared quick-add entry point; new entries are saved by their stage workflow.
Future<bool> openNewProjectJournal(
  BuildContext context, {
  required String projectId,
  required String? phase,
  required ProjectsRepo projectsRepo,
}) async {
  Widget page;
  final phaseKey = normalizePhase(phase);
  final normalized = phaseKeys.contains(phaseKey) ? phaseKey : 'discover';
  if (normalized != 'prototyping') {
    final choice = await chooseJournalType(context);
    if (choice == null || !context.mounted) return false;
    if (choice == JournalType.freeNotes) {
      await _openNewFreeNotes(context, projectId, normalized, projectsRepo);
      return true;
    }
  }
  switch (normalized) {
    case 'ideating':
      page = IdeatingEntryPage(
        projectId: projectId,
        projectsRepo: projectsRepo,
      );
    case 'implementation':
      page = ImplementationEntryPage(
        projectId: projectId,
        projectsRepo: projectsRepo,
      );
    case 'prototyping':
      final type = await showAppDialog<Object>(
        context: context,
        builder: (_) => const _PrototypeEntryTypeDialog(),
      );
      if (type == null || !context.mounted) return false;
      if (type == JournalType.freeNotes) {
        await _openNewFreeNotes(context, projectId, normalized, projectsRepo);
        return true;
      }
      page = _PrototypingJournalEntryPage(
        projectId: projectId,
        projectsRepo: projectsRepo,
        type: type as _PrototypeEntryType,
      );
    default:
      page = DiscoveryObservationEntryPage(
        projectId: projectId,
        projectsRepo: projectsRepo,
      );
  }
  if (!context.mounted) return false;
  await pushAppPage(context, MaterialPageRoute(builder: (_) => page));
  return true;
}

Future<void> _openNewFreeNotes(
  BuildContext context,
  String projectId,
  String phase,
  ProjectsRepo repo,
) async {
  await pushAppPage(
    context,
    MaterialPageRoute(
      builder: (_) => JournalEntryEditorScreen(
        projectId: projectId,
        projectName: '',
        tags: const [],
        entryId: '',
        initialTitle: '',
        initialContent: const [],
        initialProgress: phase,
        freeNotes: true,
        projectsRepo: repo,
      ),
    ),
  );
}

/// Phase dashboards return to project Development, including direct links.
void _returnToProjectDevelopment(
  BuildContext context,
  String projectId,
  ProjectsRepo repo,
  bool isOwner,
) {
  final navigator = Navigator.of(context);
  var foundProject = false;
  navigator.popUntil((route) {
    final destination = PageRefreshState.instance.describeRoute(route);
    foundProject =
        destination?['kind'] == 'project' &&
        destination?['project'] == projectId;
    return foundProject || route.isFirst;
  });
  final route = MaterialPageRoute<void>(
    builder: (_) => ProjectDashboard(
      projectId: projectId,
      projectName: '',
      tags: const [],
      projectsRepo: repo,
      isOwner: isOwner,
      initialSection: ProjectDashboardSection.development,
    ),
  );
  if (foundProject) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

class ProjectDevelopmentTab extends StatelessWidget {
  const ProjectDevelopmentTab({
    super.key,
    required this.projectId,
    required this.isOwner,
    required this.summary,
    required this.onChanged,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final DevelopmentSummary summary;
  final VoidCallback onChanged;
  final ProjectsRepo projectsRepo;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 22,
          top: 156,
          right: 22,
          height: 124,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _devBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 23,
                        height: 28,
                        child: _JournalLineIcon(),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${summary.totalEntries}',
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          color: _devGreen,
                          fontSize: AppTypography.displaySize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Total Entries',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          color: _devText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 70, color: const Color(0xFFE9E9E9)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Last Updated',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                        ),
                      ),
                      Text(
                        _lastUpdatedDay(summary.lastUpdated),
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.sectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _lastUpdatedTime(summary.lastUpdated),
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < phaseLabels.length; i++)
          Positioned(
            left: 22,
            top: 318 + (i * 94),
            right: 22,
            height: 74,
            child: _PhaseCard(
              phaseNumber: i + 1,
              label: phaseLabels[i],
              count: summary.phaseCounts[phaseKeys[i]] ?? 0,
              onTap: () async {
                if (i == 0) {
                  await pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiscoveryDashboardPage(
                        projectId: projectId,
                        isOwner: isOwner,
                        projectsRepo: projectsRepo,
                      ),
                    ),
                  );
                  onChanged();
                } else if (i == 1) {
                  await pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IdeatingDashboardPage(
                        projectId: projectId,
                        isOwner: isOwner,
                        projectsRepo: projectsRepo,
                      ),
                    ),
                  );
                  onChanged();
                } else if (i == 2) {
                  await pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PrototypingDashboardPage(
                        projectId: projectId,
                        isOwner: isOwner,
                        projectsRepo: projectsRepo,
                      ),
                    ),
                  );
                  onChanged();
                } else {
                  await pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImplementationDashboardPage(
                        projectId: projectId,
                        isOwner: isOwner,
                        projectsRepo: projectsRepo,
                      ),
                    ),
                  );
                  onChanged();
                }
              },
            ),
          ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phaseNumber,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final int phaseNumber;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _devBorder),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x121C1C1C),
              blurRadius: 40,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 22),
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _devGreen),
              ),
              child: Text(
                '$phaseNumber',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.bodySize,
                ),
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devText,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count ${count == 1 ? 'Entry' : 'Entries'}',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.black87,
                fontSize: AppTypography.helperSize,
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// IMPLEMENTATION PHASE (Phase 4 of 4)
// Stages: Overview → Assessment (Impact) → Learning (reused) → Reflection
// ═══════════════════════════════════════════════════════════════════════════

enum _ImplementationStage { overview, assessment, learning, reflection }

const _implementationStageLabels = [
  'Overview',
  'Assessment',
  'Learning',
  'Reflection',
];

bool _isSubmittedImplementationEntry(JournalEntry entry) {
  final reflection = entry.content.whereType<Map>().firstWhere(
    (item) => item['stage']?.toString() == 'reflection',
    orElse: () => const {},
  );
  return reflection['submitted'] == true;
}

Map<String, dynamic> _implementationStageMap(JournalEntry entry, String stage) {
  final match = entry.content.whereType<Map>().firstWhere(
    (item) => item['stage']?.toString() == stage,
    orElse: () => const {},
  );
  return Map<String, dynamic>.from(match);
}

class ImplementationDashboardPage extends StatefulWidget {
  const ImplementationDashboardPage({
    super.key,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;

  @override
  State<ImplementationDashboardPage> createState() =>
      _ImplementationDashboardPageState();
}

class _ImplementationDashboardPageState
    extends State<ImplementationDashboardPage> {
  List<JournalEntry> _entries = [];
  Map<String, double> _ecoPointsByEntry = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    final impacts = await widget.projectsRepo.getImpactEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    final filtered = (entries ?? [])
        .where((e) => normalizePhase(e.progress) == 'implementation')
        .toList();
    final byEntry = <String, double>{};
    for (final imp in impacts ?? const <ImpactEntry>[]) {
      final id = imp.linkedJournalEntryId;
      if (id == null) continue;
      byEntry[id] = (byEntry[id] ?? 0) + imp.ecoPoints;
    }
    setState(() {
      _entries = filtered;
      _ecoPointsByEntry = byEntry;
      _isLoading = false;
    });
  }

  Future<void> _addEntry() async {
    await openNewProjectJournal(
      context,
      projectId: widget.projectId,
      phase: 'implementation',
      projectsRepo: widget.projectsRepo,
    );
    if (mounted) await _load();
  }

  Future<void> _openEntry(JournalEntry entry, {bool edit = false}) async {
    if (await openFreeNotesIfNeeded(
      context,
      entry,
      widget.projectsRepo,
      readOnly:
          (!edit && journalEntryIsComplete(entry)) ||
          (!widget.isOwner &&
              entry.authorId != AuthService.instance.currentUser?.id),
    )) {
      if (mounted) await _load();
      return;
    }

    final submitted = !edit && journalEntryIsComplete(entry);
    await pushAppRoute<void>(
      context,
      MaterialPageRoute(
        builder: (_) => submitted
            ? ImplementationPreviewPage(
                entry: entry,
                projectId: widget.projectId,
                projectsRepo: widget.projectsRepo,
              )
            : ImplementationEntryPage(
                projectId: widget.projectId,
                projectsRepo: widget.projectsRepo,
                entry: entry,
              ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Entry',
      message: 'Delete this implementation entry?',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final deleted = await widget.projectsRepo.deleteJournalEntry(
      entryId: entry.id,
    );
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this entry. Please try again.'),
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ProjectActivityScope(
      projectId: widget.projectId,
      repo: widget.projectsRepo,
      child: _PrototypeScaffold(
        title: 'Implementation',
        onBack: () => _returnToProjectDevelopment(
          context,
          widget.projectId,
          widget.projectsRepo,
          widget.isOwner,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : PageScrollWithFooter(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
                  children: [
                    _PrototypeCountHeader(
                      count: _entries.length,
                      label: 'Entries',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                      decoration: BoxDecoration(
                        color: _devGreen.withValues(alpha: .2),
                        border: Border.all(color: _devGreen),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phase 4 of 4',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _devGreen,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Implementation',
                            style: TextStyle(
                              fontFamily: AppTypography.headingFamily,
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.sectionTitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Implement your solution and document progress, outcomes, observations, and lessons learned throughout this phase.',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.bodySize,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppMetrics.fieldGap),
                    const Divider(color: Color(0xFFE5E5E5)),
                    if (widget.isOwner) ...[
                      const SizedBox(height: 8),
                      _PrototypeOutlinedAction(
                        label: '+ Add Journal Entry',
                        onTap: _addEntry,
                      ),
                    ],
                    const SizedBox(height: AppMetrics.fieldGap),
                    if (_entries.isEmpty) const _EmptyPhaseEntries(),
                    for (var i = 0; i < _entries.length; i++)
                      _ImplementationEntryCard(
                        entry: _entries[i],
                        ecoPoints: _ecoPointsByEntry[_entries[i].id] ?? 0,
                        onTap: () => _openEntry(_entries[i]),
                        onEdit: () => _openEntry(_entries[i], edit: true),
                        onDelete: widget.isOwner
                            ? () => _deleteEntry(_entries[i])
                            : null,
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ImplementationEntryCard extends StatelessWidget {
  const _ImplementationEntryCard({
    required this.entry,
    required this.ecoPoints,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  });

  final JournalEntry entry;
  final double ecoPoints;
  final VoidCallback onTap;
  final VoidCallback? onDelete, onEdit;

  @override
  Widget build(BuildContext context) => JournalLogEntryCard(
    entry: entry,
    phaseLabel: 'IMPLEMENTATION',
    ecoPoints: ecoPoints,
    status: JournalCompletionTag(entry: entry),
    imageUrls: journalContentImageUrls(entry.content),
    onTap: onTap,
    onDelete: onDelete,
    onEdit: onEdit,
  );
}

class _ImplementationStageTracker extends StatelessWidget {
  const _ImplementationStageTracker({
    required this.activeIndex,
    this.onSelected,
    this.visitedIndices,
    this.completion,
    this.inputs,
  });
  final int activeIndex;
  final Set<int>? visitedIndices;
  final Set<int> Function()? completion;
  final Listenable? inputs;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: _StageHeader(
      visitedIndices: visitedIndices,
      completion: completion,
      inputs: inputs,
      activeIndex: activeIndex,
      labels: _implementationStageLabels,
      onSelected: onSelected,
    ),
  );
}

class _ImplementationHeader extends StatelessWidget {
  const _ImplementationHeader({
    required this.title,
    this.titleController,
    required this.onBack,
    required this.trailingLabel,
    required this.onTrailing,
  });

  final String title;
  final TextEditingController? titleController;
  final VoidCallback onBack;
  final String trailingLabel;
  final VoidCallback onTrailing;

  @override
  Widget build(BuildContext context) => _PrototypeTopBar(
    title: title,
    titleController: titleController,
    onBack: onBack,
    trailingLabel: trailingLabel == 'Save' || trailingLabel == 'Saving...'
        ? null
        : trailingLabel,
    onTrailing: onTrailing,
  );
}

class ImplementationEntryPage extends StatefulWidget {
  const ImplementationEntryPage({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.entry,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final JournalEntry? entry;

  @override
  State<ImplementationEntryPage> createState() =>
      _ImplementationEntryPageState();
}

class _ImplementationEntryPageState extends State<ImplementationEntryPage>
    with DraftAutosave<ImplementationEntryPage> {
  @override
  String get failedDraftLabel => _draftSession.failureLabel;
  @override
  String get savedDraftLabel => _draftSession.current == null
      ? ''
      : _draftSession.kept
      ? 'Saved'
      : 'Autosaved';
  late final _draftSession = JournalDraftSession(
    widget.projectsRepo,
    widget.projectId,
    initial: widget.entry,
    onKept: (id) {
      if (mounted) setState(() => _entryId = id);
    },
  );

  bool _assessmentComplete = false;
  var _stage = _ImplementationStage.overview;
  String? _entryId;
  bool _isSaving = false;
  bool _hasChanges = false;
  int _entryNumber = 1;
  final _entryTitle = TextEditingController();

  final List<UserProfile> _participantMembers = [];
  final Set<String> _participantIds = {};
  Future<void> _loadParticipants() async {
    final members = await widget.projectsRepo.getProjectMembers(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _participantMembers
        ..clear()
        ..addAll(members);
      if (widget.entry == null) {
        final author = journalRepoUserId(widget.projectsRepo);
        if (author != null && members.any((p) => p.id == author))
          _participantIds.add(author);
      }
    });
  }

  final _summary = TextEditingController();
  final _location = TextEditingController();
  DateTime? _dateImplemented;
  final List<_EvidenceBlock> _evidence = [];

  final Set<String> _selectedDci = {};
  final Set<String> _selectedSep = {};
  final Set<String> _selectedCcc = {};
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _learningAssessment = const AssessmentBlockData();

  late bool _hasBeenSubmitted =
      widget.entry?.content.whereType<Map>().any(
        (row) => row['stage'] == 'reflection' && row['submitted'] == true,
      ) ??
      false;
  final _worked = TextEditingController();
  final _notWorked = TextEditingController();
  final _takeaways = TextEditingController();
  final _change = TextEditingController();

  late final Set<int> _visitedStages = _readVisitedStages(
    widget.entry?.content,
    ['overview', 'assessment', 'learning', 'reflection'],
  );

  @override
  void initState() {
    super.initState();
    _hydrate();
    _participantIds.addAll(widget.entry?.participantIds ?? {});
    _loadParticipants();
    _resolveEntryNumber();
  }

  @override
  void dispose() {
    _entryTitle.dispose();
    _summary.dispose();
    _location.dispose();
    _worked.dispose();
    _notWorked.dispose();
    _takeaways.dispose();
    _change.dispose();
    super.dispose();
  }

  Future<void> _resolveEntryNumber() async {
    if (widget.entry != null) return;
    final entries = await widget.projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    final count = (entries ?? [])
        .where((e) => normalizePhase(e.progress) == 'implementation')
        .length;
    setState(() => _entryNumber = count + 1);
  }

  void _hydrate() {
    final entry = widget.entry;
    _assessmentComplete =
        (entry?.content.whereType<Map>().any(
          (row) => row['stage'] == 'assessment' && row['complete'] == true,
        ) ??
        false);
    if (entry == null) return;
    final savedStage = restoredJournalStage(
      entry.content,
      _ImplementationStage.values.length,
    );
    _stage = _ImplementationStage.values[savedStage];
    _entryId = entry.id;
    if (!RegExp(r'^Entry \d+:').hasMatch(entry.title))
      _entryTitle.text = entry.title;
    final match = RegExp(r'Entry (\d+)').firstMatch(entry.title);
    if (match != null) {
      _entryNumber = int.tryParse(match.group(1) ?? '') ?? 1;
    }
    final overview = _implementationStageMap(entry, 'overview');
    _summary.text = overview['summary']?.toString() ?? '';
    _location.text = overview['location']?.toString() ?? '';
    _dateImplemented = DateTime.tryParse(
      overview['dateImplemented']?.toString() ?? '',
    );
    _evidence.addAll(
      _maps(
        overview['evidence'],
      ).map(_EvidenceBlock.fromMap).whereType<_EvidenceBlock>(),
    );
    final learning = _implementationStageMap(entry, 'learning');
    _selectedDci.addAll(_stringSet(learning['dci']));
    _selectedSep.addAll(_stringSet(learning['sep']));
    _selectedCcc.addAll(_stringSet(learning['ccc']));
    _inquiryLensData = InquiryLensData.fromJson(
      learning['inquiryLensData'],
      legacyLens:
          learning['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
    );
    _learningAssessment = AssessmentBlockData.fromJson(learning['assessment']);
    final reflection = _implementationStageMap(entry, 'reflection');
    _worked.text = reflection['workedWell']?.toString() ?? '';
    _notWorked.text = reflection['didntWork']?.toString() ?? '';
    _takeaways.text = reflection['keyTakeaways']?.toString() ?? '';
    _change.text = reflection['change']?.toString() ?? '';
  }

  List<dynamic> _buildContent({required bool submitted}) {
    return [
      {
        'stage': '_navigation',
        'currentStage': _stage.index,
        'visitedStages': _visitedStages.toList()..sort(),
      },
      {
        'stage': 'overview',
        'involved': journalParticipantRows(
          _participantIds,
          _participantMembers,
          previous: widget.entry?.content ?? const [],
        ),
        'summary': _summary.text.trim(),
        'dateImplemented': _dateImplemented?.toIso8601String(),
        'location': _location.text.trim(),
        'evidence': _evidence.map((e) => e.toMap()).toList(),
      },
      {'stage': 'assessment', 'complete': _assessmentComplete},
      {
        'stage': 'learning',
        'dci': _selectedDci.toList(),
        'sep': _selectedSep.toList(),
        'ccc': _selectedCcc.toList(),
        'inquiryLens': _inquiryLensData.selectedLens,
        'inquiryLensData': _inquiryLensData.toJson(),
        'assessment': _learningAssessment.toJson(),
      },
      {
        'stage': 'reflection',
        'workedWell': _worked.text.trim(),
        'didntWork': _notWorked.text.trim(),
        'keyTakeaways': _takeaways.text.trim(),
        'change': _change.text.trim(),
        'submitted': submitted || _hasBeenSubmitted,
        if (submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
  }

  @override
  String get draftFingerprint =>
      jsonEncode([_entryTitle.text, _buildContent(submitted: false)]);
  @override
  Future<bool> writeAutosave() => _writeDraft();
  Future<bool> _save({bool submitted = false}) =>
      serializeDraft(() => _writeDraft(submitted: submitted));
  Future<bool> _writeDraft({bool submitted = false}) async {
    setState(() => _isSaving = true);
    final content = _buildContent(submitted: submitted);
    final title = journalEntryTitle(
      _entryTitle.text,
      _entryNumber,
      'Implementation',
    );
    if (await _draftSession.skipEmpty(title, content)) {
      _entryId = null;
      if (mounted) setState(() => _isSaving = false);
      return true;
    }
    var ok = false;
    if (_entryId == null) {
      final created = await _draftSession.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        content: content,
        progress: 'implementation',
      );
      _entryId = created?.id;
      ok = created != null;
    } else {
      ok = await _draftSession.updateJournalEntry(
        entryId: _entryId!,
        title: title,
        content: content,
        progress: 'implementation',
      );
    }
    if (!mounted) return ok;
    _hasChanges = _hasChanges || ok;
    if (ok && submitted) _hasBeenSubmitted = true;
    setState(() => _isSaving = false);
    return ok;
  }

  Future<void> _next() async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_buildContent(submitted: false)),
      _stage.index,
      _stage.index + 1,
      _implementationStageLabels,
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _ImplementationStage.values[_stage.index + 1]);
  }

  void _back() async {
    await flushDraft();
    if (!mounted) return;
    if (_stage.index == 0) {
      Navigator.of(context).maybePop(_hasChanges);
      return;
    }
    setState(() => _stage = _ImplementationStage.values[_stage.index - 1]);
  }

  Future<void> _submit() async {
    if (_hasBeenSubmitted) {
      final ok = await flushDraft();
      if (mounted && ok) Navigator.of(context).maybePop(true);
      return;
    }
    if (!_canSubmitJournal(
      context,
      completedJournalStageIndices(_buildContent(submitted: false)),
      _implementationStageLabels,
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    final ok = await _save(submitted: true);
    if (!mounted || !ok) return;
    JournalPublication.returnHome(context);
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _addEvidence() async {
    final type = await showAppDialog<String>(
      context: context,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(
      context,
      type,
      null,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence[index] = block);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateImplemented ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null && mounted) {
      setState(() => _dateImplemented = picked);
    }
  }

  @override
  Widget build(BuildContext context) => JournalDraftGuard(
    session: _draftSession,
    flush: flushDraft,
    section: const [
      'overview',
      'assessment',
      'learning',
      'reflection',
    ][_stage.index],
    sections: const {
      'overview': 'Overview',
      'assessment': 'Assessment',
      'learning': 'Learning',
      'reflection': 'Reflection',
    },
    onSectionSelected: (key) => setState(
      () => _stage =
          _ImplementationStage.values[const [
            'overview',
            'assessment',
            'learning',
            'reflection',
          ].indexOf(key)],
    ),
    child: _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Column(
              children: [
                _ImplementationHeader(
                  title: journalEntryTitle('', _entryNumber, 'Implementation'),
                  titleController: _entryTitle,
                  onBack: () => Navigator.of(context).maybePop(_hasChanges),
                  trailingLabel: _isSaving ? 'Saving...' : 'Save',
                  onTrailing: () => _save(),
                ),
                _ImplementationStageTracker(
                  completion: () => completedJournalStageIndices(
                    _buildContent(submitted: false),
                  ),
                  inputs: Listenable.merge([
                    _summary,
                    _worked,
                    _notWorked,
                    _takeaways,
                    _change,
                  ]),
                  visitedIndices: _visitedStages,
                  activeIndex: _stage.index,
                  onSelected: (index) async {
                    await flushDraft();
                    if (mounted)
                      setState(
                        () => _stage = _ImplementationStage.values[index],
                      );
                  },
                ),
                Expanded(child: _buildStage()),
                _DraftSaveStatus(status: draftSaveStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _ImplementationStage.overview:
        return _overviewBody();
      case _ImplementationStage.assessment:
        return _ImplementationAssessmentBody(
          projectId: widget.projectId,
          projectName: 'Entry $_entryNumber',
          entryId: _entryId,
          projectsRepo: widget.projectsRepo,
          readOnly: false,
          isDraft:
              widget.entry == null || !journalEntryIsComplete(widget.entry!),
          onCompletionChanged: (complete) {
            if (mounted && _assessmentComplete != complete)
              setState(() => _assessmentComplete = complete);
          },
          onBack: _back,
          onNext: _next,
        );
      case _ImplementationStage.learning:
        return Padding(
          padding: JournalPageLayout.stagePadding,
          child: JournalLearningStageBody(
            selectedDci: _selectedDci,
            selectedSep: _selectedSep,
            selectedCcc: _selectedCcc,
            inquiryLensData: _inquiryLensData,
            assessment: _learningAssessment,
            isSaving: _isSaving,
            onToggleDci: (v) => _toggle(_selectedDci, v),
            onToggleSep: (v) => _toggle(_selectedSep, v),
            onToggleCcc: (v) => _toggle(_selectedCcc, v),
            onInquiryLensChanged: (v) => setState(() => _inquiryLensData = v),
            onSaveAssessment: flushDraft,
            onAssessmentChanged: (v) => setState(() => _learningAssessment = v),
            onBack: _back,
            onNext: _next,
          ),
        );
      case _ImplementationStage.reflection:
        return _reflectionBody();
    }
  }

  Widget _overviewBody() {
    return _JournalStageLayout(
      padding: const EdgeInsets.fromLTRB(
        JournalPageLayout.horizontalInset,
        JournalPageLayout.stageGap,
        JournalPageLayout.horizontalInset,
        24,
      ),
      children: [
        const JournalSectionHeader(title: 'Overview'),
        _LabeledBox(
          label: 'Implementation Title',
          controller: _entryTitle,
          optional: true,
          height: 64,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Summary',
          helperText: 'Describe what was implemented and who was involved.',
          controller: _summary,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const OptionalFieldLabel(
          'Date Implemented (Optional)',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        AppTapTarget(
          onTap: _pickDate,
          child: Container(
            width: 152,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: _devGreen),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _dateImplemented == null
                          ? 'mm/dd/yy'
                          : DateFormat('MM/dd/yy').format(_dateImplemented!),
                      style: TextStyle(
                        color: _dateImplemented == null
                            ? const Color(0xFF9A9A9A)
                            : const Color(0xFF1F2024),
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/prototyping/chevron_down.svg',
                  width: 14,
                  height: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Location',
          optional: true,
          controller: _location,
          height: 36,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const JournalSectionHeader(title: 'Evidence (Optional)'),
        if (_evidence.isEmpty)
          const _EmptyEvidenceState()
        else
          for (var i = 0; i < _evidence.length; i++)
            _EvidenceSummaryCard(
              evidence: _evidence[i],
              onTap: () => _editEvidence(i),
              onDelete: () => setState(() => _evidence.removeAt(i)),
            ),
        const SizedBox(height: 12),
        Center(
          child: AppTapTarget(
            onTap: _addEvidence,
            child: Container(
              width: 202,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+ Add Evidence Block',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text('Who is involved?', style: AppTypography.fieldLabel),
        const SizedBox(height: 6),
        const Text(
          'Selected participants can edit this journal entry.',
          style: AppTypography.helper,
        ),
        const SizedBox(height: 12),
        JournalInvolvedPeopleField(
          creatorId:
              widget.entry?.authorId ?? journalRepoUserId(widget.projectsRepo),
          members: _participantMembers,
          selectedIds: _participantIds,
          onToggle: (id) => setState(() {
            if (!_participantIds.add(id)) _participantIds.remove(id);
          }),
        ),
      ],
      footer: Center(
        child: _SmallStageButton(label: 'Next', filled: true, onTap: _next),
      ),
    );
  }

  Widget _reflectionBody() {
    return _JournalStageLayout(
      padding: const EdgeInsets.fromLTRB(
        JournalPageLayout.horizontalInset,
        JournalPageLayout.stageGap,
        JournalPageLayout.horizontalInset,
        24,
      ),
      children: [
        const JournalSectionHeader(title: 'Reflection'),
        _LabeledBox(
          label: 'What worked well?',
          controller: _worked,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: "What didn't work well?",
          controller: _notWorked,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Key Takeaways',
          helperText: 'Describe the key learnings from the project.',
          controller: _takeaways,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'What would you change?',
          controller: _change,
          maxLines: 4,
        ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: _back),
          const SizedBox(width: 21),
          _SmallStageButton(
            label: _hasBeenSubmitted ? 'Done' : 'Submit',
            filled: true,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}

class _ImplementationAssessmentBody extends StatefulWidget {
  const _ImplementationAssessmentBody({
    required this.projectId,
    required this.projectName,
    required this.entryId,
    required this.projectsRepo,
    required this.readOnly,
    required this.onBack,
    required this.onNext,
    this.onCompletionChanged,
    this.isDraft = true,
  });

  final ValueChanged<bool>? onCompletionChanged;
  final String projectId;
  final String projectName;
  final String? entryId;
  final ProjectsRepo projectsRepo;
  final bool readOnly;
  final bool isDraft;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<_ImplementationAssessmentBody> createState() =>
      _ImplementationAssessmentBodyState();
}

class _ImplementationAssessmentBodyState
    extends State<_ImplementationAssessmentBody> {
  List<ImpactEntry> _impacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await widget.projectsRepo.getImpactEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _impacts = (all ?? const <ImpactEntry>[])
          .where((e) => e.linkedJournalEntryId == widget.entryId)
          .map(
            (e) => widget.isDraft
                ? ImpactEntry(
                    id: e.id,
                    projectId: e.projectId,
                    title: e.title,
                    metric: e.metric,
                    impactScale: e.impactScale,
                    patternType: e.patternType,
                    evidenceType: e.evidenceType,
                    confidenceScore: e.confidenceScore,
                    measurement: e.measurement,
                    measurementUnit: e.measurementUnit,
                    linkedJournalEntryId: e.linkedJournalEntryId,
                    createdAt: e.createdAt,
                    updatedAt: e.updatedAt,
                    ecoPoints: calculateEcoPoints(
                      impactScale: e.impactScale,
                      confidenceScore: e.confidenceScore,
                      measurement: e.measurement,
                      measurementUnit: e.measurementUnit,
                    ).roundToDouble(),
                  )
                : e,
          )
          .toList();
      _loading = false;
    });
    widget.onCompletionChanged?.call(true);
  }

  double get _total => _impacts.fold(0.0, (sum, e) => sum + e.ecoPoints);

  Future<void> _addImpact() async {
    final draft = JournalDraftScope.of(context);
    String? entryId = widget.entryId;
    if (draft != null) {
      // Impacts need a database UUID, not an on-device recovery draft ID.
      if (!await draft.save()) return;
      entryId = draft.session.current?.id;
    }
    if (!mounted ||
        entryId == null ||
        entryId.startsWith(JournalDraftSession.prefix)) {
      return;
    }
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ImpactEntryFormScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          initialTitle: 'Impact ${_impacts.length + 1}',
          lockedJournalEntryId: entryId,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteImpact(ImpactEntry impact) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Impact',
      message: 'Delete this impact?',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    await widget.projectsRepo.deleteImpactEntry(entryId: impact.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return _JournalStageLayout(
      padding: JournalPageLayout.stagePadding,
      children: [
        const JournalSectionHeader(title: 'Impact (Optional)'),
        if (widget.isDraft && !widget.readOnly) ...[
          const Text(
            'Impact EcoPoints are calculated when you save an impact. They are added to your profile when you complete this journal entry.',
            style: AppTypography.helper,
          ),
          const SizedBox(height: AppMetrics.contentGap),
        ],
        const Text(
          'Adding an impact is optional.',
          style: AppTypography.helper,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.readOnly
                    ? 'Impacts (${_impacts.length})'
                    : 'Your Impacts (${_impacts.length})',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!widget.readOnly)
              AppTapTarget(
                onTap: _addImpact,
                child: const Text(
                  '+ Add Impact',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.primary,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final impact in _impacts)
          _ImplementationImpactCard(
            impact: impact,
            pending: false,
            onEdit: widget.readOnly
                ? null
                : () async {
                    await pushAppRoute(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ImpactEntryFormScreen(
                          projectId: widget.projectId,
                          projectName: widget.projectName,
                          existing: impact,
                          lockedJournalEntryId: widget.entryId,
                        ),
                      ),
                    );
                    if (mounted) await _load();
                  },
            onDelete: widget.readOnly ? null : () => _deleteImpact(impact),
          ),
        const SizedBox(height: 16),
        const Text(
          'Total Impact',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _ImplementationTotalCard(impacts: _impacts, total: _total),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: widget.onBack),
          const SizedBox(width: 12),
          _SmallStageButton(label: 'Next', filled: true, onTap: widget.onNext),
        ],
      ),
    );
  }
}

String _implementationMetricIcon(String metric) => switch (metric) {
  'Education' => 'assets/impact/metric_education.png',
  'Energy' => 'assets/impact/metric_energy.png',
  'Waste' => 'assets/impact/metric_waste.png',
  'Water' => 'assets/impact/metric_water.png',
  _ => 'assets/impact/metric_biological.png',
};

// Gentle elevation distinguishes nested white cards without darkening surfaces.
const _nestedPreviewShadow = [
  BoxShadow(color: Color(0x0D1F2024), blurRadius: 12, offset: Offset(0, 3)),
];

class _ImplementationImpactCard extends StatelessWidget {
  const _ImplementationImpactCard({
    required this.impact,
    this.onDelete,
    this.onEdit,
    this.pending = false,
  });
  final VoidCallback? onEdit;

  final ImpactEntry impact;
  final bool pending;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scaleName = impact.impactScale.split(' (').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        boxShadow: _nestedPreviewShadow,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFCCCCCC)),
                ),
                child: Image.asset(
                  _implementationMetricIcon(impact.metric),
                  width: 26,
                  height: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      impact.metric,
                      style: const TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (impact.patternType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _devGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          impact.patternType.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: Colors.white,
                            fontSize: AppTypography.captionSize,
                            fontWeight: FontWeight.w400,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onDelete != null)
                ItemActionMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          const SizedBox(height: AppMetrics.sectionGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Measurement',
                    value: impact.measurement == null
                        ? '—'
                        : (impact.measurement ==
                                  impact.measurement!.roundToDouble()
                              ? impact.measurement!.toStringAsFixed(0)
                              : impact.measurement!.toStringAsFixed(2)),
                    unit: impact.measurementUnit,
                  ),
                ),
                const VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: Color(0xFFCCCCCC),
                ),
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Impact Scale',
                    value: scaleName,
                    valueIcon:
                        'assets/impact/scale_${switch (scaleName.toLowerCase()) {
                          'sapling' => 'sapling',
                          'grove' => 'grove',
                          'forest' => 'forest',
                          'watershed' => 'watershed',
                          _ => 'seed',
                        }}.png',
                    valueColor: _devGreen,
                  ),
                ),
                const VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: Color(0xFFCCCCCC),
                ),
                _ImplementationEcoCircle(
                  ecoPoints: impact.ecoPoints,
                  pending: pending,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E5E5)),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Evidence Type',
                    value: impact.evidenceType,
                  ),
                ),
                const VerticalDivider(
                  width: 32,
                  thickness: 1,
                  color: Color(0xFFCCCCCC),
                ),
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Confidence',
                    value: impact.confidenceScore,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImplementationImpactField extends StatelessWidget {
  const _ImplementationImpactField({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueIcon,
    this.unit,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final String? valueIcon;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (valueIcon != null) ...[
              Image.asset(valueIcon!, width: 28, height: 28),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                value,
                style: AppTypography.fieldLabel.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (unit != null && unit!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(unit!, style: AppTypography.body),
        ],
      ],
    );
  }
}

class _ImplementationEcoCircle extends StatelessWidget {
  const _ImplementationEcoCircle({
    required this.ecoPoints,
    this.pending = false,
  });

  final bool pending;

  final double ecoPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pending ? 'Pending' : ecoPoints.toStringAsFixed(0),
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              color: _devGreen,
              fontSize: pending
                  ? AppTypography.helperSize
                  : AppTypography.sectionTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            pending ? 'completion' : 'EcoPoints',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _devGreen,
              fontSize: AppTypography.captionSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImplementationTotalCard extends StatelessWidget {
  const _ImplementationTotalCard({required this.impacts, required this.total});

  final List<ImpactEntry> impacts;
  final double total;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final impact in impacts) {
      totals.update(
        impact.metric,
        (value) => value + impact.ecoPoints,
        ifAbsent: () => impact.ecoPoints,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final metric in totals.keys) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  _implementationMetricIcon(metric),
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    metric,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                ),
                Text(
                  '${totals[metric]!.toStringAsFixed(0)} EcoPoints',
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _devGreen,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E5E5)),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/project_setup/card_eco_leaf.svg',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Total',
                textHeightBehavior: TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${total.toStringAsFixed(0)} EcoPoints',
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                      applyHeightToLastDescent: false,
                    ),
                    style: const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      color: _devGreen,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ImplementationPreviewPage extends StatefulWidget {
  const ImplementationPreviewPage({
    super.key,
    required this.entry,
    required this.projectId,
    required this.projectsRepo,
  });

  final JournalEntry entry;
  final String projectId;
  final ProjectsRepo projectsRepo;

  @override
  State<ImplementationPreviewPage> createState() =>
      _ImplementationPreviewPageState();
}

class _ImplementationPreviewPageState extends State<ImplementationPreviewPage> {
  late final _previewImpacts = widget.projectsRepo.getImpactEntries(
    projectId: widget.projectId,
  );
  var _stage = 0;

  String _summary = '';
  String _location = '';
  DateTime? _date;
  List<_EvidenceBlock> _evidence = [];

  final Set<String> _dci = {};
  final Set<String> _sep = {};
  final Set<String> _ccc = {};
  InquiryLensData _lens = const InquiryLensData();
  AssessmentBlockData _assessment = const AssessmentBlockData();

  String _worked = '';
  String _notWorked = '';
  String _takeaways = '';
  String _change = '';

  late final Set<int> _visitedStages = _readVisitedStages(
    widget.entry.content,
    ['overview', 'assessment', 'learning', 'reflection'],
  );
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final ov = _implementationStageMap(e, 'overview');
    _summary = ov['summary']?.toString() ?? '';
    _location = ov['location']?.toString() ?? '';
    _date = DateTime.tryParse(ov['dateImplemented']?.toString() ?? '');
    _evidence = _maps(
      ov['evidence'],
    ).map(_EvidenceBlock.fromMap).whereType<_EvidenceBlock>().toList();
    final l = _implementationStageMap(e, 'learning');
    _dci.addAll(_stringSet(l['dci']));
    _sep.addAll(_stringSet(l['sep']));
    _ccc.addAll(_stringSet(l['ccc']));
    _lens = InquiryLensData.fromJson(
      l['inquiryLensData'],
      legacyLens: l['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
    );
    _assessment = AssessmentBlockData.fromJson(l['assessment']);
    final r = _implementationStageMap(e, 'reflection');
    _worked = r['workedWell']?.toString() ?? '';
    _notWorked = r['didntWork']?.toString() ?? '';
    _takeaways = r['keyTakeaways']?.toString() ?? '';
    _change = r['change']?.toString() ?? '';
  }

  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return _PrototypeScaffold(
      title: 'Journal Entry: Implementation',
      previewEntry: widget.entry,
      onBack: _exit,
      body: PageScrollWithFooter(
        child: ListView(
          padding: const EdgeInsets.all(40),
          children: [
            Text(widget.entry.title, style: AppTypography.pageTitle),
            const SizedBox(height: AppMetrics.fieldGap),
            _PreviewPanel(
              title: 'Overview',
              children: [
                _PreviewField('Summary', _summary),
                if (_date != null)
                  _PreviewField(
                    'Date',
                    DateFormat('MMMM d, yyyy').format(_date!),
                  ),
                _PreviewField('Location', _location),
                JournalInvolvedPeoplePreview(
                  people: _maps(
                    _implementationStageMap(
                      widget.entry,
                      'overview',
                    )['involved'],
                  ),
                ),
                if (_evidence.isNotEmpty) ...[
                  const JournalSectionHeader(title: 'Evidence'),
                  for (final block in _evidence)
                    _EvidencePreviewBlock(evidence: block),
                ],
              ],
            ),
            _PreviewPanel(
              title: 'Assessment',
              children: [
                FutureBuilder<List<ImpactEntry>?>(
                  future: _previewImpacts,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    return Column(
                      children: [
                        for (final impact in snapshot.data!.where(
                          (impact) =>
                              impact.linkedJournalEntryId == widget.entry.id,
                        ))
                          _ImplementationImpactCard(impact: impact),
                      ],
                    );
                  },
                ),
              ],
            ),
            _LearningPreviewContent(
              reflection: _takeaways,
              selectedDci: _dci,
              selectedSep: _sep,
              selectedCcc: _ccc,
              inquiryLensData: _lens,
              assessment: _assessment,
            ),
            _PreviewPanel(
              title: 'Reflection',
              children: [
                _PreviewField('What worked well?', _worked),
                _PreviewField('What did not work?', _notWorked),
                _PreviewField('What would you change?', _change),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImplPreviewSection extends StatelessWidget {
  const _ImplPreviewSection({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body.isEmpty ? 'Not provided.' : body,
            style: TextStyle(
              color: body.isEmpty
                  ? const Color(0xFFB0B0B0)
                  : const Color(0xFF838383),
              fontSize: AppTypography.bodySize,
              height: 1.3,
              fontWeight: FontWeight.w400,
              fontStyle: body.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class PhasePlaceholderPage extends StatelessWidget {
  const PhasePlaceholderPage({
    super.key,
    required this.phaseNumber,
    required this.phaseLabel,
  });

  final int phaseNumber;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 41,
                  top: 38,
                  child: ContentAlignedBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  left: 70,
                  right: 70,
                  top: 78,
                  child: Text(
                    phaseLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Positioned(
                  left: 41,
                  top: 174,
                  width: 361,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: _devGreen.withValues(alpha: .12),
                      border: Border.all(color: _devGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Phase $phaseNumber of 4\n$phaseLabel',
                      style: const TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DiscoveryDashboardPage extends StatefulWidget {
  const DiscoveryDashboardPage({
    super.key,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;

  @override
  State<DiscoveryDashboardPage> createState() => _DiscoveryDashboardPageState();
}

class _DiscoveryDashboardPageState extends State<DiscoveryDashboardPage> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _entries = (entries ?? [])
          .where((entry) => normalizePhase(entry.progress) == 'discover')
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _openEntry() async {
    await openNewProjectJournal(
      context,
      projectId: widget.projectId,
      phase: 'discover',
      projectsRepo: widget.projectsRepo,
    );
    if (mounted) await _load();
  }

  Future<void> _editEntry(JournalEntry entry, {bool edit = false}) async {
    if (await openFreeNotesIfNeeded(
      context,
      entry,
      widget.projectsRepo,
      readOnly:
          (!edit && journalEntryIsComplete(entry)) ||
          (!widget.isOwner &&
              entry.authorId != AuthService.instance.currentUser?.id),
    )) {
      if (mounted) await _load();
      return;
    }

    if (!edit && journalEntryIsComplete(entry)) {
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => DiscoveryEntryPreviewPage(entry: entry),
        ),
      );
      return;
    }
    if (!widget.isOwner &&
        (entry.authorId == null ||
            entry.authorId != AuthService.instance.currentUser?.id)) {
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => DiscoveryEntryPreviewPage(entry: entry),
        ),
      );
      return;
    }
    final changed = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DiscoveryObservationEntryPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entry: entry,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (!await _confirmPrototypeDelete(
          context,
          title: 'Delete Entry',
          message: 'Delete this journal entry?',
          action: 'Delete',
        ) ||
        !mounted)
      return;
    final ok = await widget.projectsRepo.deleteJournalEntry(entryId: entry.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this entry. Please try again.'),
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _PhaseDashboardScaffold(
      projectId: widget.projectId,
      projectsRepo: widget.projectsRepo,
      title: 'Discovery',
      phaseNumber: 1,
      description:
          'Explore the problem through research, observations, and stakeholder engagement. Document key insights that will guide your project.',
      entries: _entries,
      isLoading: _isLoading,
      isOwner: widget.isOwner,
      badgeLabel: 'DISCOVERY',
      onBack: () => _returnToProjectDevelopment(
        context,
        widget.projectId,
        widget.projectsRepo,
        widget.isOwner,
      ),
      onAddEntry: _openEntry,
      onOpenEntry: _editEntry,
      onDeleteEntry: _deleteEntry,
      onEditEntry: (entry) => _editEntry(entry, edit: true),
    );
  }
}

/// Walks a journal entry's content JSON for the first image the user added
/// (from an "Images" evidence block). Returns null when there is none.
List<String> journalContentImageUrls(List<dynamic> content) =>
    journalPreviewImageSources(content);

class _DiscoveryEntryCard extends StatelessWidget {
  const _DiscoveryEntryCard({
    required this.entry,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  });

  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete, onEdit;

  @override
  Widget build(BuildContext context) => JournalLogEntryCard(
    entry: entry,
    phaseLabel: 'DISCOVERY',
    status: JournalCompletionTag(entry: entry),
    imageUrls: journalContentImageUrls(entry.content),
    onTap: onTap,
    onDelete: onDelete,
    onEdit: onEdit,
  );
}

class IdeatingDashboardPage extends StatefulWidget {
  const IdeatingDashboardPage({
    super.key,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;

  @override
  State<IdeatingDashboardPage> createState() => _IdeatingDashboardPageState();
}

class _IdeatingDashboardPageState extends State<IdeatingDashboardPage> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _entries = (entries ?? [])
          .where((entry) => normalizePhase(entry.progress) == 'ideating')
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _openEntry([JournalEntry? entry]) async {
    if (entry == null) {
      await openNewProjectJournal(
        context,
        projectId: widget.projectId,
        phase: 'ideating',
        projectsRepo: widget.projectsRepo,
      );
      if (mounted) await _load();
      return;
    }
    if (await openFreeNotesIfNeeded(
      context,
      entry,
      widget.projectsRepo,
      readOnly:
          journalEntryIsComplete(entry) ||
          (!widget.isOwner &&
              entry.authorId != AuthService.instance.currentUser?.id),
    )) {
      if (mounted) await _load();
      return;
    }

    if (journalEntryIsComplete(entry)) {
      await pushAppRoute<void>(
        context,
        MaterialPageRoute(
          builder: (_) => IdeatingEntryPreviewPage(entry: entry),
        ),
      );
      return;
    }
    final changed = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IdeatingEntryPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entry: entry,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _editEntry(JournalEntry entry) async {
    if (await openFreeNotesIfNeeded(
      context,
      entry,
      widget.projectsRepo,
      readOnly:
          (!widget.isOwner &&
          entry.authorId != AuthService.instance.currentUser?.id),
    )) {
      if (mounted) await _load();
      return;
    }

    final changed = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => IdeatingEntryPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entry: entry,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (!await _confirmPrototypeDelete(
          context,
          title: 'Delete Entry',
          message: 'Delete this journal entry?',
          action: 'Delete',
        ) ||
        !mounted)
      return;
    final ok = await widget.projectsRepo.deleteJournalEntry(entryId: entry.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this entry. Please try again.'),
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _PhaseDashboardScaffold(
      projectId: widget.projectId,
      projectsRepo: widget.projectsRepo,
      title: 'Ideating',
      phaseNumber: 2,
      description:
          'Generate possible solutions, compare them with a decision matrix, and choose the strongest direction for your project.',
      entries: _entries,
      isLoading: _isLoading,
      isOwner: widget.isOwner,
      badgeLabel: 'IDEATING',
      onBack: () => _returnToProjectDevelopment(
        context,
        widget.projectId,
        widget.projectsRepo,
        widget.isOwner,
      ),
      onAddEntry: () => _openEntry(),
      onOpenEntry: _openEntry,
      onDeleteEntry: _deleteEntry,
      onEditEntry: _editEntry,
    );
  }
}

class PrototypingDashboardPage extends StatefulWidget {
  const PrototypingDashboardPage({
    super.key,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;

  @override
  State<PrototypingDashboardPage> createState() =>
      _PrototypingDashboardPageState();
}

class _PrototypingDashboardPageState extends State<PrototypingDashboardPage> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await widget.projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _entries = (entries ?? [])
          .where((entry) => normalizePhase(entry.progress) == 'prototyping')
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _addEntry() async {
    await openNewProjectJournal(
      context,
      projectId: widget.projectId,
      phase: 'prototyping',
      projectsRepo: widget.projectsRepo,
    );
    if (mounted) await _load();
  }

  Future<void> _openEntry(JournalEntry entry, {bool edit = false}) async {
    if (await openFreeNotesIfNeeded(
      context,
      entry,
      widget.projectsRepo,
      readOnly:
          (!edit && journalEntryIsComplete(entry)) ||
          (!widget.isOwner &&
              entry.authorId != AuthService.instance.currentUser?.id),
    )) {
      if (mounted) await _load();
      return;
    }

    final type = _PrototypeEntryType.parse(
      _prototypeEntryData(entry)['entryType'],
    );
    if (type != null) {
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => PrototypingJournalEntryPage(
            projectId: widget.projectId,
            projectsRepo: widget.projectsRepo,
            entry: entry,
            readOnly:
                (!edit && journalEntryIsComplete(entry)) ||
                (!widget.isOwner &&
                    entry.authorId != AuthService.instance.currentUser?.id),
          ),
        ),
      );
    } else {
      // Existing nested prototype records remain accessible without rewriting or deleting them.
      final records = _prototypeIterationsFromEntry(entry);
      if (records.isEmpty) return;
      final record = records.length == 1
          ? records.first
          : await showAppDialog<_PrototypeIterationDraft>(
              context: context,
              builder: (dialogContext) => SimpleDialog(
                title: const Text('Saved Prototype Records'),
                children: [
                  for (final record in records)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(dialogContext, record),
                      child: Text(record.title),
                    ),
                ],
              ),
            );
      if (!mounted || record == null) return;
      Future<void> pending = Future.value();
      void saveLegacy() {
        pending = pending.then((_) async {
          final content = entry.content
              .map(
                (row) => row is Map && row['stage'] == 'prototyping'
                    ? {
                        ...row,
                        'iterations': records
                            .map((record) => record.toMap())
                            .toList(),
                      }
                    : row,
              )
              .toList();
          await widget.projectsRepo.updateJournalEntry(
            entryId: entry.id,

            title: entry.title,
            content: content,
            progress: 'prototyping',
          );
        });
      }

      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => _PrototypeComponentsPage(
            projectId: widget.projectId,
            projectsRepo: widget.projectsRepo,
            iteration: record,
            iterationIndex: records.indexOf(record),
            onChanged: saveLegacy,
          ),
        ),
      );
      await pending;
    }
    if (mounted) await _load();
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    if (!await _confirmPrototypeDelete(
          context,
          title: 'Delete Entry',
          message: 'Delete this prototyping journal entry?',
          action: 'Delete',
        ) ||
        !mounted)
      return;
    final ok = await widget.projectsRepo.deleteJournalEntry(entryId: entry.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete this entry. Please try again.'),
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) => _PhaseDashboardScaffold(
    projectId: widget.projectId,
    projectsRepo: widget.projectsRepo,
    title: 'Prototyping',
    phaseNumber: 3,
    description:
        'Build, test, and analyze your prototype. Document your work, evidence, and learning in journal entries.',
    entries: _entries,
    isLoading: _isLoading,
    isOwner: widget.isOwner,
    badgeLabel: 'PROTOTYPING',
    onBack: () => _returnToProjectDevelopment(
      context,
      widget.projectId,
      widget.projectsRepo,
      widget.isOwner,
    ),
    onAddEntry: _addEntry,
    onOpenEntry: _openEntry,
    onEditEntry: (entry) => _openEntry(entry, edit: true),
    onDeleteEntry: _deleteEntry,
  );
}

const _analysisSources = [
  (
    'Field Measurements',
    'On-site observations and measurements (e.g. temperature, flow, energy use).',
    Icons.assignment_outlined,
  ),
  (
    'Utility / Meter Data',
    'Utility bills, meter readings, or usage records.',
    Icons.bar_chart_outlined,
  ),
  (
    'Equipment Specifications',
    'Manufacturer data, datasheets, or technical specifications.',
    Icons.settings_outlined,
  ),
  (
    'Simulation / Model Results',
    'Outputs from software or modeled performance (e.g. energy models).',
    Icons.show_chart,
  ),
  (
    'Research / Literature',
    'Published studies, reports, or other references.',
    Icons.menu_book_outlined,
  ),
  (
    'Historical / Project Records',
    'Previous project data or documentation.',
    Icons.storage_outlined,
  ),
  (
    'Assumptions / Estimates',
    'Estimated or assumed input values.',
    Icons.edit_note_outlined,
  ),
];

enum _PrototypeEntryType {
  building(
    'building',
    'Building',
    'Construct, manufacture, or modify your prototype.',
    Icons.build_outlined,
    [
      ('title', 'Build Title'),
      ('objective', 'Objective'),
      ('summary', 'Build Process'),
      ('designNotes', 'Design Notes (Optional)'),
    ],
  ),
  testing(
    'testing',
    'Testing',
    'Evaluate performance, conduct experiments, or test functionality.',
    Icons.science_outlined,
    [
      ('title', 'Test Title'),
      ('question', 'Objective'),
      ('method', 'Method'),
      ('expectedOutcome', 'Expected Outcome'),
      ('feedback', 'Feedback & Notes (Optional)'),
    ],
  ),
  analysis(
    'technical_analysis',
    'Technical Analysis',
    'Analyze data, calculations, or design performance.',
    Icons.bar_chart_outlined,
    [
      ('title', 'Technical Analysis Title'),
      ('question', 'Objective'),
      ('baseline', 'Baseline Description'),
      ('proposed', 'Proposed Description (Optional)'),
      ('fieldNotes', 'Field Notes (Optional)'),
    ],
  );

  const _PrototypeEntryType(
    this.value,
    this.label,
    this.description,
    this.icon,
    this.fields,
  );
  final String value, label, description;
  final IconData icon;
  final List<(String, String)> fields;
  String get titlePlaceholder => switch (this) {
    _PrototypeEntryType.building => 'Build Title',
    _PrototypeEntryType.testing => 'Test Title',
    _PrototypeEntryType.analysis => 'Technical Analysis Title',
  };
  static _PrototypeEntryType? parse(Object? value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class _PrototypeEntryTypeDialog extends StatelessWidget {
  const _PrototypeEntryTypeDialog();
  @override
  Widget build(BuildContext context) {
    return JournalChoiceDialog(
      title: 'New Prototyping Entry',
      closeTooltip: 'Close entry type picker',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppMetrics.fieldGap),
            const Text(
              "Choose a guided entry type or capture your work in Free Notes.",
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: AppTypography.helperSize,
                height: 1.4,
                color: Color(0xFF838B99),
              ),
            ),
            const SizedBox(height: 16),
            for (final option in [
              for (final type in _PrototypeEntryType.values)
                (type, type.value, type.label, type.description, type.icon),
              (
                JournalType.freeNotes,
                'free_notes',
                'Free Notes',
                'An open canvas for notes, images, and ideas.',
                Icons.edit_note_outlined,
              ),
            ]) ...[
              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                  side: const BorderSide(color: Color(0xFFE1E5EA)),
                ),
                child: InkWell(
                  key: ValueKey('prototype-type-${option.$2}'),
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => Navigator.pop(context, option.$1),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 96),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F8F3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(option.$5, size: 28, color: _devGreen),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  option.$3,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  option.$4,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    fontSize: AppTypography.helperSize,
                                    height: 1.35,
                                    color: Color(0xFF838B99),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: _devGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (option.$1 != _PrototypeEntryType.values.last)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

Map _prototypeEntryData(JournalEntry entry) => entry.content
    .whereType<Map>()
    .firstWhere((row) => row['stage'] == 'prototyping', orElse: () => {});

class _PrototypeJournalDraft implements _HasLearningStages {
  _PrototypeJournalDraft(this.type, JournalEntry? entry)
    : id = entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      data = entry == null
          ? {}
          : Map<String, dynamic>.from(_prototypeEntryData(entry)),
      learning = _stageMap(entry, 'learning'),
      nextAction = _stageMap(entry, 'nextAction'),
      visitedStages = _readVisitedStages(
        entry?.content,
        type != _PrototypeEntryType.analysis
            ? const ['component', 'prototyping', 'learning', 'nextAction']
            : const ['prototyping', 'learning', 'nextAction'],
      ) {
    if (type == _PrototypeEntryType.building) data['materialsWorkflow'] = true;
    if (type == _PrototypeEntryType.analysis) data['analysisWorkflow'] = true;
    if (type == _PrototypeEntryType.testing &&
        data['testingWorkflow'] != true) {
      if (entry != null) {
        final old = visitedStages.toList();
        visitedStages
          ..clear()
          ..addAll([0, ...old.map((index) => index + 1)]);
      }
      data['testingWorkflow'] = true;
    }
    if (type == _PrototypeEntryType.building &&
        data['buildingWorkflow'] != true) {
      if (entry != null) {
        final old = visitedStages.toList();
        visitedStages
          ..clear()
          ..addAll([0, ...old.map((index) => index + 1)]);
      }
      final previous = [
        data['summary'],
        data['method'],
      ].whereType<String>().where((text) => text.trim().isNotEmpty).toList();
      if (previous.isNotEmpty) data['summary'] = previous.join('\n\n');
      data['designNotes'] ??= data['challenges'] ?? '';
      data['buildingWorkflow'] = true;
    }
  }
  static Map<String, dynamic> _stageMap(JournalEntry? entry, String stage) =>
      Map<String, dynamic>.from(
        (entry?.content ?? []).whereType<Map>().firstWhere(
          (row) => row['stage'] == stage,
          orElse: () => {},
        ),
      );
  final _PrototypeEntryType type;
  @override
  final String id;
  final Map<String, dynamic> data;
  @override
  Map<String, dynamic> learning, nextAction;
  @override
  final Set<int> visitedStages;
  @override
  String get stageTitle => (data['title']?.toString() ?? '').trim().isEmpty
      ? type.titlePlaceholder
      : data['title'].toString().trim();
  List<dynamic> toContent() => [
    {...data, 'stage': 'prototyping', 'entryType': type.value},
    {...learning, 'stage': 'learning'},
    {...nextAction, 'stage': 'nextAction'},
    {'stage': '_navigation', 'visitedStages': visitedStages.toList()..sort()},
  ];
}

/// Opens a typed prototyping journal from the phase list, overview, or journal log.
class PrototypingJournalEntryPage extends StatelessWidget {
  const PrototypingJournalEntryPage({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    required this.entry,
    this.readOnly = false,
  });
  final String projectId;
  final ProjectsRepo projectsRepo;
  final JournalEntry entry;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final type = _PrototypeEntryType.parse(
      _prototypeEntryData(entry)['entryType'],
    );
    if (type == null)
      return PrototypingDashboardPage(
        projectId: projectId,
        isOwner: !readOnly,
        projectsRepo: projectsRepo,
      );
    if (!readOnly)
      return _PrototypingJournalEntryPage(
        projectId: projectId,
        projectsRepo: projectsRepo,
        type: type,
        entry: entry,
      );
    return _CompletePrototypePreview(entry: entry, type: type);
  }
}

class _CompletePrototypePreview extends StatelessWidget {
  const _CompletePrototypePreview({required this.entry, required this.type});
  final JournalEntry entry;
  final _PrototypeEntryType type;
  @override
  Widget build(BuildContext context) {
    final draft = _PrototypeJournalDraft(type, entry);
    final component = draft.data['component'];
    return _PrototypeScaffold(
      title: 'Journal Entry: Prototyping',
      previewEntry: entry,
      onBack: () => Navigator.pop(context),
      body: PageScrollWithFooter(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          children: [
            Text(entry.title, style: AppTypography.pageTitle),
            const SizedBox(height: AppMetrics.fieldGap),
            if (component is Map)
              _PreviewPanel(
                title: 'Component',
                children: [
                  _PreviewField('Name', component['name']?.toString() ?? ''),
                  _PreviewField(
                    'Purpose of the Component',
                    component['description']?.toString() ?? '',
                  ),
                  _PreviewField(
                    'Key Features',
                    _previewStringList(component['features']).join('\n'),
                  ),
                ],
              ),
            _PreviewPanel(
              title: type == _PrototypeEntryType.building
                  ? 'Build'
                  : type == _PrototypeEntryType.testing
                  ? 'Test'
                  : type.label,
              children: [
                for (final field in type.fields)
                  _PreviewField(
                    field.$2,
                    draft.data[field.$1]?.toString() ?? '',
                  ),
                if (type == _PrototypeEntryType.analysis) ...[
                  _PreviewField(
                    'Data Source',
                    _maps(
                      draft.data['dataSources'],
                    ).map((source) => source['label']).join(', '),
                  ),
                  _PreviewField(
                    'Calculation Type',
                    draft.data['calculationType']?.toString() ?? '',
                  ),
                  _PreviewField(
                    'Previously recorded method',
                    draft.data['method']?.toString() ?? '',
                  ),
                  _PreviewField(
                    'Previously recorded interpretation',
                    draft.data['interpretation']?.toString() ?? '',
                  ),
                ],
                _PreviewField(
                  'Outcomes & Rating',
                  draft.data['outcome']?.toString() ?? '',
                ),
                _PreviewField(
                  'Previously recorded results',
                  draft.data['results']?.toString() ?? '',
                ),
                JournalInvolvedPeoplePreview(
                  people: _maps(draft.data['involved']),
                ),
                if (_maps(draft.data['evidence']).isNotEmpty) ...[
                  const JournalSectionHeader(title: 'Evidence'),
                  for (final item in _maps(draft.data['evidence']))
                    if (_EvidenceBlock.fromMap(item) case final block?)
                      _EvidencePreviewBlock(evidence: block),
                ],
              ],
            ),
            if (type == _PrototypeEntryType.building &&
                draft.data['materialsWorkflow'] == true)
              _PreviewPanel(
                title: 'Materials & Cost',
                children: [
                  BuildMaterialsStage(
                    showHeading: false,
                    items: _maps(draft.data['materials']),
                    currency:
                        draft.data['materialsCurrency']?.toString() ?? 'USD',
                    componentName: (draft.data['component'] as Map?)?['name']
                        ?.toString(),
                  ),
                ],
              ),
            _LearningPreviewContent(
              reflection: draft.nextAction['learned']?.toString() ?? '',
              selectedDci: _stringSet(draft.learning['dci']),
              selectedSep: _stringSet(draft.learning['sep']),
              selectedCcc: _stringSet(draft.learning['ccc']),
              inquiryLensData: InquiryLensData.fromJson(
                draft.learning['inquiryLensData'],
                legacyLens:
                    draft.learning['inquiryLens']?.toString() ??
                    InquiryLensData.noneValue,
              ),
              assessment: AssessmentBlockData.fromJson(
                draft.learning['assessment'],
              ),
            ),
            _NextActionPreviewContent(
              projectId: entry.projectId,
              includeLearned: false,
              learned: draft.nextAction['learned']?.toString() ?? '',
              challenges: draft.nextAction['challenges']?.toString() ?? '',
              nextSteps: draft.nextAction['nextSteps']?.toString() ?? '',
              notes: draft.nextAction['notes']?.toString() ?? '',
              linkedTimelineEvent:
                  draft.nextAction['linkedTimelineEvent'] is Map
                  ? Map<String, String>.from(
                      draft.nextAction['linkedTimelineEvent'] as Map,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateBuildingComponentSheet extends StatefulWidget {
  const _CreateBuildingComponentSheet({this.component});
  final _PrototypeComponentDraft? component;
  @override
  State<_CreateBuildingComponentSheet> createState() =>
      _CreateBuildingComponentSheetState();
}

class _CreateBuildingComponentSheetState
    extends State<_CreateBuildingComponentSheet> {
  final _name = TextEditingController();
  final _purpose = TextEditingController();
  final List<TextEditingController> _features = [];
  bool _featureError = false;
  @override
  void dispose() {
    _name.dispose();
    _purpose.dispose();
    for (final feature in _features) {
      feature.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final component = widget.component;
    if (component != null) {
      _name.text = component.name;
      _purpose.text = component.description;
      _features.addAll(
        component.features.map((text) => TextEditingController(text: text)),
      );
    }
  }

  void _create() {
    final validInputs = _validateStageTextInputs(context);
    final hasFeature = _features.any((field) => field.text.trim().isNotEmpty);
    setState(() => _featureError = !hasFeature);
    if (!validInputs || !hasFeature) return;
    Navigator.pop(
      context,
      _PrototypeComponentDraft(
        id:
            widget.component?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        description: _purpose.text.trim(),
        status: 'In Progress',
        features: _features
            .map((field) => field.text.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .88,
          maxWidth: 444,
        ),
        child: PageScrollWithFooter(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              28,
              24,
              28 -
                  (ScrollConfiguration.of(context) is AppScrollBehavior &&
                          {
                            TargetPlatform.macOS,
                            TargetPlatform.windows,
                            TargetPlatform.linux,
                          }.contains(Theme.of(context).platform)
                      ? AppScrollbar.gutterWidth
                      : 0),
              28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Text(
                        widget.component == null
                            ? 'Create New Component'
                            : 'Edit Component',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          fontSize: AppTypography.sectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        tooltip: 'Close component form',
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: _devGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppMetrics.fieldGap),
                _LabeledBox(
                  label: 'Title Component',
                  controller: _name,
                  height: 64,
                ),
                const SizedBox(height: AppMetrics.fieldGap),
                _RequiredInputHighlight(
                  optional: false,
                  controller: _purpose,
                  label: 'Purpose of the Component',
                  builder: (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Purpose of the Component',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        controller: _purpose,
                        minLines: 5,
                        maxLines: null,
                        maxLength: 10000,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          counterStyle: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.helperSize,
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _inputError(_purpose).value &&
                                      _purpose.text.trim().isEmpty
                                  ? Colors.red
                                  : _devGreen,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  _inputError(_purpose).value &&
                                      _purpose.text.trim().isEmpty
                                  ? Colors.red
                                  : _devGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppMetrics.fieldGap),
                const Text(
                  'Key Features',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'What features do we hope this component will have? Add at least one, up to 10.',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_featureError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Add at least one feature.',
                      style: AppTypography.requirement,
                    ),
                  ),
                const SizedBox(height: 16),
                if (_features.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _featureError
                            ? const Color(0xFFFD1212)
                            : const Color(0xFFD9D9D9),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: _features.length,
                      onReorder: (oldIndex, newIndex) => setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final field = _features.removeAt(oldIndex);
                        _features.insert(newIndex, field);
                      }),
                      itemBuilder: (context, index) => Container(
                        key: ObjectKey(_features[index]),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: index == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: Color(0xFFD9D9D9)),
                                ),
                        ),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(
                                Icons.drag_indicator,
                                size: 20,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _devGreen,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                buildCounter:
                                    (
                                      _, {
                                      required currentLength,
                                      required isFocused,
                                      maxLength,
                                    }) => null,
                                controller: _features[index],
                                onChanged: (_) {
                                  if (_featureError)
                                    setState(
                                      () => _featureError = !_features.any(
                                        (field) => field.text.trim().isNotEmpty,
                                      ),
                                    );
                                },
                                textAlign: TextAlign.left,
                                textAlignVertical: TextAlignVertical.top,
                                minLines: 1,
                                maxLines: null,
                                maxLength: 100,
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.bodySize,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Feature',
                                  border: InputBorder.none,
                                  counterText: '',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove feature',
                              onPressed: () => setState(
                                () => _features.removeAt(index).dispose(),
                              ),
                              icon: SvgPicture.asset(
                                'assets/learning_module/learning_objective_trash.svg',
                                width: 14,
                                height: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: _PrototypeOutlinedAction(
                    label: '+ Feature',
                    onTap: _features.length >= 10
                        ? null
                        : () => setState(
                            () => _features.add(TextEditingController()),
                          ),
                  ),
                ),
                const SizedBox(height: AppMetrics.fieldGap),
                Center(
                  child: _SmallStageButton(
                    label: widget.component == null ? 'Create' : 'Save',
                    filled: true,
                    onTap: _create,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BuildingComponentTile extends StatelessWidget {
  const _BuildingComponentTile({
    required this.component,
    required this.onTap,
    required this.onToggleExpanded,
    this.selected = false,
    this.expanded = false,
    this.actions,
  });
  final _PrototypeComponentDraft component;
  final VoidCallback onTap, onToggleExpanded;
  final bool selected, expanded;
  final Widget? actions;
  @override
  Widget build(BuildContext context) => Material(
    color: selected && !expanded ? const Color(0xFFF0F8F3) : Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFDFF0E4),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.view_in_ar_outlined,
                color: _devGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    component.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 13, color: _devGreen),
                          SizedBox(width: 4),
                          Text(
                            'Selected',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _devGreen,
                              fontSize: AppTypography.helperSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (actions != null) actions!,
            IconButton(
              tooltip: '${expanded ? 'Collapse' : 'Expand'} ${component.name}',
              onPressed: onToggleExpanded,
              icon: Icon(
                expanded ? Icons.expand_less : Icons.chevron_right,
                color: selected ? _devGreen : const Color(0xFFCCCCCC),
                size: 22,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrototypingJournalEntryPage extends StatefulWidget {
  const _PrototypingJournalEntryPage({
    required this.projectId,
    required this.projectsRepo,
    required this.type,
    this.entry,
  });
  final String projectId;
  final ProjectsRepo projectsRepo;
  final _PrototypeEntryType type;
  final JournalEntry? entry;
  @override
  State<_PrototypingJournalEntryPage> createState() =>
      _PrototypingJournalEntryPageState();
}

class _PrototypingJournalEntryPageState
    extends State<_PrototypingJournalEntryPage>
    with DraftAutosave<_PrototypingJournalEntryPage> {
  @override
  String get failedDraftLabel => _draftSession.failureLabel;
  @override
  String get savedDraftLabel => _draftSession.current == null
      ? ''
      : _draftSession.kept
      ? 'Saved'
      : 'Autosaved';
  late final _draftSession = JournalDraftSession(
    widget.projectsRepo,
    widget.projectId,
    initial: widget.entry,
    onKept: (id) {
      if (mounted) setState(() => _entryId = id);
    },
  );

  int _entryNumber = 1;

  late final _draft = _PrototypeJournalDraft(widget.type, widget.entry);
  late String? _entryId = widget.entry?.id;
  late final _fields = {
    for (final field in widget.type.fields)
      field.$1: TextEditingController(
        text: _draft.data[field.$1]?.toString() ?? '',
      ),
  };
  late final _evidence = _maps(
    _draft.data['evidence'],
  ).map(_EvidenceBlock.fromMap).whereType<_EvidenceBlock>().toList();
  bool get _building => widget.type != _PrototypeEntryType.analysis;
  int _buildingStage = 0;
  int? _guidedStage;
  final _componentSearch = TextEditingController();
  final List<_PrototypeComponentDraft> _components = [];
  final Set<String> _expandedComponents = {};
  final List<UserProfile> _buildMembers = [];
  final Set<String> _involved = {};
  bool _loadingComponents = true;
  _PrototypeComponentDraft? get _selectedComponent =>
      _draft.data['component'] is Map
      ? _PrototypeComponentDraft.fromMap(_draft.data['component'])
      : null;
  List<String> get _labels => _building
      ? [
          'Component',
          widget.type == _PrototypeEntryType.testing ? 'Test' : 'Build',
          if (widget.type == _PrototypeEntryType.building) 'Materials & Cost',
          'Learning',
          'Next Action',
        ]
      : [widget.type.label, 'Learning', 'Next Action'];
  @override
  void initState() {
    super.initState();
    _buildingStage = restoredJournalStage(
      widget.entry?.content ?? [],
      _labels.length,
    );
    // Only Learning and Next Action belong to the guided continuation. Earlier
    // saved sections must reopen their own editor (component, build or analysis).
    if (_buildingStage >= _labels.length - 2) {
      _guidedStage = _buildingStage;
    }
    journalEntryNumber(
      widget.projectsRepo,
      widget.projectId,
      'Prototyping',
      widget.entry,
    ).then((number) {
      if (mounted) setState(() => _entryNumber = number);
    });

    _fields['title']!.addListener(_refreshEntryTitle);
    _loadBuildingContext();
  }

  void _refreshEntryTitle() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBuildingContext() async {
    final values = await Future.wait([
      widget.projectsRepo.getJournalEntries(projectId: widget.projectId),
      widget.projectsRepo.getProjectMembers(projectId: widget.projectId),
    ]);
    if (!mounted) return;
    final found = <String, _PrototypeComponentDraft>{};
    void collect(dynamic node) {
      if (node is Map) {
        if (node['features'] is List &&
            node['name'] != null &&
            node['id'] != null) {
          final component = _PrototypeComponentDraft.fromMap(node);
          found.putIfAbsent(component.id, () => component);
        }
        for (final value in node.values) {
          collect(value);
        }
      } else if (node is List) {
        for (final value in node) {
          collect(value);
        }
      }
    }

    final records = List<JournalEntry>.of(
      (values[0] as List<JournalEntry>?) ?? [],
    );
    records.sort(
      (a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(1970)).compareTo(
        a.updatedAt ?? a.createdAt ?? DateTime(1970),
      ),
    );
    for (final entry in records) {
      collect(entry.content);
    }
    collect(_draft.data);
    setState(() {
      _components
        ..clear()
        ..addAll(found.values);
      _buildMembers
        ..clear()
        ..addAll(values[1] as List<UserProfile>);
      _involved.addAll(
        _maps(
          _draft.data['involved'],
        ).map((member) => member['id']?.toString()).whereType<String>(),
      );
      if (_draft.data['involvedInitialized'] != true &&
          _involved.isEmpty &&
          _buildMembers.isNotEmpty) {
        final creatorId =
            widget.entry?.authorId ?? AuthService.instance.currentUser?.id;
        if (_buildMembers.any((member) => member.id == creatorId))
          _involved.add(creatorId!);
      }
      _draft.data['involvedInitialized'] = true;
      _loadingComponents = false;
    });
  }

  void _selectComponent(_PrototypeComponentDraft component) => setState(() {
    _draft.data['noComponent'] = false;
    if (_selectedComponent?.id == component.id) {
      _draft.data.remove('component');
    } else {
      _draft.data['noComponent'] = false;
      _draft.data['component'] = {
        'id': component.id,
        'name': component.name,
        'description': component.description,
        'status': component.status,
        'features': component.features,
      };
    }
  });
  Future<void> _createComponent({_PrototypeComponentDraft? existing}) async {
    if (existing == null && _maps(_draft.data['createdComponents']).isNotEmpty)
      return;
    final component = await showAppModalBottomSheet<_PrototypeComponentDraft>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: JournalPageLayout.widthFor(context),
      ),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateBuildingComponentSheet(component: existing),
    );
    if (!mounted || component == null) return;
    setState(() {
      _components.removeWhere((item) => item.id == component.id);
      _components.insert(0, component);
      final created = _maps(_draft.data['createdComponents']);
      if (existing == null ||
          created.any((item) => item['id'] == component.id)) {
        _draft.data['createdComponents'] = [
          ...created.where((item) => item['id'] != component.id),
          component.toMap(),
        ];
      }
      _draft.data['noComponent'] = false;
      _draft.data['component'] = {
        'id': component.id,
        'name': component.name,
        'description': component.description,
        'status': component.status,
        'features': component.features,
      };
    });
  }

  Widget _componentStage() {
    final selected = _selectedComponent;
    final query = _componentSearch.text.trim().toLowerCase();
    final createdIds = _maps(
      _draft.data['createdComponents'],
    ).map((item) => item['id']).toSet();
    final created = _components
        .where((item) => createdIds.contains(item.id))
        .toList();
    final matches = _components
        .where(
          (component) =>
              !createdIds.contains(component.id) &&
              (query.isEmpty ||
                  component.name.toLowerCase().contains(query) ||
                  component.description.toLowerCase().contains(query)),
        )
        .toList();
    Widget heading(String text) => Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    );
    Widget componentActions(_PrototypeComponentDraft component) =>
        ItemActionMenu(
          icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF838383)),
          onEdit: () => _createComponent(existing: component),
          onDelete: () => setState(() {
            if (_selectedComponent?.id == component.id)
              _draft.data.remove('component');
            _draft.data['createdComponents'] = _maps(
              _draft.data['createdComponents'],
            ).where((item) => item['id'] != component.id).toList();
            _components.removeWhere((item) => item.id == component.id);
          }),
        );
    Widget detail(_PrototypeComponentDraft component) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 12),
          const Text(
            'Purpose of the Component',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            component.description,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.helperSize,
              color: AppColors.textSecondary,
            ),
          ),
          if (component.features.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Key Features',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < component.features.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _devGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: Colors.white,
                          fontSize: AppTypography.helperSize,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        component.features[index],
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.helperSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    Widget list(
      List<_PrototypeComponentDraft> items, {
      required String section,
    }) => Container(
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD0D0D0)),
        borderRadius: BorderRadius.circular(10),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, 3),
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFD0D0D0)),
            AnimatedSize(
              key: ValueKey('component-card-$section-${items[i].id}'),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  _BuildingComponentTile(
                    component: items[i],
                    actions:
                        _expandedComponents.contains('$section:${items[i].id}')
                        ? componentActions(items[i])
                        : null,
                    selected: selected?.id == items[i].id,
                    expanded: _expandedComponents.contains(
                      '$section:${items[i].id}',
                    ),
                    onTap: () => _selectComponent(items[i]),
                    onToggleExpanded: () => setState(() {
                      final key = '$section:${items[i].id}';
                      if (!_expandedComponents.remove(key))
                        _expandedComponents.add(key);
                    }),
                  ),
                  if (_expandedComponents.contains('$section:${items[i].id}'))
                    detail(items[i]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Select Component'),
        _RequiredJournalInteraction(
          complete: () =>
              _selectedComponent != null || _draft.data['noComponent'] == true,
          message: 'Select or create a component, or choose No component.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('No component'),
                subtitle: const Text(
                  'Continue without linking this entry to a component.',
                ),
                value: _draft.data['noComponent'] == true,
                onChanged: (value) => setState(() {
                  _draft.data['noComponent'] = value == true;
                  if (value == true) _draft.data.remove('component');
                }),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              heading('All Project Components'),
              const SizedBox(height: AppMetrics.helperGap),
              Text(
                'Choose from an existing component or create a new one to use for this ${widget.type == _PrototypeEntryType.testing ? 'test' : 'build'} entry.',
                style: AppTypography.helper,
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              TextField(
                key: const ValueKey('project-component-search'),
                controller: _componentSearch,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                ),
                decoration: InputDecoration(
                  hintText: 'Search components',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear component search',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(_componentSearch.clear),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              if (_loadingComponents)
                const Center(child: CircularProgressIndicator())
              else if (matches.isEmpty)
                Text(
                  query.isEmpty
                      ? 'No project components yet.'
                      : 'No matching components.',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.helperSize,
                  ),
                )
              else if (matches.isNotEmpty)
                list(matches, section: 'all'),
              const SizedBox(height: AppMetrics.sectionGap),
              if (created.isEmpty)
                _PrototypeOutlinedAction(
                  label: '+ Create New Component',
                  onTap: () => _createComponent(),
                )
              else ...[
                heading('Created Component'),
                const SizedBox(height: AppMetrics.labelGap),
                list(created, section: 'created'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Who is involved?', style: AppTypography.fieldLabel),
        const SizedBox(height: 6),
        const Text(
          'Selected participants can edit this journal entry.',
          style: AppTypography.helper,
        ),
        JournalInvolvedPeopleField(
          creatorId: widget.entry?.authorId ?? _journalCurrentUserId(),
          members: _buildMembers,
          selectedIds: _involved,
          onToggle: (id) => setState(() {
            if (!_involved.add(id)) _involved.remove(id);
          }),
        ),
      ],
      footer: Center(
        child: _SmallStageButton(
          label: 'Next',
          filled: true,
          onTap: () {
            if (_selectedComponent == null &&
                _draft.data['noComponent'] != true) {
              _validateStageTextInputs(context);
              return;
            }
            _openStage(1);
          },
        ),
      ),
    );
  }

  List<Widget> _analysisFields() => [
    JournalSectionHeader(title: 'Technical Analysis'),
    _LabeledBox(
      label: 'Technical Analysis Title',
      controller: _fields['title']!,
      height: 64,
    ),
    for (final field in [
      ('question', 'Objective', 'What are you trying to learn or improve?'),
      ('baseline', 'Baseline Description', 'Current or existing conditions.'),
      (
        'proposed',
        'Proposed Description',
        'Upgraded or more efficient conditions.',
      ),
    ]) ...[
      const SizedBox(height: AppMetrics.journalSectionGap),
      _LabeledBox(
        label: field.$2,
        helperText: field.$3,
        controller: _fields[field.$1]!,
        optional: field.$1 == 'proposed',
        maxLines: 4,
        expandWithContent: true,
      ),
    ],
    const SizedBox(height: AppMetrics.journalSectionGap),
    const Text('Data Source', style: AppTypography.fieldLabel),
    const SizedBox(height: AppMetrics.helperGap),
    const Text(
      'Select all sources for the technical analysis.',
      style: AppTypography.helper,
    ),
    const SizedBox(height: 16),
    if (_maps(_draft.data['dataSources']).isNotEmpty)
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final source in _maps(_draft.data['dataSources']))
            InputChip(
              avatar: Icon(
                _analysisSourceIcon(source['label'].toString()),
                size: 18,
                color: _devGreen,
              ),
              label: Text('${source['label']}'),
              onDeleted: () => setState(() {
                final sources = _maps(_draft.data['dataSources']);
                sources.removeWhere((item) => item['label'] == source['label']);
                _draft.data['dataSources'] = sources;
              }),
            ),
        ],
      ),
    if (_maps(_draft.data['dataSources']).isNotEmpty)
      const SizedBox(height: AppMetrics.fieldGap),
    _RequiredJournalInteraction(
      complete: () => _maps(_draft.data['dataSources']).isNotEmpty,
      message: 'Select at least one data source.',
      child: _PrototypeOutlinedAction(
        label: '+ Data Source',
        onTap: _chooseDataSources,
      ),
    ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    const OptionalFieldLabel(
      'Calculation Type (Optional)',
      style: AppTypography.fieldLabel,
    ),
    const SizedBox(height: AppMetrics.helperGap),
    const Text(
      'Choose the kind of calculation used to support your analysis: performance measures how well a design works, comparison weighs alternatives, estimate predicts a quantity, and cost / value examines costs and benefits. Skip this if no calculation is needed.',
      style: AppTypography.helper,
    ),
    const SizedBox(height: 16),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final option in [
            ('Performance', Icons.speed_outlined),
            ('Comparison', Icons.balance_outlined),
            ('Estimate', Icons.bar_chart_outlined),
            ('Cost / Value', Icons.paid_outlined),
          ])
            SizedBox(
              width: (constraints.maxWidth - 12) / 2,
              height: 56,
              child: OutlinedButton.icon(
                icon: Icon(option.$2, size: 20),
                label: Text(option.$1),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _draft.data['calculationType'] == option.$1
                      ? _devGreen.withValues(alpha: .08)
                      : Colors.white,
                  side: BorderSide(color: _devGreen),
                ),
                onPressed: () => setState(
                  () => _draft.data['calculationType'] =
                      _draft.data['calculationType'] == option.$1
                      ? null
                      : option.$1,
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    const JournalSectionHeader(title: 'Evidence (Optional)'),
    if (_evidence.isEmpty)
      const _EmptyEvidenceState()
    else
      for (var index = 0; index < _evidence.length; index++)
        _EvidenceSummaryCard(
          evidence: _evidence[index],
          onTap: () => _editEvidence(index),
          onDelete: () => setState(() => _evidence.removeAt(index)),
        ),
    Center(
      child: _PrototypeOutlinedAction(
        label: '+ Add Evidence Block',
        onTap: _editEvidence,
      ),
    ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    _LabeledBox(
      label: 'Field Notes',
      helperText:
          'Provide additional feedback or notes related to the analysis.',
      controller: _fields['fieldNotes']!,
      optional: true,
      maxLines: 4,
      expandWithContent: true,
    ),
    for (final legacy in ['method', 'results', 'interpretation'])
      if ((_draft.data[legacy]?.toString() ?? '').trim().isNotEmpty)
        _ImplPreviewSection(
          label: 'Previously recorded $legacy',
          body: _draft.data[legacy].toString(),
        ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    const Text('Who is involved?', style: AppTypography.fieldLabel),
    const SizedBox(height: 12),
    JournalInvolvedPeopleField(
      creatorId: widget.entry?.authorId ?? _journalCurrentUserId(),
      members: _buildMembers,
      selectedIds: _involved,
      onToggle: (id) => setState(() {
        if (!_involved.add(id)) _involved.remove(id);
      }),
    ),
  ];

  Future<void> _chooseDataSources() async {
    final selected = _maps(
      _draft.data['dataSources'],
    ).map((source) => source['label'].toString()).toSet();
    final sources = [
      ..._analysisSources,
      for (final label in selected)
        if (!_analysisSources.any((source) => source.$1 == label))
          (label, 'Custom data source', Icons.note_add_outlined),
    ];
    var customName = '';
    var customError = false;
    var customFieldVersion = 0;
    final result = await showAppModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85,
                maxWidth: JournalPageLayout.widthFor(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add Data Source',
                          style: AppTypography.sectionTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Text(
                    'Select the information or references used for this analysis. You can add multiple sources.',
                    style: AppTypography.helper,
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ScrollConfiguration(
                      behavior: const MaterialScrollBehavior(),
                      child: PageScrollWithFooter(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final source in sources)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppMetrics.cornerRadius,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFFE5E5E5),
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      secondary: Icon(
                                        source.$3,
                                        color: _devGreen,
                                      ),
                                      title: Text(
                                        source.$1,
                                        style: AppTypography.fieldLabel,
                                      ),
                                      subtitle: Text(
                                        source.$2,
                                        style: AppTypography.helper,
                                      ),
                                      value: selected.contains(source.$1),
                                      onChanged: (value) => update(() {
                                        if (value == true) {
                                          selected.add(source.$1);
                                        } else {
                                          selected.remove(source.$1);
                                        }
                                      }),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Create your own source',
                                  style: AppTypography.fieldLabel,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                key: ValueKey(customFieldVersion),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  labelText: 'Source name',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 20,
                                  ),
                                  errorText: customError
                                      ? 'Enter a source name.'
                                      : null,
                                ),
                                onChanged: (value) {
                                  customName = value;
                                  if (customError)
                                    update(() => customError = false);
                                },
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Custom Source'),
                                onPressed: () => update(() {
                                  final name = customName.trim();
                                  if (name.isEmpty) {
                                    customError = true;
                                    return;
                                  }
                                  final match = sources.where(
                                    (source) =>
                                        source.$1.toLowerCase() ==
                                        name.toLowerCase(),
                                  );
                                  if (match.isNotEmpty) {
                                    selected.add(match.first.$1);
                                  } else {
                                    sources.add((
                                      name,
                                      'Custom data source',
                                      Icons.note_add_outlined,
                                    ));
                                    selected.add(name);
                                  }
                                  customName = '';
                                  customError = false;
                                  customFieldVersion++;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, [
                            for (final source in sources)
                              if (selected.contains(source.$1))
                                {'label': source.$1},
                          ]),
                    child: Text('Add Selected (${selected.length})'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted)
      setState(() => _draft.data['dataSources'] = result);
  }

  List<Widget> _testingFields() => [
    JournalSectionHeader(title: 'Test'),
    _LabeledBox(label: 'Test Title', controller: _fields['title']!, height: 64),
    for (final field in [
      ('question', 'Objective', 'What are you trying to learn or improve?'),
      ('method', 'Method', 'How did you conduct this test?'),
      (
        'expectedOutcome',
        'Expected Outcome',
        'What results would indicate success?',
      ),
    ]) ...[
      const SizedBox(height: AppMetrics.journalSectionGap),
      _LabeledBox(
        label: field.$2,
        helperText: field.$3,
        controller: _fields[field.$1]!,
        minLines: 5,
        maxLines: 5,
        maxLength: 10000,
        expandWithContent: true,
      ),
    ],
    const SizedBox(height: AppMetrics.journalSectionGap),
    const Text('Outcomes & Rating', style: AppTypography.fieldLabel),
    const SizedBox(height: 16),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.start,
        children: [
          for (final option in _prototypeTestOutcomes)
            _PrototypeOutcomeOption(
              width: constraints.maxWidth,
              compact: true,
              label: option[0],
              subtitle: option[1],
              selected: _draft.data['outcome'] == option[0],
              onTap: () => setState(() {
                _draft.data['outcome'] = _draft.data['outcome'] == option[0]
                    ? null
                    : option[0];
              }),
            ),
        ],
      ),
    ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    const JournalSectionHeader(title: 'Evidence (Optional)'),
    if (_evidence.isEmpty)
      const _EmptyEvidenceState()
    else
      for (var index = 0; index < _evidence.length; index++)
        _EvidenceSummaryCard(
          evidence: _evidence[index],
          onTap: () => _editEvidence(index),
          onDelete: () => setState(() => _evidence.removeAt(index)),
        ),
    const SizedBox(height: 12),
    Center(
      child: SizedBox(
        width: 224,
        child: _PrototypeOutlinedAction(
          label: '+ Add Evidence Block',
          onTap: _editEvidence,
        ),
      ),
    ),
    const SizedBox(height: AppMetrics.journalSectionGap),
    _LabeledBox(
      label: 'Feedback & Notes',
      helperText: 'Provide additional feedback or notes related to the test.',
      controller: _fields['feedback']!,
      optional: true,
      minLines: 5,
      maxLines: 5,
      maxLength: 10000,
      expandWithContent: true,
    ),
    if ((_draft.data['results']?.toString() ?? '').trim().isNotEmpty) ...[
      const SizedBox(height: AppMetrics.fieldGap),
      _ImplPreviewSection(
        label: 'Previously recorded results',
        body: _draft.data['results'].toString(),
      ),
    ],
    const SizedBox(height: AppMetrics.journalSectionGap),
    const Text('Who is involved?', style: AppTypography.fieldLabel),
    const SizedBox(height: 12),
    JournalInvolvedPeopleField(
      creatorId: widget.entry?.authorId ?? _journalCurrentUserId(),
      members: _buildMembers,
      selectedIds: _involved,
      onToggle: (id) => setState(() {
        if (!_involved.add(id)) _involved.remove(id);
      }),
    ),
  ];

  List<Widget> _buildingFields() => [
    JournalSectionHeader(
      key: const ValueKey('build-stage-heading'),
      title: 'Build',
    ),
    _LabeledBox(
      label: 'Build Title',
      controller: _fields['title']!,
      height: 44,
    ),
    const SizedBox(height: AppMetrics.sectionGap),
    _LabeledBox(
      label: 'Objective',
      helperText: 'What are you trying to learn or do?',
      controller: _fields['objective']!,
      maxLines: 5,
      maxLength: 10000,
      expandWithContent: true,
    ),
    const SizedBox(height: AppMetrics.sectionGap),
    _LabeledBox(
      label: 'Build Process',
      helperText: 'Explain the methodology of the build.',
      controller: _fields['summary']!,
      minLines: 5,
      maxLines: 5,
      maxLength: 10000,
      expandWithContent: true,
    ),
    const SizedBox(height: AppMetrics.sectionGap),
    const JournalSectionHeader(title: 'Evidence (Optional)'),
    if (_evidence.isEmpty)
      const _EmptyEvidenceState()
    else
      for (var index = 0; index < _evidence.length; index++)
        _EvidenceSummaryCard(
          evidence: _evidence[index],
          onTap: () => _editEvidence(index),
          onDelete: () => setState(() => _evidence.removeAt(index)),
        ),
    const SizedBox(height: 12),
    Center(
      child: SizedBox(
        width: 224,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _devGreen,
            side: const BorderSide(color: _devGreen),
            minimumSize: const Size.fromHeight(44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _editEvidence,
          child: const Text('+ Add Evidence Block'),
        ),
      ),
    ),
    const SizedBox(height: AppMetrics.sectionGap),
    _LabeledBox(
      label: 'Design Notes',
      helperText: 'Provide additional notes related to the build or design.',
      controller: _fields['designNotes']!,
      minLines: 5,
      optional: true,
      maxLength: 10000,
      maxLines: 5,
      expandWithContent: true,
    ),
    const SizedBox(height: AppMetrics.sectionGap),
    const Text(
      'Who is involved?',
      style: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    ),
    const SizedBox(height: 12),
    JournalInvolvedPeopleField(
      creatorId: widget.entry?.authorId ?? _journalCurrentUserId(),
      members: _buildMembers,
      selectedIds: _involved,
      onToggle: (id) => setState(() {
        if (!_involved.add(id)) _involved.remove(id);
      }),
    ),
  ];
  bool _changed = false;
  void _sync() {
    for (final field in _fields.entries) {
      _draft.data[field.key] = field.value.text.trim();
    }
    if (!_loadingComponents)
      _draft.data['involved'] = journalParticipantRows(
        _involved,
        _buildMembers,
        previous: widget.entry?.content ?? const [],
      );
    _draft.data['evidence'] = _evidence.map((item) => item.toMap()).toList();
  }

  @override
  String get draftFingerprint {
    _sync();
    return jsonEncode({
      'content': _draft.toContent(),
      'currentStage': _buildingStage,
    });
  }

  @override
  Future<bool> writeAutosave() => _writeDraft();
  Future<bool> _save() => serializeDraft(_writeDraft);
  Future<bool> _writeDraft() async {
    try {
      _sync();
      final title = journalEntryTitle(
        _fields['title']!.text,
        _entryNumber,
        'Prototyping',
      );
      if (await _draftSession.skipEmpty(title, _draft.toContent())) {
        _entryId = null;
        return true;
      }
      bool ok;
      if (_entryId == null) {
        final created = await _draftSession.createJournalEntry(
          projectId: widget.projectId,
          title: title,
          content: _draft
              .toContent()
              .map(
                (row) => row is Map && row['stage'] == '_navigation'
                    ? {...row, 'currentStage': _buildingStage}
                    : row,
              )
              .toList(),
          progress: 'prototyping',
        );
        _entryId = created?.id;
        ok = created != null;
      } else {
        ok = await _draftSession.updateJournalEntry(
          entryId: _entryId!,
          title: title,
          content: _draft
              .toContent()
              .map(
                (row) => row is Map && row['stage'] == '_navigation'
                    ? {...row, 'currentStage': _buildingStage}
                    : row,
              )
              .toList(),
          progress: 'prototyping',
        );
      }
      _changed = _changed || ok;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _exit() async {
    if (!await flushDraft() || !mounted) return;
    Navigator.maybePop(context, _changed);
  }

  Future<void> _openStage(int index) async {
    _sync();
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draft.toContent()),
      _guidedStage ?? (_building ? _buildingStage : 0),
      index,
      _labels,
    ))
      return;
    if (!await flushDraft() || !mounted) return;
    final entryStage = _building
        ? index < (widget.type == _PrototypeEntryType.building ? 3 : 2)
        : index == 0;
    if (!entryStage && !await _save()) return;
    if (!mounted) return;
    setState(() {
      _draft.visitedStages.add(index);
      if (entryStage) {
        _guidedStage = null;
        _buildingStage = index;
      } else {
        _guidedStage = index;
      }
    });
  }

  Future<void> _finishInline() async {
    if (!await flushDraft() || !mounted) return;
    JournalPublication.returnHome(context);
  }

  Future<void> _editEvidence([int? index]) async {
    final existing = index == null ? null : _evidence[index];
    final type =
        existing?.type ??
        await showAppDialog<String>(
          context: context,
          builder: (_) => const _EvidenceBlockPicker(),
        );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(
      context,
      type,
      existing,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() {
      if (index == null) {
        _evidence.add(block);
      } else {
        _evidence[index] = block;
      }
    });
  }

  @override
  void dispose() {
    _componentSearch.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => JournalDraftGuard(
    session: _draftSession,
    flush: flushDraft,
    section: (_guidedStage ?? _buildingStage) >= _labels.length - 2
        ? ((_guidedStage ?? _buildingStage) == _labels.length - 2
              ? 'learning'
              : 'nextAction')
        : 'prototyping',
    sections: const {
      'prototyping': 'Prototype work',
      'learning': 'Learning',
      'nextAction': 'Next Action',
    },
    onSectionSelected: (key) => setState(() {
      _guidedStage = key == 'prototyping'
          ? null
          : key == 'learning'
          ? _labels.length - 2
          : key == 'nextAction'
          ? _labels.length - 1
          : 0;
      _buildingStage = _guidedStage ?? 0;
    }),
    child: _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
    if (_guidedStage != null) {
      return _PrototypeLogLearningFlow(
        target: _draft,
        onSaveDraft: flushDraft,
        initialStage: _guidedStage!,
        projectId: widget.projectId,
        projectsRepo: widget.projectsRepo,
        journalEntryId: _entryId,
        onNavigateToEntryStage: _openStage,
        onActiveStageChanged: (index) {
          if (mounted) setState(() => _guidedStage = index);
        },
        onExit: _exit,
        onComplete: _finishInline,
        onChanged: () {
          if (mounted) {
            setState(() {});
            flushDraft();
          }
        },
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Padding(
              padding: JournalPageLayout.pagePadding,
              child: Column(
                children: [
                  _PrototypeTopBar(
                    title: journalEntryTitle('', _entryNumber, 'Prototyping'),
                    titleController: _fields['title']!,
                    onBack: _exit,
                    inset: 0,
                  ),
                  _StageHeader(
                    activeIndex: _building ? _buildingStage : 0,
                    completion: () {
                      _sync();
                      return completedJournalStageIndices(_draft.toContent());
                    },
                    inputs: Listenable.merge(_fields.values.toList()),
                    visitedIndices: _draft.visitedStages,
                    labels: _labels,
                    onSelected: _openStage,
                  ),
                  const SizedBox(height: JournalPageLayout.stageGap),
                  Expanded(
                    child: _building && _buildingStage == 0
                        ? _componentStage()
                        : _JournalStageLayout(
                            children: [
                              if (widget.type == _PrototypeEntryType.building &&
                                  _buildingStage == 2)
                                _RequiredJournalInteraction(
                                  complete: () =>
                                      _draft.data['noMaterials'] == true ||
                                      _maps(
                                        _draft.data['materials'],
                                      ).isNotEmpty,
                                  message:
                                      'Add the materials used or select No materials needed.',
                                  child: BuildMaterialsStage(
                                    items: _maps(_draft.data['materials']),
                                    currency:
                                        _draft.data['materialsCurrency']
                                            ?.toString() ??
                                        'USD',
                                    componentName: _selectedComponent?.name,
                                    noMaterials:
                                        _draft.data['noMaterials'] == true,
                                    onChanged: (items, currency) =>
                                        setState(() {
                                          _draft.data['materials'] = items;
                                          _draft.data['materialsCurrency'] =
                                              currency;
                                          _draft.data['noMaterials'] = false;
                                        }),
                                    onNoMaterials: (value) => setState(
                                      () => _draft.data['noMaterials'] = value,
                                    ),
                                  ),
                                )
                              else if (_building)
                                ...(widget.type == _PrototypeEntryType.testing
                                    ? _testingFields()
                                    : _buildingFields())
                              else
                                ..._analysisFields(),
                            ],
                            footer: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_building) ...[
                                  _SmallStageButton(
                                    label: 'Back',
                                    onTap: () => _openStage(_buildingStage - 1),
                                  ),
                                  const SizedBox(width: 24),
                                ],
                                _SmallStageButton(
                                  label: 'Next',
                                  filled: true,
                                  onTap: () {
                                    if (_validateStageTextInputs(context)) {
                                      _openStage(
                                        _building ? _buildingStage + 1 : 1,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),
                  _DraftSaveStatus(status: draftSaveStatus),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<_PrototypeIterationDraft> _prototypeIterationsFromEntry(
  JournalEntry entry,
) {
  final prototyping = entry.content.whereType<Map>().firstWhere(
    (item) => item['stage']?.toString() == 'prototyping',
    orElse: () => const {},
  );
  return _maps(
    prototyping['iterations'],
  ).map(_PrototypeIterationDraft.fromMap).toList();
}

class _PrototypeScaffold extends StatelessWidget {
  const _PrototypeScaffold({
    required this.title,
    required this.onBack,
    required this.body,
    this.previewEntry,
    this.actionLabel,
    this.onAction,
  });

  final JournalEntry? previewEntry;
  final String title;
  final VoidCallback onBack;
  final Widget body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: title,
                  onBack: onBack,
                  previewEntry: previewEntry,
                ),
                Expanded(child: body),
                if (actionLabel != null && actionLabel!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
                    child: _PrototypeOutlinedAction(
                      label: actionLabel!,
                      onTap: onAction,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeTopBar extends StatelessWidget {
  const _PrototypeTopBar({
    required this.title,
    this.titleController,
    required this.onBack,
    this.inset = 40,
    this.previewEntry,
    this.trailingLabel,
    this.onTrailing,
  });

  final JournalEntry? previewEntry;
  final String title;
  final TextEditingController? titleController;
  final VoidCallback onBack;
  final double inset;
  final String? trailingLabel;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    final editingJournal = JournalDraftScope.of(context) != null;
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          if (!editingJournal &&
              previewEntry == null &&
              trailingLabel != null &&
              trailingLabel != 'Save' &&
              trailingLabel != 'Saving...')
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: inset),
                child: TextButton(
                  onPressed: onTrailing,
                  child: Text(
                    trailingLabel!,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _devGreen,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (previewEntry != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: inset),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewEditButton(entry: previewEntry!),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: onBack,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: inset),
              child: ContentAlignedBackButton(onPressed: onBack),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: inset + 52),
              child: titleController != null
                  ? TextField(
                      controller: titleController,
                      textAlign: TextAlign.center,
                      style: AppTypography.pageTitle,
                      decoration: InputDecoration(
                        hintText: title,
                        hintStyle: AppTypography.pageTitle,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        key: const ValueKey('prototype-entry-title'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.pageTitle,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeOutlinedAction extends StatelessWidget {
  const _PrototypeOutlinedAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        height: AppMetrics.controlHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: _devGreen),
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: _devGreen,
            fontSize: AppTypography.buttonSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PrototypeCountHeader extends StatelessWidget {
  const _PrototypeCountHeader({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SvgPicture.asset(
          'assets/prototyping/collection_fill.svg',
          width: 24,
          height: 24,
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontFamily: AppTypography.headingFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.sectionTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFA1A1A1),
            fontSize: AppTypography.helperSize,
          ),
        ),
      ],
    );
  }
}

bool _isSubmittedIdeatingEntry(JournalEntry entry) {
  final nextAction = entry.content.whereType<Map>().firstWhere(
    (item) => item['stage']?.toString() == 'nextAction',
    orElse: () => const {},
  );
  return nextAction['submitted'] == true;
}

class _PhaseDashboardScaffold extends StatelessWidget {
  const _PhaseDashboardScaffold({
    required this.projectId,
    required this.projectsRepo,
    required this.title,
    required this.phaseNumber,
    required this.description,
    required this.entries,
    required this.isLoading,
    required this.isOwner,
    required this.badgeLabel,
    required this.onBack,
    required this.onAddEntry,
    required this.onOpenEntry,
    required this.onDeleteEntry,
    required this.onEditEntry,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final String title;
  final int phaseNumber;
  final String description;
  final List<JournalEntry> entries;
  final bool isLoading;
  final bool isOwner;
  final String badgeLabel;
  final VoidCallback onBack;
  final VoidCallback onAddEntry;
  final ValueChanged<JournalEntry> onOpenEntry, onDeleteEntry, onEditEntry;

  @override
  Widget build(BuildContext context) {
    return ProjectActivityScope(
      projectId: projectId,
      repo: projectsRepo,
      child: _PrototypeScaffold(
        title: title,
        onBack: onBack,
        body: PageScrollWithFooter(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
            children: [
              _PrototypeCountHeader(count: entries.length, label: 'Entries'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                decoration: BoxDecoration(
                  color: _devGreen.withValues(alpha: .2),
                  border: Border.all(color: _devGreen),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phase $phaseNumber of 4',
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _devGreen,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.bodySize,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              const Divider(color: Color(0xFFE5E5E5)),
              if (isOwner) ...[
                const SizedBox(height: 8),
                _PrototypeOutlinedAction(
                  label: '+ Add Journal Entry',
                  onTap: onAddEntry,
                ),
              ],
              const SizedBox(height: AppMetrics.fieldGap),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (entries.isEmpty)
                const _EmptyPhaseEntries()
              else
                for (final entry in entries)
                  if (phaseNumber == 1)
                    _DiscoveryEntryCard(
                      entry: entry,
                      onDelete:
                          (isOwner ||
                              entry.authorId ==
                                  AuthService.instance.currentUser?.id)
                          ? () => onDeleteEntry(entry)
                          : null,
                      onTap: () => onOpenEntry(entry),
                      onEdit: () => onEditEntry(entry),
                    )
                  else
                    _DevelopmentEntryCard(
                      entry: entry,
                      badgeLabel: badgeLabel,
                      onDelete:
                          (isOwner ||
                              entry.authorId ==
                                  AuthService.instance.currentUser?.id)
                          ? () => onDeleteEntry(entry)
                          : null,
                      onTap: () => onOpenEntry(entry),
                      onEdit: () => onEditEntry(entry),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevelopmentEntryCard extends StatelessWidget {
  const _DevelopmentEntryCard({
    required this.entry,
    required this.badgeLabel,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  });

  final JournalEntry entry;
  final String badgeLabel;
  final VoidCallback onTap;
  final VoidCallback? onDelete, onEdit;

  @override
  Widget build(BuildContext context) => JournalLogEntryCard(
    entry: entry,
    phaseLabel: badgeLabel,
    status: JournalCompletionTag(entry: entry),
    imageUrls: journalContentImageUrls(entry.content),
    onTap: onTap,
    onDelete: onDelete,
    onEdit: onEdit,
  );
}

enum _IdeatingStage { challenge, ideas, decisionMatrix, learning, nextAction }

class IdeatingEntryPage extends StatefulWidget {
  const IdeatingEntryPage({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.entry,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final JournalEntry? entry;

  @override
  State<IdeatingEntryPage> createState() => _IdeatingEntryPageState();
}

class _IdeatingEntryPageState extends State<IdeatingEntryPage>
    with DraftAutosave<IdeatingEntryPage> {
  @override
  String get failedDraftLabel => _draftSession.failureLabel;
  @override
  String get savedDraftLabel => _draftSession.current == null
      ? ''
      : _draftSession.kept
      ? 'Saved'
      : 'Autosaved';
  late final _draftSession = JournalDraftSession(
    widget.projectsRepo,
    widget.projectId,
    initial: widget.entry,
    onKept: (id) {
      if (mounted) setState(() => _entryId = id);
    },
  );

  int _entryNumber = 1;

  final _challengeTitle = TextEditingController();
  final _challengeProblem = TextEditingController();
  final _nextLearned = TextEditingController();
  final _nextChallenges = TextEditingController();
  final _nextSteps = TextEditingController();
  final _nextNotes = TextEditingController();
  late final _storage = StorageService();
  final List<UserProfile> _members = [];
  final Set<String> _involvedIds = {};
  final List<_IdeatingObjectiveDraft> _objectives = [];
  final List<_IdeatingIdeaDraft> _ideas = [];
  final List<_DecisionCriterionDraft> _criteria = [
    _DecisionCriterionDraft.empty(),
  ];
  final Set<String> _selectedDci = {};
  final Set<String> _selectedSep = {};
  final Set<String> _selectedCcc = {};
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _learningAssessment = const AssessmentBlockData();
  Map<String, String>? _linkedTimelineEvent;
  _SupportingContextFile? _supportingContext;
  _IdeatingStage _stage = _IdeatingStage.challenge;
  String? _entryId;
  bool _submitted = false;
  bool _isSaving = false;
  bool _isUploadingContext = false;
  bool _hasSavedChanges = false;

  late final Set<int> _visitedStages = _readVisitedStages(
    widget.entry?.content,
    ['challenge', 'ideas', 'decisionMatrix', 'learning', 'nextAction'],
  );

  @override
  void initState() {
    super.initState();
    journalEntryNumber(
      widget.projectsRepo,
      widget.projectId,
      'Ideation',
      widget.entry,
    ).then((number) {
      if (mounted) setState(() => _entryNumber = number);
    });

    _hydrateEntry();
    _loadMembers();
  }

  void _hydrateEntry() {
    final entry = widget.entry;
    if (entry == null) return;
    final savedStage = restoredJournalStage(
      entry.content,
      _IdeatingStage.values.length,
    );
    _stage = _IdeatingStage.values[savedStage];
    _entryId = entry.id;
    final challenge = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'challenge',
      orElse: () => const {},
    );
    _challengeTitle.text = challenge['title']?.toString() ?? '';
    _challengeProblem.text = challenge['problem']?.toString() ?? '';
    final objectives = challenge['objectives'];
    if (objectives is List) {
      _replaceObjectives(
        objectives
            .whereType<Map>()
            .map((item) => _IdeatingObjectiveDraft.fromMap(item))
            .where((item) => item.hasContent)
            .toList(),
      );
    }
    final supporting = challenge['supportingContext'];
    if (supporting is Map) {
      _supportingContext = _SupportingContextFile.fromMap(supporting);
    }
    final involved = challenge['involved'];
    if (involved is List) {
      _involvedIds.addAll(
        involved
            .whereType<Map>()
            .map((member) => member['id']?.toString())
            .whereType<String>(),
      );
    }
    final ideas = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'ideas',
      orElse: () => const {},
    );
    final savedIdeas = ideas['items'];
    if (savedIdeas is List) {
      _ideas.addAll(
        savedIdeas
            .whereType<Map>()
            .map((item) => _IdeatingIdeaDraft.fromMap(item))
            .where((item) => item.hasContent)
            .take(4),
      );
    }
    final matrix = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'decisionMatrix',
      orElse: () => const {},
    );
    final criteria = matrix['criteria'];
    if (criteria is List) {
      _replaceCriteria(
        criteria
            .whereType<Map>()
            .map((item) => _DecisionCriterionDraft.fromMap(item))
            .toList(),
      );
    }
    final learning = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'learning',
      orElse: () => const {},
    );
    _selectedDci.addAll(_stringSet(learning['dci']));
    _selectedSep.addAll(_stringSet(learning['sep']));
    _selectedCcc.addAll(_stringSet(learning['ccc']));
    _inquiryLensData = InquiryLensData.fromJson(
      learning['inquiryLensData'],
      legacyLens:
          learning['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
    );
    _learningAssessment = AssessmentBlockData.fromJson(learning['assessment']);
    final nextAction = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'nextAction',
      orElse: () => const {},
    );
    _nextLearned.text = nextAction['learned']?.toString() ?? '';
    _nextChallenges.text = nextAction['challenges']?.toString() ?? '';
    _nextSteps.text = nextAction['nextSteps']?.toString() ?? '';
    _nextNotes.text = nextAction['notes']?.toString() ?? '';
    _submitted = nextAction['submitted'] == true;
    final linked = nextAction['linkedTimelineEvent'];
    if (linked is Map) {
      _linkedTimelineEvent = {
        for (final entry in linked.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
    }
  }

  void _replaceObjectives(List<_IdeatingObjectiveDraft> next) {
    for (final item in _objectives) {
      item.dispose();
    }
    _objectives
      ..clear()
      ..addAll(next);
  }

  void _replaceCriteria(List<_DecisionCriterionDraft> next) {
    for (final item in _criteria) {
      item.dispose();
    }
    _criteria
      ..clear()
      ..addAll(next.isEmpty ? [_DecisionCriterionDraft.empty()] : next);
  }

  @override
  void dispose() {
    _challengeTitle.dispose();
    _challengeProblem.dispose();
    _nextLearned.dispose();
    _nextChallenges.dispose();
    _nextSteps.dispose();
    _nextNotes.dispose();
    for (final objective in _objectives) {
      objective.dispose();
    }
    for (final idea in _ideas) {
      idea.dispose();
    }
    for (final criterion in _criteria) {
      criterion.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final people = await widget.projectsRepo.getProjectMembers(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _members
        ..clear()
        ..addAll(people);
      if (widget.entry == null) {
        final currentId = AuthService.instance.currentUser?.id;
        if (people.any((person) => person.id == currentId)) {
          _involvedIds.add(currentId!);
        }
      }
    });
  }

  Map<String, double> _ideaScores() => _calculateIdeaScores(_ideas, _criteria);

  bool get _matrixComplete {
    return _isMatrixComplete(_ideas, _criteria);
  }

  List<Map<String, dynamic>> _matrixScoresForPersistence() {
    final scores = _ideaScores();
    return [
      for (final idea in _ideas)
        {
          'ideaId': idea.id,
          'title': idea.title.text.trim(),
          'score': scores[idea.id],
        },
    ];
  }

  Map<String, dynamic> _draftData() {
    final involved = journalParticipantRows(
      _involvedIds,
      _members,
      previous: widget.entry?.content ?? const [],
    );
    final title = journalEntryTitle(
      _challengeTitle.text,
      _entryNumber,
      'Ideation',
    );
    final content = [
      {
        'stage': '_navigation',
        'currentStage': _stage.index,
        'visitedStages': _visitedStages.toList()..sort(),
      },
      {
        'stage': 'challenge',
        'title': _challengeTitle.text.trim(),
        'problem': _challengeProblem.text.trim(),
        'objectives': _objectives
            .where((item) => item.hasContent)
            .map((item) => item.toMap())
            .toList(),
        'supportingContext': _supportingContext?.toMap(),
        'involved': involved,
      },
      {'stage': 'ideas', 'items': _ideas.map((item) => item.toMap()).toList()},
      {
        'stage': 'decisionMatrix',
        'criteria': _criteria.map((item) => item.toMap()).toList(),
        'scores': _matrixScoresForPersistence(),
        'formula':
            'Idea Score = sum((criterion weight percent / 100) x (idea rating / 5))',
      },
      {
        'stage': 'learning',
        'dci': _selectedDci.toList(),
        'sep': _selectedSep.toList(),
        'ccc': _selectedCcc.toList(),
        'inquiryLens': _inquiryLensData.selectedLens,
        'inquiryLensData': _inquiryLensData.toJson(),
        'assessment': _learningAssessment.toJson(),
      },
      {
        'stage': 'nextAction',
        'learned': _nextLearned.text.trim(),
        'challenges': _nextChallenges.text.trim(),
        'nextSteps': _nextSteps.text.trim(),
        'notes': _nextNotes.text.trim(),
        'submitted': _submitted,
        if (_submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    return {'title': title, 'content': content};
  }

  @override
  String get draftFingerprint => jsonEncode(_draftData());
  @override
  Future<bool> writeAutosave() => _writeDraft();
  Future<bool> _save() => serializeDraft(_writeDraft);
  Future<bool> _writeDraft() async {
    setState(() => _isSaving = true);
    final draft = _draftData();
    final title = draft['title'] as String;
    final content = draft['content'] as List;
    if (await _draftSession.skipEmpty(title, content)) {
      _entryId = null;
      if (mounted) setState(() => _isSaving = false);
      return true;
    }
    var ok = false;
    if (_entryId == null) {
      final entry = await _draftSession.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        progress: 'ideating',
        content: content,
      );
      _entryId = entry?.id;
      ok = entry != null;
    } else {
      ok = await _draftSession.updateJournalEntry(
        entryId: _entryId!,
        title: title,
        progress: 'ideating',
        content: content,
      );
    }
    if (!mounted) return ok;
    _hasSavedChanges = _hasSavedChanges || ok;
    setState(() => _isSaving = false);
    return ok;
  }

  Future<void> _advance(_IdeatingStage next) async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      _stage.index,
      next.index,
      const [
        'Challenge',
        'Ideas',
        'Decision Matrix',
        'Learning',
        'Next Action',
      ],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    if (_stage == _IdeatingStage.decisionMatrix &&
        next == _IdeatingStage.learning &&
        !_matrixComplete) {
      setState(() => _showMatrixValidation = true);
      return;
    }
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = next);
  }

  void _toggleInvolvedMember(String memberId) {
    setState(() {
      if (!_involvedIds.add(memberId) && _involvedIds.length > 1) {
        _involvedIds.remove(memberId);
      }
    });
  }

  void _addObjective() {
    if (_objectives.length >= 4) return;
    setState(() => _objectives.add(_IdeatingObjectiveDraft.empty()));
  }

  void _removeObjective(int index) {
    setState(() => _objectives.removeAt(index).dispose());
  }

  Future<void> _addSupportingContext() async {
    const group = XTypeGroup(
      label: 'Supporting context',
      extensions: [
        'pdf',
        'doc',
        'docx',
        'txt',
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
      ],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null || !mounted) return;
    setState(() => _isUploadingContext = true);
    try {
      final uploaded = await _storage.uploadFile(
        file,
        bucketName: 'journal-attachments',
        folder: widget.projectId,
      );
      if (!mounted) return;
      setState(
        () => _supportingContext = _SupportingContextFile.fromUpload(
          uploaded,
          bucket: 'journal-attachments',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supporting context upload failed.')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingContext = false);
    }
  }

  void _removeSupportingContext() {
    setState(() => _supportingContext = null);
  }

  Future<void> _openIdeaEditor([_IdeatingIdeaDraft? idea]) async {
    if (idea == null && _ideas.length >= 4) return;
    final result = await showAppDialog<_IdeatingIdeaDraft>(
      context: context,
      builder: (_) => _IdeaEditorPage(
        entryId: _entryId ?? widget.projectId,
        initial: idea,
        onOpenEvidencePicker: _openIdeaEvidencePicker,
        onOpenEvidenceEditor: _openIdeaEvidenceEditor,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final index = _ideas.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        if (_ideas.length < 4) _ideas.add(result);
      } else {
        _ideas[index].dispose();
        _ideas[index] = result;
      }
    });
  }

  Future<String?> _openIdeaEvidencePicker(BuildContext context) {
    return showAppDialog<String>(
      context: context,
      builder: (_) => const _EvidenceBlockPicker(),
    );
  }

  Future<_EvidenceBlock?> _openIdeaEvidenceEditor(
    BuildContext context,
    String type,
    _EvidenceBlock? existing,
  ) async {
    if (type == 'Images') {
      final result = await pushAppRoute<ImageBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.imageData,
            showAssessment: false,
            showInquiryLens: false,
          ),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.images(result);
    }
    if (type == 'Sketch') {
      final result = await pushAppRoute<SketchBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => SketchBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.sketchData,
          ),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.sketch(result);
    }
    if (type == 'Link') {
      final result = await pushAppRoute<LinkBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LinkBlockEditorScreen(initialData: existing?.linkData),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.link(result);
    }
    if (type == 'Video') {
      final result = await pushAppRoute<VideoBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.videoData,
          ),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.video(result);
    }
    if (type == 'Graph') {
      final result = await pushAppRoute<GraphBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GraphBlockEditorScreen(initialData: existing?.graphData),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.graph(result);
    }
    if (type == 'Table') {
      final result = await pushAppRoute<TableBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TableBlockEditorScreen(initialData: existing?.tableData),
        ),
      );
      if (!context.mounted) return null;
      if (result == null && existing != null) return null;
      return result == null
          ? await _returnToEvidenceMenu(
              context,
              (selected) => _openIdeaEvidenceEditor(
                context,
                selected,
                selected == type ? existing : null,
              ),
            )
          : _EvidenceBlock.table(result);
    }
    return null;
  }

  void _deleteIdea(int index) {
    setState(() {
      final removed = _ideas.removeAt(index);
      for (final criterion in _criteria) {
        criterion.ratings.remove(removed.id);
      }
      removed.dispose();
    });
  }

  bool _showMatrixValidation = false;

  void _addCriterion() {
    if (_criteria.length >= 5) return;
    setState(() => _criteria.add(_DecisionCriterionDraft.empty()));
  }

  void _removeCriterion(int index) {
    if (_criteria.length == 1) return;
    setState(() => _criteria.removeAt(index).dispose());
  }

  void _toggleLearningSelection(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _createTimelineEvent() => runActionOnce(
    this,
    'timeline-event',
    () async {
      if (_entryId == null) {
        final saved = await _save();
        if (!mounted || !saved) return;
      }
      final event = await showAppModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CreateJournalTimelineEventSheet(
          members: _members,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entryId: _entryId,
          entryTitle: 'Entry: Ideation',
        ),
      );
      if (event == null || !mounted) return;
      final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
      final events = [...?timeline, event];
      final ok = await widget.projectsRepo.updateTimeline(
        id: widget.projectId,
        timeline: events,
      );
      if (!mounted || !ok) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Timeline event created.')));
      await _save();
    },
  );

  Future<void> _submit() async {
    if (_submitted) {
      final ok = await flushDraft();
      if (mounted && ok) Navigator.of(context).maybePop(true);
      return;
    }

    if (!_canSubmitJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      ['Challenge', 'Ideas', 'Decision Matrix', 'Learning', 'Next Action'],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    _submitted = true;
    final ok = await _save();
    if (!ok) _submitted = false;
    if (!mounted || !ok) return;
    JournalPublication.returnHome(context);
  }

  @override
  Widget build(BuildContext context) => JournalDraftGuard(
    session: _draftSession,
    flush: flushDraft,
    section: const [
      'challenge',
      'ideas',
      'decisionMatrix',
      'learning',
      'nextAction',
    ][_stage.index],
    sections: const {
      'challenge': 'Challenge',
      'ideas': 'Ideas',
      'decisionMatrix': 'Decision Matrix',
      'learning': 'Learning',
      'nextAction': 'Next Action',
    },
    onSectionSelected: (key) => setState(
      () => _stage =
          _IdeatingStage.values[const [
            'challenge',
            'ideas',
            'decisionMatrix',
            'learning',
            'nextAction',
          ].indexOf(key)],
    ),
    child: _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
    final scores = _ideaScores();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Padding(
              padding: JournalPageLayout.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrototypeTopBar(
                    title: journalEntryTitle('', _entryNumber, 'Ideation'),
                    titleController: _challengeTitle,
                    onBack: () async {
                      await flushDraft();
                      if (!mounted || !context.mounted) return;
                      Navigator.of(context).maybePop(_hasSavedChanges);
                    },
                    inset: 0,
                  ),
                  _StageHeader(
                    completion: () => completedJournalStageIndices(
                      _draftData()['content'] as List,
                    ),
                    inputs: Listenable.merge([
                      _challengeTitle,
                      _challengeProblem,
                      ..._objectives.map((objective) => objective.text),
                      _nextLearned,
                      _nextChallenges,
                      _nextSteps,
                    ]),
                    visitedIndices: _visitedStages,
                    activeIndex: _stage.index,
                    onSelected: (index) async {
                      await flushDraft();
                      if (mounted)
                        setState(() => _stage = _IdeatingStage.values[index]);
                    },
                    labels: const [
                      'Challenge',
                      'Ideas',
                      'Decision Matrix',
                      'Learning',
                      'Next Action',
                    ],
                  ),
                  const SizedBox(height: JournalPageLayout.stageGap),
                  Expanded(
                    child: switch (_stage) {
                      _IdeatingStage.challenge => _IdeatingChallengeBody(
                        creatorId:
                            widget.entry?.authorId ?? _journalCurrentUserId(),
                        actionCenterOffset:
                            ScrollConfiguration.of(context)
                                    is AppScrollBehavior &&
                                {
                                  TargetPlatform.macOS,
                                  TargetPlatform.windows,
                                  TargetPlatform.linux,
                                }.contains(Theme.of(context).platform)
                            ? AppScrollbar.gutterWidth / 2
                            : 0,
                        title: _challengeTitle,
                        problem: _challengeProblem,
                        objectives: _objectives,
                        supportingContext: _supportingContext,
                        members: _members,
                        involvedIds: _involvedIds,
                        isSaving: _isSaving,
                        isUploadingContext: _isUploadingContext,
                        onAddObjective: _addObjective,
                        onRemoveObjective: _removeObjective,
                        onAddSupportingContext: _addSupportingContext,
                        onRemoveSupportingContext: _removeSupportingContext,
                        onToggleMember: _toggleInvolvedMember,
                        onNext: () => _advance(_IdeatingStage.ideas),
                      ),
                      _IdeatingStage.ideas => _IdeatingIdeasBody(
                        ideas: _ideas,
                        scores: scores,
                        hasScoredMatrix: _matrixComplete,
                        isSaving: _isSaving,
                        onAddIdea: _ideas.length >= 4
                            ? null
                            : () => _openIdeaEditor(),
                        onEditIdea: _openIdeaEditor,
                        onDeleteIdea: _deleteIdea,
                        onBack: () =>
                            setState(() => _stage = _IdeatingStage.challenge),
                        onNext: () => _advance(_IdeatingStage.decisionMatrix),
                      ),
                      _IdeatingStage.decisionMatrix => _DecisionMatrixBody(
                        showValidation: _showMatrixValidation,
                        onClear: () =>
                            setState(() => _showMatrixValidation = false),
                        ideas: _ideas,
                        criteria: _criteria,
                        scores: scores,
                        isSaving: _isSaving,
                        onChanged: () => setState(() {}),
                        onAddRow: _addCriterion,
                        onRemoveRow: _removeCriterion,
                        onBack: () =>
                            setState(() => _stage = _IdeatingStage.ideas),
                        onNext: () => _advance(_IdeatingStage.learning),
                      ),
                      _IdeatingStage.learning => JournalLearningStageBody(
                        selectedDci: _selectedDci,
                        selectedSep: _selectedSep,
                        selectedCcc: _selectedCcc,
                        inquiryLensData: _inquiryLensData,
                        assessment: _learningAssessment,
                        isSaving: _isSaving,
                        onToggleDci: (value) =>
                            _toggleLearningSelection(_selectedDci, value),
                        onToggleSep: (value) =>
                            _toggleLearningSelection(_selectedSep, value),
                        onToggleCcc: (value) =>
                            _toggleLearningSelection(_selectedCcc, value),
                        onInquiryLensChanged: (value) =>
                            setState(() => _inquiryLensData = value),
                        onSaveAssessment: flushDraft,
                        onAssessmentChanged: (value) =>
                            setState(() => _learningAssessment = value),
                        onBack: () => setState(
                          () => _stage = _IdeatingStage.decisionMatrix,
                        ),
                        onNext: () => _advance(_IdeatingStage.nextAction),
                      ),
                      _IdeatingStage.nextAction => _NextActionStageBody(
                        learned: _nextLearned,
                        challenges: _nextChallenges,
                        nextSteps: _nextSteps,
                        notes: _nextNotes,
                        linkedTimelineEvent: _linkedTimelineEvent,
                        isSaving: _isSaving,
                        projectId: widget.projectId,
                        isOwner: true,
                        projectsRepo: widget.projectsRepo,
                        onCreateTimelineEvent: _createTimelineEvent,
                        onBack: () =>
                            setState(() => _stage = _IdeatingStage.learning),
                        onSubmit: _submit,
                        completed: _submitted,
                      ),
                    },
                  ),
                  _DraftSaveStatus(
                    status: draftSaveStatus,
                    reserveScrollGutter: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeatingChallengeBody extends StatelessWidget {
  const _IdeatingChallengeBody({
    required this.title,
    this.actionCenterOffset = 0,
    required this.problem,
    required this.objectives,
    required this.supportingContext,
    required this.members,
    this.creatorId,
    required this.involvedIds,
    required this.isSaving,
    required this.isUploadingContext,
    required this.onAddObjective,
    required this.onRemoveObjective,
    required this.onAddSupportingContext,
    required this.onRemoveSupportingContext,
    required this.onToggleMember,
    required this.onNext,
  });

  final TextEditingController title;
  final double actionCenterOffset;
  final TextEditingController problem;
  final List<_IdeatingObjectiveDraft> objectives;
  final _SupportingContextFile? supportingContext;
  final List<UserProfile> members;
  final String? creatorId;
  final Set<String> involvedIds;
  final bool isSaving;
  final bool isUploadingContext;
  final VoidCallback onAddObjective;
  final ValueChanged<int> onRemoveObjective;
  final VoidCallback onAddSupportingContext;
  final VoidCallback onRemoveSupportingContext;
  final ValueChanged<String> onToggleMember;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    Widget centeredAction(Widget child) => Transform.translate(
      offset: Offset(actionCenterOffset, 0),
      child: Center(child: child),
    );
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(
          title: 'Challenge',
          description: 'Set up the context for this ideation session.',
        ),
        _LabeledBox(label: 'Challenge Title', controller: title, height: 64),
        const SizedBox(height: AppMetrics.sectionGap),
        _LabeledBox(
          label: 'What Challenge are we trying to solve?',
          controller: problem,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        Text(
          'Objectives for the Design',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'What do we hope to achieve with these designs or ideas? Add at least 1 objective, up to 4.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        _RequiredJournalInteraction(
          complete: () => objectives.any((objective) => objective.hasContent),
          changes: Listenable.merge(
            objectives.map((objective) => objective.text).toList(),
          ),
          message: 'Add at least one design objective.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (objectives.isNotEmpty)
                _ObjectivesList(
                  objectives: objectives,
                  onRemove: onRemoveObjective,
                ),
              if (objectives.length < 4)
                centeredAction(
                  TextButton(
                    onPressed: onAddObjective,
                    child: const Text('+ Add Objective'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text.rich(
          TextSpan(
            text: 'Supporting Context ',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
            children: [
              TextSpan(
                text: '(Optional)',
                style: TextStyle(color: Color(0xFF838383)),
              ),
            ],
          ),
        ),
        if (supportingContext != null) ...[
          const SizedBox(height: 16),
          _SupportingContextTile(
            file: supportingContext!,
            onRemove: onRemoveSupportingContext,
          ),
        ],
        const SizedBox(height: 12),
        centeredAction(
          AppTapTarget(
            onTap: isUploadingContext ? null : onAddSupportingContext,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                isUploadingContext ? 'Uploading...' : '+ Add File',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text(
          'Who is involved?',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select project members participating in this journal entry. Selected participants can edit it.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        JournalInvolvedPeopleField(
          creatorId: creatorId,
          members: members,
          selectedIds: involvedIds,
          onToggle: onToggleMember,
        ),
      ],
      footer: Center(
        child: _SmallStageButton(label: 'Next', filled: true, onTap: onNext),
      ),
    );
  }
}

class _ObjectivesList extends StatelessWidget {
  const _ObjectivesList({required this.objectives, required this.onRemove});

  final List<_IdeatingObjectiveDraft> objectives;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: PageScrollWithFooter(
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: objectives.length,
          itemBuilder: (context, index) {
            return _ObjectiveRow(
              key: ValueKey(objectives[index].id),
              objective: objectives[index],
              index: index,
              isLast: index == objectives.length - 1,
              canRemove: true,
              onRemove: () => onRemove(index),
            );
          },
        ),
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    super.key,
    required this.objective,
    required this.index,
    required this.isLast,
    required this.canRemove,
    required this.onRemove,
  });
  final _IdeatingObjectiveDraft objective;
  final int index;
  final bool isLast, canRemove;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: isLast ? Colors.transparent : AppColors.borderLight,
        ),
      ),
    ),
    child: CompactListItem(
      centerContent: true,
      leading: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _devGreen,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${index + 1}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      onRemove: canRemove ? onRemove : null,
      removeLabel: 'Remove',
      child: TextField(
        controller: objective.text,
        minLines: 2,
        maxLines: null,
        maxLength: 100,
        style: AppTypography.inputText,
        decoration: const InputDecoration(
          counterText: '',
          hintText: 'We want to create a solution that…',
          isDense: true,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    ),
  );
}

/// Navigation follows the stage content and reaches the bottom of short pages.
class _JournalStageLayout extends StatelessWidget {
  const _JournalStageLayout({
    required this.children,
    required this.footer,
    this.padding = EdgeInsets.zero,
  });
  final List<Widget> children;
  final Widget footer;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
        if (!constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              const SizedBox(height: AppMetrics.sectionGap),
              JournalActionFooter(child: footer),
            ],
          );
        }
        return PageScrollWithFooter(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  content,
                  Padding(
                    padding: const EdgeInsets.only(top: AppMetrics.sectionGap),
                    child: JournalActionFooter(child: footer),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _IdeatingIdeasBody extends StatelessWidget {
  const _IdeatingIdeasBody({
    required this.ideas,
    required this.scores,
    required this.hasScoredMatrix,
    required this.isSaving,
    required this.onAddIdea,
    required this.onEditIdea,
    required this.onDeleteIdea,
    required this.onBack,
    required this.onNext,
  });

  final List<_IdeatingIdeaDraft> ideas;
  final Map<String, double> scores;
  final bool hasScoredMatrix;
  final bool isSaving;
  final VoidCallback? onAddIdea;
  final ValueChanged<_IdeatingIdeaDraft> onEditIdea;
  final ValueChanged<int> onDeleteIdea;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(
          title: 'Ideas',
          description: 'Add up to four ideas to compare.',
        ),
        _RequiredJournalInteraction(
          complete: () => ideas.isNotEmpty,
          message: 'Add at least one complete idea.',
          child: AppTapTarget(
            onTap: onAddIdea,
            child: Container(
              width: double.infinity,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: onAddIdea == null
                      ? const Color(0xFFD9D9D9)
                      : _devGreen,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+ Add Idea',
                style: TextStyle(
                  color: onAddIdea == null
                      ? const Color(0xFF838383)
                      : _devGreen,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < ideas.length; i++)
          _IdeaSummaryCard(
            idea: ideas[i],
            score: hasScoredMatrix ? scores[ideas[i].id] : null,
            color: _ideaColor(i),
            onTap: () => onEditIdea(ideas[i]),
            onDelete: () => onDeleteIdea(i),
          ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(label: 'Next', filled: true, onTap: onNext),
        ],
      ),
    );
  }
}

class _IdeaSummaryCard extends StatelessWidget {
  const _IdeaSummaryCard({
    required this.idea,
    required this.score,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });

  final _IdeatingIdeaDraft idea;
  final double? score;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _IdeaBulbIcon(color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    idea.title.text.trim().isEmpty
                        ? 'Untitled Idea'
                        : idea.title.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Idea Score: ${_formatIdeaScore(score)}',
                    style: TextStyle(
                      color: score == null ? const Color(0xFF838383) : color,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            ItemActionMenu(onEdit: onTap, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class _IdeaBulbIcon extends StatelessWidget {
  const _IdeaBulbIcon({required this.color, this.size = 26});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/prototyping/idea_bulb.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

class _MatrixHorizontalViewport extends StatelessWidget {
  const _MatrixHorizontalViewport({
    required this.child,
    required this.showHint,
  });
  final Widget child;
  final bool showHint;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ...ScrollConfiguration.of(context).dragDevices,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: PageScrollWithFooter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
      ),
      if (showHint) ...[
        const SizedBox(height: 10),
        const Text(
          'Scroll sideways to compare all ideas.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ],
  );
}

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader(this.label, {this.color = Colors.black});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: color,
        fontSize: AppTypography.captionSize,
        fontWeight: FontWeight.w400,
      ),
    ),
  );
}

class _DecisionMatrixBody extends StatelessWidget {
  const _DecisionMatrixBody({
    required this.ideas,
    this.showValidation = false,
    required this.onClear,
    required this.criteria,
    required this.scores,
    required this.isSaving,
    required this.onChanged,
    required this.onAddRow,
    required this.onRemoveRow,
    required this.onBack,
    required this.onNext,
  });
  final List<_IdeatingIdeaDraft> ideas;
  final List<_DecisionCriterionDraft> criteria;
  final Map<String, double> scores;
  final bool isSaving;
  final bool showValidation;
  final VoidCallback onChanged, onAddRow, onBack, onNext, onClear;
  final ValueChanged<int> onRemoveRow;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _stageValidationTarget(context),
    builder: (context, _) => _buildValidated(context),
  );

  Widget _buildValidated(BuildContext context) {
    final showValidation =
        this.showValidation || _stageValidationTarget(context).value != null;

    final weight = _matrixWeightTotal(criteria);
    final complete = _isMatrixComplete(ideas, criteria);
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(
          title: 'Decision Matrix',
          description:
              'Name each criterion, set its weight (%), then rate each idea from 1 to 5.',
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1 = Low',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
              ),
            ),
            Text(
              '5 = High',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (ideas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Add an idea in the Ideas stage to start comparing.'),
          )
        else
          _RequiredJournalInteraction(
            complete: () => _isMatrixComplete(ideas, criteria),
            message:
                'Add criteria, set weights to 100%, and rate every idea from 1 to 5.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final criteriaWidth = ideas.length >= 3
                    ? constraints.maxWidth * .30
                    : constraints.maxWidth * .42;
                final ratingWidth =
                    ((constraints.maxWidth - criteriaWidth) / ideas.length)
                        .clamp(140.0, double.infinity);
                final tableWidth = criteriaWidth + ratingWidth * ideas.length;
                Widget cell(
                  Widget child, {
                  double height = 180,
                  Color? color,
                }) => Container(
                  height: height,
                  alignment: Alignment.center,
                  color: color,
                  padding: EdgeInsets.all(ideas.length >= 3 ? 6 : 12),
                  child: child,
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: _MatrixHorizontalViewport(
                    showHint: tableWidth > constraints.maxWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD9D9D9)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        key: const ValueKey('decision-matrix-table'),
                        width: tableWidth,
                        child: Table(
                          border: const TableBorder.symmetric(
                            inside: BorderSide(color: Color(0xFFE6E6E6)),
                          ),
                          columnWidths: {
                            0: FixedColumnWidth(criteriaWidth),
                            for (var i = 0; i < ideas.length; i++)
                              i + 1: FixedColumnWidth(ratingWidth),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              children: [
                                cell(
                                  const Text(
                                    'Criterion\n& weight',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.helperSize,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  height: 112,
                                ),
                                for (var i = 0; i < ideas.length; i++)
                                  cell(
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _IdeaBulbIcon(
                                          color: _ideaColor(i),
                                          size: 26,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          ideas[i].title.text.trim().isEmpty
                                              ? 'Idea ${i + 1}'
                                              : ideas[i].title.text.trim(),
                                          textAlign: TextAlign.center,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: AppTypography.captionSize,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                            color: _ideaColor(i),
                                          ),
                                        ),
                                      ],
                                    ),
                                    height: 112,
                                    color: _ideaColor(i).withValues(alpha: .06),
                                  ),
                              ],
                            ),
                            for (var row = 0; row < criteria.length; row++)
                              TableRow(
                                children: [
                                  cell(
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Criterion name',
                                          style: TextStyle(
                                            fontFamily:
                                                AppTypography.bodyFamily,
                                            fontSize: AppTypography.helperSize,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Expanded(
                                          child: TextField(
                                            key: ValueKey(
                                              'matrix-criterion-${criteria[row].id}',
                                            ),
                                            controller: criteria[row].name,
                                            maxLines: 2,
                                            style: const TextStyle(
                                              fontFamily:
                                                  AppTypography.bodyFamily,
                                              fontSize: AppTypography.bodySize,
                                            ),
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            decoration: _matrixDecoration(
                                              'e.g. Cost or feasibility',
                                              error:
                                                  showValidation &&
                                                      criteria[row].name.text
                                                          .trim()
                                                          .isEmpty &&
                                                      (criteria.every(
                                                            (c) => c.name.text
                                                                .trim()
                                                                .isEmpty,
                                                          ) ||
                                                          criteria[row]
                                                              .hasScores ||
                                                          (int.tryParse(
                                                                    criteria[row]
                                                                        .weight
                                                                        .text,
                                                                  ) ??
                                                                  0) !=
                                                              0)
                                                  ? 'Required'
                                                  : null,
                                            ),
                                            onChanged: (_) => onChanged(),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          showValidation && weight != 100
                                              ? 'Weight (%) · Must total 100%'
                                              : 'Weight (%)',
                                          style: TextStyle(
                                            fontSize: AppTypography.captionSize,
                                            color:
                                                showValidation && weight != 100
                                                ? const Color(0xFFFD1212)
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 32,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  key: ValueKey(
                                                    'matrix-weight-${criteria[row].id}',
                                                  ),
                                                  controller:
                                                      criteria[row].weight,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                      3,
                                                    ),
                                                  ],
                                                  style: const TextStyle(
                                                    fontSize:
                                                        AppTypography.bodySize,
                                                  ),
                                                  textAlignVertical:
                                                      TextAlignVertical.center,
                                                  decoration: _matrixDecoration(
                                                    'Weight',
                                                    suffixText: '%',
                                                    invalid:
                                                        showValidation &&
                                                        (weight != 100 ||
                                                            criteria[row]
                                                                .weight
                                                                .text
                                                                .trim()
                                                                .isEmpty),
                                                  ),
                                                  onChanged: (value) {
                                                    if ((int.tryParse(value) ??
                                                            0) >
                                                        100) {
                                                      criteria[row]
                                                              .weight
                                                              .text =
                                                          '100';
                                                      criteria[row]
                                                              .weight
                                                              .selection =
                                                          const TextSelection.collapsed(
                                                            offset: 3,
                                                          );
                                                    }
                                                    onChanged();
                                                  },
                                                ),
                                              ),
                                              if (criteria.length > 1)
                                                SizedBox(
                                                  width: 24,
                                                  child: IconButton(
                                                    tooltip: 'Remove criterion',
                                                    padding: EdgeInsets.zero,
                                                    onPressed: () =>
                                                        onRemoveRow(row),
                                                    icon: const Icon(
                                                      Icons.delete_outline,
                                                      size: 17,
                                                      color: Color(0xFFD12E2E),
                                                    ),
                                                    hoverColor:
                                                        Colors.transparent,
                                                    highlightColor:
                                                        Colors.transparent,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (var i = 0; i < ideas.length; i++)
                                    cell(
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            showValidation &&
                                                    criteria[row].ratingFor(
                                                          ideas[i].id,
                                                        ) ==
                                                        null
                                                ? 'Select 1–5'
                                                : 'Rating (1–5)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize:
                                                  AppTypography.captionSize,
                                              color:
                                                  showValidation &&
                                                      criteria[row].ratingFor(
                                                            ideas[i].id,
                                                          ) ==
                                                          null
                                                  ? const Color(0xFFFD1212)
                                                  : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            constraints: const BoxConstraints(
                                              maxWidth: 64,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border.all(
                                                color:
                                                    showValidation &&
                                                        criteria[row].ratingFor(
                                                              ideas[i].id,
                                                            ) ==
                                                            null
                                                    ? const Color(0xFFFD1212)
                                                    : const Color(0xFFD9D9D9),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                key: ValueKey(
                                                  'matrix-rating-${criteria[row].id}-${ideas[i].id}',
                                                ),
                                                value: criteria[row].ratingFor(
                                                  ideas[i].id,
                                                ),
                                                hint: const Center(
                                                  child: Text('—'),
                                                ),
                                                isExpanded: true,
                                                iconSize: 14,
                                                dropdownColor: Colors.white,
                                                items: [
                                                  for (
                                                    var rating = 1;
                                                    rating <= 5;
                                                    rating++
                                                  )
                                                    DropdownMenuItem(
                                                      value: rating,
                                                      child: Center(
                                                        child: Text(
                                                          '$rating',
                                                          style: const TextStyle(
                                                            fontSize:
                                                                AppTypography
                                                                    .helperSize,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                                onChanged: (rating) {
                                                  if (rating == null) return;
                                                  criteria[row]
                                                          .controllerFor(
                                                            ideas[i].id,
                                                          )
                                                          .text =
                                                      '$rating';
                                                  onChanged();
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                            TableRow(
                              children: [
                                cell(
                                  const Text(
                                    'Weighted Score\n(out of 100)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.helperSize,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  height: 64,
                                ),
                                for (var i = 0; i < ideas.length; i++)
                                  cell(
                                    Text(
                                      complete
                                          ? _formatIdeaScore(
                                              scores[ideas[i].id],
                                            )
                                          : 'NA',
                                      key: ValueKey(
                                        'matrix-score-${ideas[i].id}',
                                      ),
                                      style: TextStyle(
                                        fontSize:
                                            AppTypography.sectionTitleSize,
                                        fontWeight: FontWeight.w500,
                                        color: _ideaColor(i),
                                      ),
                                    ),
                                    height: 64,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Total weight: $weight% · Must total 100%',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.helperSize,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 224,
            height: AppMetrics.controlHeight,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFD1212),
                side: const BorderSide(color: Color(0xFFFD1212)),
                minimumSize: const Size(224, AppMetrics.controlHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
                ),
              ),
              onPressed: () {
                for (final criterion in criteria) {
                  criterion.name.clear();
                  criterion.weight.clear();
                  for (final rating in criterion.ratings.values) {
                    rating.clear();
                  }
                }
                for (var index = criteria.length - 1; index > 0; index--) {
                  onRemoveRow(index);
                }
                onClear();
                onChanged();
              },
              child: const Text(
                'Clear All',
                style: TextStyle(color: Color(0xFFFD1212)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 224,
            height: AppMetrics.controlHeight,
            child: OutlinedButton(
              onPressed: criteria.length >= 5 ? null : onAddRow,
              child: Text(
                criteria.length >= 5 ? '5 criteria maximum' : '+ Add Criterion',
              ),
            ),
          ),
        ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(
            label: 'Next',
            filled: true,
            onTap: isSaving ? null : onNext,
          ),
        ],
      ),
    );
  }
}

InputDecoration _matrixDecoration(
  String hint, {
  String? suffixText,
  String? error,
  bool invalid = false,
}) {
  return InputDecoration(
    hintText: hint,
    errorText: error,
    errorStyle: const TextStyle(
      fontSize: AppTypography.captionSize,
      color: Color(0xFFFD1212),
    ),
    hintStyle: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      color: AppColors.textSecondary,
      fontSize: AppTypography.helperSize,
    ),
    suffixText: suffixText,
    suffixStyle: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      color: _devText,
      fontSize: AppTypography.helperSize,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: invalid ? const Color(0xFFFD1212) : const Color(0xFFD9D9D9),
      ),
    ),
    focusedBorder: UnderlineInputBorder(
      borderSide: BorderSide(
        color: invalid ? const Color(0xFFFD1212) : const Color(0xFFD9D9D9),
      ),
    ),
  );
}

int _matrixWeightTotal(List<_DecisionCriterionDraft> criteria) => criteria.fold(
  0,
  (sum, item) => sum + (int.tryParse(item.weight.text.trim()) ?? 0),
);

String? _matrixValidationMessage(
  List<_IdeatingIdeaDraft> ideas,
  List<_DecisionCriterionDraft> criteria,
) {
  if (ideas.isEmpty)
    return 'Add at least one idea in the Ideas stage before comparing.';
  final active = criteria
      .where((item) => item.name.text.trim().isNotEmpty)
      .toList();
  if (active.isEmpty ||
      criteria.any(
        (item) =>
            item.name.text.trim().isEmpty &&
            ((int.tryParse(item.weight.text) ?? 0) != 0 || item.hasScores),
      )) {
    return 'Enter a name for each criterion you want to compare.';
  }
  if (_matrixWeightTotal(criteria) != 100)
    return 'Criterion weights must total 100% before continuing.';
  for (final criterion in active) {
    final weight = int.tryParse(criterion.weight.text);
    if (weight == null || weight < 0 || weight > 100)
      return 'Enter a weight from 0 to 100 for each criterion.';
    for (final idea in ideas) {
      if (criterion.ratingFor(idea.id) == null)
        return 'Choose a rating from 1 to 5 for every idea and criterion.';
    }
  }
  return null;
}

bool _isMatrixComplete(
  List<_IdeatingIdeaDraft> ideas,
  List<_DecisionCriterionDraft> criteria,
) => _matrixValidationMessage(ideas, criteria) == null;

Map<String, double> _calculateIdeaScores(
  List<_IdeatingIdeaDraft> ideas,
  List<_DecisionCriterionDraft> criteria,
) {
  final scores = {for (final idea in ideas) idea.id: 0.0};
  for (final criterion in criteria) {
    if (criterion.name.text.trim().isEmpty) continue;
    final weightPercent = int.tryParse(criterion.weight.text.trim()) ?? 0;
    if (weightPercent <= 0) continue;
    for (final idea in ideas) {
      final rating = criterion.ratingFor(idea.id);
      if (rating == null) continue;
      final weightedAverageContribution =
          (weightPercent / 100.0) * (rating / 5.0);
      scores[idea.id] = (scores[idea.id] ?? 0) + weightedAverageContribution;
    }
  }
  return scores;
}

class _IdeaEditorPage extends StatefulWidget {
  const _IdeaEditorPage({
    required this.entryId,
    required this.initial,
    required this.onOpenEvidencePicker,
    required this.onOpenEvidenceEditor,
  });

  final String entryId;
  final _IdeatingIdeaDraft? initial;
  final Future<String?> Function(BuildContext context) onOpenEvidencePicker;
  final Future<_EvidenceBlock?> Function(
    BuildContext context,
    String type,
    _EvidenceBlock? existing,
  )
  onOpenEvidenceEditor;

  @override
  State<_IdeaEditorPage> createState() => _IdeaEditorPageState();
}

class _IdeaEditorPageState extends State<_IdeaEditorPage> {
  late final _IdeatingIdeaDraft _idea;

  @override
  void initState() {
    super.initState();
    _idea = widget.initial?.clone() ?? _IdeatingIdeaDraft.empty();
  }

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  Future<void> _addEvidence() async {
    final type = await widget.onOpenEvidencePicker(context);
    if (!mounted || type == null) return;
    final block = await widget.onOpenEvidenceEditor(context, type, null);
    if (!mounted || block == null) return;
    setState(() => _idea.evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _idea.evidence[index];
    final block = await widget.onOpenEvidenceEditor(
      context,
      existing.type,
      existing,
    );
    if (!mounted || block == null) return;
    setState(() => _idea.evidence[index] = block);
  }

  void _saveIdea() {
    if (!_validateStageTextInputs(context)) return;
    Navigator.of(context).pop(_idea.clone());
  }

  @override
  Widget build(BuildContext context) {
    final platform = ScrollConfiguration.of(context).getPlatform(context);
    final gutter = switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => AppScrollbar.gutterWidth,
      _ => 0.0,
    };
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 444,
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Close idea',
                        icon: const Icon(
                          Icons.close,
                          color: _devGreen,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Center(
                      child: Text(
                        widget.initial == null ? 'Add Idea' : 'Edit Idea',
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          fontSize: AppTypography.pageTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _saveIdea,
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.primary,
                            fontSize: AppTypography.buttonSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageScrollWithFooter(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24 - gutter, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LabeledBox(
                        label: 'Title',
                        controller: _idea.title,
                        height: 36,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _LabeledBox(
                        label: 'Describe the Idea',
                        helperText: 'What is your idea?',
                        controller: _idea.description,
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _LabeledBox(
                        label: 'How would it work?',
                        helperText:
                            'Explain the main components of the process.',
                        controller: _idea.rationale,
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _LabeledBox(
                        label: 'What are the strengths of this idea?',
                        controller: _idea.strengths,
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _LabeledBox(
                        label: 'What are the challenges of this idea?',
                        controller: _idea.challenges,
                        maxLines: 4,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),
                      const OptionalFieldLabel(
                        'Evidence (Optional)',
                        style: TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          color: AppColors.primary,
                          fontSize: AppTypography.evidenceTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_idea.evidence.isEmpty)
                        const _EmptyEvidenceState()
                      else
                        for (var i = 0; i < _idea.evidence.length; i++)
                          _EvidenceSummaryCard(
                            evidence: _idea.evidence[i],
                            onTap: () => _editEvidence(i),
                            onDelete: () =>
                                setState(() => _idea.evidence.removeAt(i)),
                          ),
                      const SizedBox(height: 12),
                      Center(
                        child: AppTapTarget(
                          onTap: _addEvidence,
                          child: Container(
                            width: 202,
                            height: 33,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: _devGreen),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '+ Add Evidence Block',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: AppColors.primary,
                                fontSize: AppTypography.buttonSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportingContextTile extends StatelessWidget {
  const _SupportingContextTile({required this.file, required this.onRemove});

  final _SupportingContextFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        try {
          final url = file.bucket == 'images'
              ? file.publicUrl
              : await StorageService().createSignedUrl(
                  file.path,
                  bucketName: file.bucket,
                );
          if (context.mounted) await _openEvidenceUrl(context, url);
        } catch (_) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This attachment is unavailable or you do not have access.',
                ),
              ),
            );
        }
      },
      child: Container(
        width: 239,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AppTapTarget(
              onTap: onRemove,
              child: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportingContextSheet extends StatefulWidget {
  // ignore: unused_element_parameter
  const _SupportingContextSheet({this.initial});
  final _SupportingContextFile? initial;

  @override
  State<_SupportingContextSheet> createState() =>
      _SupportingContextSheetState();
}

class _SupportingContextSheetState extends State<_SupportingContextSheet> {
  late final TextEditingController _name;
  late final TextEditingController _reference;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _reference = TextEditingController(text: widget.initial?.publicUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .42,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: PageScrollWithFooter(
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Center(
                  child: Text(
                    'Supporting Context',
                    style: TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppMetrics.labelGap),
                _TimelineSheetField(label: 'File Name', controller: _name),
                const SizedBox(height: AppMetrics.labelGap),
                _TimelineSheetField(
                  label: 'Reference or URL',
                  optional: true,
                  controller: _reference,
                ),
                const SizedBox(height: AppMetrics.fieldGap),
                Center(
                  child: _SmallStageButton(
                    label: 'Save',
                    filled: true,
                    onTap: () {
                      final name = _name.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(context).pop(
                        _SupportingContextFile(
                          name: name,
                          path: _reference.text.trim(),
                          publicUrl: _reference.text.trim(),
                          contentType: _attachmentContentType(name),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IdeatingObjectiveDraft {
  _IdeatingObjectiveDraft({required this.id, required String text})
    : text = TextEditingController(text: text);

  factory _IdeatingObjectiveDraft.empty() {
    return _IdeatingObjectiveDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: '',
    );
  }

  factory _IdeatingObjectiveDraft.fromMap(Map<dynamic, dynamic> map) {
    return _IdeatingObjectiveDraft(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      text: map['text']?.toString() ?? '',
    );
  }

  final String id;
  final TextEditingController text;

  bool get hasContent => text.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {'id': id, 'text': text.text.trim()};

  void dispose() => text.dispose();
}

class _IdeatingIdeaDraft {
  _IdeatingIdeaDraft({
    required this.id,
    required String title,
    required String description,
    required String rationale,
    String strengths = '',
    String challenges = '',
    List<_EvidenceBlock>? evidence,
  }) : title = TextEditingController(text: title),
       description = TextEditingController(text: description),
       rationale = TextEditingController(text: rationale),
       strengths = TextEditingController(text: strengths),
       challenges = TextEditingController(text: challenges),
       evidence = evidence ?? [];

  factory _IdeatingIdeaDraft.empty() {
    return _IdeatingIdeaDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '',
      description: '',
      rationale: '',
    );
  }

  factory _IdeatingIdeaDraft.fromMap(Map<dynamic, dynamic> map) {
    final evidence = map['evidence'];
    return _IdeatingIdeaDraft(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      rationale: (map['howItWorks'] ?? map['rationale'])?.toString() ?? '',
      strengths: map['strengths']?.toString() ?? '',
      challenges: map['challenges']?.toString() ?? '',
      evidence: evidence is List
          ? evidence
                .whereType<Map>()
                .map((item) => _EvidenceBlock.fromMap(item))
                .whereType<_EvidenceBlock>()
                .toList()
          : [],
    );
  }

  final String id;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController rationale;
  final TextEditingController strengths;
  final TextEditingController challenges;
  final List<_EvidenceBlock> evidence;

  bool get hasContent {
    return title.text.trim().isNotEmpty ||
        description.text.trim().isNotEmpty ||
        rationale.text.trim().isNotEmpty ||
        strengths.text.trim().isNotEmpty ||
        challenges.text.trim().isNotEmpty ||
        evidence.isNotEmpty;
  }

  _IdeatingIdeaDraft clone() {
    return _IdeatingIdeaDraft(
      id: id,
      title: title.text,
      description: description.text,
      rationale: rationale.text,
      strengths: strengths.text,
      challenges: challenges.text,
      evidence: [...evidence],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title.text.trim(),
      'description': description.text.trim(),
      'rationale': rationale.text.trim(),
      'howItWorks': rationale.text.trim(),
      'strengths': strengths.text.trim(),
      'challenges': challenges.text.trim(),
      'evidence': evidence.map((item) => item.toMap()).toList(),
    };
  }

  void dispose() {
    title.dispose();
    description.dispose();
    rationale.dispose();
    strengths.dispose();
    challenges.dispose();
  }
}

class _DecisionCriterionDraft {
  _DecisionCriterionDraft({
    required this.id,
    required String name,
    required String weight,
    Map<String, String>? ratings,
  }) : name = TextEditingController(text: name),
       weight = TextEditingController(text: weight),
       ratings = {
         for (final entry in (ratings ?? const <String, String>{}).entries)
           entry.key: TextEditingController(text: entry.value),
       };

  factory _DecisionCriterionDraft.empty() {
    return _DecisionCriterionDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: '',
      weight: '',
    );
  }

  factory _DecisionCriterionDraft.fromMap(Map<dynamic, dynamic> map) {
    final ratings = map['ratings'];
    return _DecisionCriterionDraft(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['criterion']?.toString() ?? '',
      weight: map['weight']?.toString() ?? '',
      ratings: ratings is Map
          ? {
              for (final entry in ratings.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : null,
    );
  }

  final String id;
  final TextEditingController name;
  final TextEditingController weight;
  final Map<String, TextEditingController> ratings;

  bool get hasScores {
    return ratings.values.any((controller) {
      final rating = int.tryParse(controller.text.trim());
      return rating != null && rating >= 1 && rating <= 5;
    });
  }

  TextEditingController controllerFor(String ideaId) {
    return ratings.putIfAbsent(ideaId, () => TextEditingController());
  }

  int? ratingFor(String ideaId) {
    final rating = int.tryParse(ratings[ideaId]?.text.trim() ?? '');
    if (rating == null || rating < 1 || rating > 5) return null;
    return rating;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'criterion': name.text.trim(),
      'weight': int.tryParse(weight.text.trim()) ?? 0,
      'ratings': {
        for (final entry in ratings.entries)
          entry.key: int.tryParse(entry.value.text.trim()) ?? 0,
      },
    };
  }

  void dispose() {
    name.dispose();
    weight.dispose();
    for (final controller in ratings.values) {
      controller.dispose();
    }
  }
}

class _SupportingContextFile {
  const _SupportingContextFile({
    required this.name,
    required this.path,
    required this.publicUrl,
    required this.contentType,
    this.bucket = 'images',
  });

  factory _SupportingContextFile.fromUpload(
    UploadedStorageFile file, {
    String bucket = 'images',
  }) {
    return _SupportingContextFile(
      name: file.fileName,
      path: file.path,
      bucket: bucket,
      publicUrl: file.publicUrl,
      contentType: _attachmentContentType(file.fileName),
    );
  }

  factory _SupportingContextFile.fromMap(Map<dynamic, dynamic> map) {
    return _SupportingContextFile(
      bucket: map['bucket']?.toString() ?? 'images',
      name: map['name']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      publicUrl: map['publicUrl']?.toString() ?? '',
      contentType: map['contentType']?.toString() ?? '',
    );
  }

  final String bucket;
  final String name;
  final String path;
  final String publicUrl;
  final String contentType;

  Map<String, dynamic> toMap() {
    return {
      'bucket': bucket,
      'name': name,
      'path': path,
      'publicUrl': publicUrl,
      'contentType': contentType,
    };
  }
}

String _attachmentContentType(String fileName) {
  final extension = fileName.contains('.')
      ? fileName.split('.').last.toLowerCase()
      : '';
  return switch (extension) {
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'txt' => 'text/plain',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
}

class IdeatingEntryPreviewPage extends StatefulWidget {
  const IdeatingEntryPreviewPage({super.key, required this.entry});

  final JournalEntry entry;

  @override
  State<IdeatingEntryPreviewPage> createState() =>
      _IdeatingEntryPreviewPageState();
}

class _IdeatingEntryPreviewPageState extends State<IdeatingEntryPreviewPage> {
  late final _IdeatingPreviewData _data;
  @override
  void initState() {
    super.initState();
    _data = _IdeatingPreviewData.fromEntry(widget.entry);
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrototypeTopBar(
                      title: 'Journal Entry: Ideation',
                      previewEntry: widget.entry,
                      onBack: () => Navigator.of(context).pop(),
                      inset: 0,
                      trailingLabel: 'Exit',
                      onTrailing: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: AppMetrics.fieldGap),
                    Text(widget.entry.title, style: AppTypography.pageTitle),
                    const SizedBox(height: AppMetrics.fieldGap),
                    for (final previewSection in _IdeatingStage.values)
                      switch (previewSection) {
                        _IdeatingStage.challenge => _IdeatingChallengePreview(
                          data: _data,
                        ),
                        _IdeatingStage.ideas => _IdeatingIdeasPreview(
                          data: _data,
                        ),
                        _IdeatingStage.decisionMatrix => _IdeatingMatrixPreview(
                          data: _data,
                        ),
                        _IdeatingStage.learning => _LearningPreviewContent(
                          reflection: _data.nextLearned,
                          selectedDci: _data.selectedDci,
                          selectedSep: _data.selectedSep,
                          selectedCcc: _data.selectedCcc,
                          inquiryLensData: _data.inquiryLensData,
                          assessment: _data.learningAssessment,
                        ),
                        _IdeatingStage.nextAction => _NextActionPreviewContent(
                          projectId: widget.entry.projectId,
                          includeLearned: false,
                          learned: _data.nextLearned,
                          challenges: _data.nextChallenges,
                          nextSteps: _data.nextSteps,
                          notes: _data.nextNotes,
                          linkedTimelineEvent: _data.linkedTimelineEvent,
                        ),
                      },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeatingChallengePreview extends StatelessWidget {
  const _IdeatingChallengePreview({required this.data});

  final _IdeatingPreviewData data;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      title: 'Challenge',
      children: [
        _PreviewField('Challenge Title', data.challengeTitle),
        _PreviewField('Challenge', data.challengeProblem),
        const Text(
          'Objectives',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        if (data.objectives.isEmpty)
          const _PreviewMutedText('No objectives saved.')
        else
          for (var i = 0; i < data.objectives.length; i++)
            _NumberedPreviewRow(number: i + 1, text: data.objectives[i]),
        const SizedBox(height: AppMetrics.labelGap),
        const Text(
          'Supporting Context',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        if (data.supportingContext == null)
          const _PreviewMutedText('No supporting context attached.')
        else
          _SupportingContextTile(
            file: data.supportingContext!,
            onRemove: () {},
          ),
        const SizedBox(height: AppMetrics.labelGap),
        JournalInvolvedPeoplePreview(people: data.members),
      ],
    );
  }
}

class _IdeatingIdeasPreview extends StatelessWidget {
  const _IdeatingIdeasPreview({required this.data});

  final _IdeatingPreviewData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < data.ideas.length; i++)
          _PreviewPanel(
            title: data.ideas[i].title.text.trim().isEmpty
                ? 'Idea ${i + 1}'
                : data.ideas[i].title.text.trim(),
            color: _ideaColor(i),
            children: [
              Text(
                'Idea Score: ${_formatIdeaScore(data.scores[data.ideas[i].id])}',
                style: TextStyle(
                  color: _ideaColor(i),
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _PreviewField('Description', data.ideas[i].description.text),
              _PreviewField('How would it work?', data.ideas[i].rationale.text),
              _PreviewField('Strengths', data.ideas[i].strengths.text),
              _PreviewField('Challenges', data.ideas[i].challenges.text),
              const Text(
                'Evidence',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              if (data.ideas[i].evidence.isEmpty)
                const _PreviewMutedText('No evidence blocks attached.')
              else
                for (final evidence in data.ideas[i].evidence)
                  _EvidencePreviewBlock(evidence: evidence),
            ],
          ),
        if (data.ideas.isEmpty) const _PreviewMutedText('No ideas saved.'),
      ],
    );
  }
}

class _IdeatingMatrixPreview extends StatelessWidget {
  const _IdeatingMatrixPreview({required this.data});

  final _IdeatingPreviewData data;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      title: 'Decision Matrix',
      children: [
        const Text(
          'Each idea is rated from 1–5 against your criteria. Weights show what matters most; weighted total scores are out of 100.',
          style: AppTypography.helper,
        ),
        const SizedBox(height: 16),
        _ReadOnlyDecisionMatrix(
          ideas: data.ideas,
          criteria: data.criteria,
          scores: data.scores,
        ),
      ],
    );
  }
}

class _ReadOnlyDecisionMatrix extends StatelessWidget {
  const _ReadOnlyDecisionMatrix({
    required this.ideas,
    required this.criteria,
    required this.scores,
  });

  final List<_IdeatingIdeaDraft> ideas;
  final List<_DecisionCriterionDraft> criteria;
  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    const columnWidth = 72.0;
    return PageScrollWithFooter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 154,
                    height: 58,
                    child: _MatrixHeader('Criteria'),
                  ),
                  for (var i = 0; i < ideas.length; i++)
                    Container(
                      width: columnWidth,
                      height: 58,
                      alignment: Alignment.center,
                      color: _ideaColor(i).withValues(alpha: .14),
                      child: _MatrixHeader(
                        ideas[i].title.text.trim().isEmpty
                            ? 'Idea ${i + 1}'
                            : ideas[i].title.text.trim(),
                        color: _ideaColor(i),
                      ),
                    ),
                ],
              ),
              for (final criterion in criteria.where(
                (item) => item.name.text.trim().isNotEmpty,
              ))
                Row(
                  children: [
                    Container(
                      width: 154,
                      height: 62,
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            criterion.name.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            'Weight: ${criterion.weight.text}%',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.textSecondary,
                              fontSize: AppTypography.helperSize,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < ideas.length; i++)
                      Container(
                        width: columnWidth,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _ideaColor(i).withValues(alpha: .05),
                          border: const Border(
                            top: BorderSide(color: Color(0xFFE5E5E5)),
                            left: BorderSide(color: Color(0xFFE5E5E5)),
                          ),
                        ),
                        child: Text(
                          criterion.ratingFor(ideas[i].id)?.toString() ?? '--',
                          style: TextStyle(
                            color: _ideaColor(i),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              Row(
                children: [
                  const SizedBox(
                    width: 154,
                    height: 44,
                    child: _MatrixHeader('Total Score'),
                  ),
                  for (var i = 0; i < ideas.length; i++)
                    SizedBox(
                      width: columnWidth,
                      height: 44,
                      child: Center(
                        child: Text(
                          _formatIdeaScore(scores[ideas[i].id]),
                          style: TextStyle(
                            color: _ideaColor(i),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.title,
    required this.children,
    this.color = _devGreen,
  });

  final String title;
  final List<Widget> children;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              color: color,
              fontSize: AppTypography.sectionTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

IconData _analysisSourceIcon(String label) {
  for (final source in _analysisSources) {
    if (source.$1 == label) return source.$3;
  }
  return Icons.note_add_outlined;
}

class _PreviewField extends StatelessWidget {
  const _PreviewField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    Widget? optionIcon;
    String? explanation;
    if (label == 'Pattern Changes') {
      final options = _patternChangeOptions.where(
        (option) => option.label == value,
      );
      if (options.isNotEmpty) {
        optionIcon = SizedBox(
          width: 28,
          height: 28,
          child: _StackedSvgIcon(assets: options.first.assets),
        );
        explanation = options.first.description;
      }
    } else if (label == 'Outcomes & Rating') {
      final options = _prototypeTestOutcomes.where(
        (option) => option[0] == value,
      );
      if (options.isNotEmpty) {
        optionIcon = Icon(
          switch (value) {
            'Unsuccessful' => Icons.link_off_outlined,
            'Needs Revision' => Icons.local_fire_department_outlined,
            'Promising' => Icons.remove_circle_outline,
            'Validated' => Icons.science_outlined,
            _ => Icons.verified_user_outlined,
          },
          color: _devGreen,
          size: 28,
        );
        explanation = options.first[1];
      }
    } else if (label == 'Calculation Type') {
      optionIcon = Icon(
        switch (value) {
          'Performance' => Icons.speed_outlined,
          'Comparison' => Icons.balance_outlined,
          'Estimate' => Icons.bar_chart_outlined,
          _ => Icons.paid_outlined,
        },
        color: _devGreen,
        size: 28,
      );
      explanation = switch (value) {
        'Performance' => 'Evaluate how well a design or system performs.',
        'Comparison' =>
          'Compare alternatives or existing and proposed conditions.',
        'Estimate' => 'Estimate a quantity using available information.',
        _ => 'Examine costs and the value of an option.',
      };
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.replaceAll(' (Optional)', ''),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          if (optionIcon != null)
            Row(
              children: [
                optionIcon,
                const SizedBox(width: 12),
                Expanded(child: Text(value, style: AppTypography.fieldLabel)),
              ],
            )
          else
            _PreviewMutedText(value.trim()),
          if (explanation != null) ...[
            const SizedBox(height: 8),
            _PreviewMutedText(explanation),
          ],
        ],
      ),
    );
  }
}

class _NumberedPreviewRow extends StatelessWidget {
  const _NumberedPreviewRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _devGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.white,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _PreviewMutedText(text)),
        ],
      ),
    );
  }
}

class _LearningPreviewContent extends StatelessWidget {
  const _LearningPreviewContent({
    required this.selectedDci,
    required this.selectedSep,
    required this.selectedCcc,
    required this.inquiryLensData,
    required this.assessment,
    this.reflection = '',
  });
  final Set<String> selectedDci, selectedSep, selectedCcc;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final String reflection;
  @override
  Widget build(BuildContext context) {
    final lens = InquiryLensConfig.byValue(inquiryLensData.selectedLens);
    final connections = [
      ('Disciplinary connection', 'dci', selectedDci),
      ('Practice used', 'sep', selectedSep),
      ('Concept explored', 'ccc', selectedCcc),
    ];
    if (lens == null &&
        reflection.trim().isEmpty &&
        connections.every((item) => item.$3.isEmpty) &&
        (!assessmentFeaturesEnabled || assessment.type == null))
      return const SizedBox.shrink();
    return _PreviewPanel(
      title: 'Learning',
      children: [
        if (lens != null) ...[
          _LearningPreviewLens(
            config: lens,
            state: inquiryLensData.activeState(lens),
          ),
          const SizedBox(height: 24),
        ],
        if (reflection.trim().isNotEmpty) ...[
          const Text('What I learned', style: AppTypography.fieldLabel),
          const SizedBox(height: 12),
          Text(
            reflection.trim(),
            style: AppTypography.body.copyWith(
              height: 1.65,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (connections.any((item) => item.$3.isNotEmpty)) ...[
          const Text(
            'The Three Dimensions of Learning',
            style: AppTypography.fieldLabel,
          ),
          const SizedBox(height: 16),
        ],
        for (final dimension in [
          ('DCI', 'Disciplinary Core Ideas', 'dci', selectedDci),
          ('SEP', 'Science and Engineering Practices', 'sep', selectedSep),
          ('CCCs', 'Crosscutting Concepts', 'ccc', selectedCcc),
        ])
          if (dimension.$4.any((value) => value.trim().isNotEmpty)) ...[
            _LearningPreviewDimensionCard(
              title: dimension.$1,
              subtitle: dimension.$2,
              iconAsset: 'assets/learning_module/summary_${dimension.$3}.svg',
              values: dimension.$4,
            ),
            const SizedBox(height: 16),
          ],
        if (assessmentFeaturesEnabled && assessment.type != null)
          _AssessmentPreviewCard(assessment: assessment),
      ],
    );
  }
}

class _NextActionPreviewContent extends StatelessWidget {
  const _NextActionPreviewContent({
    required this.projectId,
    required this.learned,
    this.includeLearned = true,
    required this.challenges,
    required this.nextSteps,
    required this.notes,
    required this.linkedTimelineEvent,
  });

  final String projectId;
  final String learned;
  final bool includeLearned;
  final String challenges;
  final String nextSteps;
  final String notes;
  final Map<String, String>? linkedTimelineEvent;

  @override
  Widget build(BuildContext context) {
    if ([
      if (includeLearned) learned,
      challenges,
      nextSteps,
      notes,
    ].every((value) => value.trim().isEmpty))
      return const SizedBox.shrink();
    return _PreviewPanel(
      title: 'Next Action',
      children: [
        if (includeLearned) _PreviewField('What I learned', learned),
        _PreviewField('Challenges and open questions', challenges),
        _PreviewField('What I’ll try next', nextSteps),
        _PreviewField('Additional thoughts', notes),
      ],
    );
  }
}

class _IdeatingPreviewData {
  _IdeatingPreviewData({
    required this.challengeTitle,
    required this.challengeProblem,
    required this.objectives,
    required this.supportingContext,
    required this.members,
    required this.ideas,
    required this.criteria,
    required this.selectedDci,
    required this.selectedSep,
    required this.selectedCcc,
    required this.inquiryLensData,
    required this.learningAssessment,
    required this.nextLearned,
    required this.nextChallenges,
    required this.nextSteps,
    required this.nextNotes,
    required this.linkedTimelineEvent,
  }) : scores = _calculateIdeaScores(ideas, criteria);

  factory _IdeatingPreviewData.fromEntry(JournalEntry entry) {
    final challenge = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'challenge',
      orElse: () => const {},
    );
    final ideasStage = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'ideas',
      orElse: () => const {},
    );
    final matrix = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'decisionMatrix',
      orElse: () => const {},
    );
    final learning = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'learning',
      orElse: () => const {},
    );
    final nextAction = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'nextAction',
      orElse: () => const {},
    );
    final supporting = challenge['supportingContext'];
    final linked = nextAction['linkedTimelineEvent'];
    return _IdeatingPreviewData(
      challengeTitle: challenge['title']?.toString() ?? '',
      challengeProblem: challenge['problem']?.toString() ?? '',
      objectives: _maps(challenge['objectives'])
          .map((item) => item['text']?.toString() ?? '')
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      supportingContext: supporting is Map
          ? _SupportingContextFile.fromMap(supporting)
          : null,
      members: _maps(challenge['involved']),
      ideas: _maps(ideasStage['items'])
          .map((item) => _IdeatingIdeaDraft.fromMap(item))
          .where((item) => item.hasContent)
          .toList(),
      criteria: _maps(
        matrix['criteria'],
      ).map((item) => _DecisionCriterionDraft.fromMap(item)).toList(),
      selectedDci: _stringSet(learning['dci']),
      selectedSep: _stringSet(learning['sep']),
      selectedCcc: _stringSet(learning['ccc']),
      inquiryLensData: InquiryLensData.fromJson(
        learning['inquiryLensData'],
        legacyLens:
            learning['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
      ),
      learningAssessment: AssessmentBlockData.fromJson(learning['assessment']),
      nextLearned: nextAction['learned']?.toString() ?? '',
      nextChallenges: nextAction['challenges']?.toString() ?? '',
      nextSteps: nextAction['nextSteps']?.toString() ?? '',
      nextNotes: nextAction['notes']?.toString() ?? '',
      linkedTimelineEvent: linked is Map
          ? {
              for (final entry in linked.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : null,
    );
  }

  final String challengeTitle;
  final String challengeProblem;
  final List<String> objectives;
  final _SupportingContextFile? supportingContext;
  final List<Map> members;
  final List<_IdeatingIdeaDraft> ideas;
  final List<_DecisionCriterionDraft> criteria;
  final Set<String> selectedDci;
  final Set<String> selectedSep;
  final Set<String> selectedCcc;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData learningAssessment;
  final String nextLearned;
  final String nextChallenges;
  final String nextSteps;
  final String nextNotes;
  final Map<String, String>? linkedTimelineEvent;
  final Map<String, double> scores;

  void dispose() {
    for (final idea in ideas) {
      idea.dispose();
    }
    for (final criterion in criteria) {
      criterion.dispose();
    }
  }
}

class _PrototypeComponentsPage extends StatefulWidget {
  const _PrototypeComponentsPage({
    required this.projectId,
    required this.projectsRepo,
    required this.iteration,
    required this.iterationIndex,
    required this.onChanged,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final _PrototypeIterationDraft iteration;
  final int iterationIndex;
  final VoidCallback onChanged;

  @override
  State<_PrototypeComponentsPage> createState() =>
      _PrototypeComponentsPageState();
}

class _PrototypeComponentsPageState extends State<_PrototypeComponentsPage> {
  Future<void> _addComponent() async {
    final component = await pushAppRoute<_PrototypeComponentDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeComponentEditorPage(
          onDraftChanged: (draft) {
            final index = widget.iteration.components.indexWhere(
              (item) => item.id == draft.id,
            );
            if (index < 0) {
              widget.iteration.components.add(draft);
            } else {
              widget.iteration.components[index] = draft;
            }
            widget.onChanged();
          },
        ),
      ),
    );
    if (component == null || !mounted) return;
    setState(() {
      if (!widget.iteration.components.any((item) => item.id == component.id)) {
        widget.iteration.components.add(component);
      }
    });
    widget.onChanged();
  }

  Future<void> _editComponent(int index) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeComponentEditorPage(
          existing: widget.iteration.components[index],
          onDraftChanged: (draft) {
            widget.iteration.components[index] = draft;
            _refresh();
          },
        ),
      ),
    );
    if (mounted) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  /// Build section: opens the editable Build Log list (each log is a journal
  /// entry with its own Learning / Next Action). Previews are removed for now.
  Future<void> _openBuild(_PrototypeComponentDraft component) async {
    await pushAppRoute<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeBuildLogsPage(
          component: component,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: _refresh,
        ),
      ),
    );
    _refresh();
  }

  /// Test section: opens the editable Test Log list.
  Future<void> _openTest(_PrototypeComponentDraft component) async {
    await pushAppRoute<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeTestLogsPage(
          component: component,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: _refresh,
        ),
      ),
    );
    _refresh();
  }

  void _moveComponent(int index, int delta) {
    final target = index + delta;
    final components = widget.iteration.components;
    if (target < 0 || target >= components.length) return;
    setState(() {
      final item = components.removeAt(index);
      components.insert(target, item);
    });
    widget.onChanged();
  }

  Future<void> _openComponent(_PrototypeComponentDraft component) async {
    await pushAppRoute<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeComponentDetailPage(
          component: component,
          onBuild: () => _openBuild(component),
          onTest: () => _openTest(component),
          onMaterials: () => _openMaterials(component),
        ),
      ),
    );
  }

  Future<void> _deleteComponent(int index) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Component',
      message: 'Delete this component and its build logs?',
      action: 'Delete Component',
    );
    if (!ok || !mounted) return;
    setState(() => widget.iteration.components.removeAt(index));
    widget.onChanged();
  }

  /// Materials section: opens the editable [MaterialsCostPage] for this
  /// component (preview removed for now).
  Future<void> _openMaterials(_PrototypeComponentDraft component) async {
    await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialsCostPage(
          projectId: widget.projectId,
          projectName: component.name,
          tags: const [],
          projectsRepo: widget.projectsRepo,
          componentName: component.name,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final components = widget.iteration.components;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: 'Journal Entry: Prototyping',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: PageScrollWithFooter(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(46, 4, 46, 8),
                      children: [
                        const JournalSectionHeader(title: 'Components'),
                        const Text(
                          'Create and develop components of your prototype.',
                          style: AppTypography.helper,
                        ),
                        const SizedBox(height: AppMetrics.sectionGap),
                        for (var i = 0; i < components.length; i++)
                          _PrototypeComponentListCard(
                            component: components[i],
                            onEdit: () => _editComponent(i),
                            index: i,
                            onTap: () => _openComponent(components[i]),
                            onDelete: () => _deleteComponent(i),
                            onMoveUp: i > 0
                                ? () => _moveComponent(i, -1)
                                : null,
                            onMoveDown: i < components.length - 1
                                ? () => _moveComponent(i, 1)
                                : null,
                          ),
                        const SizedBox(height: 8),
                        Center(
                          child: SizedBox(
                            width: 242,
                            child: _PrototypeOutlinedAction(
                              label: '+ Component',
                              onTap: _addComponent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeComponentEditorPage extends StatefulWidget {
  const _PrototypeComponentEditorPage({this.onDraftChanged, this.existing});
  final _PrototypeComponentDraft? existing;

  final ValueChanged<_PrototypeComponentDraft>? onDraftChanged;

  @override
  State<_PrototypeComponentEditorPage> createState() =>
      _PrototypeComponentEditorPageState();
}

class _PrototypeComponentEditorPageState
    extends State<_PrototypeComponentEditorPage>
    with DraftAutosave<_PrototypeComponentEditorPage> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final List<TextEditingController> _features =
      widget.existing == null || widget.existing!.features.isEmpty
      ? [TextEditingController()]
      : [
          for (final text in widget.existing!.features)
            TextEditingController(text: text),
        ];
  late var _status = widget.existing?.status ?? 'In Progress';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final feature in _features) {
      feature.dispose();
    }
    super.dispose();
  }

  void _addFeature() {
    setState(() => _features.add(TextEditingController()));
  }

  void _removeFeature(int index) {
    if (_features.length == 1) return;
    setState(() => _features.removeAt(index).dispose());
  }

  void _reorderFeature(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _features.removeAt(oldIndex);
      _features.insert(newIndex, item);
    });
  }

  late final String _draftId = DateTime.now().microsecondsSinceEpoch.toString();
  @override
  String get draftFingerprint => jsonEncode([
    _name.text,
    _description.text,
    _status,
    _features.map((c) => c.text).toList(),
  ]);
  @override
  Future<bool> writeAutosave() async {
    _captureDraft(false);
    return true;
  }

  void _emitDraft(_PrototypeComponentDraft draft, bool close) {
    widget.onDraftChanged?.call(draft);
    if (close) Navigator.of(context).pop(draft);
  }

  void _save() {
    if (!_validateStageTextInputs(context)) return;
    _captureDraft(true);
  }

  void _captureDraft(bool close) {
    if (_name.text.trim().isEmpty) {
      if (close) Navigator.of(context).pop();
      return;
    }
    _emitDraft(
      _PrototypeComponentDraft(
        id: widget.existing?.id ?? _draftId,
        buildLogs: widget.existing?.buildLogs,
        testEntries: widget.existing?.testEntries,
        learning: widget.existing?.learning,
        nextAction: widget.existing?.nextAction,
        name: _name.text.trim(),
        description: _description.text.trim(),
        status: _status,
        features: _features
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      ),
      close,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Component',
      onSave: _save,
      onBack: () => _captureDraft(true),
      children: [
        const Text(
          'Component Overview',
          style: TextStyle(
            fontFamily: AppTypography.headingFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.sectionTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _LabeledBox(label: 'Title Component', controller: _name, height: 64),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Purpose of the Component',
          controller: _description,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const Text(
          'Status',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'What is the current build status of the component?',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        _PrototypeStatusSelector(
          value: _status,
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const Text(
          'Key Features',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'What features do we hope this component will have.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        _PrototypeFeatureList(
          features: _features,
          onAdd: _addFeature,
          onRemove: _removeFeature,
          onReorder: _reorderFeature,
        ),
        const SizedBox(height: 94),
        Center(
          child: _SmallStageButton(label: 'Add', filled: true, onTap: _save),
        ),
      ],
    );
  }
}

class _PrototypeBuildLogsPage extends StatefulWidget {
  const _PrototypeBuildLogsPage({
    required this.component,
    required this.projectId,
    required this.projectsRepo,
    required this.onChanged,
  });

  final _PrototypeComponentDraft component;
  final String projectId;
  final ProjectsRepo projectsRepo;
  final VoidCallback onChanged;

  @override
  State<_PrototypeBuildLogsPage> createState() =>
      _PrototypeBuildLogsPageState();
}

class _PrototypeBuildLogsPageState extends State<_PrototypeBuildLogsPage> {
  Future<void> _addLog() async {
    final log = await pushAppRoute<_PrototypeBuildLogDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeBuildLogEditorPage(
          projectId: widget.projectId,
          onNavigate: (draft, index) => _openLogLearning(
            draft,
            initialStage: index,
            returnToEditor: true,
          ),
          onDraftChanged: (draft) {
            final index = widget.component.buildLogs.indexWhere(
              (item) => item.id == draft.id,
            );
            if (index < 0) {
              widget.component.buildLogs.add(draft);
            } else {
              widget.component.buildLogs[index] = draft;
            }
            widget.onChanged();
          },
        ),
      ),
    );
    if (log == null || !mounted) return;
    setState(() {
      if (!widget.component.buildLogs.any((item) => item.id == log.id)) {
        widget.component.buildLogs.add(log);
      }
    });
    widget.onChanged();
    await _openLogLearning(log);
  }

  Future<void> _editLog(int index) async {
    final log = widget.component.buildLogs[index];
    final updated = await pushAppRoute<_PrototypeBuildLogDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeBuildLogEditorPage(
          projectId: widget.projectId,
          onNavigate: (draft, index) => _openLogLearning(
            draft,
            initialStage: index,
            returnToEditor: true,
          ),
          existing: log,
          onDraftChanged: (draft) {
            final index = widget.component.buildLogs.indexWhere(
              (item) => item.id == draft.id,
            );
            if (index < 0) {
              widget.component.buildLogs.add(draft);
            } else {
              widget.component.buildLogs[index] = draft;
            }
            widget.onChanged();
          },
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {});
    widget.onChanged();
    await _openLogLearning(log);
  }

  /// Each build log owns its own Learning -> Next Action stages.
  Future<void> _openLogLearning(
    _PrototypeBuildLogDraft log, {
    int initialStage = 1,
    bool returnToEditor = false,
  }) async {
    final result = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeLogLearningFlow(
          target: log,
          initialStage: initialStage,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
    if (result == false && !returnToEditor) {
      final index = widget.component.buildLogs.indexWhere(
        (item) => item.id == log.id,
      );
      if (index >= 0) await _editLog(index);
    }
  }

  Future<void> _deleteLog(int index) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Build Log',
      message: 'Delete this build log?',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => widget.component.buildLogs.removeAt(index));
    widget.onChanged();
  }

  void _moveLog(int index, int delta) {
    final target = index + delta;
    final logs = widget.component.buildLogs;
    if (target < 0 || target >= logs.length) return;
    setState(() {
      final item = logs.removeAt(index);
      logs.insert(target, item);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeBuildLogDashboard(
      component: widget.component,
      onAddLog: _addLog,
      onOpenLog: _editLog,
      onDeleteLog: _deleteLog,
      onMoveLog: _moveLog,
    );
  }
}

class _PrototypeBuildLogDashboard extends StatelessWidget {
  const _PrototypeBuildLogDashboard({
    required this.component,
    required this.onAddLog,
    required this.onOpenLog,
    required this.onDeleteLog,
    required this.onMoveLog,
  });

  final _PrototypeComponentDraft component;
  final VoidCallback onAddLog;
  final ValueChanged<int> onOpenLog;
  final ValueChanged<int> onDeleteLog;
  final void Function(int index, int delta) onMoveLog;

  @override
  Widget build(BuildContext context) {
    final logs = component.buildLogs;
    return _PrototypeScaffold(
      title: 'Component: ${component.name}',
      onBack: () => Navigator.of(context).pop(),
      actionLabel: '+ New Build Log',
      onAction: onAddLog,
      body: PageScrollWithFooter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(44, 4, 44, 8),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/prototyping/build_wrench.svg',
                  width: 37,
                  height: 37,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Build Log',
                  style: TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.sectionTitleSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PrototypeCountHeader(count: logs.length, label: 'Entries'),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFE5E5E5)),
            const SizedBox(height: 16),
            for (var i = 0; i < logs.length; i++)
              _PrototypeBuildLogFigmaCard(
                log: logs[i],
                onTap: () => onOpenLog(i),
                onDelete: () => onDeleteLog(i),
                onMoveUp: i > 0 ? () => onMoveLog(i, -1) : null,
                onMoveDown: i < logs.length - 1 ? () => onMoveLog(i, 1) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeBuildLogEditorPage extends StatefulWidget {
  const _PrototypeBuildLogEditorPage({
    required this.projectId,
    this.onDraftChanged,
    this.existing,
    this.onNavigate,
  });
  final Future<void> Function(_PrototypeBuildLogDraft, int)? onNavigate;

  final ValueChanged<_PrototypeBuildLogDraft>? onDraftChanged;

  final _PrototypeBuildLogDraft? existing;

  final String projectId;

  @override
  State<_PrototypeBuildLogEditorPage> createState() =>
      _PrototypeBuildLogEditorPageState();
}

class _PrototypeBuildLogEditorPageState
    extends State<_PrototypeBuildLogEditorPage>
    with DraftAutosave<_PrototypeBuildLogEditorPage> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _summary = TextEditingController(
    text: widget.existing?.summary ?? '',
  );
  late final _challenges = TextEditingController(
    text: widget.existing?.challenges ?? '',
  );
  late final List<_EvidenceBlock> _evidence = [...?widget.existing?.evidence];

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _challenges.dispose();
    super.dispose();
  }

  Future<void> _addEvidence() async {
    final type = await showAppDialog<String>(
      context: context,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(
      context,
      type,
      null,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence[index] = block);
  }

  late final String _draftId = DateTime.now().microsecondsSinceEpoch.toString();
  @override
  String get draftFingerprint => jsonEncode([
    _title.text,
    _summary.text,
    _challenges.text,
    _evidence.map((e) => e.toMap()).toList(),
  ]);
  @override
  Future<bool> writeAutosave() async {
    _captureDraft(false);
    return true;
  }

  _PrototypeBuildLogDraft? _currentDraft;
  final Set<int> _visitedStages = {0};
  int? _requestedStage;
  void _navigateStage(int index) {
    if (index == 0) return;
    _requestedStage = index;
    _captureDraft(false);
    _requestedStage = null;
  }

  Future<void> _openTrackedStage(
    _PrototypeBuildLogDraft draft,
    int index,
  ) async {
    await widget.onNavigate?.call(draft, index);
    if (mounted) setState(() {});
  }

  void _emitDraft(_PrototypeBuildLogDraft draft, bool close) {
    draft.visitedStages.addAll(_visitedStages);
    _currentDraft = draft;
    widget.onDraftChanged?.call(draft);
    if (_requestedStage != null) _openTrackedStage(draft, _requestedStage!);
    if (close) Navigator.of(context).pop(draft);
  }

  void _save() {
    if (!_validateStageTextInputs(context)) return;
    _captureDraft(true);
  }

  void _captureDraft(bool close) {
    if (_title.text.trim().isEmpty && _requestedStage == null) {
      if (close) Navigator.of(context).pop();
      return;
    }
    final existing = _currentDraft ?? widget.existing;
    if (existing != null) {
      existing.title = _title.text.trim();
      existing.summary = _summary.text.trim();
      existing.challenges = _challenges.text.trim();
      existing.evidence = [..._evidence];
      _emitDraft(existing, close);
    } else {
      _emitDraft(
        _PrototypeBuildLogDraft(
          id: _draftId,
          title: _title.text.trim(),
          summary: _summary.text.trim(),
          challenges: _challenges.text.trim(),
          createdAt: DateTime.now(),
          evidence: [..._evidence],
        ),
        close,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Journal Entry: Prototyping',
      onSave: _save,
      onBack: () => _captureDraft(true),
      children: [
        _PrototypeGuidedStepper(
          activeIndex: 0,
          onSelected: _navigateStage,
          completion: () => _completedLogStages(
            [_title, _summary].every((field) => field.text.trim().isNotEmpty),
            (_currentDraft ?? widget.existing)?.learning ?? {},
            (_currentDraft ?? widget.existing)?.nextAction ?? {},
          ),
          inputs: Listenable.merge([_title, _summary]),
          visitedIndices:
              (_currentDraft ?? widget.existing)?.visitedStages ??
              _visitedStages,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        Row(
          children: [
            SvgPicture.asset(
              'assets/prototyping/build_wrench.svg',
              width: 37,
              height: 37,
            ),
            const SizedBox(width: 8),
            const Text(
              'Build',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(label: 'Build Title', controller: _title, height: 64),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Description',
          helperText: 'Explain the methodology of the build.',
          controller: _summary,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const OptionalFieldLabel(
          'Evidence (Optional)',
          style: TextStyle(
            fontFamily: AppTypography.headingFamily,
            fontSize: AppTypography.evidenceTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_evidence.isEmpty)
          const _EmptyEvidenceState()
        else
          for (var i = 0; i < _evidence.length; i++)
            _EvidenceSummaryCard(
              evidence: _evidence[i],
              onTap: () => _editEvidence(i),
              onDelete: () => setState(() => _evidence.removeAt(i)),
            ),
        const SizedBox(height: 12),
        Center(
          child: AppTapTarget(
            onTap: _addEvidence,
            child: Container(
              width: 202,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+ Add Evidence Block',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Design Notes',
          optional: true,
          helperText:
              'Provide additional notes related to the build or design.',
          controller: _challenges,
          minLines: 5,
          maxLines: 5,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        Center(
          child: _SmallStageButton(label: 'Next', filled: true, onTap: _save),
        ),
      ],
    );
  }
}

class _PrototypeTestLogsPage extends StatefulWidget {
  const _PrototypeTestLogsPage({
    required this.component,
    required this.projectId,
    required this.projectsRepo,
    required this.onChanged,
  });

  final _PrototypeComponentDraft component;
  final String projectId;
  final ProjectsRepo projectsRepo;
  final VoidCallback onChanged;

  @override
  State<_PrototypeTestLogsPage> createState() => _PrototypeTestLogsPageState();
}

class _PrototypeTestLogsPageState extends State<_PrototypeTestLogsPage> {
  Future<void> _addTest() async {
    final entry = await pushAppRoute<_PrototypeTestEntryDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeTestEntryEditorPage(
          projectId: widget.projectId,
          onNavigate: (draft, index) => _openTestLearning(
            draft,
            initialStage: index,
            returnToEditor: true,
          ),
          onDraftChanged: (draft) {
            final index = widget.component.testEntries.indexWhere(
              (item) => item.id == draft.id,
            );
            if (index < 0) {
              widget.component.testEntries.add(draft);
            } else {
              widget.component.testEntries[index] = draft;
            }
            widget.onChanged();
          },
        ),
      ),
    );
    if (entry == null || !mounted) return;
    setState(() {
      if (!widget.component.testEntries.any((item) => item.id == entry.id)) {
        widget.component.testEntries.add(entry);
      }
    });
    widget.onChanged();
    await _openTestLearning(entry);
  }

  Future<void> _editTest(int index) async {
    final entry = widget.component.testEntries[index];
    final updated = await pushAppRoute<_PrototypeTestEntryDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeTestEntryEditorPage(
          projectId: widget.projectId,
          onNavigate: (draft, index) => _openTestLearning(
            draft,
            initialStage: index,
            returnToEditor: true,
          ),
          existing: entry,
          onDraftChanged: (draft) {
            final index = widget.component.testEntries.indexWhere(
              (item) => item.id == draft.id,
            );
            if (index < 0) {
              widget.component.testEntries.add(draft);
            } else {
              widget.component.testEntries[index] = draft;
            }
            widget.onChanged();
          },
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {});
    widget.onChanged();
    await _openTestLearning(entry);
  }

  /// Each test log owns its own Learning -> Next Action stages.
  Future<void> _openTestLearning(
    _PrototypeTestEntryDraft entry, {
    int initialStage = 1,
    bool returnToEditor = false,
  }) async {
    final result = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _PrototypeLogLearningFlow(
          target: entry,
          initialStage: initialStage,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
    if (result == false && !returnToEditor) {
      final index = widget.component.testEntries.indexWhere(
        (item) => item.id == entry.id,
      );
      if (index >= 0) await _editTest(index);
    }
  }

  Future<void> _deleteTest(int index) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Test',
      message: 'Delete this test entry?',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => widget.component.testEntries.removeAt(index));
    widget.onChanged();
  }

  void _moveTest(int index, int delta) {
    final target = index + delta;
    final entries = widget.component.testEntries;
    if (target < 0 || target >= entries.length) return;
    setState(() {
      final item = entries.removeAt(index);
      entries.insert(target, item);
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.component.testEntries;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: 'Component: ${widget.component.name}',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: PageScrollWithFooter(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(44, 4, 44, 8),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/prototyping/test_flask.png',
                              width: 37,
                              height: 37,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Test Log',
                              style: TextStyle(
                                fontFamily: AppTypography.headingFamily,
                                color: AppColors.textPrimary,
                                fontSize: AppTypography.sectionTitleSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _PrototypeCountHeader(
                          count: entries.length,
                          label: 'Entries',
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFFE5E5E5)),
                        const SizedBox(height: 16),
                        for (var i = 0; i < entries.length; i++)
                          _PrototypeTestEntryCard(
                            entry: entries[i],
                            onTap: () => _editTest(i),
                            onDelete: () => _deleteTest(i),
                            onMoveUp: i > 0 ? () => _moveTest(i, -1) : null,
                            onMoveDown: i < entries.length - 1
                                ? () => _moveTest(i, 1)
                                : null,
                          ),
                        const SizedBox(height: 8),
                        Center(
                          child: SizedBox(
                            width: 242,
                            child: _PrototypeOutlinedAction(
                              label: '+ Test',
                              onTap: _addTest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
                  child: Center(
                    child: _SmallStageButton(
                      label: 'Finish',
                      filled: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeOutcomeBadge extends StatelessWidget {
  const _PrototypeOutcomeBadge({required this.outcome});

  final String outcome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _devGreen.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        outcome,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _devGreen,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _PrototypeTestEntryCard extends StatelessWidget {
  const _PrototypeTestEntryCard({
    required this.entry,
    required this.onDelete,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
  });

  final _PrototypeTestEntryDraft entry;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: _devGreen, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title.isEmpty ? 'Test Entry' : entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySize,
                        ),
                      ),
                      if (entry.outcome.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _PrototypeOutcomeBadge(outcome: entry.outcome),
                      ],
                    ],
                  ),
                ),
                _PrototypeReorderMenu(
                  onEdit: onTap,
                  onDelete: onDelete,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  iconAsset: 'assets/prototyping/build_pagination.svg',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(entry.createdAt),
                  style: const TextStyle(
                    color: Color(0xFFA1A1A1),
                    fontSize: AppTypography.helperSize,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entry.evidence.length} evidence',
                  style: const TextStyle(
                    color: Color(0xFF717171),
                    fontSize: AppTypography.helperSize,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeTestEntryEditorPage extends StatefulWidget {
  const _PrototypeTestEntryEditorPage({
    required this.projectId,
    this.onDraftChanged,
    this.existing,
    this.onNavigate,
  });
  final Future<void> Function(_PrototypeTestEntryDraft, int)? onNavigate;

  final ValueChanged<_PrototypeTestEntryDraft>? onDraftChanged;

  final _PrototypeTestEntryDraft? existing;

  final String projectId;

  @override
  State<_PrototypeTestEntryEditorPage> createState() =>
      _PrototypeTestEntryEditorPageState();
}

class _PrototypeTestEntryEditorPageState
    extends State<_PrototypeTestEntryEditorPage>
    with DraftAutosave<_PrototypeTestEntryEditorPage> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _method = TextEditingController(
    text: widget.existing?.method ?? '',
  );
  late final _expected = TextEditingController(
    text: widget.existing?.expectedOutcome ?? '',
  );
  late final _feedback = TextEditingController(
    text: widget.existing?.feedback ?? '',
  );
  late final List<_EvidenceBlock> _evidence = [...?widget.existing?.evidence];
  late String _outcome = widget.existing?.outcome ?? '';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _method.dispose();
    _expected.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _addEvidence() async {
    final type = await showAppDialog<String>(
      context: context,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(
      context,
      type,
      null,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
      projectId: widget.projectId,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence[index] = block);
  }

  late final String _draftId = DateTime.now().microsecondsSinceEpoch.toString();
  @override
  String get draftFingerprint => jsonEncode([
    _title.text,
    _description.text,
    _method.text,
    _expected.text,
    _outcome,
    _feedback.text,
    _evidence.map((e) => e.toMap()).toList(),
  ]);
  @override
  Future<bool> writeAutosave() async {
    _captureDraft(false);
    return true;
  }

  _PrototypeTestEntryDraft? _currentDraft;
  final Set<int> _visitedStages = {0};
  int? _requestedStage;
  void _navigateStage(int index) {
    if (index == 0) return;
    _requestedStage = index;
    _captureDraft(false);
    _requestedStage = null;
  }

  Future<void> _openTrackedStage(
    _PrototypeTestEntryDraft draft,
    int index,
  ) async {
    await widget.onNavigate?.call(draft, index);
    if (mounted) setState(() {});
  }

  void _emitDraft(_PrototypeTestEntryDraft draft, bool close) {
    draft.visitedStages.addAll(_visitedStages);
    _currentDraft = draft;
    widget.onDraftChanged?.call(draft);
    if (_requestedStage != null) _openTrackedStage(draft, _requestedStage!);
    if (close) Navigator.of(context).pop(draft);
  }

  void _save() {
    if (!_canAdvanceJournal(
      context,
      _completedLogStages(
        [
              _title,
              _description,
              _method,
              _expected,
            ].every((field) => field.text.trim().isNotEmpty) &&
            _outcome != null,
        (_currentDraft ?? widget.existing)?.learning ?? {},
        (_currentDraft ?? widget.existing)?.nextAction ?? {},
      ),
      0,
      1,
      ['Test', 'Learning', 'Next Action'],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    _captureDraft(true);
  }

  void _captureDraft(bool close) {
    if (_title.text.trim().isEmpty && _requestedStage == null) {
      if (close) Navigator.of(context).pop();
      return;
    }
    final existing = _currentDraft ?? widget.existing;
    if (existing != null) {
      existing.title = _title.text.trim();
      existing.description = _description.text.trim();
      existing.method = _method.text.trim();
      existing.expectedOutcome = _expected.text.trim();
      existing.outcome = _outcome;
      existing.feedback = _feedback.text.trim();
      existing.evidence = [..._evidence];
      _emitDraft(existing, close);
    } else {
      _emitDraft(
        _PrototypeTestEntryDraft(
          id: _draftId,
          title: _title.text.trim(),
          description: _description.text.trim(),
          method: _method.text.trim(),
          expectedOutcome: _expected.text.trim(),
          outcome: _outcome,
          feedback: _feedback.text.trim(),
          createdAt: DateTime.now(),
          evidence: [..._evidence],
        ),
        close,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Journal Entry: Prototyping',
      onSave: _save,
      onBack: () => _captureDraft(true),
      children: [
        _PrototypeGuidedStepper(
          completion: () => _completedLogStages(
            [
                  _title,
                  _description,
                  _method,
                  _expected,
                ].every((field) => field.text.trim().isNotEmpty) &&
                _outcome != null,
            (_currentDraft ?? widget.existing)?.learning ?? {},
            (_currentDraft ?? widget.existing)?.nextAction ?? {},
          ),
          inputs: Listenable.merge([_title, _description, _method, _expected]),
          visitedIndices:
              (_currentDraft ?? widget.existing)?.visitedStages ??
              _visitedStages,
          activeIndex: 0,
          firstLabel: 'Test',
          onSelected: _navigateStage,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        Row(
          children: [
            Image.asset(
              'assets/prototyping/test_flask.png',
              width: 37,
              height: 37,
            ),
            const SizedBox(width: 8),
            const Text(
              'Test',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(label: 'Test Title', controller: _title, height: 64),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Description',
          helperText: 'What are you trying to learn or improve?',
          controller: _description,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Method',
          helperText: 'How did you conduct this test?',
          controller: _method,
          minLines: 5,
          maxLines: 5,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Expected Outcome',
          helperText: 'What results would indicate success?',
          controller: _expected,
          minLines: 5,
          maxLines: 5,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const Text(
          'Outcomes & Rating',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final option in _prototypeTestOutcomes)
              _PrototypeOutcomeOption(
                label: option[0],
                subtitle: option[1],
                selected: _outcome == option[0],
                onTap: () => setState(() => _outcome = option[0]),
              ),
          ],
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        const OptionalFieldLabel(
          'Evidence (Optional)',
          style: TextStyle(
            fontFamily: AppTypography.headingFamily,
            fontSize: AppTypography.evidenceTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (_evidence.isEmpty)
          const _EmptyEvidenceState()
        else
          for (var i = 0; i < _evidence.length; i++)
            _EvidenceSummaryCard(
              evidence: _evidence[i],
              onTap: () => _editEvidence(i),
              onDelete: () => setState(() => _evidence.removeAt(i)),
            ),
        const SizedBox(height: 12),
        Center(
          child: AppTapTarget(
            onTap: _addEvidence,
            child: Container(
              width: 202,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+ Add Evidence Block',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'Feedback & Notes',
          optional: true,
          helperText:
              'Provide additional feedback or notes related to the test.',
          controller: _feedback,
          minLines: 5,
          maxLines: 5,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        Center(
          child: _SmallStageButton(label: 'Next', filled: true, onTap: _save),
        ),
      ],
    );
  }
}

class _PrototypeOutcomeOption extends StatelessWidget {
  const _PrototypeOutcomeOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.width = 108,
    this.compact = false,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textWidth = (constraints.maxWidth - 108).clamp(
        40.0,
        double.infinity,
      );
      double measure(String text, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: textWidth);
        return painter.height;
      }

      var rowHeight = 88.0;
      for (final option in _prototypeTestOutcomes) {
        final height =
            measure(option[0], AppTypography.fieldLabel) +
            measure(option[1], AppTypography.helper) +
            36;
        if (height > rowHeight) rowHeight = height;
      }
      return SizedBox(
        height: rowHeight,
        child: Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected
                    ? _devGreen.withValues(alpha: .08)
                    : Colors.white,
                border: Border.all(
                  color: selected ? _devGreen : const Color(0xFFE5E5E5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (label) {
                      'Unsuccessful' => Icons.link_off_outlined,
                      'Needs Revision' => Icons.local_fire_department_outlined,
                      'Promising' => Icons.remove_circle_outline,
                      'Validated' => Icons.science_outlined,
                      _ => Icons.verified_user_outlined,
                    },
                    size: 24,
                    color: _devGreen,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTypography.fieldLabel),
                        const SizedBox(height: 4),
                        Text(subtitle, style: AppTypography.helper),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? _devGreen : const Color(0xFFB8C1BB),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PrototypeGuidedStepper extends StatelessWidget {
  const _PrototypeGuidedStepper({
    required this.activeIndex,
    this.firstLabel = 'Build',
    this.onSelected,
    this.visitedIndices,
    this.completion,
    this.inputs,
    this.labels,
  });
  final int activeIndex;
  final List<String>? labels;
  final Set<int>? visitedIndices;
  final Set<int> Function()? completion;
  final Listenable? inputs;
  final String firstLabel;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 40),
    child: _StageHeader(
      visitedIndices: visitedIndices,
      completion: completion,
      inputs: inputs,
      activeIndex: activeIndex,
      labels: labels ?? [firstLabel, 'Learning', 'Next Action'],
      onSelected: onSelected,
    ),
  );
}

/// Shared Learning -> Next Action flow for a Prototyping component. Reuses the
/// existing [JournalLearningStageBody] and [_NextActionStageBody] widgets (no
/// duplication); persists the result onto the component.
class _PrototypeLogLearningFlow extends StatefulWidget {
  const _PrototypeLogLearningFlow({
    required this.target,
    this.journalEntryId,
    this.onNavigateToEntryStage,
    this.onActiveStageChanged,
    this.onExit,
    this.onComplete,
    this.initialStage = 1,
    required this.projectId,
    required this.projectsRepo,
    required this.onChanged,
    this.onSaveDraft,
  });

  final _HasLearningStages target;
  final ValueChanged<int>? onNavigateToEntryStage;
  final ValueChanged<int>? onActiveStageChanged;
  final VoidCallback? onExit, onComplete;
  final String? journalEntryId;
  final int initialStage;
  final String projectId;
  final ProjectsRepo projectsRepo;
  final VoidCallback onChanged;
  final Future<bool> Function()? onSaveDraft;

  @override
  State<_PrototypeLogLearningFlow> createState() =>
      _PrototypeLogLearningFlowState();
}

class _PrototypeLogLearningFlowState extends State<_PrototypeLogLearningFlow>
    with DraftAutosave<_PrototypeLogLearningFlow> {
  bool get _building =>
      widget.target is _PrototypeJournalDraft &&
      (widget.target as _PrototypeJournalDraft).type !=
          _PrototypeEntryType.analysis;
  bool get _hasMaterials =>
      widget.target is _PrototypeJournalDraft &&
      (widget.target as _PrototypeJournalDraft).type ==
          _PrototypeEntryType.building;
  int get _learningIndex => _hasMaterials ? 3 : (_building ? 2 : 1);
  int get _nextIndex => _learningIndex + 1;
  List<String> get _flowLabels => _building
      ? [
          'Component',
          _hasMaterials ? 'Build' : 'Test',
          if (_hasMaterials) 'Materials & Cost',
          'Learning',
          'Next Action',
        ]
      : [
          widget.target is _PrototypeJournalDraft
              ? 'Technical Analysis'
              : widget.target is _PrototypeTestEntryDraft
              ? 'Test'
              : 'Build',
          'Learning',
          'Next Action',
        ];
  Set<int> _completedStages() {
    final learning = <String, dynamic>{
      'stage': 'learning',
      'inquiryLens': _inquiryLensData.selectedLens,
      'inquiryLensData': _inquiryLensData.toJson(),
      'dci': _selectedDci.toList(),
      'sep': _selectedSep.toList(),
      'ccc': _selectedCcc.toList(),
      'assessment': _learningAssessment.toJson(),
    };
    final next = <String, dynamic>{
      'stage': 'nextAction',
      'learned': _nextLearned.text,
      'challenges': _nextChallenges.text,
      'nextSteps': _nextSteps.text,
    };
    final target = widget.target;
    if (target is _PrototypeJournalDraft)
      return completedJournalStageIndices([
        {
          'stage': 'prototyping',
          ...target.data,
          'entryType': target.type.value,
        },
        learning,
        next,
      ]);
    final ready = target is _PrototypeBuildLogDraft
        ? target.title.trim().isNotEmpty && target.summary.trim().isNotEmpty
        : target is _PrototypeTestEntryDraft
        ? [
            target.title,
            target.description,
            target.method,
            target.expectedOutcome,
            target.outcome,
          ].every((value) => value.trim().isNotEmpty)
        : false;
    return completedJournalStageIndices([
      {'stage': 'log', 'complete': ready},
      learning,
      next,
    ]);
  }

  @override
  String get draftFingerprint => jsonEncode([
    widget.target.visitedStages.toList()..sort(),
    _selectedDci.toList(),
    _selectedSep.toList(),
    _selectedCcc.toList(),
    _inquiryLensData.toJson(),
    _learningAssessment.toJson(),
    _nextLearned.text,
    _nextChallenges.text,
    _nextSteps.text,
    _nextNotes.text,
    _linkedTimelineEvent,
  ]);
  @override
  Future<bool> writeAutosave() async {
    _persistLearning();
    _persistNextAction(
      submitted: widget.target.nextAction['submitted'] == true,
    );
    return true;
  }

  final List<UserProfile> _members = [];
  final Set<String> _selectedDci = {};
  final Set<String> _selectedSep = {};
  final Set<String> _selectedCcc = {};
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _learningAssessment = const AssessmentBlockData();
  final _nextLearned = TextEditingController();
  final _nextChallenges = TextEditingController();
  final _nextSteps = TextEditingController();
  final _nextNotes = TextEditingController();
  Map<String, String>? _linkedTimelineEvent;
  bool _showNextAction = false;

  @override
  void initState() {
    super.initState();
    _showNextAction = widget.initialStage == _nextIndex;
    _hydrate();
    _loadMembers();
  }

  @override
  void dispose() {
    _nextLearned.dispose();
    _nextChallenges.dispose();
    _nextSteps.dispose();
    _nextNotes.dispose();
    super.dispose();
  }

  void _hydrate() {
    final learning = widget.target.learning;
    _selectedDci.addAll(_stringSet(learning['dci']));
    _selectedSep.addAll(_stringSet(learning['sep']));
    _selectedCcc.addAll(_stringSet(learning['ccc']));
    _inquiryLensData = InquiryLensData.fromJson(
      learning['inquiryLensData'],
      legacyLens:
          learning['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
    );
    _learningAssessment = AssessmentBlockData.fromJson(learning['assessment']);
    final nextAction = widget.target.nextAction;
    _nextLearned.text = nextAction['learned']?.toString() ?? '';
    _nextChallenges.text = nextAction['challenges']?.toString() ?? '';
    _nextSteps.text = nextAction['nextSteps']?.toString() ?? '';
    _nextNotes.text = nextAction['notes']?.toString() ?? '';
    final linked = nextAction['linkedTimelineEvent'];
    if (linked is Map) {
      _linkedTimelineEvent = {
        for (final e in linked.entries)
          e.key.toString(): e.value?.toString() ?? '',
      };
    }
  }

  Future<void> _loadMembers() async {
    final people = await widget.projectsRepo.getProjectMembers(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _members
        ..clear()
        ..addAll(people);
    });
  }

  void _persistLearning() {
    widget.target.learning = {
      'dci': _selectedDci.toList(),
      'sep': _selectedSep.toList(),
      'ccc': _selectedCcc.toList(),
      'inquiryLens': _inquiryLensData.selectedLens,
      'inquiryLensData': _inquiryLensData.toJson(),
      'assessment': _learningAssessment.toJson(),
    };
    widget.onChanged();
  }

  void _persistNextAction({required bool submitted}) {
    widget.target.nextAction = {
      'learned': _nextLearned.text.trim(),
      'challenges': _nextChallenges.text.trim(),
      'nextSteps': _nextSteps.text.trim(),
      'notes': _nextNotes.text.trim(),
      'submitted': submitted,
    };
    widget.onChanged();
  }

  void _toggleSelection(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _createTimelineEvent() => runActionOnce(
    this,
    'timeline-event',
    () async {
      final event = await showAppModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CreateJournalTimelineEventSheet(
          members: _members,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entryChildId: widget.journalEntryId == null ? widget.target.id : null,
          entryId: widget.journalEntryId,
          entryTitle: widget.target.stageTitle,
        ),
      );
      if (event == null || !mounted) return;
      final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
      final events = [...?timeline, event];
      final ok = await widget.projectsRepo.updateTimeline(
        id: widget.projectId,
        timeline: events,
      );
      if (!mounted || !ok) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Timeline event created.')));
    },
  );

  @override
  void didUpdateWidget(covariant _PrototypeLogLearningFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStage != widget.initialStage) {
      _showNextAction = widget.initialStage == _nextIndex;
    }
  }

  Future<void> _goToNextAction() async {
    if (!_canAdvanceJournal(
      context,
      _completedStages(),
      _learningIndex,
      _nextIndex,
      _flowLabels,
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    _persistLearning();
    if (!await flushDraft() || !mounted) return;
    setState(() => _showNextAction = true);
    widget.onActiveStageChanged?.call(_nextIndex);
  }

  void _finish() {
    final labels = _flowLabels;
    if (widget.target.nextAction['submitted'] != true) {
      if (!_canSubmitJournal(context, _completedStages(), labels)) return;
      if (!_validateStageTextInputs(context)) return;
    }
    _persistNextAction(submitted: true);
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _returnToEntry(int index) async {
    if (!await flushDraft() || !mounted) return;
    widget.onNavigateToEntryStage?.call(index);
    if (widget.onExit == null && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _exitFlow() async {
    if (!await flushDraft() || !mounted) return;
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: 'Journal Entry: Prototyping',
                  onBack: _exitFlow,
                ),
                _PrototypeGuidedStepper(
                  completion: () => _completedStages(),
                  inputs: Listenable.merge([
                    _nextLearned,
                    _nextChallenges,
                    _nextSteps,
                  ]),
                  visitedIndices: widget.target.visitedStages,
                  activeIndex: _showNextAction ? _nextIndex : _learningIndex,
                  labels: _flowLabels,
                  onSelected: (index) async {
                    await flushDraft();
                    if (!mounted) return;
                    if ((_building && index < _learningIndex) ||
                        (!_building && index == 0)) {
                      await _returnToEntry(index);
                      return;
                    }
                    setState(() => _showNextAction = index == _nextIndex);
                    widget.onActiveStageChanged?.call(index);
                  },
                  firstLabel: widget.target is _PrototypeJournalDraft
                      ? (widget.target as _PrototypeJournalDraft).type.label
                      : widget.target.stageTitle.contains('Test')
                      ? 'Test'
                      : 'Build',
                ),
                Expanded(
                  child: Padding(
                    padding: JournalPageLayout.stagePadding,
                    child: _showNextAction
                        ? _NextActionStageBody(
                            learned: _nextLearned,
                            challenges: _nextChallenges,
                            nextSteps: _nextSteps,
                            notes: _nextNotes,
                            linkedTimelineEvent: _linkedTimelineEvent,
                            isSaving: false,
                            projectId: widget.projectId,
                            isOwner: true,
                            projectsRepo: widget.projectsRepo,
                            onCreateTimelineEvent: _createTimelineEvent,
                            onBack: () async {
                              if (!await flushDraft() || !mounted) return;
                              setState(() => _showNextAction = false);
                              widget.onActiveStageChanged?.call(_learningIndex);
                            },
                            onSubmit: _finish,
                            completed:
                                widget.target.nextAction['submitted'] == true,
                          )
                        : JournalLearningStageBody(
                            selectedDci: _selectedDci,
                            selectedSep: _selectedSep,
                            selectedCcc: _selectedCcc,
                            inquiryLensData: _inquiryLensData,
                            assessment: _learningAssessment,
                            isSaving: false,
                            onToggleDci: (value) =>
                                _toggleSelection(_selectedDci, value),
                            onToggleSep: (value) =>
                                _toggleSelection(_selectedSep, value),
                            onToggleCcc: (value) =>
                                _toggleSelection(_selectedCcc, value),
                            onInquiryLensChanged: (value) =>
                                setState(() => _inquiryLensData = value),
                            onSaveAssessment: () async {
                              if (!await flushDraft()) return false;
                              return await widget.onSaveDraft?.call() ?? true;
                            },
                            onAssessmentChanged: (value) =>
                                setState(() => _learningAssessment = value),
                            onBack: () => _returnToEntry(_learningIndex - 1),
                            onNext: _goToNextAction,
                          ),
                  ),
                ),
                _DraftSaveStatus(status: draftSaveStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeFormScaffold extends StatelessWidget {
  const _PrototypeFormScaffold({
    required this.title,
    required this.onSave,
    this.onBack,
    required this.children,
  });

  final String title;
  final VoidCallback onSave;
  final VoidCallback? onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrototypeTopBar(
                      title: title,
                      onBack: onBack ?? onSave,
                      inset: 0,
                    ),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared "⋯" overflow menu with Move Up / Move Down (reorder) + Delete.
/// Move items appear only when the corresponding callback is provided.
class _PrototypeReorderMenu extends StatelessWidget {
  const _PrototypeReorderMenu({
    required this.onDelete,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.deleteLabel = 'Delete',
    this.iconAsset = 'assets/prototyping/pagination_dots.svg',
  });
  final VoidCallback onDelete;
  final VoidCallback? onEdit, onMoveUp, onMoveDown;
  final String deleteLabel, iconAsset;
  @override
  Widget build(BuildContext context) => ItemActionMenu(
    onEdit: onEdit,
    onDelete: onDelete,
    extraActions: [
      if (onMoveUp != null) ItemMenuAction('Move Up', onMoveUp!),
      if (onMoveDown != null) ItemMenuAction('Move Down', onMoveDown!),
    ],
  );
}

class _PrototypeComponentListCard extends StatelessWidget {
  const _PrototypeComponentListCard({
    required this.component,
    required this.index,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
  });

  final _PrototypeComponentDraft component;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete, onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final isComplete = component.status == 'Completed';
    final statusColor = isComplete ? _devGreen : const Color(0xFF2C70BF);
    final statusFill = isComplete
        ? const Color(0xFFD8F0DF)
        : const Color(0xFFDCEBFF);
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x33090909)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 23,
              height: 23,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _devGreen,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    component.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusFill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      component.status,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: statusColor,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (component.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      component.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _PrototypeReorderMenu(
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  deleteLabel: 'Delete Component',
                  iconAsset: 'assets/prototyping/component_pagination.svg',
                ),
                const SizedBox(height: 7),
                SvgPicture.asset(
                  'assets/prototyping/component_chevron.svg',
                  width: 14,
                  height: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeComponentDetailPage extends StatelessWidget {
  const _PrototypeComponentDetailPage({
    required this.component,
    required this.onBuild,
    required this.onTest,
    required this.onMaterials,
  });

  final _PrototypeComponentDraft component;
  final VoidCallback onBuild;
  final VoidCallback onTest;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context) {
    final isComplete = component.status == 'Completed';
    final statusColor = isComplete ? _devGreen : const Color(0xFF2C70BF);
    final statusFill = isComplete
        ? const Color(0xFFD8F0DF)
        : const Color(0xFFDCEBFF);
    return _PrototypeScaffold(
      title: 'Component: ${component.name}',
      onBack: () => Navigator.of(context).pop(),
      body: PageScrollWithFooter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(40, 4, 40, 8),
          children: [
            const Text(
              'Component Overview',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    component.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusFill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      component.status,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: statusColor,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (component.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E5E5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Purpose of the Component',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      component.description,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.helperSize,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                  if (component.features.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E5E5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Key Features',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < component.features.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _devGreen,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  color: Colors.white,
                                  fontSize: AppTypography.helperSize,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                component.features[i],
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: AppTypography.helperSize,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: AppMetrics.labelGap),
                  const Text(
                    'View',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.labelGap),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _PrototypeViewAction(
                          onTap: onBuild,
                          label: 'Build',
                          icon: SvgPicture.asset(
                            'assets/prototyping/build_wrench.svg',
                            width: 37,
                            height: 37,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _PrototypeViewAction(
                          onTap: onTest,
                          label: 'Test',
                          icon: Image.asset(
                            'assets/prototyping/test_flask.png',
                            width: 37,
                            height: 37,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _PrototypeViewAction(
                          onTap: onMaterials,
                          label: 'Materials & Cost',
                          icon: const _MaterialsDollarIcon(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeViewAction extends StatelessWidget {
  const _PrototypeViewAction({
    required this.onTap,
    required this.label,
    required this.icon,
  });

  final VoidCallback onTap;
  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(height: 37, child: Center(child: icon)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _devGreen,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialsDollarIcon extends StatelessWidget {
  const _MaterialsDollarIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _devGreen, width: 2),
      ),
      child: const Text(
        r'$',
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _devGreen,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PrototypeStatusSelector extends StatelessWidget {
  const _PrototypeStatusSelector({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
        PopupMenuItem(value: 'Completed', child: Text('Completed')),
      ],
      child: Container(
        width: double.infinity,
        height: 47,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _devGreen,
          border: Border.all(color: const Color(0x80000000)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.white,
                fontSize: AppTypography.captionSize,
                height: 1.4,
                fontWeight: FontWeight.w400,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(width: 6),
            SvgPicture.asset(
              'assets/prototyping/chevron_down.svg',
              width: 16,
              height: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeFeatureList extends StatelessWidget {
  const _PrototypeFeatureList({
    required this.features,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final List<TextEditingController> features;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 192),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0x33000000)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: features.length,
            // ignore: deprecated_member_use
            onReorder: onReorder,
            itemBuilder: (context, index) {
              return Container(
                key: ValueKey(features[index]),
                height: 49,
                padding: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: index == features.length - 1
                          ? Colors.transparent
                          : const Color(0xFFE5E5E5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: SizedBox(
                        width: 48,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/prototyping/drag_handle.svg',
                            width: 12,
                            height: 22,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _devGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: Colors.white,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: TextField(
                        controller: features[index],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '',
                          hintStyle: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textSecondary,
                            fontSize: AppTypography.helperSize,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    if (features.length > 1) ...[
                      const SizedBox(width: 6),
                      AppTapTarget(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onRemove(index),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: SvgPicture.asset(
                            'assets/prototyping/close_x.svg',
                            width: 10,
                            height: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        AppTapTarget(
          onTap: onAdd,
          child: const Text(
            '+ Add Feature',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.primary,
              fontSize: AppTypography.buttonSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrototypeBuildLogFigmaCard extends StatelessWidget {
  const _PrototypeBuildLogFigmaCard({
    required this.log,
    required this.onDelete,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
  });

  final _PrototypeBuildLogDraft log;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 122),
        margin: const EdgeInsets.only(bottom: 27),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: _devGreen, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 5, top: 3),
                      child: SizedBox(
                        width: 5,
                        height: 12,
                        child: _BookmarkCutIcon(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySize,
                        ),
                      ),
                      if (log.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _PrototypeReorderMenu(
                  onEdit: onTap,
                  onDelete: onDelete,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  iconAsset: 'assets/prototyping/build_pagination.svg',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(log.createdAt),
                  style: const TextStyle(
                    color: Color(0xFFA1A1A1),
                    fontSize: AppTypography.helperSize,
                  ),
                ),
                const Spacer(),
                Text(
                  '${log.evidence.length} evidence',
                  style: const TextStyle(
                    color: Color(0xFF717171),
                    fontSize: AppTypography.helperSize,
                  ),
                ),
              ],
            ),
            if (log.evidence.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final evidence in log.evidence)
                _EvidencePreviewBlock(evidence: evidence),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookmarkCutIcon extends StatelessWidget {
  const _BookmarkCutIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BookmarkCutPainter());
}

class _BookmarkCutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _devGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PrototypeIterationDraft {
  _PrototypeIterationDraft({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.goal,
    required this.notes,
    List<_PrototypeComponentDraft>? components,
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : components = components ?? [],
       learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeIterationDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeIterationDraft(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      goal: map['goal']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      components: _maps(
        map['components'],
      ).map(_PrototypeComponentDraft.fromMap).toList(),
      learning: map['learning'] is Map
          ? Map<String, dynamic>.from(map['learning'] as Map)
          : <String, dynamic>{},
      nextAction: map['nextAction'] is Map
          ? Map<String, dynamic>.from(map['nextAction'] as Map)
          : <String, dynamic>{},
    );
  }

  final String id;
  String title;
  final DateTime createdAt;
  final String goal;
  final String notes;
  final List<_PrototypeComponentDraft> components;

  /// Learning + Next Action are shared across the whole iteration (all of its
  /// components' Build / Test / Materials flows lead here).
  Map<String, dynamic> learning;
  Map<String, dynamic> nextAction;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'goal': goal,
      'notes': notes,
      'components': components.map((item) => item.toMap()).toList(),
      'learning': learning,
      'nextAction': nextAction,
    };
  }
}

class _PrototypeComponentDraft {
  _PrototypeComponentDraft({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.features,
    List<_PrototypeBuildLogDraft>? buildLogs,
    List<_PrototypeTestEntryDraft>? testEntries,
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : buildLogs = buildLogs ?? [],
       testEntries = testEntries ?? [],
       learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeComponentDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeComponentDraft(
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      status: map['status']?.toString() ?? 'In Progress',
      features: _previewStringList(map['features']),
      buildLogs: _maps(
        map['buildLogs'],
      ).map(_PrototypeBuildLogDraft.fromMap).toList(),
      testEntries: _maps(
        map['testEntries'],
      ).map(_PrototypeTestEntryDraft.fromMap).toList(),
      learning: map['learning'] is Map
          ? Map<String, dynamic>.from(map['learning'] as Map)
          : <String, dynamic>{},
      nextAction: map['nextAction'] is Map
          ? Map<String, dynamic>.from(map['nextAction'] as Map)
          : <String, dynamic>{},
    );
  }

  final String id;
  final String name;
  final String description;
  final String status;
  final List<String> features;
  final List<_PrototypeBuildLogDraft> buildLogs;
  final List<_PrototypeTestEntryDraft> testEntries;
  Map<String, dynamic> learning;
  Map<String, dynamic> nextAction;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'features': features,
      'buildLogs': buildLogs.map((item) => item.toMap()).toList(),
      'testEntries': testEntries.map((item) => item.toMap()).toList(),
      'learning': learning,
      'nextAction': nextAction,
    };
  }
}

/// Implemented by log drafts (Build / Test) that own their own Learning and
/// Next Action stages — learning/next action are per log, not per component.
abstract class _HasLearningStages {
  Set<int> get visitedStages;
  String get id;
  abstract Map<String, dynamic> learning;
  abstract Map<String, dynamic> nextAction;
  String get stageTitle;
}

class _PrototypeTestEntryDraft implements _HasLearningStages {
  _PrototypeTestEntryDraft({
    required this.id,
    required this.title,
    required this.description,
    required this.method,
    required this.expectedOutcome,
    required this.outcome,
    required this.feedback,
    required this.createdAt,
    required this.evidence,
    List<int>? visitedStages,
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : visitedStages =
           visitedStages?.toSet() ??
           _readVisitedStages(
             [
               {'stage': 'learning', ...?learning},
               {'stage': 'nextAction', ...?nextAction},
             ],
             const ['build', 'learning', 'nextAction'],
           ),
       learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeTestEntryDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeTestEntryDraft(
      visitedStages: (map['visitedStages'] as List?)?.whereType<int>().toList(),
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      method: map['method']?.toString() ?? '',
      expectedOutcome: map['expectedOutcome']?.toString() ?? '',
      outcome: map['outcome']?.toString() ?? '',
      feedback: map['feedback']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      evidence: _maps(
        map['evidence'],
      ).map(_EvidenceBlock.fromMap).whereType<_EvidenceBlock>().toList(),
      learning: map['learning'] is Map
          ? Map<String, dynamic>.from(map['learning'] as Map)
          : <String, dynamic>{},
      nextAction: map['nextAction'] is Map
          ? Map<String, dynamic>.from(map['nextAction'] as Map)
          : <String, dynamic>{},
    );
  }

  @override
  final String id;
  @override
  final Set<int> visitedStages;
  String title;
  String description;
  String method;
  String expectedOutcome;
  String outcome;
  String feedback;
  final DateTime createdAt;
  List<_EvidenceBlock> evidence;
  @override
  Map<String, dynamic> learning;
  @override
  Map<String, dynamic> nextAction;

  @override
  String get stageTitle => title.trim().isEmpty ? 'Test Title' : title.trim();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitedStages': visitedStages.toList()..sort(),
      'title': title,
      'description': description,
      'method': method,
      'expectedOutcome': expectedOutcome,
      'outcome': outcome,
      'feedback': feedback,
      'createdAt': createdAt.toIso8601String(),
      'evidence': evidence.map((item) => item.toMap()).toList(),
      'learning': learning,
      'nextAction': nextAction,
    };
  }
}

/// The five Test outcome ratings, exactly as labelled in Figma
/// (node 8484:39933). Order matches the frame.
const List<List<String>> _prototypeTestOutcomes = [
  ['Unsuccessful', 'Failed to function.'],
  ['Needs Revision', 'Performance below expectations'],
  ['Promising', 'Acceptable performance.'],
  ['Validated', 'Performed as expected.'],
  ['Optimized', 'Exceeded expectations'],
];

class _PrototypeBuildLogDraft implements _HasLearningStages {
  _PrototypeBuildLogDraft({
    required this.id,
    required this.title,
    required this.summary,
    required this.challenges,
    required this.createdAt,
    required this.evidence,
    List<int>? visitedStages,
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : visitedStages =
           visitedStages?.toSet() ??
           _readVisitedStages(
             [
               {'stage': 'learning', ...?learning},
               {'stage': 'nextAction', ...?nextAction},
             ],
             const ['build', 'learning', 'nextAction'],
           ),
       learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeBuildLogDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeBuildLogDraft(
      visitedStages: (map['visitedStages'] as List?)?.whereType<int>().toList(),
      id:
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      summary: map['summary']?.toString() ?? '',
      challenges: map['challenges']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      evidence: _maps(
        map['evidence'],
      ).map(_EvidenceBlock.fromMap).whereType<_EvidenceBlock>().toList(),
      learning: map['learning'] is Map
          ? Map<String, dynamic>.from(map['learning'] as Map)
          : <String, dynamic>{},
      nextAction: map['nextAction'] is Map
          ? Map<String, dynamic>.from(map['nextAction'] as Map)
          : <String, dynamic>{},
    );
  }

  @override
  final String id;
  @override
  final Set<int> visitedStages;
  String title;
  String summary;
  String challenges;
  final DateTime createdAt;
  List<_EvidenceBlock> evidence;
  @override
  Map<String, dynamic> learning;
  @override
  Map<String, dynamic> nextAction;

  @override
  String get stageTitle => title.trim().isEmpty ? 'Build Title' : title.trim();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitedStages': visitedStages.toList()..sort(),
      'title': title,
      'summary': summary,
      'challenges': challenges,
      'createdAt': createdAt.toIso8601String(),
      'evidence': evidence.map((item) => item.toMap()).toList(),
      'learning': learning,
      'nextAction': nextAction,
    };
  }
}

Future<_EvidenceBlock?> _openPrototypeEvidenceEditor(
  BuildContext context,
  String type,
  _EvidenceBlock? existing, {
  required String projectId,
}) async {
  if (type == 'Images') {
    final result = await pushAppRoute<ImageBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageBlockEditorScreen(
          moduleId: 'prototype',
          projectId: projectId,
          initialData: existing?.imageData,
          showAssessment: false,
          showInquiryLens: false,
        ),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.images(result);
  }
  if (type == 'Sketch') {
    final result = await pushAppRoute<SketchBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) => SketchBlockEditorScreen(
          moduleId: 'prototype',
          projectId: projectId,
          initialData: existing?.sketchData,
        ),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.sketch(result);
  }
  if (type == 'Link') {
    final result = await pushAppRoute<LinkBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) => LinkBlockEditorScreen(initialData: existing?.linkData),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.link(result);
  }
  if (type == 'Video') {
    final result = await pushAppRoute<VideoBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoBlockEditorScreen(
          moduleId: 'prototype',
          projectId: projectId,
          initialData: existing?.videoData,
        ),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.video(result);
  }
  if (type == 'Graph') {
    final result = await pushAppRoute<GraphBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GraphBlockEditorScreen(initialData: existing?.graphData),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.graph(result);
  }
  if (type == 'Table') {
    final result = await pushAppRoute<TableBlockData>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TableBlockEditorScreen(initialData: existing?.tableData),
      ),
    );
    if (!context.mounted) return null;
    if (result == null && existing != null) return null;
    return result == null
        ? await _returnToEvidenceMenu(
            context,
            (selected) => _openPrototypeEvidenceEditor(
              context,
              selected,
              selected == type ? existing : null,
              projectId: projectId,
            ),
          )
        : _EvidenceBlock.table(result);
  }
  return null;
}

class DiscoveryObservationEntryPage extends StatefulWidget {
  const DiscoveryObservationEntryPage({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.entry,
    this.returnToPhaseDashboard = false,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final JournalEntry? entry;
  final bool returnToPhaseDashboard;

  @override
  State<DiscoveryObservationEntryPage> createState() =>
      _DiscoveryObservationEntryPageState();
}

class _DiscoveryObservationEntryPageState
    extends State<DiscoveryObservationEntryPage>
    with DraftAutosave<DiscoveryObservationEntryPage> {
  @override
  String get failedDraftLabel => _draftSession.failureLabel;
  @override
  String get savedDraftLabel => _draftSession.current == null
      ? ''
      : _draftSession.kept
      ? 'Saved'
      : 'Autosaved';
  late final _draftSession = JournalDraftSession(
    widget.projectsRepo,
    widget.projectId,
    initial: widget.entry,
    onKept: (id) {
      if (mounted) setState(() => _entryId = id);
    },
  );

  int _entryNumber = 1;

  final _title = TextEditingController();
  final _observed = TextEditingController();
  final _location = TextEditingController();
  final _known = TextEditingController();
  final _patternExplanation = TextEditingController();
  final _questionText = TextEditingController();
  final _nextLearned = TextEditingController();
  final _nextChallenges = TextEditingController();
  final _nextSteps = TextEditingController();
  final _nextNotes = TextEditingController();
  final _communitiesRepo = CommunitiesRepo();
  final List<UserProfile> _members = [];
  final Set<String> _involvedIds = {};
  final List<_AffectedCommunity> _affectedCommunities = [];
  final List<_RootCauseDraft> _rootCauses = [];
  _RootCauseDraft _rootCauseEditor = _RootCauseDraft.empty();
  int? _editingRootCauseIndex;
  _RootCauseDraft? _editingRootCauseDraft;
  bool _showAnalyzeValidation = false;
  final List<_QuestionDraft> _questions = [];
  final Set<String> _selectedDci = {};
  final Set<String> _selectedSep = {};
  final Set<String> _selectedCcc = {};
  Map<String, String>? _linkedTimelineEvent;
  String? _entryId;
  String? _selectedPatternChange;
  String? _selectedQuestionType;
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _learningAssessment = const AssessmentBlockData();
  bool _submitted = false;
  _DiscoveryStage _stage = _DiscoveryStage.observe;
  bool _isSaving = false;
  bool _hasSavedChanges = false;

  late final Set<int> _visitedStages = _readVisitedStages(
    widget.entry?.content,
    ['observations', 'analyze', 'question', 'learning', 'nextAction'],
  );

  @override
  void initState() {
    super.initState();
    journalEntryNumber(
      widget.projectsRepo,
      widget.projectId,
      'Discovery',
      widget.entry,
    ).then((number) {
      if (mounted) setState(() => _entryNumber = number);
    });

    _questionText.addListener(_refreshQuestionText);
    _title.addListener(_refreshQuestionText);
    _hydrateEntry();
    _loadMembers();
  }

  void _refreshQuestionText() {
    if (mounted) setState(() {});
  }

  void _hydrateEntry() {
    final entry = widget.entry;
    if (entry == null) return;
    final savedStage = restoredJournalStage(
      entry.content,
      _DiscoveryStage.values.length,
    );
    _stage = _DiscoveryStage.values[savedStage];
    _entryId = entry.id;
    final observation = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'observations',
      orElse: () => const {},
    );
    _title.text =
        observation['title']?.toString() ??
        (entry.title == 'Entry: Discovery'
            ? ''
            : entry.title.replaceFirst(RegExp(r'^Entry:\s*'), ''));
    _observed.text = observation['observed']?.toString() ?? '';
    _location.text = observation['location']?.toString() ?? '';
    _known.text = observation['known']?.toString() ?? '';
    final communities = observation['affectedCommunities'];
    if (communities is List) {
      _affectedCommunities.addAll(
        communities
            .whereType<Map>()
            .map((item) => _AffectedCommunity.fromMap(item))
            .where((item) => item.name.isNotEmpty),
      );
    }
    final involved = observation['involved'];
    if (involved is List) {
      _involvedIds.addAll(
        involved
            .whereType<Map>()
            .map((member) => member['id']?.toString())
            .whereType<String>(),
      );
    }
    final analyze = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'analyze',
      orElse: () => const {},
    );
    final rootCauses = analyze['rootCauses'];
    if (rootCauses is List) {
      _rootCauses.addAll(
        rootCauses
            .whereType<Map>()
            .map((item) => _RootCauseDraft.fromMap(item))
            .where((item) => item.hasContent),
      );
    }
    final pattern = analyze['patternChange']?.toString() ?? '';
    _selectedPatternChange = pattern.isEmpty ? null : pattern;
    _patternExplanation.text = analyze['patternExplanation']?.toString() ?? '';
    final question = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'question',
      orElse: () => const {},
    );
    final questions = question['questions'];
    if (questions is List) {
      _questions.addAll(
        questions
            .whereType<Map>()
            .map((item) => _QuestionDraft.fromMap(item))
            .where((item) => item.text.isNotEmpty),
      );
    }
    final learning = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'learning',
      orElse: () => const {},
    );
    _selectedDci.addAll(_stringSet(learning['dci']));
    _selectedSep.addAll(_stringSet(learning['sep']));
    _selectedCcc.addAll(_stringSet(learning['ccc']));
    _inquiryLensData = InquiryLensData.fromJson(
      learning['inquiryLensData'],
      legacyLens:
          learning['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
    );
    _learningAssessment = AssessmentBlockData.fromJson(learning['assessment']);
    final nextAction = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'nextAction',
      orElse: () => const {},
    );
    _nextLearned.text = nextAction['learned']?.toString() ?? '';
    _nextChallenges.text = nextAction['challenges']?.toString() ?? '';
    _nextSteps.text = nextAction['nextSteps']?.toString() ?? '';
    _nextNotes.text = nextAction['notes']?.toString() ?? '';
    _submitted = nextAction['submitted'] == true;
    final linked = nextAction['linkedTimelineEvent'];
    if (linked is Map) {
      _linkedTimelineEvent = {
        for (final entry in linked.entries)
          entry.key.toString(): entry.value?.toString() ?? '',
      };
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _observed.dispose();
    _location.dispose();
    _known.dispose();
    _patternExplanation.dispose();
    _questionText.removeListener(_refreshQuestionText);
    _questionText.dispose();
    _nextLearned.dispose();
    _nextChallenges.dispose();
    _nextSteps.dispose();
    _nextNotes.dispose();
    for (final rootCause in _rootCauses) {
      rootCause.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final people = await widget.projectsRepo.getProjectMembers(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _members
        ..clear()
        ..addAll(people);
      if (widget.entry == null && people.isNotEmpty) {
        final currentId = AuthService.instance.currentUser?.id;
        if (people.any((person) => person.id == currentId)) {
          _involvedIds.add(currentId!);
        }
      }
    });
  }

  Map<String, dynamic> _draftData() {
    final involved = journalParticipantRows(
      _involvedIds,
      _members,
      previous: widget.entry?.content ?? const [],
    );
    final title = journalEntryTitle(_title.text, _entryNumber, 'Discovery');
    final savedRootCauses = _rootCauses
        .where((item) => item.hasContent)
        .toList();
    final content = [
      {
        'stage': '_navigation',
        'currentStage': _stage.index,
        'visitedStages': _visitedStages.toList()..sort(),
      },
      {
        'stage': 'observations',
        'title': _title.text.trim(),
        'observed': _observed.text.trim(),
        'location': _location.text.trim(),
        'affected': _affectedCommunities.map((item) => item.name).join(', '),
        'affectedCommunities': _affectedCommunities
            .map((community) => community.toMap())
            .toList(),
        'known': _known.text.trim(),
        'involved': involved,
      },
      {
        'stage': 'analyze',
        'rootCauses': savedRootCauses.map((item) => item.toMap()).toList(),
        'patternChange': _selectedPatternChange,
        'patternExplanation': _patternExplanation.text.trim(),
      },
      {
        'stage': 'question',
        'questions': _questions.map((item) => item.toMap()).toList(),
      },
      {
        'stage': 'learning',
        'dci': _selectedDci.toList(),
        'sep': _selectedSep.toList(),
        'ccc': _selectedCcc.toList(),
        'inquiryLens': _inquiryLensData.selectedLens,
        'inquiryLensData': _inquiryLensData.toJson(),
        'assessment': _learningAssessment.toJson(),
      },
      {
        'stage': 'nextAction',
        'learned': _nextLearned.text.trim(),
        'challenges': _nextChallenges.text.trim(),
        'nextSteps': _nextSteps.text.trim(),
        'notes': _nextNotes.text.trim(),
        'submitted': _submitted,
        if (_submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    return {'title': title, 'content': content};
  }

  @override
  String get draftFingerprint => jsonEncode(_draftData());
  @override
  Future<bool> writeAutosave() => _writeDraft();
  Future<bool> _save() => serializeDraft(_writeDraft);
  Future<bool> _writeDraft() async {
    setState(() => _isSaving = true);
    final draft = _draftData();
    final title = draft['title'] as String;
    final content = draft['content'] as List;
    if (await _draftSession.skipEmpty(title, content)) {
      _entryId = null;
      if (mounted) setState(() => _isSaving = false);
      return true;
    }
    var ok = false;
    if (_entryId == null) {
      final entry = await _draftSession.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        progress: 'discover',
        content: content,
      );
      _entryId = entry?.id;
      ok = entry != null;
    } else {
      ok = await _draftSession.updateJournalEntry(
        entryId: _entryId!,
        title: title,
        progress: 'discover',
        content: content,
      );
    }
    if (!mounted) return ok;
    _hasSavedChanges = _hasSavedChanges || ok;
    setState(() => _isSaving = false);
    return ok;
  }

  Future<void> _goToAnalyze() async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      _stage.index,
      1,
      const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() {
      _resetRootCauseEditors();
      _stage = _DiscoveryStage.analyze;
    });
  }

  // ignore: unused_element
  Future<void> _openAnalyzePreview() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    final advance = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _AnalyzePreviewPage(
          rootCauses: _rootCauses.where((item) => item.hasContent).toList(),
          patternChange: _selectedPatternChange,
          patternExplanation: _patternExplanation.text.trim(),
        ),
      ),
    );
    if (!mounted || advance != true) return;
    setState(() {
      _clearQuestionComposer();
      _stage = _DiscoveryStage.question;
    });
  }

  Future<void> _goToQuestion() async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      _stage.index,
      2,
      const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
    ))
      return;
    setState(() => _showAnalyzeValidation = true);
    if (!_validateStageTextInputs(context)) return;
    if (_rootCauses.isEmpty || _selectedPatternChange == null) return;
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() {
      _clearQuestionComposer();
      _stage = _DiscoveryStage.question;
    });
  }

  bool _showQuestionValidation = false;
  bool _questionLimitReached = false;

  void _clearQuestionComposer() {
    _showQuestionValidation = false;
    _questionLimitReached = false;
    _selectedQuestionType = null;
    _questionText.clear();
  }

  void _addQuestion() {
    final type = _selectedQuestionType;
    final text = _questionText.text.trim();
    if (_questions.length >= 4) {
      setState(() => _questionLimitReached = true);
      return;
    }
    if (type == null || text.isEmpty) {
      setState(() => _showQuestionValidation = true);
      return;
    }
    setState(() {
      _questions.add(_QuestionDraft(type: type, text: text));
      _clearQuestionComposer();
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      _questionLimitReached = false;
    });
  }

  Future<void> _finishQuestionStage() async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      _stage.index,
      3,
      const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
    ))
      return;
    if (_questions.isEmpty) {
      setState(() => _showQuestionValidation = true);
      return;
    }
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _DiscoveryStage.learning);
  }

  Future<void> _finishLearningStage() async {
    if (!_canAdvanceJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      _stage.index,
      4,
      const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _DiscoveryStage.nextAction);
  }

  Future<void> _finishNextActionStage() async {
    if (_submitted) {
      final ok = await flushDraft();
      if (mounted && ok) Navigator.of(context).maybePop(true);
      return;
    }

    if (!_canSubmitJournal(
      context,
      completedJournalStageIndices(_draftData()['content'] as List),
      ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
    ))
      return;
    if (!_validateStageTextInputs(context)) return;
    _submitted = true;
    final ok = await _save();
    if (!ok) _submitted = false;
    if (!mounted || !ok) return;
    JournalPublication.returnHome(context);
  }

  Future<void> _createTimelineEvent() => runActionOnce(
    this,
    'timeline-event',
    () async {
      if (_entryId == null) {
        final saved = await _save();
        if (!mounted || !saved) return;
      }
      final event = await showAppModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CreateJournalTimelineEventSheet(
          members: _members,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          entryId: _entryId,
          entryTitle: _title.text.trim().isEmpty
              ? 'Discovery Title'
              : _title.text.trim(),
        ),
      );
      if (event == null || !mounted) return;
      final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
      final events = [...?timeline, event];
      final ok = await widget.projectsRepo.updateTimeline(
        id: widget.projectId,
        timeline: events,
      );
      if (!mounted || !ok) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Timeline event created.')));
      await _save();
    },
  );

  void _toggleLearningSelection(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _openAffectedChoices() async {
    final result = await showAppModalBottomSheet<_AffectedCommunity>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AffectedChoiceSheet(communitiesRepo: _communitiesRepo),
    );
    if (result == null || !mounted) return;
    _addAffectedCommunity(result);
  }

  void _addAffectedCommunity(_AffectedCommunity community) {
    setState(() {
      final id = community.id;
      final exists = _affectedCommunities.any(
        (item) => id != null ? item.id == id : item.name == community.name,
      );
      if (!exists) _affectedCommunities.add(community);
    });
  }

  void _toggleInvolvedMember(String memberId) {
    setState(() {
      if (!_involvedIds.add(memberId) && _involvedIds.length > 1) {
        _involvedIds.remove(memberId);
      }
    });
  }

  void _resetRootCauseEditors() {
    _rootCauseEditor = _RootCauseDraft.empty();
    _editingRootCauseDraft = null;
    _editingRootCauseIndex = null;
    _showAnalyzeValidation = false;
  }

  void _addRootCause() {
    final fields = [
      _rootCauseEditor.title,
      _rootCauseEditor.description,
      _rootCauseEditor.reason,
    ];
    var missing = false;
    for (final field in fields) {
      final invalid = field.text.trim().isEmpty;
      _inputError(field).value = invalid;
      missing = missing || invalid;
    }
    if (missing) return;
    final saved = _RootCauseDraft.fromMap(_rootCauseEditor.toMap());
    setState(() {
      _rootCauses.add(saved);
      _rootCauseEditor = _RootCauseDraft.empty();
    });
  }

  void _editRootCause(int index) {
    setState(() {
      _editingRootCauseDraft = _RootCauseDraft.fromMap(
        _rootCauses[index].toMap(),
      );
      _editingRootCauseIndex = index;
    });
  }

  void _saveEditedRootCause() {
    final draft = _editingRootCauseDraft;
    final index = _editingRootCauseIndex;
    if (draft == null || index == null) return;
    var missing = false;
    for (final field in [draft.title, draft.description, draft.reason]) {
      final invalid = field.text.trim().isEmpty;
      _inputError(field).value = invalid;
      missing = missing || invalid;
    }
    if (missing) return;
    setState(() {
      _rootCauses[index] = _RootCauseDraft.fromMap(draft.toMap());
      _editingRootCauseDraft = null;
      _editingRootCauseIndex = null;
    });
  }

  void _deleteRootCause(int index) {
    setState(() {
      _rootCauses.removeAt(index).dispose();
      if (_editingRootCauseIndex == index) {
        _editingRootCauseDraft = null;
        _editingRootCauseIndex = null;
      } else if (_editingRootCauseIndex != null &&
          _editingRootCauseIndex! > index) {
        _editingRootCauseIndex = _editingRootCauseIndex! - 1;
      }
    });
  }

  Future<void> _openEvidencePicker(_RootCauseDraft rootCause) async {
    final type = await showAppDialog<String>(
      context: context,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    await _openEvidenceEditor(rootCause, type);
  }

  Future<void> _openEvidenceEditor(
    _RootCauseDraft rootCause,
    String type, [
    int? index,
  ]) async {
    final existing = index == null ? null : rootCause.evidence[index];
    _EvidenceBlock? block;
    if (type == 'Images') {
      final result = await pushAppRoute<ImageBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.imageData,
            showAssessment: false,
            showInquiryLens: false,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.images(result);
    } else if (type == 'Sketch') {
      final result = await pushAppRoute<SketchBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => SketchBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.sketchData,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.sketch(result);
    } else if (type == 'Link') {
      final result = await pushAppRoute<LinkBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LinkBlockEditorScreen(initialData: existing?.linkData),
        ),
      );
      if (result != null) block = _EvidenceBlock.link(result);
    } else if (type == 'Video') {
      final result = await pushAppRoute<VideoBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) => VideoBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            projectId: widget.projectId,
            initialData: existing?.videoData,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.video(result);
    } else if (type == 'Graph') {
      final result = await pushAppRoute<GraphBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GraphBlockEditorScreen(initialData: existing?.graphData),
        ),
      );
      if (result != null) block = _EvidenceBlock.graph(result);
    } else if (type == 'Table') {
      final result = await pushAppRoute<TableBlockData>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TableBlockEditorScreen(initialData: existing?.tableData),
        ),
      );
      if (result != null) block = _EvidenceBlock.table(result);
    }
    if (!mounted) return;
    if (block == null) {
      if (existing == null) await _openEvidencePicker(rootCause);
      return;
    }
    setState(() {
      if (index == null) {
        rootCause.evidence.add(block!);
      } else {
        rootCause.evidence[index] = block!;
      }
    });
  }

  @override
  Widget build(BuildContext context) => JournalDraftGuard(
    session: _draftSession,
    flush: flushDraft,
    section: const [
      'observations',
      'analyze',
      'question',
      'learning',
      'nextAction',
    ][_stage.index],
    sections: const {
      'observations': 'Observe',
      'analyze': 'Analyze',
      'question': 'Question',
      'learning': 'Learning',
      'nextAction': 'Next Action',
    },
    onSectionSelected: (key) => setState(
      () => _stage =
          _DiscoveryStage.values[const [
            'observations',
            'analyze',
            'question',
            'learning',
            'nextAction',
          ].indexOf(key)],
    ),
    child: _buildEditor(context),
  );

  Widget _buildEditor(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: Padding(
              padding: JournalPageLayout.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrototypeTopBar(
                    title: journalEntryTitle('', _entryNumber, 'Discovery'),
                    titleController: _title,
                    onBack: () async {
                      await flushDraft();
                      if (!mounted || !context.mounted) return;
                      Navigator.of(context).maybePop(_hasSavedChanges);
                    },
                    inset: 0,
                  ),
                  _StageHeader(
                    completion: () => completedJournalStageIndices(
                      _draftData()['content'] as List,
                    ),
                    inputs: Listenable.merge([
                      _title,
                      _observed,
                      _known,
                      _patternExplanation,
                      _nextLearned,
                      _nextChallenges,
                      _nextSteps,
                    ]),
                    visitedIndices: _visitedStages,
                    activeIndex: _stage.index,
                    onSelected: (index) async {
                      await flushDraft();
                      if (mounted)
                        setState(() => _stage = _DiscoveryStage.values[index]);
                    },
                  ),
                  const SizedBox(height: JournalPageLayout.stageGap),
                  Expanded(
                    child: switch (_stage) {
                      _DiscoveryStage.observe => _ObserveStageBody(
                        creatorId:
                            widget.entry?.authorId ?? _journalCurrentUserId(),
                        title: _title,
                        observed: _observed,
                        location: _location,
                        known: _known,
                        members: _members,
                        involvedIds: _involvedIds,
                        affectedCommunities: _affectedCommunities,
                        onAddAffected: _openAffectedChoices,
                        onRemoveAffected: (community) => setState(
                          () => _affectedCommunities.removeWhere(
                            (item) => item.id == community.id,
                          ),
                        ),
                        onToggleMember: _toggleInvolvedMember,
                        isSaving: _isSaving,
                        onNext: _goToAnalyze,
                      ),
                      _DiscoveryStage.analyze => _AnalyzeStageBody(
                        rootCauses: _rootCauses,
                        editor: _rootCauseEditor,
                        editingIndex: _editingRootCauseIndex,
                        editingDraft: _editingRootCauseDraft,
                        onSaveEdit: _saveEditedRootCause,
                        showValidation: _showAnalyzeValidation,
                        onEditRootCause: _editRootCause,
                        selectedPatternChange: _selectedPatternChange,
                        patternExplanation: _patternExplanation,
                        isSaving: _isSaving,
                        onAddRootCause: _addRootCause,
                        onDeleteRootCause: _deleteRootCause,
                        onAddEvidence: _openEvidencePicker,
                        onEditEvidence: _openEvidenceEditor,
                        onDeleteEvidence: (cause, index) =>
                            setState(() => cause.evidence.removeAt(index)),
                        onPatternChanged: (value) =>
                            setState(() => _selectedPatternChange = value),
                        onBack: () =>
                            setState(() => _stage = _DiscoveryStage.observe),
                        onNext: _goToQuestion,
                      ),
                      _DiscoveryStage.question => _QuestionStageBody(
                        onComposerChanged: () => setState(() {}),
                        showValidation: _showQuestionValidation,
                        limitReached: _questionLimitReached,
                        selectedType: _selectedQuestionType,
                        questionController: _questionText,
                        questions: _questions,
                        isSaving: _isSaving,
                        onTypeSelected: (value) =>
                            setState(() => _selectedQuestionType = value),
                        onAddQuestion: _addQuestion,
                        onDeleteQuestion: _deleteQuestion,
                        onEditQuestion: (index, text) => setState(
                          () => _questions[index] = _QuestionDraft(
                            type: _questions[index].type,
                            text: text,
                          ),
                        ),
                        onBack: () => setState(() {
                          _resetRootCauseEditors();
                          _stage = _DiscoveryStage.analyze;
                        }),
                        onNext: _finishQuestionStage,
                      ),
                      _DiscoveryStage.learning => JournalLearningStageBody(
                        selectedDci: _selectedDci,
                        selectedSep: _selectedSep,
                        selectedCcc: _selectedCcc,
                        inquiryLensData: _inquiryLensData,
                        assessment: _learningAssessment,
                        isSaving: _isSaving,
                        onToggleDci: (value) =>
                            _toggleLearningSelection(_selectedDci, value),
                        onToggleSep: (value) =>
                            _toggleLearningSelection(_selectedSep, value),
                        onToggleCcc: (value) =>
                            _toggleLearningSelection(_selectedCcc, value),
                        onInquiryLensChanged: (value) =>
                            setState(() => _inquiryLensData = value),
                        onSaveAssessment: flushDraft,
                        onAssessmentChanged: (value) =>
                            setState(() => _learningAssessment = value),
                        onBack: () => setState(() {
                          _clearQuestionComposer();
                          _stage = _DiscoveryStage.question;
                        }),
                        onNext: _finishLearningStage,
                      ),
                      _DiscoveryStage.nextAction => _NextActionStageBody(
                        learned: _nextLearned,
                        challenges: _nextChallenges,
                        nextSteps: _nextSteps,
                        notes: _nextNotes,
                        linkedTimelineEvent: _linkedTimelineEvent,
                        isSaving: _isSaving,
                        projectId: widget.projectId,
                        isOwner: true,
                        projectsRepo: widget.projectsRepo,
                        onCreateTimelineEvent: _createTimelineEvent,
                        onBack: () =>
                            setState(() => _stage = _DiscoveryStage.learning),
                        onSubmit: _finishNextActionStage,
                        completed: _submitted,
                      ),
                    },
                  ),
                  _DraftSaveStatus(
                    status: draftSaveStatus,
                    reserveScrollGutter: _stage.index == 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DiscoveryStage { observe, analyze, question, learning, nextAction }

Set<int> _completedLogStages(bool ready, Map learning, Map next) =>
    completedJournalStageIndices([
      {'stage': 'log', 'complete': ready},
      {...learning, 'stage': 'learning'},
      {...next, 'stage': 'nextAction'},
    ]);

final _stageValidationTargets = Expando<ValueNotifier<int?>>();
ValueNotifier<int?> _stageValidationTarget(BuildContext context) {
  final owner = ModalRoute.of(context) ?? context;
  return _stageValidationTargets[owner] ??= ValueNotifier<int?>(null);
}

bool _canAdvanceJournal(
  BuildContext context,
  Set<int> complete,
  int current,
  int target,
  List<String> labels,
) {
  if (target <= current) {
    _stageValidationTarget(context).value = null;
    return true;
  }
  final missing = [
    for (var i = 0; i < target; i++)
      if (!complete.contains(i)) labels[i],
  ];
  if (missing.isEmpty) {
    _stageValidationTarget(context).value = null;
    return true;
  }
  _stageValidationTarget(context).value = target;
  _validateStageTextInputs(context);
  return false;
}

bool _canSubmitJournal(
  BuildContext context,
  Set<int> complete,
  List<String> labels,
) {
  final missing = [
    for (var i = 0; i < labels.length; i++)
      if (!complete.contains(i)) labels[i],
  ];
  if (missing.isEmpty) return true;
  _stageValidationTarget(context).value = labels.length;
  _validateStageTextInputs(context);
  showAppDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Complete your journal'),
      content: Text(
        'Finish these stages before submitting:\n\n${missing.map((label) => '• $label').join('\n')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continue editing'),
        ),
      ],
    ),
  );
  return false;
}

Set<int> _readVisitedStages(List<dynamic>? content, List<String> stageKeys) {
  final rows = (content ?? const []).whereType<Map>().toList();
  final navigation = rows.where((row) => row['stage'] == '_navigation');
  if (navigation.isNotEmpty && navigation.first['visitedStages'] is List) {
    return {
      0,
      ...((navigation.first['visitedStages'] as List).whereType<int>().where(
        (index) => index >= 0 && index < stageKeys.length,
      )),
    };
  }
  // Older drafts have no visit history; recover stages with saved content.
  bool populated(dynamic value) {
    if (value is String) return value.trim().isNotEmpty && value != 'None';
    if (value is num) return value != 0;
    if (value is List) return value.any(populated);
    if (value is Map)
      return value.entries.any(
        (entry) =>
            !{
              'stage',
              'id',
              'involved',
              'formula',
              'scores',
              'inquiryLensData',
              'assessment',
              'submittedAt',
            }.contains(entry.key) &&
            populated(entry.value),
      );
    return value == true;
  }

  var last = 0;
  for (var index = 0; index < stageKeys.length; index++) {
    if (rows.any((row) => row['stage'] == stageKeys[index] && populated(row)))
      last = index;
  }
  return {for (var index = 0; index <= last; index++) index};
}

class _StageHeader extends StatefulWidget {
  const _StageHeader({
    required this.activeIndex,
    this.labels,
    this.onSelected,
    this.visitedIndices,
    this.completion,
    this.inputs,
  });
  final Set<int>? visitedIndices;
  final Set<int> Function()? completion;
  final Listenable? inputs;

  final ValueChanged<int>? onSelected;

  final int activeIndex;
  final List<String>? labels;

  @override
  State<_StageHeader> createState() => _StageHeaderState();
}

class _StageHeaderState extends State<_StageHeader> {
  final Set<int> _localVisited = {};
  Set<int> get _visited => widget.visitedIndices ?? _localVisited;
  @override
  void initState() {
    super.initState();
    _visited.add(widget.activeIndex);
  }

  @override
  void didUpdateWidget(covariant _StageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.activeIndex);
    if (oldWidget.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) journalValidationIssues(context).value = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget tracker() => ProgressTracker(
      requireCompletionForHighlight: true,
      labels:
          widget.labels ??
          const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'],
      currentIndex: widget.activeIndex,
      reachedIndices: widget.completion?.call() ?? {},
      onSelected: widget.onSelected == null
          ? null
          : (index) {
              if (widget.completion != null &&
                  !_canAdvanceJournal(
                    context,
                    widget.completion!(),
                    widget.activeIndex,
                    index,
                    widget.labels ??
                        const [
                          'Observe',
                          'Analyze',
                          'Question',
                          'Learning',
                          'Next Action',
                        ],
                  ))
                return;
              widget.onSelected!(index);
            },
    );
    return AnimatedBuilder(
      animation: Listenable.merge([
        _stageValidationTarget(context),
        if (widget.inputs != null) widget.inputs!,
      ]),
      builder: (context, _) => tracker(),
    );
  }
}

class _ObserveStageBody extends StatelessWidget {
  const _ObserveStageBody({
    required this.title,
    required this.observed,
    required this.location,
    required this.known,
    required this.members,
    this.creatorId,
    required this.involvedIds,
    required this.affectedCommunities,
    required this.onAddAffected,
    required this.onRemoveAffected,
    required this.onToggleMember,
    required this.isSaving,
    required this.onNext,
  });

  final TextEditingController title;
  final TextEditingController observed;
  final TextEditingController location;
  final TextEditingController known;
  final List<UserProfile> members;
  final String? creatorId;
  final Set<String> involvedIds;
  final List<_AffectedCommunity> affectedCommunities;
  final VoidCallback onAddAffected;
  final ValueChanged<_AffectedCommunity> onRemoveAffected;
  final ValueChanged<String> onToggleMember;
  final bool isSaving;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Observations'),
        _LabeledBox(label: 'Discovery Title', controller: title, height: 64),
        const SizedBox(height: AppMetrics.fieldGap),
        _LabeledBox(
          label: 'What was observed?',
          controller: observed,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        _LabeledBox(
          label: 'Location',
          optional: true,
          controller: location,
          height: 36,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        _AffectedCommunitiesField(
          communities: affectedCommunities,
          onRemove: onRemoveAffected,
          onAdd: onAddAffected,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        _LabeledBox(
          label: 'What is already known?',
          controller: known,
          maxLines: 4,
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text(
          'Who is involved?',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select project members participating in this journal entry. Selected participants can edit it.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        JournalInvolvedPeopleField(
          creatorId: creatorId,
          members: members,
          selectedIds: involvedIds,
          onToggle: onToggleMember,
        ),
      ],
      footer: Center(
        child: _SmallStageButton(label: 'Next', filled: true, onTap: onNext),
      ),
    );
  }
}

class _AnalyzeStageBody extends StatelessWidget {
  const _AnalyzeStageBody({
    required this.rootCauses,
    required this.editor,
    this.editingIndex,
    this.editingDraft,
    required this.onSaveEdit,
    this.showValidation = false,
    required this.onEditRootCause,
    required this.selectedPatternChange,
    required this.patternExplanation,
    required this.isSaving,
    required this.onAddRootCause,
    required this.onDeleteRootCause,
    required this.onAddEvidence,
    required this.onEditEvidence,
    required this.onDeleteEvidence,
    required this.onPatternChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<_RootCauseDraft> rootCauses;
  final _RootCauseDraft editor;
  final int? editingIndex;
  final _RootCauseDraft? editingDraft;
  final VoidCallback onSaveEdit;
  final bool showValidation;
  final ValueChanged<int> onEditRootCause;
  final String? selectedPatternChange;
  final TextEditingController patternExplanation;
  final bool isSaving;
  final VoidCallback onAddRootCause;
  final ValueChanged<int> onDeleteRootCause;
  final ValueChanged<_RootCauseDraft> onAddEvidence;
  final void Function(_RootCauseDraft rootCause, String type, [int? index])
  onEditEvidence;
  final void Function(_RootCauseDraft, int) onDeleteEvidence;
  final ValueChanged<String> onPatternChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _stageValidationTarget(context),
    builder: (context, _) => _buildValidated(context),
  );

  Widget _buildValidated(BuildContext context) {
    final showValidation =
        this.showValidation || _stageValidationTarget(context).value != null;

    final saved = rootCauses;
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Root Causes'),
        _RequiredJournalInteraction(
          complete: () => saved.isNotEmpty,
          message:
              'Add at least one complete root cause using Add Key Root Causes.',
          child: _RootCauseEditorCard(
            rootCause: editor,
            requireInput: saved.isEmpty,
            showError: showValidation && saved.isEmpty,
            onAddEvidence: () => onAddEvidence(editor),
            onEditEvidence: (type, index) =>
                onEditEvidence(editor, type, index),
            onDeleteEvidence: (index) => onDeleteEvidence(editor, index),
          ),
        ),
        if (showValidation && saved.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 8),
            child: Text(
              'Required',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.red,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ),
        const SizedBox(height: AppMetrics.labelGap),
        Center(
          child: AppTapTarget(
            onTap: onAddRootCause,
            child: const Text(
              '+ Add Key Root Causes',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.primary,
                fontSize: AppTypography.buttonSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        if (saved.isNotEmpty) ...[
          const Text(
            'Added Root Causes',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (var index = 0; index < saved.length; index++)
          if (index == editingIndex && editingDraft != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 19),
              child: Column(
                children: [
                  _RootCauseEditorCard(
                    rootCause: editingDraft!,
                    onAddEvidence: () => onAddEvidence(editingDraft!),
                    onDeleteEvidence: (index) =>
                        onDeleteEvidence(editingDraft!, index),
                    onEditEvidence: (type, evidenceIndex) =>
                        onEditEvidence(editingDraft!, type, evidenceIndex),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onSaveEdit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _devGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            )
          else
            _RootCauseCompactCard(
              key: ObjectKey(saved[index]),
              rootCause: saved[index],
              onDelete: () => onDeleteRootCause(index),
              onEdit: () => onEditRootCause(index),
            ),
        const SizedBox(height: JournalPageLayout.stageGap),
        const JournalSectionHeader(title: 'Pattern Changes'),
        const Text(
          'What could change or improve?',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        _RequiredJournalInteraction(
          complete: () => selectedPatternChange != null,
          message: 'Select a pattern change.',
          child: Column(
            children: [
              for (final option in _patternChangeOptions) ...[
                _PatternChangeOptionTile(
                  option: option,
                  selected: selectedPatternChange == option.label,
                  showError: showValidation && selectedPatternChange == null,
                  onTap: () => onPatternChanged(option.label),
                ),
                const SizedBox(height: AppMetrics.labelGap),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LabeledBox(
          label: 'Why was this pattern selected?',
          controller: patternExplanation,
          maxLines: 4,
        ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(label: 'Next', filled: true, onTap: onNext),
        ],
      ),
    );
  }
}

class _QuestionDraft {
  const _QuestionDraft({required this.type, required this.text});

  factory _QuestionDraft.fromMap(Map<dynamic, dynamic> map) {
    return _QuestionDraft(
      type: map['type']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
    );
  }

  final String type;
  final String text;

  Map<String, dynamic> toMap() => {'type': type, 'text': text};
}

class _QuestionTypeOption {
  const _QuestionTypeOption({
    required this.label,
    required this.description,
    required this.color,
    required this.fill,
    required this.assets,
  });

  final String label;
  final String description;
  final Color color;
  final Color fill;
  final List<String> assets;
}

const _questionTypeOptions = [
  _QuestionTypeOption(
    label: 'How',
    description: 'Ask about process or methods',
    color: Color(0xFF2C70BF),
    fill: Color(0x332C70BF),
    assets: [
      'assets/discovery/question_how_figma_1.svg',
      'assets/discovery/question_how_figma_2.svg',
    ],
  ),
  _QuestionTypeOption(
    label: 'Where',
    description: 'Ask about locations or places',
    color: Color(0xFFF3AA15),
    fill: Color(0x33F3AA15),
    assets: ['assets/discovery/question_where_figma.svg'],
  ),
  _QuestionTypeOption(
    label: 'What',
    description: 'Ask about things or outcomes',
    color: Color(0xFF5DB075),
    fill: Color(0x335DB075),
    assets: ['assets/discovery/question_what_figma.svg'],
  ),
  _QuestionTypeOption(
    label: 'When',
    description: 'Ask about time or timing',
    color: Color(0xFF9027BD),
    fill: Color(0x339027BD),
    assets: [
      'assets/discovery/question_when_figma_1.svg',
      'assets/discovery/question_when_figma_2.svg',
    ],
  ),
];

class _QuestionStageBody extends StatelessWidget {
  const _QuestionStageBody({
    required this.onComposerChanged,
    required this.showValidation,
    required this.limitReached,
    required this.selectedType,
    required this.questionController,
    required this.questions,
    required this.isSaving,
    required this.onTypeSelected,
    required this.onAddQuestion,
    required this.onDeleteQuestion,
    required this.onEditQuestion,
    required this.onBack,
    required this.onNext,
  });

  final VoidCallback onComposerChanged;
  final bool showValidation;
  final bool limitReached;
  final String? selectedType;
  final TextEditingController questionController;
  final List<_QuestionDraft> questions;
  final bool isSaving;
  final ValueChanged<String> onTypeSelected;
  final VoidCallback onAddQuestion;
  final ValueChanged<int> onDeleteQuestion;
  final void Function(int, String) onEditQuestion;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _stageValidationTarget(context),
    builder: (context, _) => _buildValidated(context),
  );

  Widget _buildValidated(BuildContext context) {
    final showValidation =
        this.showValidation || _stageValidationTarget(context).value != null;

    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Question'),
        const Text('Create a new question', style: AppTypography.fieldLabel),
        const SizedBox(height: AppMetrics.fieldGap),
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final option in _questionTypeOptions)
                _QuestionTypeTile(
                  option: option,
                  showError:
                      showValidation &&
                      (questions.isEmpty || selectedType == null),
                  selected: selectedType == option.label,
                  onTap: () => onTypeSelected(option.label),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextField(
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            controller: questionController,
            minLines: AppMetrics.longResponseLines,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            onChanged: (_) => onComposerChanged(),
            maxLength: 100,
            decoration: InputDecoration(
              hintText: selectedType == null
                  ? 'Choose a type, then write a question to explore.'
                  : 'Write a “${selectedType!.toLowerCase()}” question you want to explore.',
              hintStyle: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
              ),
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(9, 0, 9, 7),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color:
                      showValidation && questionController.text.trim().isEmpty
                      ? Colors.red
                      : const Color(0x33000000),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color:
                      showValidation && questionController.text.trim().isEmpty
                      ? Colors.red
                      : const Color(0x33000000),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (showValidation)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              questions.isEmpty
                  ? 'Required: add at least one question (maximum four).'
                  : 'Select a question type and enter your question.',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.red,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ),
        if (limitReached)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Maximum four questions. Delete one question before adding another.',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.red,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ),
        const SizedBox(height: AppMetrics.fieldGap),
        _RequiredJournalInteraction(
          complete: () => questions.isNotEmpty,
          message: 'Add at least one question with a question type.',
          child: AppTapTarget(
            onTap: onAddQuestion,
            child: Container(
              width: double.infinity,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+ Add Question',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 33),
        const Text(
          'Questions to explore',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Nothing here yet...',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppMetrics.labelGap),
        for (var i = 0; i < questions.length; i++)
          _QuestionCard(
            question: questions[i],
            onEdit: (text) => onEditQuestion(i, text),
            onDelete: () => onDeleteQuestion(i),
          ),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(label: 'Next', filled: true, onTap: onNext),
        ],
      ),
    );
  }
}

class _QuestionTypeTile extends StatelessWidget {
  const _QuestionTypeTile({
    this.showError = false,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final bool showError;
  final _QuestionTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        width: 82,
        height: 98,
        padding: const EdgeInsets.fromLTRB(9, 13, 7, 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : Colors.white,
          border: Border.all(color: showError ? Colors.red : _devGreen),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: _StackedSvgIcon(assets: option.assets),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      option.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: option.color,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              option.description,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.onDelete,
    required this.onEdit,
  });
  final ValueChanged<String> onEdit;

  final _QuestionDraft question;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final option = _questionTypeOptions.firstWhere(
      (item) => item.label == question.type,
      orElse: () => _questionTypeOptions.first,
    );
    return Container(
      width: double.infinity,
      height: 67,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x33090909)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: option.fill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: _StackedSvgIcon(assets: option.assets),
                ),
                const SizedBox(width: 5),
                Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: option.color,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              question.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          ItemActionMenu(
            onDelete: onDelete,
            onEdit: () async {
              final controller = TextEditingController(text: question.text);
              final updated = await showAppDialog<String>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Edit Question'),
                  content: TextField(
                    controller: controller,
                    minLines: AppMetrics.longResponseLines,
                    maxLines: null,
                    decoration: const InputDecoration(labelText: 'Question'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty)
                          Navigator.pop(dialogContext, controller.text.trim());
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (updated != null) onEdit(updated);
              controller.dispose();
            },
          ),
        ],
      ),
    );
  }
}

const _discoveryDciOptions = [
  'Ecosystems & Biodiversity',
  'Climate & Weather Patterns',
  'Human Impact on Natural Systems',
  'Natural Resources & Conservation',
  'Pollution and Waste Management',
];
const _discoverySepOptions = [
  'Asking Questions & Defining Problems',
  'Planning & Conducting Investigations',
  'Analyzing & Interpreting Data',
  'Constructing Explanations',
  'Designing Solutions',
];
const _discoveryCccOptions = [
  'Patterns',
  'Cause and Effect',
  'Systems & System Models',
  'Energy & Matter',
  'Stability & Change',
];

class JournalLearningStageBody extends StatefulWidget {
  const JournalLearningStageBody({
    super.key,
    required this.selectedDci,
    required this.selectedSep,
    required this.selectedCcc,
    required this.inquiryLensData,
    required this.assessment,
    required this.isSaving,
    required this.onToggleDci,
    required this.onToggleSep,
    required this.onToggleCcc,
    required this.onInquiryLensChanged,
    required this.onAssessmentChanged,
    this.onSaveAssessment,
    required this.onBack,
    required this.onNext,
  });

  final Set<String> selectedDci;
  final Set<String> selectedSep;
  final Set<String> selectedCcc;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final bool isSaving;
  final ValueChanged<String> onToggleDci;
  final ValueChanged<String> onToggleSep;
  final ValueChanged<String> onToggleCcc;
  final ValueChanged<InquiryLensData> onInquiryLensChanged;
  final ValueChanged<AssessmentBlockData> onAssessmentChanged;
  final Future<bool> Function()? onSaveAssessment;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  State<JournalLearningStageBody> createState() =>
      _JournalLearningStageBodyState();
}

class _JournalLearningStageBodyState extends State<JournalLearningStageBody> {
  bool _showValidation = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (assessmentFeaturesEnabled && mounted && !widget.assessment.hasDraft) {
        widget.onAssessmentChanged(const AssessmentBlockData());
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _stageValidationTarget(context),
    builder: (context, _) => _buildValidated(context),
  );

  Widget _buildValidated(BuildContext context) {
    final showValidation =
        _showValidation || _stageValidationTarget(context).value != null;

    final selectedDci = widget.selectedDci;
    final selectedSep = widget.selectedSep;
    final selectedCcc = widget.selectedCcc;
    final inquiryLensData = widget.inquiryLensData;
    final assessment = widget.assessment;
    final onToggleDci = widget.onToggleDci;
    final onToggleSep = widget.onToggleSep;
    final onToggleCcc = widget.onToggleCcc;
    final onInquiryLensChanged = widget.onInquiryLensChanged;
    final onAssessmentChanged = widget.onAssessmentChanged;
    final onBack = widget.onBack;
    final onNext = widget.onNext;
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Learning'),
        _LearningPanel(
          title: 'Inquiry Lens',
          description:
              'Choose the lens that best describes your thinking for this entry.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RequiredJournalInteraction(
                complete: () => inquiryLensData.hasLens,
                message: 'Select an inquiry lens.',
                child: InquiryLensChoiceGrid(
                  data: inquiryLensData,
                  showError: showValidation && !inquiryLensData.hasLens,
                  onChanged: onInquiryLensChanged,
                ),
              ),
              if (showValidation && !inquiryLensData.hasLens)
                const _LearningRequiredMessage(
                  'Required: select an inquiry lens.',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _LearningPanel(
          title: 'The Three Dimensions of Learning',
          description: 'Select NGSS components demonstrated in this entry.',
          child: Column(
            children: [
              _RequiredJournalInteraction(
                complete: () => selectedDci.isNotEmpty,
                message: 'Select at least one DCI option.',
                child: _LearningCheckboxSection(
                  showError: showValidation && selectedDci.isEmpty,
                  title: 'DCI',
                  subtitle: 'Disciplinary Core Ideas',
                  iconAsset: 'assets/learning_module/summary_dci.svg',
                  options: _discoveryDciOptions,
                  selected: selectedDci,
                  onToggle: onToggleDci,
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              _RequiredJournalInteraction(
                complete: () => selectedSep.isNotEmpty,
                message: 'Select at least one SEP option.',
                child: _LearningCheckboxSection(
                  showError: showValidation && selectedSep.isEmpty,
                  title: 'SEP',
                  subtitle: 'Science and Engineering Practices',
                  iconAsset: 'assets/learning_module/summary_sep.svg',
                  options: _discoverySepOptions,
                  selected: selectedSep,
                  onToggle: onToggleSep,
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              _RequiredJournalInteraction(
                complete: () => selectedCcc.isNotEmpty,
                message: 'Select at least one CCCs option.',
                child: _LearningCheckboxSection(
                  showError: showValidation && selectedCcc.isEmpty,
                  title: 'CCCs',
                  subtitle: 'Crosscutting Concepts',
                  iconAsset: 'assets/learning_module/summary_ccc.svg',
                  options: _discoveryCccOptions,
                  selected: selectedCcc,
                  onToggle: onToggleCcc,
                ),
              ),
            ],
          ),
        ),
        if (assessmentFeaturesEnabled) ...[
          const SizedBox(height: AppMetrics.fieldGap),
          _LearningPanel(
            title: 'Assessment Type (Optional)',
            description:
                'How can learning be demonstrated? Choose how someone could show their learning from this entry.',
            child: _RequiredJournalInteraction(
              complete: () => assessment.type == null || assessment.isValid,
              message: 'Complete the selected assessment or remove its type.',
              child: AssessmentBlockSection(
                value: assessment,
                showValidation: showValidation,
                onSave: widget.onSaveAssessment,
                onChanged: onAssessmentChanged,
              ),
            ),
          ),
        ],
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(
            label: 'Next',
            filled: true,
            onTap: () {
              setState(() => _showValidation = true);
              if (!inquiryLensData.hasLens ||
                  selectedDci.isEmpty ||
                  selectedSep.isEmpty ||
                  selectedCcc.isEmpty) {
                return;
              }
              onNext();
            },
          ),
        ],
      ),
    );
  }
}

class _LearningPanel extends StatelessWidget {
  const _LearningPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: 8),
          Text(description, style: AppTypography.helper),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LearningPreviewPage extends StatelessWidget {
  const _LearningPreviewPage({
    required this.selectedDci,
    required this.selectedSep,
    required this.selectedCcc,
    required this.inquiryLensData,
    required this.assessment,
  });

  final Set<String> selectedDci;
  final Set<String> selectedSep;
  final Set<String> selectedCcc;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(43, 64, 43, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Entry: Discovery',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const _StageHeader(activeIndex: 3),
                    const SizedBox(height: JournalPageLayout.stageGap),
                    const JournalSectionHeader(title: 'Learning'),
                    _LearningPreviewContent(
                      selectedDci: selectedDci,
                      selectedSep: selectedSep,
                      selectedCcc: selectedCcc,
                      inquiryLensData: inquiryLensData,
                      assessment: assessment,
                    ),
                    const SizedBox(height: AppMetrics.sectionGap),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SmallStageButton(
                          label: 'Back',
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: 21),
                        _SmallStageButton(
                          label: 'Next',
                          filled: true,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningPreviewLens extends StatelessWidget {
  const _LearningPreviewLens({required this.config, required this.state});

  final InquiryLensConfig config;
  final InquiryLensState state;

  @override
  Widget build(BuildContext context) {
    final focus = [
      ...state.checkedFocusItems,
      ...state.customFocusItems.where((item) => item.trim().isNotEmpty),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(config.iconAsset, width: 28, height: 27),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Looking through ${switch (config.value) {
                  "Design" => "a design",
                  "Observe" => "an observation",
                  "Investigate" => "an investigation",
                  "Wonder" => "a curiosity",
                  "Systems" => "a systems",
                  "Explain" => "an explanation",
                  _ => config.value.toLowerCase(),
                }} lens',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devText,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          config.description,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.helperSize,
            height: 1.3,
          ),
        ),
        if (focus.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PreviewMutedText('Focus: ${focus.join(', ')}'),
        ],
        if (state.studentInstruction.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _PreviewMutedText(state.studentInstruction.trim()),
        ],
      ],
    );
  }
}

class _PreviewSectionHeader extends StatelessWidget {
  const _PreviewSectionHeader({required this.title, this.iconAsset});

  final String title;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (iconAsset != null) ...[
          SvgPicture.asset(iconAsset!, width: 28, height: 27),
          const SizedBox(width: 12),
        ],
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _LearningPreviewDimensionCard extends StatelessWidget {
  const _LearningPreviewDimensionCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.values,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final Set<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.every((value) => value.trim().isEmpty))
      return const SizedBox.shrink();
    return Container(
      width: 329,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        boxShadow: _nestedPreviewShadow,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(iconAsset, width: 29, height: 29),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.sectionTitleSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _learningDimensionContext(title),
            style: AppTypography.helper.copyWith(height: 1.45),
          ),
          const SizedBox(height: 10),
          if (values.isEmpty)
            const _PreviewMutedText('None selected.')
          else
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 19,
                      margin: const EdgeInsets.only(top: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _devGreen,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _PreviewMutedText(value)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _AssessmentPreviewCard extends StatelessWidget {
  const _AssessmentPreviewCard({required this.assessment});
  final AssessmentBlockData assessment;
  @override
  Widget build(BuildContext context) =>
      InteractiveJournalAssessment(assessment: assessment);
}

List<String> _assessmentPreviewLines(AssessmentBlockData assessment) {
  final data = assessment.data;
  String s(String key) => data[key]?.toString().trim() ?? '';
  switch (assessment.type) {
    case AssessmentType.numeric:
      return [
        if (s('question').isNotEmpty) s('question'),
        if (s('correct_answer').isNotEmpty) 'Answer: ${s('correct_answer')}',
        if (s('min_value').isNotEmpty || s('max_value').isNotEmpty)
          'Range: ${s('min_value')} - ${s('max_value')}',
        if (s('explanation').isNotEmpty) s('explanation'),
      ];
    case AssessmentType.matching:
      final top = _previewStringList(data['top_items']);
      final bottom = _previewStringList(data['bottom_items']);
      return [
        for (var i = 0; i < top.length || i < bottom.length; i++)
          '${i < top.length ? top[i] : ''} -> ${i < bottom.length ? bottom[i] : ''}',
      ];
    case AssessmentType.trueFalse:
      final questions = data['questions'];
      if (questions is! List || questions.isEmpty) {
        return [];
      }
      return [
        for (final item in questions.whereType<Map>())
          if ((item['text']?.toString() ?? '').trim().isNotEmpty)
            '${item['text']?.toString() ?? ''} (${item['correct_answer'] == true
                ? 'True'
                : item['correct_answer'] == false
                ? 'False'
                : 'Not set'})',
      ];
    case AssessmentType.paragraph:
      return [
        if (s('question').isNotEmpty) s('question'),
        if (s('response_length').isNotEmpty)
          'Response length: ${s('response_length')}',
      ];
    case AssessmentType.multipleChoice:
      final options = _previewStringList(data['options']);
      final correct = data['correct_index'];
      return [
        if (s('question').isNotEmpty) s('question'),
        for (var i = 0; i < options.length; i++)
          '${i + 1}. ${options[i]}${correct == i ? ' (correct)' : ''}',
        if (s('explanation').isNotEmpty) s('explanation'),
      ];
    case null:
      return [];
  }
}

List<String> _previewStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item.toString().trim().isNotEmpty) item.toString().trim(),
  ];
}

List<Map<dynamic, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) item,
  ];
}

class _PreviewMutedText extends StatelessWidget {
  const _PreviewMutedText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: AppColors.textSecondary,
        fontSize: AppTypography.helperSize,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
  }
}

String _learningDimensionContext(String title) => switch (title) {
  'DCI' =>
    'The science ideas behind this experience: the knowledge that helps explain what happened and why.',
  'SEP' =>
    'How science and engineering were put into practice: asking questions, investigating, analyzing evidence, and developing solutions.',
  'CCCs' =>
    'Ways to connect ideas across science, such as patterns, cause and effect, and systems. These help make sense of the experience as a whole.',
  _ => '',
};

class _LearningCheckboxSection extends StatelessWidget {
  const _LearningCheckboxSection({
    this.showError = false,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final bool showError;
  final String title;
  final String subtitle;
  final String iconAsset;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: showError ? Colors.red : const Color(0xFFD0D0D0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(iconAsset, width: 29, height: 29),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: title == 'DCI'
                            ? const Color(0xFF00A9F4)
                            : title == 'SEP'
                            ? const Color(0xFF607DB9)
                            : const Color(0xFF4948BF),
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.helperSize,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _learningDimensionContext(title),
            style: AppTypography.helper.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          for (final option in options)
            _LearningCheckboxRow(
              label: option,
              selected: selected.contains(option),
              onTap: () => onToggle(option),
            ),
          if (showError)
            const _LearningRequiredMessage(
              'Required: select at least one option.',
            ),
        ],
      ),
    );
  }
}

class _LearningCheckboxRow extends StatelessWidget {
  const _LearningCheckboxRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 19,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _devGreen : Colors.transparent,
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(3),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 22),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: _devText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextActionStageBody extends StatelessWidget {
  const _NextActionStageBody({
    required this.learned,
    required this.challenges,
    required this.nextSteps,
    required this.notes,
    required this.linkedTimelineEvent,
    required this.isSaving,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
    required this.onCreateTimelineEvent,
    required this.onBack,
    required this.onSubmit,
    this.completed = false,
  });

  final TextEditingController learned;
  final TextEditingController challenges;
  final TextEditingController nextSteps;
  final TextEditingController notes;
  final Map<String, String>? linkedTimelineEvent;
  final bool isSaving;
  final bool completed;
  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;
  final VoidCallback onCreateTimelineEvent;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _JournalStageLayout(
      children: [
        const JournalSectionHeader(title: 'Next Action'),
        _CounterTextBox(
          label: 'What did you learn today?',
          controller: learned,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _CounterTextBox(
          label: 'What challenges or questions came up?',
          controller: challenges,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _CounterTextBox(label: 'What are next steps?', controller: nextSteps),
        const SizedBox(height: AppMetrics.fieldGap),
        _TimelineLinkButton(
          label: 'Create New Timeline Event',
          addIcon: true,
          onTap: onCreateTimelineEvent,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _CounterTextBox(label: 'Open Notes', optional: true, controller: notes),
      ],
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallStageButton(label: 'Back', onTap: onBack),
          const SizedBox(width: 21),
          _SmallStageButton(
            label: completed ? 'Done' : 'Submit',
            filled: true,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _CounterTextBox extends StatelessWidget {
  const _CounterTextBox({
    required this.label,
    required this.controller,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return _RequiredInputHighlight(
      label: label,
      controller: controller,
      optional: optional,
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (optional)
                      const TextSpan(
                        text: ' (Optional)',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                style: AppTypography.fieldLabel,
              ),
              const SizedBox(height: AppMetrics.labelGap),
              TextField(
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                controller: controller,
                maxLength: 10000,
                minLines: AppMetrics.longResponseLines,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          !optional &&
                              _inputError(controller).value &&
                              controller.text.trim().isEmpty
                          ? Colors.red
                          : _devGreen,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          !optional &&
                              _inputError(controller).value &&
                              controller.text.trim().isEmpty
                          ? Colors.red
                          : _devGreen,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimelineLinkButton extends StatelessWidget {
  const _TimelineLinkButton({
    required this.label,
    this.addIcon = false,
    this.onTap,
  });

  final String label;
  final bool addIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 39,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: addIcon ? const Color(0xFFD9ECDD) : Colors.white,
          border: Border.all(color: _devGreen),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (addIcon) ...[
              const Text(
                '+',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!addIcon)
              const Icon(Icons.keyboard_arrow_down, color: _devGreen, size: 18),
          ],
        ),
      ),
    );
  }
}

class CreateJournalTimelineEventSheet extends StatefulWidget {
  const CreateJournalTimelineEventSheet({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.entryChildId,
    required this.members,
    required this.entryId,
    required this.entryTitle,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final String? entryChildId;
  final List<UserProfile> members;
  final String? entryId;
  final String entryTitle;

  @override
  State<CreateJournalTimelineEventSheet> createState() =>
      CreateJournalTimelineEventSheetState();
}

class CreateJournalTimelineEventSheetState
    extends State<CreateJournalTimelineEventSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final Set<String> _assigneeIds = {};
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime _end = DateTime.now().add(const Duration(hours: 2));
  bool _allDay = false;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showWheelDatePicker(context, start ? _start : _end);
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = _mergeDateAndTime(picked, _start);
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = _mergeDateAndTime(picked, _end);
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final value = start ? _start : _end;
    final hour12 = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final picked = await showWheelTimePicker(
      context,
      hour12,
      value.minute,
      value.hour >= 12 ? 'PM' : 'AM',
    );
    if (picked == null || !mounted) return;
    final hour = _to24Hour(picked['hour'] as int, picked['amPm'].toString());
    setState(() {
      final next = DateTime(
        value.year,
        value.month,
        value.day,
        hour,
        picked['minute'] as int,
      );
      if (start) {
        _start = next;
        if (_end.isBefore(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = next;
      }
    });
  }

  void _submit() {
    if (!_validateStageTextInputs(context)) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final assignees = widget.members
        .where((member) => _assigneeIds.contains(member.id))
        .toList();
    final event = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'name': name,
      'event': name,
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_start),
      'startDate': DateFormat('yyyy-MM-dd').format(_start),
      'endDate': DateFormat('yyyy-MM-dd').format(_end),
      'start': _start.toIso8601String(),
      'end': _end.toIso8601String(),
      'time': _allDay ? 'All Day' : _timeWithAmPmLocal(_start),
      'startTime': _allDay ? 'All Day' : _timeWithAmPmLocal(_start),
      'endTime': _allDay ? '' : _timeWithAmPmLocal(_end),
      'allDay': _allDay.toString(),
      'assigneeIds': assignees.map((member) => member.id).join('|'),
      'assigneeNames': assignees
          .map((member) => member.resolvedDisplayName)
          .join('|'),
    };
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .86,
      maxChildSize: .94,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: PageScrollWithFooter(
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9D9D9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Center(
                  child: Text(
                    'Create Event',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.primary,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: AppMetrics.labelGap),
                _TimelineSheetField(label: 'Event Name', controller: _name),
                const SizedBox(height: AppMetrics.labelGap),
                _TimelineSheetField(
                  label: 'Description',
                  optional: true,
                  controller: _description,
                ),
                const SizedBox(height: AppMetrics.labelGap),
                _TimelineSheetField(
                  label: 'Location',
                  optional: true,
                  controller: _location,
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Text(
                  'Start',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TimelinePickerChip(
                      label: DateFormat('MMM d, yyyy').format(_start),
                      onTap: () => _pickDate(start: true),
                    ),
                    const SizedBox(width: 10),
                    _TimelinePickerChip(
                      label: _timeWithAmPmLocal(_start),
                      onTap: () => _pickTime(start: true),
                    ),
                  ],
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Text(
                  'End',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TimelinePickerChip(
                      label: DateFormat('MMM d, yyyy').format(_end),
                      onTap: () => _pickDate(start: false),
                    ),
                    const SizedBox(width: 10),
                    _TimelinePickerChip(
                      label: _timeWithAmPmLocal(_end),
                      onTap: () => _pickTime(start: false),
                    ),
                  ],
                ),
                const SizedBox(height: AppMetrics.labelGap),
                Row(
                  children: [
                    const Text(
                      'All Day',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: _allDay,
                      activeThumbColor: _devGreen,
                      onChanged: (value) => setState(() => _allDay = value),
                    ),
                  ],
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Text(
                  'Assign To',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final member in widget.members)
                      FilterChip(
                        label: Text(member.resolvedDisplayName),
                        selected: _assigneeIds.contains(member.id),
                        selectedColor: _devGreen.withValues(alpha: .2),
                        checkmarkColor: _devGreen,
                        onSelected: (_) {
                          setState(() {
                            if (!_assigneeIds.add(member.id)) {
                              _assigneeIds.remove(member.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const SizedBox(height: AppMetrics.sectionGap),
                Center(
                  child: _SmallStageButton(
                    label: 'Create',
                    filled: true,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineSheetField extends StatelessWidget {
  const _TimelineSheetField({
    required this.label,
    required this.controller,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OptionalFieldLabel(
          label,
          optional: optional,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: TextField(
            controller: controller,
            style: AppTypography.inputText,
            minLines: label == 'Description' ? AppMetrics.longResponseLines : 1,
            maxLines: null,
            textAlignVertical: label == 'Description'
                ? TextAlignVertical.top
                : TextAlignVertical.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _devGreen),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelinePickerChip extends StatelessWidget {
  const _TimelinePickerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _devGreen.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: _devGreen,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CalendarMiniIcon extends StatelessWidget {
  const _CalendarMiniIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CalendarMiniPainter());
  }
}

class _CalendarMiniPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _devGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(5, 3, size.width - 10, size.height - 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, paint);
    canvas.drawLine(Offset(5, 11), Offset(size.width - 5, 11), paint);
    canvas.drawLine(const Offset(13, 0), const Offset(13, 7), paint);
    canvas.drawLine(
      Offset(size.width - 13, 0),
      Offset(size.width - 13, 7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

DateTime _mergeDateAndTime(DateTime date, DateTime time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

int _to24Hour(int hour, String amPm) {
  final normalized = hour % 12;
  return amPm == 'PM' ? normalized + 12 : normalized;
}

String _timeWithAmPmLocal(DateTime date) {
  return DateFormat('h:mm a').format(date);
}

class _LabeledBox extends StatelessWidget {
  const _LabeledBox({
    required this.label,
    required this.controller,
    bool optional = false,
    this.helperText,
    this.height = 89,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.expandWithContent = false,
  }) : optional =
           optional ||
           label == 'Discovery Title' ||
           label == 'Challenge Title' ||
           label == 'Build Title' ||
           label == 'Test Title' ||
           label == 'Technical Analysis Title' ||
           label == 'Implementation Title';

  final String label;
  final bool optional, expandWithContent;
  final String? helperText;
  final double height;
  final int maxLines;
  final int minLines;
  final int? maxLength;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _RequiredInputHighlight(
      label: label,
      controller: controller,
      optional: optional,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.fieldLabel,
              children: [
                if (optional)
                  const TextSpan(
                    text: ' (Optional)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: AppMetrics.helperGap),
            Text(
              helperText!,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: AppMetrics.labelGap),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              minLines: maxLines > 1 ? AppMetrics.longResponseLines : minLines,
              maxLines: null,
              style: AppTypography.inputText,
              textAlignVertical: maxLines > 1 || minLines > 1
                  ? TextAlignVertical.top
                  : TextAlignVertical.center,
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        !optional &&
                            _inputError(controller).value &&
                            controller.text.trim().isEmpty
                        ? Colors.red
                        : _devGreen,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        !optional &&
                            _inputError(controller).value &&
                            controller.text.trim().isEmpty
                        ? Colors.red
                        : _devGreen,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RootCauseDraft {
  _RootCauseDraft({
    required String title,
    required String description,
    required String reason,
    List<_EvidenceBlock>? evidence,
  }) : title = TextEditingController(text: title),
       description = TextEditingController(text: description),
       reason = TextEditingController(text: reason),
       evidence = evidence ?? [];

  factory _RootCauseDraft.empty() {
    return _RootCauseDraft(title: '', description: '', reason: '');
  }

  factory _RootCauseDraft.fromMap(Map<dynamic, dynamic> map) {
    final evidence = map['evidence'];
    return _RootCauseDraft(
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      evidence: evidence is List
          ? evidence
                .whereType<Map>()
                .map((item) => _EvidenceBlock.fromMap(item))
                .whereType<_EvidenceBlock>()
                .toList()
          : [],
    );
  }

  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController reason;
  final List<_EvidenceBlock> evidence;

  bool get hasContent {
    return title.text.trim().isNotEmpty ||
        description.text.trim().isNotEmpty ||
        reason.text.trim().isNotEmpty ||
        evidence.isNotEmpty;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.text.trim(),
      'description': description.text.trim(),
      'reason': reason.text.trim(),
      'evidence': evidence.map((item) => item.toMap()).toList(),
    };
  }

  void dispose() {
    title.dispose();
    description.dispose();
    reason.dispose();
  }
}

class _EvidenceBlock {
  const _EvidenceBlock._(this.type, this.data);

  factory _EvidenceBlock.images(ImageBlockData data) =>
      _EvidenceBlock._('Images', _imageBlockToMap(data));
  factory _EvidenceBlock.sketch(SketchBlockData data) =>
      _EvidenceBlock._('Sketch', data.toJson());
  factory _EvidenceBlock.link(LinkBlockData data) =>
      _EvidenceBlock._('Link', data.toJson());
  factory _EvidenceBlock.video(VideoBlockData data) =>
      _EvidenceBlock._('Video', data.toJson());
  factory _EvidenceBlock.graph(GraphBlockData data) =>
      _EvidenceBlock._('Graph', data.toJson());
  factory _EvidenceBlock.table(TableBlockData data) =>
      _EvidenceBlock._('Table', data.toJson());

  static _EvidenceBlock? fromMap(Map<dynamic, dynamic> map) {
    final type = map['type']?.toString() ?? '';
    final rawData = map['data'];
    if (type.isEmpty || rawData is! Map) return null;
    return _EvidenceBlock._(type, Map<String, dynamic>.from(rawData));
  }

  final String type;
  final Map<String, dynamic> data;

  ImageBlockData? get imageData =>
      type == 'Images' ? _imageBlockFromMap(data) : null;
  SketchBlockData? get sketchData =>
      type == 'Sketch' ? SketchBlockData.fromJson(data) : null;
  LinkBlockData? get linkData =>
      type == 'Link' ? LinkBlockData.fromJson(data) : null;
  VideoBlockData? get videoData =>
      type == 'Video' ? VideoBlockData.fromJson(data) : null;
  GraphBlockData? get graphData =>
      type == 'Graph' ? GraphBlockData.fromJson(data) : null;
  TableBlockData? get tableData =>
      type == 'Table' ? TableBlockData.fromJson(data) : null;

  String get title {
    final value = data['title']?.toString() ?? '';
    if (value.isNotEmpty) return value;
    if (type == 'Link') return data['url']?.toString() ?? 'Link';
    if (type == 'Video') return data['file_name']?.toString() ?? 'Video';
    return type;
  }

  String get subtitle {
    final candidates = [
      data['caption'],
      data['description'],
      data['url'],
      data['external_url'],
      data['graph_type'],
    ];
    for (final value in candidates) {
      final text = value?.toString() ?? '';
      if (text.trim().isNotEmpty) return text.trim();
    }
    return type;
  }

  String get iconAsset {
    return switch (type) {
      'Images' => 'assets/learning_module/concept_image.svg',
      'Sketch' => 'assets/learning_module/concept_sketch.svg',
      'Video' => 'assets/learning_module/concept_video.svg',
      'Table' => 'assets/learning_module/concept_table.svg',
      'Graph' => 'assets/learning_module/concept_graph.svg',
      'Link' => 'assets/learning_module/concept_link.svg',
      _ => 'assets/learning_module/concept_text.svg',
    };
  }

  Color get tileColor {
    return switch (type) {
      'Images' => const Color(0xFFD8F0DF),
      'Sketch' => const Color(0xFF8CDADB),
      'Video' => const Color(0xFFFFE2E2),
      'Link' => const Color(0xFFFFEFE7),
      _ => const Color(0xFFCDCDCD),
    };
  }

  Map<String, dynamic> toMap() => {'type': type, 'data': data};
}

Map<String, dynamic> _imageBlockToMap(ImageBlockData data) {
  return {
    'title': data.title,
    'caption': data.caption,
    'images': [
      for (final item in data.images)
        {
          'description': item.description,
          'has_placeholder_image': item.hasPlaceholderImage,
          'storage_path': item.storagePath,
          'public_url': item.publicUrl,
          'file_name': item.fileName,
        },
    ],
  };
}

ImageBlockData _imageBlockFromMap(Map<String, dynamic> data) {
  final images = data['images'];
  return ImageBlockData(
    title: data['title']?.toString() ?? '',
    caption: data['caption']?.toString() ?? '',
    images: images is List
        ? [
            for (final item in images)
              if (item is Map)
                ImageBlockItem(
                  description: item['description']?.toString() ?? '',
                  hasPlaceholderImage: item['has_placeholder_image'] == true,
                  storagePath:
                      (item['storage_path'] ?? item['storagePath'])
                          ?.toString() ??
                      '',
                  publicUrl:
                      (item['public_url'] ?? item['publicUrl'] ?? item['url'])
                          ?.toString() ??
                      '',
                  fileName: item['file_name']?.toString() ?? '',
                ),
          ]
        : const [],
  );
}

Set<String> _stringSet(Object? raw) {
  if (raw is! List) return {};
  return {
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  };
}

class _RootCauseEditorCard extends StatelessWidget {
  const _RootCauseEditorCard({
    required this.rootCause,
    this.requireInput = true,
    this.showError = false,
    required this.onAddEvidence,
    required this.onEditEvidence,
    required this.onDeleteEvidence,
  });

  final _RootCauseDraft rootCause;
  final ValueChanged<int> onDeleteEvidence;
  final bool requireInput;
  final bool showError;
  final VoidCallback onAddEvidence;
  final void Function(String type, int index) onEditEvidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: showError ? Colors.red : _devGreen),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactField(label: 'Root Cause', controller: rootCause.title),
          const SizedBox(height: 13),
          _CompactField(
            label: 'Short Description',
            controller: rootCause.description,
          ),
          const SizedBox(height: 13),
          _CompactField(
            label: 'Why do you think this occurs?',
            controller: rootCause.reason,
            height: 93,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          const OptionalFieldLabel(
            'Evidence (Optional)',
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              color: AppColors.primary,
              fontSize: AppTypography.evidenceTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (rootCause.evidence.isEmpty)
            const _EmptyEvidenceState(rootCauseLayout: true)
          else
            for (var i = 0; i < rootCause.evidence.length; i++)
              _EvidenceSummaryCard(
                evidence: rootCause.evidence[i],
                onTap: () => onEditEvidence(rootCause.evidence[i].type, i),
                onDelete: () => onDeleteEvidence(i),
              ),
          const SizedBox(height: 12),
          Center(
            child: AppTapTarget(
              onTap: onAddEvidence,
              child: Container(
                width: 202,
                height: 33,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: _devGreen),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '+ Add Evidence Block',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.primary,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.label,
    required this.controller,
    this.height = 36,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final double height;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return _RequiredInputHighlight(
      label: label,
      controller: controller,
      optional: false,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: TextField(
              controller: controller,
              minLines: maxLines > 1 ? AppMetrics.longResponseLines : 1,
              maxLines: null,
              style: AppTypography.inputText,
              textAlignVertical: maxLines > 1
                  ? TextAlignVertical.top
                  : TextAlignVertical.center,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 9,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        _inputError(controller).value &&
                            controller.text.trim().isEmpty
                        ? Colors.red
                        : _devGreen,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        _inputError(controller).value &&
                            controller.text.trim().isEmpty
                        ? Colors.red
                        : _devGreen,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEvidenceState extends StatelessWidget {
  const _EmptyEvidenceState({this.rootCauseLayout = false});
  final bool rootCauseLayout;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: rootCauseLayout ? 80 : 100,
            height: 56,
            child: const FittedBox(child: _CubesEvidenceIcon()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nothing yet...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first block',
            textAlign: TextAlign.center,
            style: AppTypography.helper,
          ),
        ],
      ),
    ),
  );
}

class _EvidenceSummaryCard extends StatelessWidget {
  const _EvidenceSummaryCard({
    required this.evidence,
    this.onTap,
    this.onDelete,
  });

  final _EvidenceBlock evidence;
  final VoidCallback? onTap, onDelete;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x1A000000)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: evidence.tileColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                evidence.iconAsset,
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evidence.type,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    evidence.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null || onDelete != null)
              ItemActionMenu(onEdit: onTap, onDelete: onDelete),
          ],
        ),
      ),
    );
  }
}

class _RootCauseCompactCard extends StatefulWidget {
  const _RootCauseCompactCard({
    super.key,
    required this.rootCause,
    this.onDelete,
    this.onEdit,
  });

  final _RootCauseDraft rootCause;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  State<_RootCauseCompactCard> createState() => _RootCauseCompactCardState();
}

class _RootCauseCompactCardState extends State<_RootCauseCompactCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (_expanded) {
      return _RootCausePreviewCard(
        rootCause: widget.rootCause,
        onToggle: () => setState(() => _expanded = false),
        onEdit: widget.onEdit,
        onDelete: widget.onDelete,
      );
    }
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = true),
      child: Container(
        constraints: const BoxConstraints(minHeight: 67),
        margin: const EdgeInsets.only(bottom: 19),
        padding: const EdgeInsets.fromLTRB(25, 10, 24, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x33090909)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 35, height: 35, child: _RootCauseIcon()),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.rootCause.title.text.trim().isEmpty
                        ? 'Root Cause'
                        : widget.rootCause.title.text.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.rootCause.description.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            _RootCauseActions(
              expanded: false,
              onToggle: () => setState(() => _expanded = true),
              onEdit: widget.onEdit,
              onDelete: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _PatternChangeOption {
  const _PatternChangeOption(this.label, this.assets);

  String get description => switch (label) {
    'Reduction' => 'Use fewer resources or reduce waste and harmful impacts.',
    'Substitution' =>
      'Replace a material, process, or resource with an alternative that reduces harm.',
    'Behavior Change' => 'Change habits or actions to improve outcomes.',
    'Capacity Building' =>
      'Build knowledge, skills, or tools that enable lasting change.',
    'Regeneration' => 'Restore or renew natural systems and resources.',
    _ => '',
  };
  final String label;
  final List<String> assets;
}

const _patternChangeOptions = [
  _PatternChangeOption('Reduction', [
    'assets/project_setup/pattern_reduction.svg',
  ]),
  _PatternChangeOption('Substitution', [
    'assets/project_setup/pattern_substitution.svg',
  ]),
  _PatternChangeOption('Behavior Change', [
    'assets/project_setup/pattern_behavior.svg',
  ]),
  _PatternChangeOption('Capacity Building', [
    'assets/project_setup/pattern_capacity.svg',
  ]),
  _PatternChangeOption('Regeneration', [
    'assets/project_setup/pattern_regeneration.svg',
  ]),
];

class _PatternChangeOptionTile extends StatelessWidget {
  const _PatternChangeOptionTile({
    required this.option,
    required this.selected,
    this.showError = false,
    required this.onTap,
  });

  final _PatternChangeOption option;
  final bool selected;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: showError ? Colors.red : const Color(0x80000000),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(width: 22),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _devGreen),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: _devGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 48),
            SizedBox(
              width: 34,
              height: 28,
              child: _StackedSvgIcon(assets: option.assets),
            ),
            const SizedBox(width: 44),
            Expanded(
              child: Text(
                option.label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackedSvgIcon extends StatelessWidget {
  const _StackedSvgIcon({required this.assets});

  final List<String> assets;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final asset in assets)
          SvgPicture.asset(asset, fit: BoxFit.contain),
      ],
    );
  }
}

class _SmallStageButton extends StatelessWidget {
  const _SmallStageButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: AppMetrics.controlHeight,
      child: filled
          ? FilledButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

class _EvidenceBlockPicker extends StatelessWidget {
  const _EvidenceBlockPicker();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.padding.vertical - 48;
    const items = ['Images', 'Sketch', 'Link', 'Video', 'Graph', 'Table'];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 340,
        height: availableHeight.clamp(0.0, 510.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 36,
                      right: 36,
                      child: Text(
                        'Select Evidence Block',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: _devGreen,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      child: IconButton(
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: _devGreen,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tileHeight =
                        (constraints.maxWidth - 16 - 44) / 2 / 1.05;
                    final verticalPadding =
                        ((constraints.maxHeight - tileHeight * 3 - 48) / 2)
                            .clamp(4.0, double.infinity);
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: Scrollbar(
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 44,
                          childAspectRatio: 1.05,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: verticalPadding,
                          ),
                          children: [
                            for (final item in items)
                              _EvidencePickerTile(
                                type: item,
                                onTap: () => Navigator.of(context).pop(item),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidencePickerTile extends StatelessWidget {
  const _EvidencePickerTile({required this.type, required this.onTap});

  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final evidence = _EvidenceBlock._(type, const {});
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x33000000)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 33,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: evidence.tileColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SvgPicture.asset(
                evidence.iconAsset,
                width: 20,
                height: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzePreviewPage extends StatelessWidget {
  const _AnalyzePreviewPage({
    required this.rootCauses,
    required this.patternChange,
    required this.patternExplanation,
  });

  final List<_RootCauseDraft> rootCauses;
  final String? patternChange;
  final String patternExplanation;

  @override
  Widget build(BuildContext context) {
    final selected = _patternChangeOptions.where(
      (option) => option.label == patternChange,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PrototypeTopBar(
                      title: 'Journal Entry: Discovery',
                      onBack: () => Navigator.of(context).pop(),
                      inset: 0,
                    ),
                    const _StageHeader(activeIndex: 1),
                    const SizedBox(height: JournalPageLayout.stageGap),
                    const JournalSectionHeader(title: 'Root Causes'),
                    if (rootCauses.isEmpty)
                      const Text(
                        'No root causes added yet.',
                        style: TextStyle(color: Color(0x80000000)),
                      )
                    else
                      for (final rootCause in rootCauses)
                        _RootCausePreviewCard(rootCause: rootCause),
                    const SizedBox(height: AppMetrics.fieldGap),
                    const JournalSectionHeader(title: 'Pattern Changes'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 15, 16, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0x80000000)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What could change or improve?',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (selected.isNotEmpty)
                            Row(
                              children: [
                                SizedBox(
                                  width: 34,
                                  height: 28,
                                  child: _StackedSvgIcon(
                                    assets: selected.first.assets,
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Text(
                                  selected.first.label,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: AppTypography.bodySize,
                                  ),
                                ),
                              ],
                            )
                          else
                            const Text(
                              'No pattern change selected.',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: AppColors.textSecondary,
                                fontSize: AppTypography.helperSize,
                              ),
                            ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const Text(
                            'Why was this pattern selected?',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.textPrimary,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            patternExplanation.isEmpty
                                ? 'No explanation added yet.'
                                : patternExplanation,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: AppColors.textSecondary,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 70),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SmallStageButton(
                          label: 'Back',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 21),
                        _SmallStageButton(
                          label: 'Next',
                          filled: true,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RootCausePreviewCard extends StatelessWidget {
  const _RootCausePreviewCard({
    required this.rootCause,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  final VoidCallback? onToggle;

  final _RootCauseDraft rootCause;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 37),
      padding: const EdgeInsets.fromLTRB(90, 9, 24, 18),
      decoration: BoxDecoration(
        boxShadow: _nestedPreviewShadow,
        color: Colors.white,
        border: Border.all(color: const Color(0x33090909)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: -68,
            top: 4,
            width: 35,
            height: 35,
            child: _RootCauseIcon(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTapTarget(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          rootCause.title.text.trim().isEmpty
                              ? 'Root Cause'
                              : rootCause.title.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.headingFamily,
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.sectionTitleSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onToggle != null ||
                          onEdit != null ||
                          onDelete != null)
                        _RootCauseActions(
                          expanded: true,
                          onToggle: onToggle,
                          onEdit: onEdit,
                          onDelete: onDelete,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rootCause.description.text.trim(),
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              const Divider(color: Color(0xFFE1E1E1)),
              const SizedBox(height: 8),
              const Text(
                'Why does this occur?',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rootCause.reason.text.trim(),
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              const Divider(color: Color(0xFFE1E1E1)),
              const SizedBox(height: 8),
              const Text(
                'Evidence',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppMetrics.labelGap),
              if (rootCause.evidence.isEmpty)
                const Text(
                  'No evidence added yet.',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.helperSize,
                  ),
                )
              else
                for (final evidence in rootCause.evidence)
                  _EvidencePreviewBlock(evidence: evidence),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidencePreviewBlock extends StatelessWidget {
  const _EvidencePreviewBlock({required this.evidence});
  final _EvidenceBlock evidence;

  @override
  Widget build(BuildContext context) {
    final images = evidence.data['images'];
    final caption =
        (evidence.data['caption'] ?? evidence.data['description'] ?? '')
            .toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: evidence.tileColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.asset(evidence.iconAsset),
              ),
              const SizedBox(width: 7),
              Text(
                evidence.type,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            evidence.title,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          switch (evidence.type) {
            'Images' => Column(
              children: [
                if (images is List)
                  for (var i = 0; i < images.length; i++)
                    if (images[i] is Map)
                      _ImageEvidencePreview(
                        index: i + 1,
                        image: Map<dynamic, dynamic>.from(images[i] as Map),
                      ),
              ],
            ),
            'Sketch' => SketchEvidencePreview(data: evidence.sketchData!),
            'Graph' => GraphEvidencePreview(data: evidence.graphData!),
            'Table' => _TableEvidencePreview(data: evidence.tableData!),
            'Video' => _VideoEvidencePreview(data: evidence.videoData!),
            'Link' => _EvidenceLink(
              url: evidence.data['url']?.toString() ?? '',
            ),
            _ => const Text('This evidence type is not supported yet.'),
          },
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              caption,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openEvidenceUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    /* Display a recoverable message below. */
  }
  if (context.mounted)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open this evidence. Please try again.'),
      ),
    );
}

class _EvidenceLink extends StatelessWidget {
  const _EvidenceLink({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Open the link to view the material.',
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
        ),
      ),
      TextButton.icon(
        onPressed: url.isEmpty ? null : () => _openEvidenceUrl(context, url),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open link'),
      ),
      SelectableText(
        url,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          color: Colors.grey,
        ),
      ),
    ],
  );
}

class _TableEvidencePreview extends StatelessWidget {
  const _TableEvidencePreview({required this.data});
  final TableBlockData data;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PageScrollWithFooter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 44,
            columnSpacing: 18,
            horizontalMargin: 10,
            columns: [
              for (final column in data.columns)
                DataColumn(
                  label: Text(
                    column.name,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
            ],
            rows: [
              for (final row in data.rows.where(
                (row) => data.columns.any(
                  (column) => (row[column.id] ?? '').trim().isNotEmpty,
                ),
              ))
                DataRow(
                  cells: [
                    for (final column in data.columns)
                      DataCell(
                        Text(
                          (row[column.id] ?? '').trim().isEmpty
                              ? '—'
                              : row[column.id]!,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VideoEvidencePreview extends StatefulWidget {
  const _VideoEvidencePreview({required this.data});
  final VideoBlockData data;
  @override
  State<_VideoEvidencePreview> createState() => _VideoEvidencePreviewState();
}

class _VideoEvidencePreviewState extends State<_VideoEvidencePreview> {
  late final Future<String> _url = _resolveUrl();
  Future<String> _resolveUrl() async {
    if (widget.data.externalUrl.isNotEmpty) return widget.data.externalUrl;
    if (widget.data.signedUrl.isNotEmpty) return widget.data.signedUrl;
    if (widget.data.storagePath.isEmpty) return '';
    return StorageService().createSignedUrl(
      widget.data.storagePath,
      bucketName: widget.data.storageBucket,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const LinearProgressIndicator();
      if (snapshot.hasError || snapshot.data?.isNotEmpty != true)
        return const Text(
          'Video unavailable. Please reopen the entry to retry.',
        );
      final url = snapshot.data!;
      if (widget.data.sourceMode == VideoSourceMode.upload) {
        return _UploadedEvidenceVideo(url: url);
      }
      final uri = Uri.tryParse(url);
      final id = uri?.host == 'youtu.be'
          ? uri?.pathSegments.firstOrNull
          : uri?.host.endsWith('youtube.com') == true
          ? uri?.queryParameters['v']
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTapTarget(
            onTap: () => _openEvidenceUrl(context, url),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFFFE2E2)),
                  if (id != null)
                    ProtectedImage.network(
                      'https://img.youtube.com/vi/$id/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.red,
                      size: 44,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _openEvidenceUrl(context, url),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Watch video'),
          ),
        ],
      );
    },
  );
}

class _ImageEvidencePreview extends StatefulWidget {
  const _ImageEvidencePreview({required this.index, required this.image});

  final int index;
  final Map<dynamic, dynamic> image;

  @override
  State<_ImageEvidencePreview> createState() => _ImageEvidencePreviewState();
}

class _ImageEvidencePreviewState extends State<_ImageEvidencePreview> {
  late final Future<String> _url = _resolveUrl();
  Future<String> _resolveUrl() =>
      resolveEvidenceMediaUrl(widget.image, bucket: 'images');

  @override
  Widget build(BuildContext context) {
    final description = widget.image['description']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 17,
                height: 17,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _devGreen,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${widget.index}',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: Colors.white,
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.textPrimary,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<String>(
            future: _url,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 114,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data?.isNotEmpty != true) {
                return _unavailable(
                  snapshot.hasError
                      ? 'Image could not be loaded.'
                      : 'No image was attached to this evidence.',
                );
              }
              final url = snapshot.data!;
              return AppTapTarget(
                onTap: () => showAppDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    insetPadding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width * .85,
                      height: MediaQuery.sizeOf(context).height * .8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            child: Center(
                              child: ProtectedImage.network(
                                url,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _unavailable('Image could not be loaded.'),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              tooltip: 'Close image',
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ProtectedImage.network(
                    url,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _unavailable('Image could not be loaded.'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _unavailable(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}

class _RootCauseIcon extends StatelessWidget {
  const _RootCauseIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/project_setup/root_cause.svg');
  }
}

class _CubesEvidenceIcon extends StatelessWidget {
  const _CubesEvidenceIcon();
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/evidence_cubes.svg',
      width: 100,
      height: 68,
    );
  }
}

class _AffectedCommunitiesField extends StatelessWidget {
  const _AffectedCommunitiesField({
    required this.communities,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_AffectedCommunity> communities;
  final VoidCallback onAdd;
  final ValueChanged<_AffectedCommunity> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            text: 'Who is affected?',
            style: AppTypography.fieldLabel,
            children: [
              TextSpan(
                text: ' (Optional)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 103),
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            color: _devGreen.withValues(alpha: .06),
            border: Border.all(color: _devGreen),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (communities.isNotEmpty)
                const SizedBox(height: AppMetrics.labelGap),
              for (final community in communities) ...[
                _AffectedCommunityRow(
                  community: community,
                  onRemove: () => onRemove(community),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Center(
                child: AppTapTarget(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAdd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Add Communities',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.primary,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _devGreen,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: _devGreen,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AffectedCommunityRow extends StatelessWidget {
  const _AffectedCommunityRow({
    required this.community,
    required this.onRemove,
  });
  final VoidCallback onRemove;

  final _AffectedCommunity community;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CommunityAvatar(community: community),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            community.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ItemActionMenu(
          extraActions: [
            ItemMenuAction('Remove', onRemove, color: const Color(0xFFFD1212)),
          ],
        ),
      ],
    );
  }
}

class _AffectedChoiceSheet extends StatelessWidget {
  const _AffectedChoiceSheet({required this.communitiesRepo});

  final CommunitiesRepo communitiesRepo;

  @override
  Widget build(BuildContext context) {
    final availableHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.vertical -
        32;
    return SafeArea(
      child: Center(
        child: Container(
          width: 341,
          constraints: BoxConstraints(maxHeight: availableHeight),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(16),
          ),
          child: PageScrollWithFooter(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppTapTarget(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          color: _devGreen,
                          size: 22,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Add Who is Affected',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.primary,
                            fontSize: AppTypography.buttonSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 22),
                    ],
                  ),
                  const SizedBox(height: 31),
                  const Text(
                    'Choose an option',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.helperSize,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AffectedChoiceCard(
                    icon: Icons.groups_outlined,
                    title: 'Choose an existing Juniper Journal Community',
                    subtitle:
                        'Find and add an organization that has an account.',
                    onTap: () async {
                      final result =
                          await showAppModalBottomSheet<_AffectedCommunity>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => _ExistingCommunitiesSheet(
                              communitiesRepo: communitiesRepo,
                            ),
                          );
                      if (!context.mounted || result == null) return;
                      Navigator.of(context).pop(result);
                    },
                  ),
                  const SizedBox(height: 16),
                  _AffectedChoiceCard(
                    icon: Icons.business_outlined,
                    title: 'Add a new organization',
                    subtitle:
                        "Create a new organization that doesn't have an account.",
                    onTap: () async {
                      final result = await pushAppRoute<_AffectedCommunity>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AddOrganizationPage(
                            communitiesRepo: communitiesRepo,
                          ),
                        ),
                      );
                      if (!context.mounted || result == null) return;
                      Navigator.of(context).pop(result);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AffectedChoiceCard extends StatelessWidget {
  const _AffectedChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 114),
        padding: const EdgeInsets.fromLTRB(23, 18, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black.withValues(alpha: .2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _devGreen, size: 34),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0x80000000), size: 22),
          ],
        ),
      ),
    );
  }
}

class _ExistingCommunitiesSheet extends StatefulWidget {
  const _ExistingCommunitiesSheet({required this.communitiesRepo});

  final CommunitiesRepo communitiesRepo;

  @override
  State<_ExistingCommunitiesSheet> createState() =>
      _ExistingCommunitiesSheetState();
}

class _ExistingCommunitiesSheetState extends State<_ExistingCommunitiesSheet> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Community> _communities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final communities = await widget.communitiesRepo.getAllCommunities();
    if (!mounted) return;
    setState(() {
      _communities = communities;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _communities
        : _communities
              .where(
                (community) => community.name.toLowerCase().contains(query),
              )
              .toList();

    return SafeArea(
      child: Center(
        child: Container(
          width: 360,
          height:
              (MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.vertical -
                      48)
                  .clamp(0.0, 400.0),
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppTapTarget(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _devGreen, size: 22),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Communities',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.primary,
                        fontSize: AppTypography.buttonSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
              const SizedBox(height: AppMetrics.labelGap),
              const Text(
                'Search',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '',
                    hintStyle: const TextStyle(color: Color(0x80000000)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 9),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _devGreen),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _devGreen),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              const Text(
                'Your Communities',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                ),
              ),
              const SizedBox(height: AppMetrics.labelGap),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No existing communities',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textSecondary,
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                      )
                    : AppScrollbar(
                        controller: _scroll,
                        thumbVisibility: true,
                        child: PageScrollWithFooter(
                          child: ListView.separated(
                            controller: _scroll,
                            padding: const EdgeInsets.only(right: 10),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppMetrics.labelGap),
                            itemBuilder: (context, index) {
                              final community = filtered[index];
                              return _ExistingCommunityRow(
                                community: community,
                                onAdd: () => Navigator.of(context).pop(
                                  _AffectedCommunity.fromCommunity(community),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingCommunityRow extends StatelessWidget {
  const _ExistingCommunityRow({required this.community, required this.onAdd});

  final Community community;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final affected = _AffectedCommunity.fromCommunity(community);
    return Row(
      children: [
        _CommunityAvatar(community: affected, size: 28),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            community.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AppTapTarget(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _devGreen),
            ),
            child: const Icon(Icons.add, color: _devGreen, size: 18),
          ),
        ),
      ],
    );
  }
}

class _AddOrganizationPage extends StatefulWidget {
  const _AddOrganizationPage({required this.communitiesRepo});

  final CommunitiesRepo communitiesRepo;

  @override
  State<_AddOrganizationPage> createState() => _AddOrganizationPageState();
}

class _AddOrganizationPageState extends State<_AddOrganizationPage> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _website = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _description.dispose();
    _website.dispose();
    super.dispose();
  }

  bool get _hasValidWebsite {
    final value = _website.text.trim();
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(
      value.startsWith(RegExp(r'https?://')) ? value : 'https://$value',
    );
    return uri != null && uri.host.contains('.');
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);
    final community = await widget.communitiesRepo.createCommunity(
      name: name,
      visibility: 'public',
      subjectFocus: _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (community == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add organization')),
      );
      return;
    }
    Navigator.of(context).pop(
      _AffectedCommunity.fromCommunity(
        community,
        location: _location.text.trim(),
        description: _description.text.trim(),
        website: _website.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(context),
            ),
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(44, 35, 51, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 56,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 2,
                            child: ContentAlignedBackButton(
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const Center(
                            child: Text(
                              'Add New Organization',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: AppColors.primary,
                                fontSize: AppTypography.buttonSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 31),
                    _OrgField(
                      label: 'Organization Name',
                      controller: _name,
                      height: 93,
                      maxLines: 3,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AppMetrics.sectionGap),
                    _OrgField(
                      label: 'Location',
                      optional: true,
                      controller: _location,
                      height: 36,
                    ),
                    const SizedBox(height: AppMetrics.sectionGap),
                    _OrgField(
                      label: 'Description',
                      controller: _description,
                      height: 93,
                      maxLines: 3,
                    ),
                    const SizedBox(height: AppMetrics.sectionGap),
                    _OrgField(
                      label: 'Website or Socials',
                      optional: true,
                      controller: _website,
                      height: 40,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 38),
                    _WebsitePreview(
                      url: _website.text.trim(),
                      isValid: _hasValidWebsite,
                    ),
                    const SizedBox(height: AppMetrics.sectionGap),
                    Center(
                      child: AppTapTarget(
                        onTap: _isSaving ? null : _add,
                        child: Container(
                          width: 91,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _devGreen,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _isSaving ? 'Adding...' : 'Add',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: Colors.white,
                              fontSize: AppTypography.helperSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrgField extends StatelessWidget {
  const _OrgField({
    required this.label,
    required this.controller,
    required this.height,
    this.optional = false,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final bool optional;
  final TextEditingController controller;
  final double height;
  final int maxLines;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: AppTypography.fieldLabel,
            children: [
              if (optional)
                const TextSpan(
                  text: ' (Optional)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: maxLines > 1 ? AppMetrics.longResponseHeight : height,
          ),
          child: TextField(
            controller: controller,
            minLines: maxLines > 1 ? AppMetrics.longResponseLines : 1,
            maxLines: maxLines > 1 ? null : 1,
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _devGreen),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _devGreen),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebsitePreview extends StatelessWidget {
  const _WebsitePreview({required this.url, required this.isValid});

  final String url;
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final normalized = url.startsWith(RegExp(r'https?://'))
        ? url
        : 'https://$url';
    final host = Uri.tryParse(normalized)?.host ?? url;
    return Container(
      width: double.infinity,
      height: 175,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .02),
        border: Border.all(
          color: Colors.black.withValues(alpha: .1),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: isValid
          ? Row(
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFE7),
                    borderRadius: BorderRadius.circular(56),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/learning_module/concept_link.svg',
                    width: 56,
                    height: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        normalized,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Website link',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: 0.2,
                  child: SvgPicture.asset(
                    'assets/learning_module/concept_link.svg',
                    width: 58,
                    height: 36,
                  ),
                ),
                const SizedBox(height: AppMetrics.labelGap),
                const Text(
                  'Provide a link to\nsee preview.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x33000000),
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({required this.community, this.size = 28});

  final _AffectedCommunity community;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (community.imageUrl != null && community.imageUrl!.isNotEmpty) {
      return ClipOval(
        child: ProtectedImage.network(
          community.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _FallbackCommunityAvatar(name: community.name, size: size),
        ),
      );
    }
    return _FallbackCommunityAvatar(name: community.name, size: size);
  }
}

class _FallbackCommunityAvatar extends StatelessWidget {
  const _FallbackCommunityAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _devGreen.withValues(alpha: .12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.business_outlined, color: _devGreen, size: size * .72),
    );
  }
}

class _AffectedCommunity {
  const _AffectedCommunity({
    this.id,
    required this.name,
    this.imageUrl,
    this.location,
    this.description,
    this.website,
    required this.kind,
  });

  final String? id;
  final String name;
  final String? imageUrl;
  final String? location;
  final String? description;
  final String? website;
  final String kind;

  factory _AffectedCommunity.fromCommunity(
    Community community, {
    String? location,
    String? description,
    String? website,
  }) {
    return _AffectedCommunity(
      id: community.id,
      name: community.name,
      imageUrl: community.imageUrl,
      location: location,
      description: description,
      website: website,
      kind: 'community',
    );
  }

  factory _AffectedCommunity.fromMap(Map<dynamic, dynamic> map) {
    return _AffectedCommunity(
      id: map['id']?.toString(),
      name: map['name']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString(),
      location: map['location']?.toString(),
      description: map['description']?.toString(),
      website: map['website']?.toString(),
      kind: map['kind']?.toString() ?? 'community',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (location != null && location!.isNotEmpty) 'location': location,
      if (description != null && description!.isNotEmpty)
        'description': description,
      if (website != null && website!.isNotEmpty) 'website': website,
      'kind': kind,
    };
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final UserProfile member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.black.withValues(alpha: .1) : Colors.white,
          border: selected ? null : Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: _devGreen.withValues(alpha: .2),
              child: Text(
                member.resolvedDisplayName.characters.first.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _devGreen,
                  fontSize: AppTypography.captionSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              member.resolvedDisplayName,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.bodySize,
              ),
            ),
            if (selected) const SizedBox(width: 10),
            if (selected)
              const SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: Icon(Icons.close, size: 16, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JournalLineIcon extends StatelessWidget {
  const _JournalLineIcon();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _JournalPainter());
}

class _JournalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _devGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .3, 0),
      Offset(size.width * .3, size.height * .3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _lastUpdatedDay(DateTime? date) {
  if (date == null) return 'N/A';
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, date)) return 'Today';
  return DateFormat('MMM d').format(date);
}

String _lastUpdatedTime(DateTime? date) {
  if (date == null) return '';
  return DateFormat('h:mm a').format(date);
}

class _EmptyPhaseEntries extends StatelessWidget {
  const _EmptyPhaseEntries();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: [
          Text(
            'Nothing yet...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF929292),
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Add your first entry',
            textAlign: TextAlign.center,
            style: AppTypography.helper,
          ),
        ],
      ),
    );
  }
}

/// Validates the inputs rendered for the current stage without blocking drafts.
final _requiredInputErrors = Expando<ValueNotifier<bool>>();
ValueNotifier<bool> _inputError(TextEditingController controller) =>
    _requiredInputErrors[controller] ??= ValueNotifier(false);

class _RequiredInputHighlight extends StatefulWidget {
  const _RequiredInputHighlight({
    required this.controller,
    required this.optional,
    required this.builder,
    this.label = 'Required field',
  });
  final String label;
  final TextEditingController controller;
  final bool optional;
  final WidgetBuilder builder;
  @override
  State<_RequiredInputHighlight> createState() =>
      _RequiredInputHighlightState();
}

class _RequiredInputHighlightState extends State<_RequiredInputHighlight> {
  TextEditingController get controller => widget.controller;
  bool get optional => widget.optional;
  WidgetBuilder get builder => widget.builder;

  @override
  void initState() {
    super.initState();
    // Validation is local to this visit, never part of the saved draft.
    _requiredInputErrors[controller] = ValueNotifier(false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, _inputError(controller)]),
      builder: (context, _) {
        final invalid =
            !optional &&
            _inputError(controller).value &&
            controller.text.trim().isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            builder(context),
            if (invalid)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  'Required',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: Colors.red,
                    fontSize: AppTypography.helperSize,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A required selection, collection, or action, including its empty state.
class _RequiredJournalInteraction extends StatefulWidget {
  const _RequiredJournalInteraction({
    required this.complete,
    required this.message,
    required this.child,
    this.changes,
  });
  final bool Function() complete;
  final String message;
  final Widget child;
  final Listenable? changes;
  @override
  State<_RequiredJournalInteraction> createState() =>
      _RequiredJournalInteractionState();
}

class _RequiredJournalInteractionState
    extends State<_RequiredJournalInteraction> {
  bool _attempted = false;
  bool validate() {
    setState(() => _attempted = true);
    return widget.complete();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      _stageValidationTarget(context),
      if (widget.changes != null) widget.changes!,
    ]),
    builder: (context, _) {
      final invalid =
          (_attempted || _stageValidationTarget(context).value != null) &&
          !widget.complete();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (invalid)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.message, style: AppTypography.requirement),
            ),
          widget.child,
        ],
      );
    },
  );
}

bool _validateStageTextInputs(BuildContext context) {
  var valid = true;
  final issues = <JournalValidationIssue>[];
  BuildContext? firstMissing;
  void inspect(Element element) {
    final widget = element.widget;
    if (widget is _RootCauseEditorCard && !widget.requireInput) return;
    if (widget is _RequiredJournalInteraction && element is StatefulElement) {
      final state = element.state as _RequiredJournalInteractionState;
      issues.add(
        JournalValidationIssue(
          widget.message,
          () => state.mounted && !state.widget.complete(),
          changes: widget.changes,
        ),
      );
      if (!state.validate()) {
        valid = false;
        firstMissing ??= element;
      }
    }
    if (widget is _RequiredInputHighlight) {
      if (!widget.optional) {
        issues.add(
          JournalValidationIssue(
            'Required: ${widget.label}.',
            () => element.mounted && widget.controller.text.trim().isEmpty,
            changes: widget.controller,
          ),
        );
      }
      final missing = !widget.optional && widget.controller.text.trim().isEmpty;
      _inputError(widget.controller).value = missing;
      if (missing) {
        valid = false;
        firstMissing ??= element;
      }
      return;
    }
    element.visitChildren(inspect);
  }

  // Tracker callbacks live beside the form, so validate the whole visible
  // scaffold rather than only the tracker's descendants.
  Element scope = context as Element;
  context.visitAncestorElements((ancestor) {
    if (ancestor.widget is Scaffold) {
      scope = ancestor;
      return false;
    }
    return true;
  });
  scope.visitChildren(inspect);
  journalValidationIssues(context).value = issues;
  if (firstMissing != null) {
    Scrollable.ensureVisible(
      firstMissing!,
      alignment: 0.1,
      duration: const Duration(milliseconds: 250),
    );
  }
  return valid;
}

Future<_EvidenceBlock?> _returnToEvidenceMenu(
  BuildContext context,
  Future<_EvidenceBlock?> Function(String type) openEditor,
) async {
  if (!context.mounted) return null;
  final selected = await showAppDialog<String>(
    context: context,
    builder: (_) => const _EvidenceBlockPicker(),
  );
  if (!context.mounted || selected == null) return null;
  return openEditor(selected);
}

class _DraftSaveStatus extends StatelessWidget {
  const _DraftSaveStatus({
    required this.status,
    this.reserveScrollGutter = false,
  });
  final bool reserveScrollGutter;
  final ValueNotifier<String> status;
  @override
  Widget build(BuildContext context) => _status(context);
  Widget _status(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: 16,
      bottom: 8,
      right:
          reserveScrollGutter &&
              ScrollConfiguration.of(context) is AppScrollBehavior &&
              {
                TargetPlatform.macOS,
                TargetPlatform.windows,
                TargetPlatform.linux,
              }.contains(Theme.of(context).platform)
          ? AppScrollbar.gutterWidth
          : 0,
    ),
    child: Center(
      child: ValueListenableBuilder<String>(
        valueListenable: status,
        builder: (_, value, child) => SizedBox(
          width: double.infinity,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textSecondary,
              fontSize: AppTypography.helperSize,
            ),
          ),
        ),
      ),
    ),
  );
}

class _LearningRequiredMessage extends StatelessWidget {
  const _LearningRequiredMessage(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      message,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: Colors.red,
        fontSize: AppTypography.helperSize,
      ),
    ),
  );
}

class JournalInvolvedPeopleField extends StatelessWidget {
  const JournalInvolvedPeopleField({
    super.key,
    required this.members,
    required this.selectedIds,
    required this.onToggle,
    this.creatorId,
  });
  final List<UserProfile> members;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final String? creatorId;
  String? get author => creatorId ?? _journalCurrentUserId();
  Future<void> _open(BuildContext context) async {
    var query = '';
    final selected = {...selectedIds}..remove(author);
    final saved = await showAppDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add People',
                          style: AppTypography.pageTitle,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close contributor selection',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) =>
                        update(() => query = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      labelText: 'Search project members',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: PageScrollWithFooter(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final person in members.where(
                            (p) =>
                                p.id != author &&
                                (p.resolvedDisplayName.toLowerCase().contains(
                                      query,
                                    ) ||
                                    (p.username ?? '').toLowerCase().contains(
                                      query,
                                    )),
                          ))
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.trailing,
                              visualDensity: VisualDensity.compact,
                              value: selected.contains(person.id),
                              title: Text(person.resolvedDisplayName),
                              onChanged: (v) => update(() {
                                ModalDraftScope.changed(context);
                                if (v == true)
                                  selected.add(person.id);
                                else
                                  selected.remove(person.id);
                              }),
                            ),
                          if (members.where((p) => p.id != author).isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No other project members yet.'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Save Contributors'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (saved == null) return;
    for (final id in {...selectedIds, ...saved}) {
      if (id != author && selectedIds.contains(id) != saved.contains(id))
        onToggle(id);
    }
  }

  @override
  Widget build(BuildContext context) => _ParticipantManagementGate(
    authorId: author,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final person in members.where(
              (p) => p.id == author || selectedIds.contains(p.id),
            ))
              person.id == author
                  ? Chip(
                      label: Text('${person.resolvedDisplayName} · Author'),
                      avatar: const Icon(Icons.person_outline, size: 18),
                    )
                  : _MemberChip(
                      member: person,
                      selected: true,
                      onTap: () => onToggle(person.id),
                    ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add People'),
          ),
        ),
      ],
    ),
  );
}

/// Read-only rendering of the structured Discovery entry saved by the creator.
class DiscoveryEntryPreviewPage extends StatefulWidget {
  const DiscoveryEntryPreviewPage({super.key, required this.entry});
  final JournalEntry entry;
  @override
  State<DiscoveryEntryPreviewPage> createState() =>
      _DiscoveryEntryPreviewPageState();
}

class _DiscoveryEntryPreviewPageState extends State<DiscoveryEntryPreviewPage> {
  late final List<_RootCauseDraft> _causes = [
    for (final stage in widget.entry.content.whereType<Map>())
      if (stage['stage'] == 'analyze' && stage['rootCauses'] is List)
        for (final cause in (stage['rootCauses'] as List).whereType<Map>())
          _RootCauseDraft.fromMap(cause),
  ];
  final Set<int> _expanded = {};
  @override
  void dispose() {
    for (final cause in _causes) {
      cause.dispose();
    }
    super.dispose();
  }

  Widget _stagePreview(Map stage) {
    final key = stage['stage'];
    if (key == 'learning')
      return _LearningPreviewContent(
        reflection:
            widget.entry.content
                .whereType<Map>()
                .firstWhere(
                  (row) => row['stage'] == 'nextAction',
                  orElse: () => {},
                )['learned']
                ?.toString() ??
            '',
        selectedDci: _stringSet(stage['dci']),
        selectedSep: _stringSet(stage['sep']),
        selectedCcc: _stringSet(stage['ccc']),
        inquiryLensData: InquiryLensData.fromJson(
          stage['inquiryLensData'],
          legacyLens:
              stage['inquiryLens']?.toString() ?? InquiryLensData.noneValue,
        ),
        assessment: AssessmentBlockData.fromJson(stage['assessment']),
      );
    if (key == 'nextAction')
      return _NextActionPreviewContent(
        projectId: widget.entry.projectId,
        includeLearned: false,
        learned: stage['learned']?.toString() ?? '',
        challenges: stage['challenges']?.toString() ?? '',
        nextSteps: stage['nextSteps']?.toString() ?? '',
        notes: stage['notes']?.toString() ?? '',
        linkedTimelineEvent: stage['linkedTimelineEvent'] is Map
            ? Map<String, String>.from(stage['linkedTimelineEvent'])
            : null,
      );
    final title = switch (key) {
      'observations' || 'observation' => 'Observations',
      'analyze' => 'Analyze',
      'question' => 'Question',
      _ => null,
    };
    if (title == null) return const SizedBox.shrink();
    return _PreviewPanel(
      title: title,
      children: [
        for (final field in const {
          'title': 'Discovery Title',
          'observed': 'What was observed?',
          'location': 'Location',
          'known': 'What is already known?',
          'patternChange': 'Pattern Changes',
          'patternExplanation': 'Pattern Explanation',
        }.entries)
          _PreviewField(field.value, stage[field.key]?.toString() ?? ''),
        if (key == 'analyze')
          for (var i = 0; i < _causes.length; i++)
            _RootCauseCompactCard(rootCause: _causes[i]),
        if (stage['questions'] is List)
          for (final question in (stage['questions'] as List).whereType<Map>())
            _PreviewField(
              question['type']?.toString() ?? 'Question',
              question['text']?.toString() ?? '',
            ),
        JournalInvolvedPeoplePreview(people: _maps(stage['involved'])),
        for (final field in const {
          'affectedCommunities': 'Who is affected?',
        }.entries)
          _PreviewField(
            field.value,
            _maps(stage[field.key])
                .map((item) => item['name'] ?? item['title'] ?? '')
                .where((value) => value.toString().trim().isNotEmpty)
                .join(', '),
          ),
        for (final item in _maps(stage['evidence']))
          if (_EvidenceBlock.fromMap(item) case final block?)
            _EvidencePreviewBlock(evidence: block),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _PrototypeScaffold(
    title: 'Journal Entry: Discovery',
    previewEntry: widget.entry,
    onBack: () => Navigator.of(context).pop(),
    body: PageScrollWithFooter(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 32),
        children: [
          Text(widget.entry.title, style: AppTypography.pageTitle),
          const SizedBox(height: AppMetrics.fieldGap),
          for (final stage in widget.entry.content.whereType<Map>())
            _stagePreview(stage),
        ],
      ),
    ),
  );
}

class _RootCauseActions extends StatelessWidget {
  const _RootCauseActions({
    required this.expanded,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null || onDelete != null)
          SizedBox(
            width: 32,
            height: 32,
            child: ItemActionMenu(onEdit: onEdit, onDelete: onDelete),
          ),
        if (onToggle != null)
          SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              tooltip: expanded ? 'Collapse root cause' : 'Expand root cause',
              onPressed: onToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              style: const ButtonStyle(),
              icon: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: _devGreen,
                size: 20,
              ),
            ),
          ),
      ],
    ),
  );
}

class _UploadedEvidenceVideo extends StatefulWidget {
  const _UploadedEvidenceVideo({required this.url});
  final String url;
  @override
  State<_UploadedEvidenceVideo> createState() => _UploadedEvidenceVideoState();
}

class _UploadedEvidenceVideoState extends State<_UploadedEvidenceVideo> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  late final Future<void> _ready = _controller.initialize();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return TextButton(
          onPressed: () => _openEvidenceUrl(context, widget.url),
          child: const Text('Open video'),
        );
      if (snapshot.connectionState != ConnectionState.done)
        return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        );
      return Column(
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          VideoProgressIndicator(_controller, allowScrubbing: true),
          IconButton(
            tooltip: _controller.value.isPlaying ? 'Pause video' : 'Play video',
            onPressed: () => setState(() {
              _controller.value.isPlaying
                  ? _controller.pause()
                  : _controller.play();
            }),
            icon: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: _devGreen,
            ),
          ),
        ],
      );
    },
  );
}

class _PreviewEditButton extends StatelessWidget {
  const _PreviewEditButton({required this.entry});
  final JournalEntry entry;
  @override
  Widget build(BuildContext context) => JournalEntryMenu(entry: entry);
}

String? prototypingRefreshType(Widget page) =>
    page is _PrototypingJournalEntryPage ? page.type.value : null;
Widget restoreEmptyPrototypingPage(
  String projectId,
  ProjectsRepo repo,
  String? type,
) => _PrototypingJournalEntryPage(
  projectId: projectId,
  projectsRepo: repo,
  type: _PrototypeEntryType.parse(type) ?? _PrototypeEntryType.building,
);

String? journalRepoUserId(ProjectsRepo repo) {
  try {
    return repo.currentUserId;
  } catch (_) {
    return null;
  }
}

class _ParticipantManagementGate extends StatefulWidget {
  const _ParticipantManagementGate({
    required this.authorId,
    required this.child,
  });
  final String? authorId;
  final Widget child;
  @override
  State<_ParticipantManagementGate> createState() =>
      _ParticipantManagementGateState();
}

class _ParticipantManagementGateState
    extends State<_ParticipantManagementGate> {
  Future<bool>? _allowed;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.findAncestorWidgetOfExactType<ProjectActivityScope>();
    final user = scope == null ? null : journalRepoUserId(scope.repo);
    _allowed ??=
        scope == null ||
            user == null ||
            widget.authorId == null ||
            user == widget.authorId
        ? Future.value(true)
        : scope.repo
              .getProjectById(scope.projectId)
              .then((p) => p?.userId == user);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(ignoring: snapshot.data != true, child: widget.child),
        if (snapshot.data == false)
          const Text(
            'Only the entry author or project owner can change participants.',
            style: AppTypography.helper,
          ),
      ],
    ),
  );
}

List<Map<String, dynamic>> journalParticipantRows(
  Set<String> ids,
  List<UserProfile> members, {
  List<dynamic> previous = const [],
}) {
  final known = <String, Map<String, dynamic>>{};
  void walk(dynamic node) {
    if (node is Map) {
      for (final pair in node.entries) {
        if (pair.key == 'involved' && pair.value is List) {
          for (final person in (pair.value as List).whereType<Map>()) {
            final id = (person['id'] ?? person['user_id'])?.toString();
            if (id != null) known[id] = Map<String, dynamic>.from(person);
          }
        } else {
          walk(pair.value);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        walk(item);
      }
    }
  }

  walk(previous);
  for (final person in members) {
    known[person.id] = {
      'id': person.id,
      'name': person.resolvedDisplayName,
      'avatarUrl': person.avatarUrl,
    };
  }
  return [
    for (final id in ids.toList()..sort()) known[id] ?? {'id': id},
  ];
}
