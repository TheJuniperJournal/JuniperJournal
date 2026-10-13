import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
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

const _devGreen = Color(0xFF5DB075);
const _devText = Color(0xFF1C1C1C);
const _devBorder = Color(0xFFDED7D7);
const _ideaGreen = Color(0xFF5DB075);
const _ideaYellow = Color(0xFFF3AA15);
const _ideaRed = Color(0xFFE57373);
const _ideaBlue = Color(0xFF2C70BF);
const _ideaColors = [_ideaGreen, _ideaYellow, _ideaRed, _ideaBlue];

Color _ideaColor(int index) => _ideaColors[index.clamp(0, 3)];

String _formatIdeaScore(double? score) =>
    score == null ? '--' : score.toStringAsFixed(2);

Future<bool> _confirmPrototypeDelete(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
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
  if (normalized == 'discovery') return 'discover';
  if (normalized == 'discover') return 'discover';
  if (normalized == 'ideation') return 'ideating';
  if (normalized == 'ideating') return 'ideating';
  if (normalized == 'prototype') return 'prototyping';
  if (normalized == 'prototyping') return 'prototyping';
  if (normalized == 'implementation') return 'implementation';
  return normalized;
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
          left: 32,
          top: 194,
          width: 337,
          height: 108,
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
                        width: 18,
                        height: 22,
                        child: _JournalLineIcon(),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${summary.totalEntries}',
                        style: const TextStyle(
                          color: _devGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Total Entries',
                        style: TextStyle(fontSize: 12, color: _devText),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 58, color: const Color(0xFFE9E9E9)),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Last Updated',
                        style: TextStyle(
                          color: Color(0xFF838383),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        _lastUpdatedDay(summary.lastUpdated),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _lastUpdatedTime(summary.lastUpdated),
                        style: const TextStyle(
                          color: Color(0xFF838383),
                          fontSize: 10,
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
            left: 32,
            top: 340 + (i * 94),
            width: 337,
            height: 74,
            child: _PhaseCard(
              phaseNumber: i + 1,
              label: phaseLabels[i],
              count: summary.phaseCounts[phaseKeys[i]] ?? 0,
              onTap: () async {
                if (i == 0) {
                  await Navigator.of(context).push(
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
                  await Navigator.of(context).push(
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
                  await Navigator.of(context).push(
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
                  await Navigator.of(context).push(
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
    return GestureDetector(
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
                style: const TextStyle(color: _devGreen, fontSize: 15),
              ),
            ),
            const SizedBox(width: 17),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _devText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count ${count == 1 ? 'Entry' : 'Entries'}',
              style: const TextStyle(color: Colors.black87, fontSize: 12),
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
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImplementationEntryPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openEntry(JournalEntry entry) async {
    final submitted = _isSubmittedImplementationEntry(entry);
    await Navigator.of(context).push<void>(
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
    await widget.projectsRepo.deleteJournalEntry(entryId: entry.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeScaffold(
      title: 'Implementation',
      onBack: () => Navigator.of(context).pop(true),
      actionLabel: widget.isOwner ? '+ Journal Entry' : null,
      onAction: _addEntry,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
              children: [
                _PrototypeCountHeader(count: _entries.length, label: 'Entries'),
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
                          color: _devGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Implementation',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Implement your solution and document progress, outcomes, observations, and lessons learned throughout this phase.',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE5E5E5)),
                const SizedBox(height: 24),
                for (var i = 0; i < _entries.length; i++)
                  _ImplementationEntryCard(
                    entry: _entries[i],
                    ecoPoints: _ecoPointsByEntry[_entries[i].id] ?? 0,
                    onTap: () => _openEntry(_entries[i]),
                    onDelete: widget.isOwner
                        ? () => _deleteEntry(_entries[i])
                        : null,
                  ),
              ],
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
  });

  final JournalEntry entry;
  final double ecoPoints;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final date = entry.updatedAt ?? entry.createdAt;
    final imageUrl = _firstContentImageUrl(entry.content);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 28, height: 34, child: _JournalLineIcon()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? 'Implementation Entry' : entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2024),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _devGreen.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IMPLEMENTATION',
                          style: TextStyle(
                            color: _devGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${ecoPoints.toStringAsFixed(0)} EcoPoints',
                        style: const TextStyle(
                          color: Color(0xFF717171),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM d, yyyy').format(date.toLocal()),
                      style: const TextStyle(
                        color: Color(0xFFA1A1A1),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (imageUrl != null) ...[
              const SizedBox(width: 10),
              _EntryThumbnail(url: imageUrl),
            ],
            if (onDelete != null)
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: SvgPicture.asset(
                  'assets/prototyping/pagination_dots.svg',
                  width: 15,
                  height: 3,
                ),
                onSelected: (_) => onDelete!(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ImplementationStageTracker extends StatelessWidget {
  const _ImplementationStageTracker({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    Widget dot(int i) => Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i <= activeIndex ? _devGreen : Colors.white,
        border: Border.all(color: _devGreen),
      ),
    );
    Widget line(int i) => Expanded(
      child: Container(
        height: 1,
        color: i < activeIndex ? _devGreen : const Color(0xFFD9D9D9),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
      child: Column(
        children: [
          Row(
            children: [
              dot(0),
              line(0),
              dot(1),
              line(1),
              dot(2),
              line(2),
              dot(3),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in _implementationStageLabels)
                Text(
                  l,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImplementationHeader extends StatelessWidget {
  const _ImplementationHeader({
    required this.title,
    required this.onBack,
    required this.trailingLabel,
    required this.onTrailing,
  });

  final String title;
  final VoidCallback onBack;
  final String trailingLabel;
  final VoidCallback onTrailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, color: _devGreen, size: 32),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2024),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: onTrailing,
                child: Text(
                  trailingLabel,
                  style: const TextStyle(
                    color: _devGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _ImplementationEntryPageState extends State<ImplementationEntryPage> {
  var _stage = _ImplementationStage.overview;
  String? _entryId;
  bool _isSaving = false;
  bool _hasChanges = false;
  int _entryNumber = 1;

  final _summary = TextEditingController();
  final _location = TextEditingController();
  DateTime? _dateImplemented;
  final List<_EvidenceBlock> _evidence = [];

  final Set<String> _selectedDci = {};
  final Set<String> _selectedSep = {};
  final Set<String> _selectedCcc = {};
  InquiryLensData _inquiryLensData = const InquiryLensData();
  AssessmentBlockData _learningAssessment = const AssessmentBlockData();

  final _worked = TextEditingController();
  final _notWorked = TextEditingController();
  final _takeaways = TextEditingController();
  final _change = TextEditingController();

  @override
  void initState() {
    super.initState();
    _hydrate();
    _resolveEntryNumber();
  }

  @override
  void dispose() {
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
    if (entry == null) return;
    _entryId = entry.id;
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
        'stage': 'overview',
        'summary': _summary.text.trim(),
        'dateImplemented': _dateImplemented?.toIso8601String(),
        'location': _location.text.trim(),
        'evidence': _evidence.map((e) => e.toMap()).toList(),
      },
      const {'stage': 'assessment'},
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
        'submitted': submitted,
        if (submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
  }

  Future<bool> _save({bool submitted = false}) async {
    setState(() => _isSaving = true);
    final content = _buildContent(submitted: submitted);
    final title = 'Entry $_entryNumber: Implementation';
    var ok = false;
    if (_entryId == null) {
      final created = await widget.projectsRepo.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        content: content,
        progress: 'implementation',
      );
      _entryId = created?.id;
      ok = created != null;
    } else {
      ok = await widget.projectsRepo.updateJournalEntry(
        entryId: _entryId!,
        title: title,
        content: content,
        progress: 'implementation',
      );
    }
    if (!mounted) return ok;
    _hasChanges = _hasChanges || ok;
    setState(() => _isSaving = false);
    return ok;
  }

  Future<void> _next() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _ImplementationStage.values[_stage.index + 1]);
  }

  void _back() {
    if (_stage.index == 0) {
      Navigator.of(context).pop(_hasChanges);
      return;
    }
    setState(() => _stage = _ImplementationStage.values[_stage.index - 1]);
  }

  Future<void> _submit() async {
    final ok = await _save(submitted: true);
    if (!mounted || !ok) return;
    Navigator.of(context).pop(true);
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _addEvidence() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(context, type, null);
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _ImplementationHeader(
                  title: 'Entry $_entryNumber: Implementation',
                  onBack: _back,
                  trailingLabel: _isSaving ? 'Saving...' : 'Save',
                  onTrailing: () => _save(),
                ),
                _ImplementationStageTracker(activeIndex: _stage.index),
                Expanded(child: _buildStage()),
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
          onBack: _back,
          onNext: _next,
        );
      case _ImplementationStage.learning:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(31, 12, 31, 28),
          child: _LearningStageBody(
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 8, 44, 24),
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            color: _devGreen,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledBox(
          label: 'Summary',
          helperText: 'Describe what was implemented and who was involved.',
          controller: _summary,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        const Text(
          'Date Implemented',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              border: Border.all(color: _devGreen),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dateImplemented == null
                      ? 'mm/dd/yy'
                      : DateFormat('MM/dd/yy').format(_dateImplemented!),
                  style: TextStyle(
                    color: _dateImplemented == null
                        ? const Color(0xFF9A9A9A)
                        : const Color(0xFF1F2024),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SvgPicture.asset(
                  'assets/prototyping/chevron_down.svg',
                  width: 14,
                  height: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Location',
          optional: true,
          controller: _location,
          height: 36,
        ),
        const SizedBox(height: 22),
        const Text(
          'Evidence',
          style: TextStyle(
            color: _devGreen,
            fontSize: 24,
            fontWeight: FontWeight.w700,
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
            ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
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
                  color: _devGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: _SmallStageButton(label: 'Next', filled: true, onTap: _next),
        ),
      ],
    );
  }

  Widget _reflectionBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(44, 8, 44, 24),
      children: [
        const Text(
          'Reflection',
          style: TextStyle(
            color: _devGreen,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledBox(
          label: 'What worked well?',
          controller: _worked,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: "What didn't work well?",
          controller: _notWorked,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Key Takeaways',
          helperText: 'Describe the key learnings from the project.',
          controller: _takeaways,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'What would you change?',
          controller: _change,
          maxLines: 4,
        ),
        const SizedBox(height: 28),
        Center(
          child: _SmallStageButton(
            label: 'Submit',
            filled: true,
            onTap: _submit,
          ),
        ),
      ],
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
  });

  final String projectId;
  final String projectName;
  final String? entryId;
  final ProjectsRepo projectsRepo;
  final bool readOnly;
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
          .toList();
      _loading = false;
    });
  }

  double get _total => _impacts.fold(0.0, (sum, e) => sum + e.ecoPoints);

  Future<void> _addImpact() async {
    if (widget.entryId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImpactEntryFormScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          initialTitle: 'Impact ${_impacts.length + 1}',
          lockedJournalEntryId: widget.entryId,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(34, 8, 34, 24),
      children: [
        const Text(
          'Impact',
          style: TextStyle(
            color: _devGreen,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              widget.readOnly
                  ? 'Impacts (${_impacts.length})'
                  : 'Your Impacts (${_impacts.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (!widget.readOnly)
              GestureDetector(
                onTap: _addImpact,
                child: const Text(
                  '+ Add Impact',
                  style: TextStyle(
                    color: _devGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final impact in _impacts)
          _ImplementationImpactCard(
            impact: impact,
            onDelete: widget.readOnly ? null : () => _deleteImpact(impact),
          ),
        const SizedBox(height: 16),
        const Text(
          'Total Impact',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _ImplementationTotalCard(impacts: _impacts, total: _total),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: widget.onBack),
            const SizedBox(width: 12),
            _SmallStageButton(
              label: 'Next',
              filled: true,
              onTap: widget.onNext,
            ),
          ],
        ),
      ],
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

class _ImplementationImpactCard extends StatelessWidget {
  const _ImplementationImpactCard({required this.impact, this.onDelete});

  final ImpactEntry impact;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scaleName = impact.impactScale.split(' (').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
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
                  color: _devGreen.withValues(alpha: 0.1),
                ),
                child: Image.asset(
                  _implementationMetricIcon(impact.metric),
                  width: 26,
                  height: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  impact.metric,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
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
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
              if (onDelete != null)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, size: 18),
                  onSelected: (_) => onDelete!(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Measurement',
                    value: impact.measurementDisplay,
                  ),
                ),
                Expanded(
                  child: _ImplementationImpactField(
                    label: 'Impact Scale',
                    value: scaleName,
                    valueColor: _devGreen,
                  ),
                ),
                _ImplementationEcoCircle(ecoPoints: impact.ecoPoints),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE5E5E5)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ImplementationImpactField(
                  label: 'Evidence Type',
                  value: impact.evidenceType,
                ),
              ),
              Expanded(
                child: _ImplementationImpactField(
                  label: 'Confidence',
                  value: impact.confidenceScore,
                ),
              ),
            ],
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
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF838383), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1F2024),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ImplementationEcoCircle extends StatelessWidget {
  const _ImplementationEcoCircle({required this.ecoPoints});

  final double ecoPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E5E5), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ecoPoints.toStringAsFixed(0),
            style: const TextStyle(
              color: _devGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'EcoPoints',
            style: TextStyle(color: _devGreen, fontSize: 10),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (final impact in impacts) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    impact.metric,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                Text(
                  '${impact.ecoPoints.toStringAsFixed(0)} EcoPoints',
                  style: const TextStyle(
                    color: _devGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFE5E5E5)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: _devGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${total.toStringAsFixed(0)} EcoPoints',
                style: const TextStyle(
                  color: _devGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
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

  void _next() => setState(() => _stage = (_stage + 1).clamp(0, 3));
  void _prev() => setState(() => _stage = (_stage - 1).clamp(0, 3));
  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _ImplementationHeader(
                  title: widget.entry.title.isEmpty
                      ? 'Implementation'
                      : widget.entry.title,
                  onBack: _exit,
                  trailingLabel: 'Exit',
                  onTrailing: _exit,
                ),
                _ImplementationStageTracker(activeIndex: _stage),
                Expanded(child: _body()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navRow({required bool showBack, required bool finish}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showBack) ...[
          _SmallStageButton(label: 'Back', onTap: _prev),
          const SizedBox(width: 12),
        ],
        _SmallStageButton(
          label: finish ? 'Finish' : 'Next',
          filled: true,
          onTap: finish ? _exit : _next,
        ),
      ],
    );
  }

  Widget _body() {
    switch (_stage) {
      case 1:
        return Column(
          children: [
            Expanded(
              child: _ImplementationAssessmentBody(
                projectId: widget.projectId,
                projectName: widget.entry.title,
                entryId: widget.entry.id,
                projectsRepo: widget.projectsRepo,
                readOnly: true,
                onBack: _prev,
                onNext: _next,
              ),
            ),
          ],
        );
      case 2:
        return ListView(
          padding: const EdgeInsets.fromLTRB(31, 12, 31, 28),
          children: [
            _LearningPreviewContent(
              selectedDci: _dci,
              selectedSep: _sep,
              selectedCcc: _ccc,
              inquiryLensData: _lens,
              assessment: _assessment,
            ),
            const SizedBox(height: 24),
            _navRow(showBack: true, finish: false),
          ],
        );
      case 3:
        return ListView(
          padding: const EdgeInsets.fromLTRB(44, 8, 44, 24),
          children: [
            const Text(
              'Reflection',
              style: TextStyle(
                color: _devGreen,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _ImplPreviewSection(label: 'What worked well?', body: _worked),
            _ImplPreviewSection(
              label: "What didn't work well?",
              body: _notWorked,
            ),
            _ImplPreviewSection(label: 'Key Takeaways', body: _takeaways),
            _ImplPreviewSection(label: 'What would you change?', body: _change),
            const SizedBox(height: 20),
            _navRow(showBack: true, finish: true),
          ],
        );
      default:
        return ListView(
          padding: const EdgeInsets.fromLTRB(44, 8, 44, 24),
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                color: _devGreen,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImplPreviewSection(label: 'Summary', body: _summary),
                  if (_date != null)
                    _ImplPreviewSection(
                      label: 'Date',
                      body: DateFormat('MMMM d, yyyy').format(_date!.toLocal()),
                    ),
                  if (_location.isNotEmpty)
                    _ImplPreviewSection(label: 'Location', body: _location),
                  if (_evidence.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE5E5E5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Evidence',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final block in _evidence)
                      _EvidencePreviewBlock(evidence: block),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _navRow(showBack: false, finish: false),
          ],
        );
    }
  }
}

class _ImplPreviewSection extends StatelessWidget {
  const _ImplPreviewSection({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body.isEmpty ? 'Not provided.' : body,
            style: TextStyle(
              color: body.isEmpty
                  ? const Color(0xFFB0B0B0)
                  : const Color(0xFF838383),
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
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
            constraints: const BoxConstraints(maxWidth: 444),
            child: Stack(
              children: [
                Positioned(
                  left: 35,
                  top: 38,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: _devGreen,
                      size: 34,
                    ),
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
                      color: Color(0xFF1F2024),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                        color: _devGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiscoveryObservationEntryPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _editEntry(JournalEntry entry) async {
    final changed = await Navigator.of(context).push<bool>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: Stack(
              children: [
                Positioned(
                  left: 35,
                  top: 38,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: _devGreen,
                      size: 34,
                    ),
                  ),
                ),
                const Positioned(
                  left: 123,
                  right: 123,
                  top: 77,
                  child: Text(
                    'Discovery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF1F2024),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 104,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: _CollectionIcon(),
                      ),
                      Text(
                        '${_entries.length}',
                        style: const TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Entries',
                        style: TextStyle(
                          color: Color(0xFFA1A1A1),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 41,
                  top: 188,
                  width: 361,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    decoration: BoxDecoration(
                      color: _devGreen.withValues(alpha: .2),
                      border: Border.all(color: _devGreen),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phase 1 of 4',
                          style: TextStyle(
                            color: _devGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Discovery',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Explore the problem through research, observations, and stakeholder engagement. Document key insights that will guide your project.',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 53,
                  top: 356,
                  width: 338,
                  child: Divider(color: Color(0xFFE5E5E5)),
                ),
                Positioned(
                  left: 51,
                  right: 40,
                  top: 391,
                  bottom: 90,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            for (final entry in _entries)
                              _DiscoveryEntryCard(
                                entry: entry,
                                onTap: () => _editEntry(entry),
                              ),
                          ],
                        ),
                ),
                if (widget.isOwner)
                  Positioned(
                    left: 107,
                    bottom: 44,
                    width: 242,
                    height: 33,
                    child: GestureDetector(
                      onTap: _openEntry,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: _devGreen),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '+ Journal Entry',
                          style: TextStyle(
                            color: _devGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

/// Walks a journal entry's content JSON for the first image the user added
/// (from an "Images" evidence block). Returns null when there is none.
String? _firstContentImageUrl(List<dynamic> content) {
  String? found;
  void walk(dynamic node) {
    if (found != null) return;
    if (node is Map) {
      if (node['type'] == 'Images' && node['data'] is Map) {
        final imgs = (node['data'] as Map)['images'];
        if (imgs is List) {
          for (final im in imgs) {
            if (im is Map) {
              final url =
                  (im['public_url'] ?? im['publicUrl'])?.toString() ?? '';
              if (url.isNotEmpty) {
                found = url;
                return;
              }
            }
          }
        }
      }
      for (final v in node.values) {
        walk(v);
        if (found != null) return;
      }
    } else if (node is List) {
      for (final v in node) {
        walk(v);
        if (found != null) return;
      }
    }
  }

  for (final item in content) {
    walk(item);
    if (found != null) break;
  }
  return found;
}

String? _firstImageInEvidence(List<_EvidenceBlock> evidence) {
  for (final block in evidence) {
    if (block.type != 'Images') continue;
    final imgs = block.data['images'];
    if (imgs is List) {
      for (final im in imgs) {
        if (im is Map) {
          final url = (im['public_url'] ?? im['publicUrl'])?.toString() ?? '';
          if (url.isNotEmpty) return url;
        }
      }
    }
  }
  return null;
}

/// First image across all of an iteration's components (build + test evidence).
String? _firstPrototypeIterationImageUrl(_PrototypeIterationDraft iteration) {
  for (final component in iteration.components) {
    for (final log in component.buildLogs) {
      final url = _firstImageInEvidence(log.evidence);
      if (url != null) return url;
    }
    for (final test in component.testEntries) {
      final url = _firstImageInEvidence(test.evidence);
      if (url != null) return url;
    }
  }
  return null;
}

/// Small rounded thumbnail of a user-added image, shown on phase entry cards.
class _EntryThumbnail extends StatelessWidget {
  const _EntryThumbnail({required this.url, this.size = 44});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: const Color(0xFFEFEFEF),
        ),
      ),
    );
  }
}

class _DiscoveryEntryCard extends StatelessWidget {
  const _DiscoveryEntryCard({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstContentImageUrl(entry.content);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 122,
        margin: const EdgeInsets.only(bottom: 31),
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 34,
                  child: _JournalLineIcon(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        '0 EcoPoints',
                        style: TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 120,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _devGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DISCOVERY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(width: 8),
                  _EntryThumbnail(url: imageUrl),
                ],
              ],
            ),
            const Spacer(),
            Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  entry.createdAt == null
                      ? ''
                      : DateFormat('EEEE, MMM d').format(entry.createdAt!),
                  style: const TextStyle(
                    color: Color(0xFFA1A1A1),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.more_horiz,
                  color: Color(0xFF717171),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
    if (entry != null && _isSubmittedIdeatingEntry(entry)) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => IdeatingEntryPreviewPage(entry: entry),
        ),
      );
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
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

  @override
  Widget build(BuildContext context) {
    return _PhaseDashboardScaffold(
      title: 'Ideating',
      phaseNumber: 2,
      description:
          'Generate possible solutions, compare them with a decision matrix, and choose the strongest direction for your project.',
      entries: _entries,
      isLoading: _isLoading,
      isOwner: widget.isOwner,
      badgeLabel: 'IDEATING',
      onBack: () => Navigator.of(context).pop(true),
      onAddEntry: () => _openEntry(),
      onOpenEntry: _openEntry,
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
  JournalEntry? _entry;
  final List<_PrototypeIterationDraft> _iterations = [];
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
    final prototypingEntries = (entries ?? [])
        .where((entry) => normalizePhase(entry.progress) == 'prototyping')
        .toList();
    final entry = prototypingEntries.isEmpty ? null : prototypingEntries.first;
    final iterations = entry == null
        ? <_PrototypeIterationDraft>[]
        : _prototypeIterationsFromEntry(entry);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _iterations
        ..clear()
        ..addAll(iterations);
      _isLoading = false;
    });
  }

  Future<void> _persist() async {
    final content = [
      {
        'stage': 'prototyping',
        'iterations': _iterations.map((item) => item.toMap()).toList(),
      },
    ];
    final title = _iterations.isEmpty
        ? 'Entry: Prototyping'
        : 'Entry: ${_iterations.first.title}';
    if (_entry == null) {
      final created = await widget.projectsRepo.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        content: content,
        progress: 'prototyping',
      );
      if (created != null) _entry = created;
    } else {
      await widget.projectsRepo.updateJournalEntry(
        entryId: _entry!.id,
        title: title,
        content: content,
        progress: 'prototyping',
      );
    }
  }

  Future<void> _addIteration() async {
    final iteration = await Navigator.of(context)
        .push<_PrototypeIterationDraft>(
          MaterialPageRoute(
            builder: (_) => const _PrototypeIterationEditorPage(),
          ),
        );
    if (iteration == null || !mounted) return;
    setState(() => _iterations.add(iteration));
    await _persist();
  }

  Future<void> _openIteration(int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PrototypeComponentsPage(
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          iteration: _iterations[index],
          iterationIndex: index,
          onChanged: () {
            if (!mounted) return;
            setState(() {});
            _persist();
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    await _persist();
  }

  Future<void> _deleteIteration(int index) async {
    final ok = await _confirmPrototypeDelete(
      context,
      title: 'Delete Iteration',
      message: 'Delete this iteration and its components?',
      action: 'Delete Iteration',
    );
    if (!ok || !mounted) return;
    setState(() => _iterations.removeAt(index));
    await _persist();
  }

  void _moveIteration(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _iterations.length) return;
    setState(() {
      final item = _iterations.removeAt(index);
      _iterations.insert(target, item);
    });
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypingIterationsScreen(
      iterations: _iterations,
      isLoading: _isLoading,
      onBack: () => Navigator.of(context).pop(true),
      onAddIteration: _addIteration,
      onOpenIteration: _openIteration,
      onDeleteIteration: _deleteIteration,
      onMoveIteration: _moveIteration,
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
    this.actionLabel,
    this.onAction,
  });

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
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _PrototypeTopBar(title: title, onBack: onBack),
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
  const _PrototypeTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 40),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset('assets/prototyping/nav_back.svg'),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 72),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2024),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: _devGreen),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _devGreen,
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
            color: Color(0xFF1F2024),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFA1A1A1), fontSize: 12),
        ),
      ],
    );
  }
}

class _PrototypingIterationsScreen extends StatelessWidget {
  const _PrototypingIterationsScreen({
    required this.iterations,
    required this.isLoading,
    required this.onBack,
    required this.onAddIteration,
    required this.onOpenIteration,
    required this.onDeleteIteration,
    this.onMoveIteration,
  });

  final List<_PrototypeIterationDraft> iterations;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onAddIteration;
  final ValueChanged<int> onOpenIteration;
  final ValueChanged<int> onDeleteIteration;
  final void Function(int index, int delta)? onMoveIteration;

  @override
  Widget build(BuildContext context) {
    return _PrototypeScaffold(
      title: 'Prototyping',
      onBack: onBack,
      actionLabel: '+ Iteration',
      onAction: onAddIteration,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
              children: [
                _PrototypeCountHeader(
                  count: iterations.length,
                  label: 'Iterations',
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
                        'Phase 3 of 4',
                        style: TextStyle(
                          color: _devGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Prototyping',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Transform ideas into sketches, models, or early prototypes. Capture design decisions, experiments, and refinements as your solution develops.',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFE5E5E5)),
                const SizedBox(height: 24),
                for (var i = 0; i < iterations.length; i++)
                  _PrototypeIterationCard(
                    iteration: iterations[i],
                    index: i,
                    onTap: () => onOpenIteration(i),
                    onDelete: () => onDeleteIteration(i),
                    onMoveUp: (onMoveIteration != null && i > 0)
                        ? () => onMoveIteration!(i, -1)
                        : null,
                    onMoveDown:
                        (onMoveIteration != null && i < iterations.length - 1)
                        ? () => onMoveIteration!(i, 1)
                        : null,
                  ),
              ],
            ),
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
  });

  final String title;
  final int phaseNumber;
  final String description;
  final List<JournalEntry> entries;
  final bool isLoading;
  final bool isOwner;
  final String badgeLabel;
  final VoidCallback onBack;
  final VoidCallback onAddEntry;
  final ValueChanged<JournalEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: Stack(
              children: [
                Positioned(
                  left: 35,
                  top: 38,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: _devGreen,
                      size: 34,
                    ),
                  ),
                ),
                Positioned(
                  left: 123,
                  right: 123,
                  top: 77,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F2024),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 104,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: _CollectionIcon(),
                      ),
                      Text(
                        '${entries.length}',
                        style: const TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Entries',
                        style: TextStyle(
                          color: Color(0xFFA1A1A1),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 41,
                  top: 188,
                  width: 361,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
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
                            color: _devGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  left: 53,
                  top: 356,
                  width: 338,
                  child: Divider(color: Color(0xFFE5E5E5)),
                ),
                Positioned(
                  left: 51,
                  right: 40,
                  top: 391,
                  bottom: 90,
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            for (final entry in entries)
                              _DevelopmentEntryCard(
                                entry: entry,
                                badgeLabel: badgeLabel,
                                onTap: () => onOpenEntry(entry),
                              ),
                          ],
                        ),
                ),
                if (isOwner)
                  Positioned(
                    left: 107,
                    bottom: 44,
                    width: 242,
                    height: 33,
                    child: GestureDetector(
                      onTap: onAddEntry,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: _devGreen),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '+ Journal Entry',
                          style: TextStyle(
                            color: _devGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

class _DevelopmentEntryCard extends StatelessWidget {
  const _DevelopmentEntryCard({
    required this.entry,
    required this.badgeLabel,
    required this.onTap,
  });

  final JournalEntry entry;
  final String badgeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstContentImageUrl(entry.content);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 122,
        margin: const EdgeInsets.only(bottom: 31),
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 34,
                  child: _JournalLineIcon(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        '0 EcoPoints',
                        style: TextStyle(
                          color: Color(0xFF1F2024),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 120,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _devGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(width: 8),
                  _EntryThumbnail(url: imageUrl),
                ],
              ],
            ),
            const Spacer(),
            Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  entry.createdAt == null
                      ? ''
                      : DateFormat('EEEE, MMM d').format(entry.createdAt!),
                  style: const TextStyle(
                    color: Color(0xFFA1A1A1),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.more_horiz,
                  color: Color(0xFF717171),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

class _IdeatingEntryPageState extends State<IdeatingEntryPage> {
  final _challengeTitle = TextEditingController();
  final _challengeProblem = TextEditingController();
  final _nextLearned = TextEditingController();
  final _nextChallenges = TextEditingController();
  final _nextSteps = TextEditingController();
  final _nextNotes = TextEditingController();
  final _usersRepo = UsersRepo();
  final _storage = StorageService();
  final List<UserProfile> _members = [];
  final Set<String> _involvedIds = {};
  final List<_IdeatingObjectiveDraft> _objectives = [
    _IdeatingObjectiveDraft.empty(),
  ];
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

  @override
  void initState() {
    super.initState();
    _hydrateEntry();
    _loadMembers();
  }

  void _hydrateEntry() {
    final entry = widget.entry;
    if (entry == null) return;
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
            .where((item) => item.hasContent),
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
      ..addAll(next.isEmpty ? [_IdeatingObjectiveDraft.empty()] : next);
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
    final current = await _usersRepo.getCurrentUserProfile();
    final collaborators = await widget.projectsRepo.getProjectCollaborators(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      if (current != null) {
        _members.add(current);
        _involvedIds.add(current.id);
      } else {
        final user = AuthService.instance.currentUser;
        if (user != null) {
          _members.add(UserProfile(id: user.id, username: user.email));
          _involvedIds.add(user.id);
        }
      }
      _members.addAll(collaborators.where((m) => !_involvedIds.contains(m.id)));
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

  Future<bool> _save() async {
    setState(() => _isSaving = true);
    final involved = _members
        .where((member) => _involvedIds.contains(member.id))
        .map((member) => {'id': member.id, 'name': member.resolvedDisplayName})
        .toList();
    final title = _challengeTitle.text.trim().isEmpty
        ? 'Entry: Ideation'
        : 'Entry: ${_challengeTitle.text.trim().split(RegExp(r'\s+')).take(3).join(' ')}';
    final content = [
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
        'linkedTimelineEventId': _linkedTimelineEvent?['id'],
        'linkedTimelineEvent': _linkedTimelineEvent,
        'submitted': _submitted,
        if (_submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    var ok = false;
    if (_entryId == null) {
      final entry = await widget.projectsRepo.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        progress: 'ideating',
        content: content,
      );
      _entryId = entry?.id;
      ok = entry != null;
    } else {
      ok = await widget.projectsRepo.updateJournalEntry(
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
    if (_stage == _IdeatingStage.decisionMatrix &&
        next == _IdeatingStage.learning &&
        !_matrixComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _matrixWeightTotal(_criteria) == 100
                ? 'Enter a 1-5 rating for every idea and criterion.'
                : 'Criterion weights must total 100% before continuing.',
          ),
        ),
      );
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
    if (_objectives.length == 1) return;
    setState(() => _objectives.removeAt(index).dispose());
  }

  void _reorderObjective(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _objectives.removeAt(oldIndex);
      _objectives.insert(newIndex, item);
    });
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
        bucketName: 'images',
        folder: 'journal-attachments/${widget.projectId}',
      );
      if (!mounted) return;
      setState(
        () => _supportingContext = _SupportingContextFile.fromUpload(uploaded),
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
    final result = await Navigator.of(context).push<_IdeatingIdeaDraft>(
      MaterialPageRoute(
        builder: (_) => _IdeaEditorPage(
          entryId: _entryId ?? widget.projectId,
          initial: idea,
          onOpenEvidencePicker: _openIdeaEvidencePicker,
          onOpenEvidenceEditor: _openIdeaEvidenceEditor,
        ),
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EvidenceBlockPicker(),
    );
  }

  Future<_EvidenceBlock?> _openIdeaEvidenceEditor(
    BuildContext context,
    String type,
    _EvidenceBlock? existing,
  ) async {
    if (type == 'Images') {
      final result = await Navigator.of(context).push<ImageBlockData>(
        MaterialPageRoute(
          builder: (_) => ImageBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.imageData,
            showAssessment: false,
            showInquiryLens: false,
          ),
        ),
      );
      return result == null ? null : _EvidenceBlock.images(result);
    }
    if (type == 'Sketch') {
      final result = await Navigator.of(context).push<SketchBlockData>(
        MaterialPageRoute(
          builder: (_) => SketchBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.sketchData,
          ),
        ),
      );
      return result == null ? null : _EvidenceBlock.sketch(result);
    }
    if (type == 'Link') {
      final result = await Navigator.of(context).push<LinkBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              LinkBlockEditorScreen(initialData: existing?.linkData),
        ),
      );
      return result == null ? null : _EvidenceBlock.link(result);
    }
    if (type == 'Video') {
      final result = await Navigator.of(context).push<VideoBlockData>(
        MaterialPageRoute(
          builder: (_) => VideoBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.videoData,
          ),
        ),
      );
      return result == null ? null : _EvidenceBlock.video(result);
    }
    if (type == 'Graph') {
      final result = await Navigator.of(context).push<GraphBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              GraphBlockEditorScreen(initialData: existing?.graphData),
        ),
      );
      return result == null ? null : _EvidenceBlock.graph(result);
    }
    if (type == 'Table') {
      final result = await Navigator.of(context).push<TableBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              TableBlockEditorScreen(initialData: existing?.tableData),
        ),
      );
      return result == null ? null : _EvidenceBlock.table(result);
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

  void _addCriterion() {
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

  Future<void> _createTimelineEvent() async {
    if (_entryId == null) {
      final saved = await _save();
      if (!mounted || !saved) return;
    }
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDiscoveryTimelineEventSheet(
        members: _members,
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
    setState(() => _linkedTimelineEvent = event);
    await _save();
  }

  Future<void> _linkExistingTimelineEvent() async {
    final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
    if (!mounted) return;
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExistingTimelineEventSheet(events: timeline ?? const []),
    );
    if (event == null || !mounted) return;
    setState(() => _linkedTimelineEvent = event);
    await _save();
  }

  void _unlinkTimelineEvent() {
    setState(() => _linkedTimelineEvent = null);
  }

  Future<void> _submit() async {
    _submitted = true;
    final ok = await _save();
    if (!mounted || !ok) return;
    final navigator = Navigator.of(context);
    navigator.pop(true);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scores = _ideaScores();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(43, 31, 50, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_hasSavedChanges),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          top: 33,
                          child: Text(
                            'Entry: Ideation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: 39,
                          child: GestureDetector(
                            onTap: _isSaving ? null : () => _save(),
                            child: Text(
                              _isSaving ? 'Saving...' : 'Save',
                              style: const TextStyle(
                                color: _devGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StageHeader(
                    activeIndex: _stage.index,
                    labels: const [
                      'Challenge',
                      'Ideas',
                      'Decision Matrix',
                      'Learning',
                      'Next Action',
                    ],
                  ),
                  const SizedBox(height: 30),
                  switch (_stage) {
                    _IdeatingStage.challenge => _IdeatingChallengeBody(
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
                      onReorderObjective: _reorderObjective,
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
                    _IdeatingStage.learning => _LearningStageBody(
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
                      onLinkExistingTimelineEvent: _linkExistingTimelineEvent,
                      onCreateTimelineEvent: _createTimelineEvent,
                      onUnlinkTimelineEvent: _unlinkTimelineEvent,
                      onBack: () =>
                          setState(() => _stage = _IdeatingStage.learning),
                      onSubmit: _submit,
                    ),
                  },
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
    required this.problem,
    required this.objectives,
    required this.supportingContext,
    required this.members,
    required this.involvedIds,
    required this.isSaving,
    required this.isUploadingContext,
    required this.onAddObjective,
    required this.onRemoveObjective,
    required this.onReorderObjective,
    required this.onAddSupportingContext,
    required this.onRemoveSupportingContext,
    required this.onToggleMember,
    required this.onNext,
  });

  final TextEditingController title;
  final TextEditingController problem;
  final List<_IdeatingObjectiveDraft> objectives;
  final _SupportingContextFile? supportingContext;
  final List<UserProfile> members;
  final Set<String> involvedIds;
  final bool isSaving;
  final bool isUploadingContext;
  final VoidCallback onAddObjective;
  final ValueChanged<int> onRemoveObjective;
  final void Function(int oldIndex, int newIndex) onReorderObjective;
  final VoidCallback onAddSupportingContext;
  final VoidCallback onRemoveSupportingContext;
  final ValueChanged<String> onToggleMember;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Challenge',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Set up the context for this ideation session.',
          style: TextStyle(
            color: Color(0xFF838383),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        _LabeledBox(label: 'Challenge Title', controller: title, height: 36),
        const SizedBox(height: 28),
        _LabeledBox(
          label: 'What Challenge are we trying to solve?',
          controller: problem,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        Text(
          'Objectives for the Design (${objectives.length}/4)',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'What do we hope to achieve with this designs or ideas?',
          style: TextStyle(
            color: Color(0xFF838383),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _ObjectivesList(
          objectives: objectives,
          onReorder: onReorderObjective,
          onRemove: onRemoveObjective,
        ),
        if (objectives.length < 4) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAddObjective,
            child: const Text(
              '+ Add Objective',
              style: TextStyle(
                color: _devGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        const Text.rich(
          TextSpan(
            text: 'Supporting Context ',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: '(optional)',
                style: TextStyle(color: Color(0xFF838383)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (supportingContext != null)
          _SupportingContextTile(
            file: supportingContext!,
            onRemove: onRemoveSupportingContext,
          ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: isUploadingContext ? null : onAddSupportingContext,
          child: Text(
            isUploadingContext ? 'Uploading...' : '+  Add File',
            style: const TextStyle(
              color: _devGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Who was Involved?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final member in members)
              _MemberChip(
                member: member,
                selected: involvedIds.contains(member.id),
                onTap: () => onToggleMember(member.id),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 11),
              child: Text(
                'Add People',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        Center(
          child: _SmallStageButton(
            label: isSaving ? 'Saving...' : 'Next',
            filled: true,
            onTap: isSaving ? null : onNext,
          ),
        ),
      ],
    );
  }
}

class _ObjectivesList extends StatelessWidget {
  const _ObjectivesList({
    required this.objectives,
    required this.onReorder,
    required this.onRemove,
  });

  final List<_IdeatingObjectiveDraft> objectives;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 346,
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
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: objectives.length,
        // ignore: deprecated_member_use
        onReorder: onReorder,
        itemBuilder: (context, index) {
          return _ObjectiveRow(
            key: ValueKey(objectives[index].id),
            objective: objectives[index],
            index: index,
            canRemove: objectives.length > 1,
            onRemove: () => onRemove(index),
          );
        },
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    super.key,
    required this.objective,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final _IdeatingObjectiveDraft objective;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 51,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: index == 3 ? Colors.transparent : Colors.black,
            width: .7,
          ),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const SizedBox(
              width: 42,
              child: Icon(Icons.drag_indicator, color: Color(0xFFC8C8C8)),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _devGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: objective.text,
              maxLength: 100,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                hintText: 'We want to create a solution that...',
                hintStyle: TextStyle(
                  color: Color(0xFF838383),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: objective.text,
            builder: (_, __) => Text(
              '${objective.text.text.length}/100',
              style: const TextStyle(color: Colors.black, fontSize: 8),
            ),
          ),
          if (canRemove)
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFD12E2E)),
              iconSize: 18,
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ideas',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add up to four ideas to compare.',
          style: TextStyle(color: Color(0xFF838383), fontSize: 12),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < ideas.length; i++)
          _IdeaSummaryCard(
            idea: ideas[i],
            score: hasScoredMatrix ? scores[ideas[i].id] : null,
            color: _ideaColor(i),
            onTap: () => onEditIdea(ideas[i]),
            onDelete: () => onDeleteIdea(i),
          ),
        GestureDetector(
          onTap: onAddIdea,
          child: Container(
            width: 367,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: onAddIdea == null ? const Color(0xFFD9D9D9) : _devGreen,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+ Add Idea',
              style: TextStyle(
                color: onAddIdea == null ? const Color(0xFF838383) : _devGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Next',
              filled: true,
              onTap: isSaving ? null : onNext,
            ),
          ],
        ),
      ],
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 367,
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
              child: Icon(Icons.lightbulb_outline, color: color),
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
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Idea Score: ${_formatIdeaScore(score)}',
                    style: TextStyle(
                      color: score == null ? const Color(0xFF838383) : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Color(0xFFD12E2E)),
                  ),
                ),
              ],
              child: const Icon(Icons.more_horiz, color: Color(0xFF717171)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionMatrixBody extends StatelessWidget {
  const _DecisionMatrixBody({
    required this.ideas,
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
  final VoidCallback onChanged;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final columnWidth = ideas.isEmpty ? 82.0 : 78.0;
    final totalWeight = _matrixWeightTotal(criteria);
    final complete = _isMatrixComplete(ideas, criteria);
    final totalColor = totalWeight == 100
        ? _devGreen
        : totalWeight > 100
        ? const Color(0xFFD12E2E)
        : const Color(0xFFF3AA15);
    final totalHint = totalWeight == 100
        ? 'Ready'
        : totalWeight > 100
        ? 'Reduce by ${totalWeight - 100}%'
        : '${100 - totalWeight}% more required';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Decision Matrix',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Score each idea from 1-5 for every weighted criterion.',
          style: TextStyle(color: Color(0xFF838383), fontSize: 12),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              'Total Weight: $totalWeight%',
              style: TextStyle(
                color: totalColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              totalHint,
              style: TextStyle(
                color: totalColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 154,
                      height: 62,
                      child: _MatrixHeader('Criteria'),
                    ),
                    for (var i = 0; i < ideas.length; i++)
                      Container(
                        width: columnWidth,
                        height: 62,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _ideaColor(i).withValues(alpha: .14),
                          border: const Border(
                            left: BorderSide(color: Color(0xFFE5E5E5)),
                          ),
                        ),
                        child: _MatrixHeader(
                          ideas[i].title.text.trim().isEmpty
                              ? 'Idea ${i + 1}'
                              : ideas[i].title.text.trim(),
                          color: _ideaColor(i),
                        ),
                      ),
                    const SizedBox(width: 34),
                  ],
                ),
                for (var i = 0; i < criteria.length; i++)
                  _DecisionCriterionRow(
                    criterion: criteria[i],
                    ideas: ideas,
                    canRemove: criteria.length > 1,
                    onRemove: () => onRemoveRow(i),
                    columnWidth: columnWidth,
                    onChanged: onChanged,
                  ),
                Row(
                  children: [
                    const SizedBox(
                      width: 154,
                      height: 52,
                      child: _MatrixHeader('Total Score'),
                    ),
                    for (var i = 0; i < ideas.length; i++)
                      Container(
                        width: columnWidth,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Color(0xFFE5E5E5)),
                            top: BorderSide(color: Color(0xFFE5E5E5)),
                          ),
                        ),
                        child: Text(
                          complete
                              ? _formatIdeaScore(scores[ideas[i].id])
                              : '--',
                          style: TextStyle(
                            color: complete
                                ? _ideaColor(i)
                                : const Color(0xFF838383),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onAddRow,
          child: const Text(
            '+ Add Row',
            style: TextStyle(
              color: _devGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Next',
              filled: true,
              onTap: isSaving || !complete ? null : onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader(this.label, {this.color = Colors.black});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    );
  }
}

class _DecisionCriterionRow extends StatelessWidget {
  const _DecisionCriterionRow({
    required this.criterion,
    required this.ideas,
    required this.canRemove,
    required this.onRemove,
    required this.columnWidth,
    required this.onChanged,
  });

  final _DecisionCriterionDraft criterion;
  final List<_IdeatingIdeaDraft> ideas;
  final bool canRemove;
  final VoidCallback onRemove;
  final double columnWidth;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 154,
            height: 104,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: criterion.name,
                      onChanged: (_) => onChanged(),
                      decoration: _matrixDecoration('Criterion'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: criterion.weight,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final weight = int.tryParse(value);
                        if (weight != null && weight < 0) {
                          criterion.weight.text = '0';
                          criterion.weight.selection =
                              TextSelection.fromPosition(
                                const TextPosition(offset: 1),
                              );
                        }
                        onChanged();
                      },
                      decoration: _matrixDecoration(
                        'Weight (%)',
                        suffixText: criterion.weight.text.trim().isEmpty
                            ? null
                            : '%',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < ideas.length; i++)
            Container(
              width: columnWidth,
              height: 104,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _ideaColor(i).withValues(alpha: .05),
                border: const Border(
                  left: BorderSide(color: Color(0xFFE5E5E5)),
                ),
              ),
              child: Center(
                child: TextField(
                  controller: criterion.controllerFor(ideas[i].id),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: _matrixDecoration('1-5'),
                  onChanged: (value) {
                    final rating = int.tryParse(value);
                    if (rating == null) {
                      onChanged();
                      return;
                    }
                    if (rating < 1 || rating > 5) {
                      criterion.controllerFor(ideas[i].id).text = rating < 1
                          ? '1'
                          : '5';
                      criterion
                          .controllerFor(ideas[i].id)
                          .selection = TextSelection.fromPosition(
                        TextPosition(
                          offset: criterion
                              .controllerFor(ideas[i].id)
                              .text
                              .length,
                        ),
                      );
                    }
                    onChanged();
                  },
                ),
              ),
            ),
          if (canRemove)
            SizedBox(
              width: 34,
              height: 104,
              child: Center(
                child: IconButton(
                  tooltip: 'Remove row',
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFD12E2E),
                  ),
                  iconSize: 18,
                ),
              ),
            ),
          if (!canRemove) const SizedBox(width: 34, height: 104),
        ],
      ),
    );
  }
}

InputDecoration _matrixDecoration(String hint, {String? suffixText}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF838383), fontSize: 10),
    suffixText: suffixText,
    suffixStyle: const TextStyle(color: _devText, fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _devGreen),
      borderRadius: BorderRadius.circular(6),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: _devGreen),
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

int _matrixWeightTotal(List<_DecisionCriterionDraft> criteria) {
  return criteria
      .where((item) => item.name.text.trim().isNotEmpty)
      .fold<int>(
        0,
        (sum, item) =>
            sum + (int.tryParse(item.weight.text.trim()) ?? 0).clamp(0, 1000),
      );
}

bool _isMatrixComplete(
  List<_IdeatingIdeaDraft> ideas,
  List<_DecisionCriterionDraft> criteria,
) {
  final activeCriteria = criteria
      .where((item) => item.name.text.trim().isNotEmpty)
      .toList();
  if (ideas.isEmpty || activeCriteria.isEmpty) return false;
  if (_matrixWeightTotal(criteria) != 100) return false;
  for (final criterion in activeCriteria) {
    final weight = int.tryParse(criterion.weight.text.trim());
    if (weight == null || weight < 0) return false;
    for (final idea in ideas) {
      if (criterion.ratingFor(idea.id) == null) return false;
    }
  }
  return true;
}

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(43, 31, 50, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          top: 33,
                          child: Text(
                            'Add Idea',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Idea',
                    style: TextStyle(
                      color: _devGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LabeledBox(
                    label: 'Idea Title',
                    controller: _idea.title,
                    height: 36,
                  ),
                  const SizedBox(height: 22),
                  _LabeledBox(
                    label: 'Describe the idea',
                    controller: _idea.description,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 22),
                  _LabeledBox(
                    label: 'Why might this work?',
                    controller: _idea.rationale,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Evidence',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
                      ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
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
                            color: _devGreen,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: _SmallStageButton(
                      label: 'Save',
                      filled: true,
                      onTap: () => Navigator.of(context).pop(_idea.clone()),
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
}

class _SupportingContextTile extends StatelessWidget {
  const _SupportingContextTile({required this.file, required this.onRemove});

  final _SupportingContextFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.delete_outline,
              size: 16,
              color: Colors.red,
            ),
          ),
        ],
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
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Supporting Context',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 18),
              _TimelineSheetField(label: 'File Name', controller: _name),
              const SizedBox(height: 14),
              _TimelineSheetField(
                label: 'Reference or URL',
                optional: true,
                controller: _reference,
              ),
              const SizedBox(height: 24),
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
    List<_EvidenceBlock>? evidence,
  }) : title = TextEditingController(text: title),
       description = TextEditingController(text: description),
       rationale = TextEditingController(text: rationale),
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
      rationale: map['rationale']?.toString() ?? '',
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
  final List<_EvidenceBlock> evidence;

  bool get hasContent {
    return title.text.trim().isNotEmpty ||
        description.text.trim().isNotEmpty ||
        rationale.text.trim().isNotEmpty ||
        evidence.isNotEmpty;
  }

  _IdeatingIdeaDraft clone() {
    return _IdeatingIdeaDraft(
      id: id,
      title: title.text,
      description: description.text,
      rationale: rationale.text,
      evidence: [...evidence],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title.text.trim(),
      'description': description.text.trim(),
      'rationale': rationale.text.trim(),
      'evidence': evidence.map((item) => item.toMap()).toList(),
    };
  }

  void dispose() {
    title.dispose();
    description.dispose();
    rationale.dispose();
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
  });

  factory _SupportingContextFile.fromUpload(UploadedStorageFile file) {
    return _SupportingContextFile(
      name: file.fileName,
      path: file.path,
      publicUrl: file.publicUrl,
      contentType: _attachmentContentType(file.fileName),
    );
  }

  factory _SupportingContextFile.fromMap(Map<dynamic, dynamic> map) {
    return _SupportingContextFile(
      name: map['name']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      publicUrl: map['publicUrl']?.toString() ?? '',
      contentType: map['contentType']?.toString() ?? '',
    );
  }

  final String name;
  final String path;
  final String publicUrl;
  final String contentType;

  Map<String, dynamic> toMap() {
    return {
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
  var _section = _IdeatingStage.challenge;

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 31, 32, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          top: 33,
                          child: Text(
                            'Entry: Ideation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 39,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Exit',
                              style: TextStyle(
                                color: _devGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StageHeader(
                    activeIndex: _section.index,
                    labels: const [
                      'Challenge',
                      'Ideas',
                      'Decision Matrix',
                      'Learning',
                      'Next Action',
                    ],
                  ),
                  const SizedBox(height: 22),
                  _PreviewSectionTabs(
                    section: _section,
                    onChanged: (value) => setState(() => _section = value),
                  ),
                  const SizedBox(height: 24),
                  switch (_section) {
                    _IdeatingStage.challenge => _IdeatingChallengePreview(
                      data: _data,
                    ),
                    _IdeatingStage.ideas => _IdeatingIdeasPreview(data: _data),
                    _IdeatingStage.decisionMatrix => _IdeatingMatrixPreview(
                      data: _data,
                    ),
                    _IdeatingStage.learning => _LearningPreviewContent(
                      selectedDci: _data.selectedDci,
                      selectedSep: _data.selectedSep,
                      selectedCcc: _data.selectedCcc,
                      inquiryLensData: _data.inquiryLensData,
                      assessment: _data.learningAssessment,
                    ),
                    _IdeatingStage.nextAction => _NextActionPreviewContent(
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
    );
  }
}

class _PreviewSectionTabs extends StatelessWidget {
  const _PreviewSectionTabs({required this.section, required this.onChanged});

  final _IdeatingStage section;
  final ValueChanged<_IdeatingStage> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _IdeatingStage.challenge: 'Challenge',
      _IdeatingStage.ideas: 'Ideas',
      _IdeatingStage.decisionMatrix: 'Matrix',
      _IdeatingStage.learning: 'Learning',
      _IdeatingStage.nextAction: 'Next',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in labels.entries)
          GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: section == entry.key ? _devGreen : Colors.white,
                border: Border.all(color: _devGreen),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  color: section == entry.key ? Colors.white : _devGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (data.objectives.isEmpty)
          const _PreviewMutedText('No objectives saved.')
        else
          for (var i = 0; i < data.objectives.length; i++)
            _NumberedPreviewRow(number: i + 1, text: data.objectives[i]),
        const SizedBox(height: 18),
        const Text(
          'Supporting Context',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (data.supportingContext == null)
          const _PreviewMutedText('No supporting context attached.')
        else
          _SupportingContextTile(
            file: data.supportingContext!,
            onRemove: () {},
          ),
        const SizedBox(height: 18),
        const Text(
          'Members',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (data.members.isEmpty)
          const _PreviewMutedText('No members saved.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in data.members)
                Chip(
                  label: Text(member),
                  backgroundColor: Colors.black.withValues(alpha: .08),
                ),
            ],
          ),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _PreviewField('Description', data.ideas[i].description.text),
              _PreviewField(
                'Why might this work?',
                data.ideas[i].rationale.text,
              ),
              const Text(
                'Evidence',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
    return SingleChildScrollView(
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
                      border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Weight: ${criterion.weight.text}%',
                          style: const TextStyle(
                            color: Color(0xFF838383),
                            fontSize: 10,
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
                          fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
      width: 380,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: color.withValues(alpha: .45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _PreviewMutedText(
            value.trim().isEmpty ? 'Not provided.' : value.trim(),
          ),
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
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
  });

  final Set<String> selectedDci;
  final Set<String> selectedSep;
  final Set<String> selectedCcc;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;

  @override
  Widget build(BuildContext context) {
    final lensConfig = InquiryLensConfig.byValue(inquiryLensData.selectedLens);
    final lensState = lensConfig == null
        ? null
        : inquiryLensData.activeState(lensConfig);
    return _PreviewPanel(
      title: 'Learning',
      children: [
        const _PreviewSectionHeader(
          title: 'Inquiry Lens',
          iconAsset: 'assets/learning_module/inquiry_design.svg',
        ),
        const SizedBox(height: 12),
        if (lensConfig == null)
          const _PreviewMutedText('No inquiry lens selected.')
        else
          _LearningPreviewLens(config: lensConfig, state: lensState!),
        const SizedBox(height: 18),
        _LearningPreviewDimensionCard(
          title: 'DCI',
          subtitle: 'Disciplinary Core Ideas',
          iconAsset: 'assets/learning_module/summary_dci.svg',
          values: selectedDci,
        ),
        const SizedBox(height: 11),
        _LearningPreviewDimensionCard(
          title: 'SEP',
          subtitle: 'Science and Engineering Practices',
          iconAsset: 'assets/learning_module/summary_sep.svg',
          values: selectedSep,
        ),
        const SizedBox(height: 11),
        _LearningPreviewDimensionCard(
          title: 'CCCs',
          subtitle: 'Crosscutting Concepts',
          iconAsset: 'assets/learning_module/summary_ccc.svg',
          values: selectedCcc,
        ),
        const SizedBox(height: 18),
        _AssessmentPreviewCard(assessment: assessment),
      ],
    );
  }
}

class _NextActionPreviewContent extends StatelessWidget {
  const _NextActionPreviewContent({
    required this.learned,
    required this.challenges,
    required this.nextSteps,
    required this.notes,
    required this.linkedTimelineEvent,
  });

  final String learned;
  final String challenges;
  final String nextSteps;
  final String notes;
  final Map<String, String>? linkedTimelineEvent;

  @override
  Widget build(BuildContext context) {
    return _PreviewPanel(
      title: 'Next Action',
      children: [
        _PreviewField('What did you learn today?', learned),
        _PreviewField('What challenges or questions came up?', challenges),
        _PreviewField('What are next steps?', nextSteps),
        if (linkedTimelineEvent == null)
          const _PreviewMutedText('No linked timeline event.')
        else
          _LinkedTimelineEventCard(event: linkedTimelineEvent!),
        _PreviewField('Open Notes', notes),
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
      members: _maps(challenge['involved'])
          .map((item) => item['name']?.toString() ?? '')
          .where((item) => item.trim().isNotEmpty)
          .toList(),
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
  final List<String> members;
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

class _PrototypeIterationEditorPage extends StatefulWidget {
  const _PrototypeIterationEditorPage();

  @override
  State<_PrototypeIterationEditorPage> createState() =>
      _PrototypeIterationEditorPageState();
}

class _PrototypeIterationEditorPageState
    extends State<_PrototypeIterationEditorPage> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _PrototypeIterationDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        createdAt: DateTime.now(),
        goal: '',
        notes: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AddIterationSheetPage(titleController: _title, onAdd: _save);
  }
}

class _AddIterationSheetPage extends StatelessWidget {
  const _AddIterationSheetPage({
    required this.titleController,
    required this.onAdd,
  });

  final TextEditingController titleController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SizedBox(
              height: 279,
              child: Stack(
                children: [
                  Positioned(
                    left: 31,
                    top: 58,
                    width: 23,
                    height: 23,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: SvgPicture.asset('assets/prototyping/close_x.svg'),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 53,
                    child: Text(
                      'Add Iteration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF1F2024),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 49,
                    top: 100,
                    width: 346,
                    child: _LabeledBox(
                      label: 'Iteration Name',
                      controller: titleController,
                      height: 39,
                    ),
                  ),
                  Positioned(
                    left: 176,
                    top: 193,
                    width: 91,
                    height: 31,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _devGreen,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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
    );
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
    final component = await Navigator.of(context)
        .push<_PrototypeComponentDraft>(
          MaterialPageRoute(
            builder: (_) => const _PrototypeComponentEditorPage(),
          ),
        );
    if (component == null || !mounted) return;
    setState(() => widget.iteration.components.add(component));
    widget.onChanged();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  /// Build section: opens the editable Build Log list (each log is a journal
  /// entry with its own Learning / Next Action). Previews are removed for now.
  Future<void> _openBuild(_PrototypeComponentDraft component) async {
    await Navigator.of(context).push<void>(
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
    await Navigator.of(context).push<void>(
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
    await Navigator.of(context).push<void>(
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
    await Navigator.of(context).push<bool>(
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
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title:
                      'Iteration ${widget.iterationIndex + 1}: ${widget.iteration.title}',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(46, 4, 46, 8),
                    children: [
                      const Text(
                        'Components',
                        style: TextStyle(
                          color: _devGreen,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create and develop components of your prototype.',
                        style: TextStyle(
                          color: Color(0x80000000),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 28),
                      for (var i = 0; i < components.length; i++)
                        _PrototypeComponentListCard(
                          component: components[i],
                          index: i,
                          onTap: () => _openComponent(components[i]),
                          onDelete: () => _deleteComponent(i),
                          onMoveUp: i > 0 ? () => _moveComponent(i, -1) : null,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrototypeComponentEditorPage extends StatefulWidget {
  const _PrototypeComponentEditorPage();

  @override
  State<_PrototypeComponentEditorPage> createState() =>
      _PrototypeComponentEditorPageState();
}

class _PrototypeComponentEditorPageState
    extends State<_PrototypeComponentEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _features = [TextEditingController()];
  var _status = 'In Progress';

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

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      _PrototypeComponentDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        status: _status,
        features: _features
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Component',
      onSave: _save,
      children: [
        const Text(
          'Component Overview',
          style: TextStyle(
            color: _devGreen,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _LabeledBox(label: 'Title Component', controller: _name, height: 39),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Purpose of the Component',
          controller: _description,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        const Text(
          'Status',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'What is the current build status of the component?',
          style: TextStyle(
            color: Color(0xFF838383),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _PrototypeStatusSelector(
          value: _status,
          onChanged: (value) => setState(() => _status = value),
        ),
        const SizedBox(height: 22),
        const Text(
          'Key Features',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'What features do we hope this component will have.',
          style: TextStyle(
            color: Color(0xFF838383),
            fontSize: 10,
            fontWeight: FontWeight.w700,
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
    final log = await Navigator.of(context).push<_PrototypeBuildLogDraft>(
      MaterialPageRoute(builder: (_) => const _PrototypeBuildLogEditorPage()),
    );
    if (log == null || !mounted) return;
    setState(() => widget.component.buildLogs.add(log));
    widget.onChanged();
    await _openLogLearning(log);
  }

  Future<void> _editLog(int index) async {
    final log = widget.component.buildLogs[index];
    final updated = await Navigator.of(context).push<_PrototypeBuildLogDraft>(
      MaterialPageRoute(
        builder: (_) => _PrototypeBuildLogEditorPage(existing: log),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {});
    widget.onChanged();
    await _openLogLearning(log);
  }

  /// Each build log owns its own Learning -> Next Action stages.
  Future<void> _openLogLearning(_PrototypeBuildLogDraft log) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PrototypeLogLearningFlow(
          target: log,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
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
      body: ListView(
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
                  color: _devGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
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
    );
  }
}

class _PrototypeBuildLogEditorPage extends StatefulWidget {
  const _PrototypeBuildLogEditorPage({this.existing});

  final _PrototypeBuildLogDraft? existing;

  @override
  State<_PrototypeBuildLogEditorPage> createState() =>
      _PrototypeBuildLogEditorPageState();
}

class _PrototypeBuildLogEditorPageState
    extends State<_PrototypeBuildLogEditorPage> {
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
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(context, type, null);
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence[index] = block);
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final existing = widget.existing;
    if (existing != null) {
      existing.title = _title.text.trim();
      existing.summary = _summary.text.trim();
      existing.challenges = _challenges.text.trim();
      existing.evidence = [..._evidence];
      Navigator.of(context).pop(existing);
    } else {
      Navigator.of(context).pop(
        _PrototypeBuildLogDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          summary: _summary.text.trim(),
          challenges: _challenges.text.trim(),
          createdAt: DateTime.now(),
          evidence: [..._evidence],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Entry: Build',
      onSave: _save,
      children: [
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
                color: _devGreen,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LabeledBox(label: 'Build Title', controller: _title, height: 36),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Description',
          helperText: 'Explain the methodology of the build.',
          controller: _summary,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        const Text(
          'Evidence',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (_evidence.isEmpty)
          const _EmptyEvidenceState()
        else
          for (var i = 0; i < _evidence.length; i++)
            _EvidenceSummaryCard(
              evidence: _evidence[i],
              onTap: () => _editEvidence(i),
            ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
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
                  color: _devGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Design Notes',
          optional: true,
          helperText:
              'Provide additional notes related to the build or design.',
          controller: _challenges,
          maxLines: 4,
        ),
        const SizedBox(height: 28),
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
    final entry = await Navigator.of(context).push<_PrototypeTestEntryDraft>(
      MaterialPageRoute(builder: (_) => const _PrototypeTestEntryEditorPage()),
    );
    if (entry == null || !mounted) return;
    setState(() => widget.component.testEntries.add(entry));
    widget.onChanged();
    await _openTestLearning(entry);
  }

  Future<void> _editTest(int index) async {
    final entry = widget.component.testEntries[index];
    final updated = await Navigator.of(context).push<_PrototypeTestEntryDraft>(
      MaterialPageRoute(
        builder: (_) => _PrototypeTestEntryEditorPage(existing: entry),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {});
    widget.onChanged();
    await _openTestLearning(entry);
  }

  /// Each test log owns its own Learning -> Next Action stages.
  Future<void> _openTestLearning(_PrototypeTestEntryDraft entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PrototypeLogLearningFlow(
          target: entry,
          projectId: widget.projectId,
          projectsRepo: widget.projectsRepo,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
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
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: 'Component: ${widget.component.name}',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Expanded(
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
                              color: _devGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
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
          color: _devGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
    return GestureDetector(
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
                          color: Color(0xFF1F2024),
                          fontSize: 15,
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
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entry.evidence.length} evidence',
                  style: const TextStyle(
                    color: Color(0xFF717171),
                    fontSize: 11,
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
  const _PrototypeTestEntryEditorPage({this.existing});

  final _PrototypeTestEntryDraft? existing;

  @override
  State<_PrototypeTestEntryEditorPage> createState() =>
      _PrototypeTestEntryEditorPageState();
}

class _PrototypeTestEntryEditorPageState
    extends State<_PrototypeTestEntryEditorPage> {
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
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EvidenceBlockPicker(),
    );
    if (!mounted || type == null) return;
    final block = await _openPrototypeEvidenceEditor(context, type, null);
    if (!mounted || block == null) return;
    setState(() => _evidence.add(block));
  }

  Future<void> _editEvidence(int index) async {
    final existing = _evidence[index];
    final block = await _openPrototypeEvidenceEditor(
      context,
      existing.type,
      existing,
    );
    if (!mounted || block == null) return;
    setState(() => _evidence[index] = block);
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final existing = widget.existing;
    if (existing != null) {
      existing.title = _title.text.trim();
      existing.description = _description.text.trim();
      existing.method = _method.text.trim();
      existing.expectedOutcome = _expected.text.trim();
      existing.outcome = _outcome;
      existing.feedback = _feedback.text.trim();
      existing.evidence = [..._evidence];
      Navigator.of(context).pop(existing);
    } else {
      Navigator.of(context).pop(
        _PrototypeTestEntryDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: _title.text.trim(),
          description: _description.text.trim(),
          method: _method.text.trim(),
          expectedOutcome: _expected.text.trim(),
          outcome: _outcome,
          feedback: _feedback.text.trim(),
          createdAt: DateTime.now(),
          evidence: [..._evidence],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrototypeFormScaffold(
      title: 'Entry: Test',
      onSave: _save,
      children: [
        const _PrototypeGuidedStepper(activeIndex: 0, firstLabel: 'Test'),
        const SizedBox(height: 20),
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
                color: _devGreen,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LabeledBox(label: 'Test Title', controller: _title, height: 36),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Description',
          helperText: 'What are you trying to learn or improve?',
          controller: _description,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Method',
          helperText: 'How did you conduct this test?',
          controller: _method,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Expected Outcome',
          helperText: 'What results would indicate success?',
          controller: _expected,
          maxLines: 4,
        ),
        const SizedBox(height: 22),
        const Text(
          'Outcomes & Rating',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
        const SizedBox(height: 22),
        const Text(
          'Evidence',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        if (_evidence.isEmpty)
          const _EmptyEvidenceState()
        else
          for (var i = 0; i < _evidence.length; i++)
            _EvidenceSummaryCard(
              evidence: _evidence[i],
              onTap: () => _editEvidence(i),
            ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
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
                  color: _devGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _LabeledBox(
          label: 'Feedback & Notes',
          optional: true,
          helperText:
              'Provide additional feedback or notes related to the test.',
          controller: _feedback,
          maxLines: 4,
        ),
        const SizedBox(height: 28),
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
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _devGreen.withValues(alpha: .12) : Colors.white,
          border: Border.all(
            color: selected ? _devGreen : const Color(0xFFE5E5E5),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF838383), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeGuidedStepper extends StatelessWidget {
  const _PrototypeGuidedStepper({
    required this.activeIndex,
    this.firstLabel = 'Build',
  });

  final int activeIndex;
  final String firstLabel;

  @override
  Widget build(BuildContext context) {
    final labels = [firstLabel, 'Learning', 'Next Action'];
    Widget dot(int i) => Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i <= activeIndex ? _devGreen : Colors.white,
        border: Border.all(color: _devGreen),
      ),
    );
    Widget line(int i) => Expanded(
      child: Container(
        height: 1,
        color: i < activeIndex ? _devGreen : const Color(0xFFD9D9D9),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 52),
      child: Column(
        children: [
          Row(children: [dot(0), line(0), dot(1), line(1), dot(2)]),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in labels)
                Text(
                  l,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared Learning -> Next Action flow for a Prototyping component. Reuses the
/// existing [_LearningStageBody] and [_NextActionStageBody] widgets (no
/// duplication); persists the result onto the component.
class _PrototypeLogLearningFlow extends StatefulWidget {
  const _PrototypeLogLearningFlow({
    required this.target,
    required this.projectId,
    required this.projectsRepo,
    required this.onChanged,
  });

  final _HasLearningStages target;
  final String projectId;
  final ProjectsRepo projectsRepo;
  final VoidCallback onChanged;

  @override
  State<_PrototypeLogLearningFlow> createState() =>
      _PrototypeLogLearningFlowState();
}

class _PrototypeLogLearningFlowState extends State<_PrototypeLogLearningFlow> {
  final _usersRepo = UsersRepo();
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
    final current = await _usersRepo.getCurrentUserProfile();
    final collaborators = await widget.projectsRepo.getProjectCollaborators(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      if (current != null) {
        _members.add(current);
      } else {
        final user = AuthService.instance.currentUser;
        if (user != null) {
          _members.add(UserProfile(id: user.id, username: user.email));
        }
      }
      _members.addAll(
        collaborators.where((m) => !_members.any((e) => e.id == m.id)),
      );
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
      'linkedTimelineEventId': _linkedTimelineEvent?['id'],
      'linkedTimelineEvent': _linkedTimelineEvent,
      'submitted': submitted,
    };
    widget.onChanged();
  }

  void _toggleSelection(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _createTimelineEvent() async {
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDiscoveryTimelineEventSheet(
        members: _members,
        entryId: null,
        entryTitle: 'Entry: Prototyping',
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
    setState(() => _linkedTimelineEvent = event);
  }

  Future<void> _linkExistingTimelineEvent() async {
    final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
    if (!mounted) return;
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExistingTimelineEventSheet(events: timeline ?? const []),
    );
    if (event == null || !mounted) return;
    setState(() => _linkedTimelineEvent = event);
  }

  void _unlinkTimelineEvent() => setState(() => _linkedTimelineEvent = null);

  void _goToNextAction() {
    _persistLearning();
    setState(() => _showNextAction = true);
  }

  void _finish() {
    _persistNextAction(submitted: true);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: Column(
              children: [
                _PrototypeTopBar(
                  title: widget.target.stageTitle,
                  onBack: () => Navigator.of(context).pop(),
                ),
                _PrototypeGuidedStepper(
                  activeIndex: _showNextAction ? 2 : 1,
                  firstLabel: widget.target.stageTitle.contains('Test')
                      ? 'Test'
                      : 'Build',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(31, 16, 31, 38),
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
                            onLinkExistingTimelineEvent:
                                _linkExistingTimelineEvent,
                            onCreateTimelineEvent: _createTimelineEvent,
                            onUnlinkTimelineEvent: _unlinkTimelineEvent,
                            onBack: () =>
                                setState(() => _showNextAction = false),
                            onSubmit: _finish,
                          )
                        : _LearningStageBody(
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
                            onAssessmentChanged: (value) =>
                                setState(() => _learningAssessment = value),
                            onBack: () => Navigator.of(context).pop(),
                            onNext: _goToNextAction,
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

class _PrototypeFormScaffold extends StatelessWidget {
  const _PrototypeFormScaffold({
    required this.title,
    required this.onSave,
    required this.children,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(43, 31, 50, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          top: 33,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: 39,
                          child: GestureDetector(
                            onTap: onSave,
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                color: _devGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...children,
                ],
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
    this.onMoveUp,
    this.onMoveDown,
    this.deleteLabel = 'Delete',
    this.iconAsset = 'assets/prototyping/pagination_dots.svg',
  });

  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String deleteLabel;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: SvgPicture.asset(iconAsset, width: 15, height: 3),
      onSelected: (value) {
        switch (value) {
          case 'up':
            onMoveUp?.call();
          case 'down':
            onMoveDown?.call();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        if (onMoveUp != null)
          const PopupMenuItem(value: 'up', child: Text('Move Up')),
        if (onMoveDown != null)
          const PopupMenuItem(value: 'down', child: Text('Move Down')),
        PopupMenuItem(value: 'delete', child: Text(deleteLabel)),
      ],
    );
  }
}

class _PrototypeIterationCard extends StatelessWidget {
  const _PrototypeIterationCard({
    required this.iteration,
    required this.index,
    required this.onTap,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final _PrototypeIterationDraft iteration;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _firstPrototypeIterationImageUrl(iteration);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(10, 16, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/prototyping/iteration_wrench.svg',
                  width: 37,
                  height: 37,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    'Iteration ${index + 1}: ${iteration.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2024),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (imageUrl != null) ...[
                  const SizedBox(width: 10),
                  _EntryThumbnail(url: imageUrl, size: 40),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMMM d').format(iteration.createdAt),
                  style: const TextStyle(
                    color: Color(0xFFA1A1A1),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                _PrototypeReorderMenu(
                  onDelete: onDelete,
                  onMoveUp: onMoveUp,
                  onMoveDown: onMoveDown,
                  deleteLabel: 'Delete Iteration',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypeComponentListCard extends StatelessWidget {
  const _PrototypeComponentListCard({
    required this.component,
    required this.index,
    required this.onTap,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final _PrototypeComponentDraft component;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final isComplete = component.status == 'Completed';
    final statusColor = isComplete ? _devGreen : const Color(0xFF2C70BF);
    final statusFill = isComplete
        ? const Color(0xFFD8F0DF)
        : const Color(0xFFDCEBFF);
    return GestureDetector(
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
                  fontWeight: FontWeight.w700,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                        color: Color(0xFF838383),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(40, 4, 40, 8),
        children: [
          const Text(
            'Component Overview',
            style: TextStyle(
              color: _devGreen,
              fontSize: 22,
              fontWeight: FontWeight.w700,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (component.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E5E5)),
                  const SizedBox(height: 12),
                  const Text(
                    'Purpose of the Component',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    component.description,
                    style: const TextStyle(
                      color: Color(0xFF838383),
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (component.features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E5E5)),
                  const SizedBox(height: 12),
                  const Text(
                    'Key Features',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              component.features[i],
                              style: const TextStyle(
                                color: Color(0xFF838383),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'View',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
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
    return GestureDetector(
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
              color: _devGreen,
              fontSize: 13,
              fontWeight: FontWeight.w700,
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
          color: _devGreen,
          fontSize: 16,
          fontWeight: FontWeight.w700,
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
        width: 353,
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
                color: Colors.white,
                fontSize: 10,
                height: 20 / 10,
                fontWeight: FontWeight.w600,
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
          width: 346,
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
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: TextField(
                        controller: features[index],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Feature',
                          hintStyle: TextStyle(
                            color: Color(0x80000000),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      '0/100',
                      style: TextStyle(color: Colors.black, fontSize: 8),
                    ),
                    if (features.length > 1) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
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
        GestureDetector(
          onTap: onAdd,
          child: const Text(
            '+ Add Feature',
            style: TextStyle(
              color: _devGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 353,
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
                          color: Color(0xFF1F2024),
                          fontSize: 15,
                        ),
                      ),
                      if (log.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1F2024),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _PrototypeReorderMenu(
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
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${log.evidence.length} evidence',
                  style: const TextStyle(
                    color: Color(0xFF717171),
                    fontSize: 11,
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
  final String title;
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
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeTestEntryDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeTestEntryDraft(
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

  final String id;
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
  String get stageTitle => 'Entry: Test';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
    Map<String, dynamic>? learning,
    Map<String, dynamic>? nextAction,
  }) : learning = learning ?? <String, dynamic>{},
       nextAction = nextAction ?? <String, dynamic>{};

  factory _PrototypeBuildLogDraft.fromMap(Map<dynamic, dynamic> map) {
    return _PrototypeBuildLogDraft(
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

  final String id;
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
  String get stageTitle => 'Entry: Build';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
  _EvidenceBlock? existing,
) async {
  if (type == 'Images') {
    final result = await Navigator.of(context).push<ImageBlockData>(
      MaterialPageRoute(
        builder: (_) => ImageBlockEditorScreen(
          moduleId: 'prototype',
          initialData: existing?.imageData,
          showAssessment: false,
          showInquiryLens: false,
        ),
      ),
    );
    return result == null ? null : _EvidenceBlock.images(result);
  }
  if (type == 'Sketch') {
    final result = await Navigator.of(context).push<SketchBlockData>(
      MaterialPageRoute(
        builder: (_) => SketchBlockEditorScreen(
          moduleId: 'prototype',
          initialData: existing?.sketchData,
        ),
      ),
    );
    return result == null ? null : _EvidenceBlock.sketch(result);
  }
  if (type == 'Link') {
    final result = await Navigator.of(context).push<LinkBlockData>(
      MaterialPageRoute(
        builder: (_) => LinkBlockEditorScreen(initialData: existing?.linkData),
      ),
    );
    return result == null ? null : _EvidenceBlock.link(result);
  }
  if (type == 'Video') {
    final result = await Navigator.of(context).push<VideoBlockData>(
      MaterialPageRoute(
        builder: (_) => VideoBlockEditorScreen(
          moduleId: 'prototype',
          initialData: existing?.videoData,
        ),
      ),
    );
    return result == null ? null : _EvidenceBlock.video(result);
  }
  if (type == 'Graph') {
    final result = await Navigator.of(context).push<GraphBlockData>(
      MaterialPageRoute(
        builder: (_) =>
            GraphBlockEditorScreen(initialData: existing?.graphData),
      ),
    );
    return result == null ? null : _EvidenceBlock.graph(result);
  }
  if (type == 'Table') {
    final result = await Navigator.of(context).push<TableBlockData>(
      MaterialPageRoute(
        builder: (_) =>
            TableBlockEditorScreen(initialData: existing?.tableData),
      ),
    );
    return result == null ? null : _EvidenceBlock.table(result);
  }
  return null;
}

class DiscoveryObservationEntryPage extends StatefulWidget {
  const DiscoveryObservationEntryPage({
    super.key,
    required this.projectId,
    required this.projectsRepo,
    this.entry,
  });

  final String projectId;
  final ProjectsRepo projectsRepo;
  final JournalEntry? entry;

  @override
  State<DiscoveryObservationEntryPage> createState() =>
      _DiscoveryObservationEntryPageState();
}

class _DiscoveryObservationEntryPageState
    extends State<DiscoveryObservationEntryPage> {
  final _observed = TextEditingController();
  final _location = TextEditingController();
  final _known = TextEditingController();
  final _patternExplanation = TextEditingController();
  final _questionText = TextEditingController();
  final _nextLearned = TextEditingController();
  final _nextChallenges = TextEditingController();
  final _nextSteps = TextEditingController();
  final _nextNotes = TextEditingController();
  final _usersRepo = UsersRepo();
  final _communitiesRepo = CommunitiesRepo();
  final List<UserProfile> _members = [];
  final Set<String> _involvedIds = {};
  final List<_AffectedCommunity> _affectedCommunities = [];
  final List<_RootCauseDraft> _rootCauses = [];
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

  @override
  void initState() {
    super.initState();
    _questionText.addListener(_refreshQuestionText);
    _hydrateEntry();
    _loadMembers();
  }

  void _refreshQuestionText() {
    if (mounted) setState(() {});
  }

  void _hydrateEntry() {
    final entry = widget.entry;
    if (entry == null) return;
    _entryId = entry.id;
    final observation = entry.content.whereType<Map>().firstWhere(
      (item) => item['stage']?.toString() == 'observations',
      orElse: () => const {},
    );
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
    final current = await _usersRepo.getCurrentUserProfile();
    final collaborators = await widget.projectsRepo.getProjectCollaborators(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      if (current != null) {
        _members.add(current);
        _involvedIds.add(current.id);
      } else {
        final user = AuthService.instance.currentUser;
        if (user != null) {
          _members.add(UserProfile(id: user.id, username: user.email));
          _involvedIds.add(user.id);
        }
      }
      _members.addAll(collaborators.where((m) => !_involvedIds.contains(m.id)));
    });
  }

  Future<bool> _save() async {
    setState(() => _isSaving = true);
    final involved = _members
        .where((member) => _involvedIds.contains(member.id))
        .map((member) => {'id': member.id, 'name': member.resolvedDisplayName})
        .toList();
    final title = _observed.text.trim().isEmpty
        ? 'Entry: Discovery'
        : 'Entry: ${_observed.text.trim().split(RegExp(r'\s+')).take(3).join(' ')}';
    final savedRootCauses = _rootCauses
        .where((item) => item.hasContent)
        .toList();
    final content = [
      {
        'stage': 'observations',
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
        'linkedTimelineEventId': _linkedTimelineEvent?['id'],
        'linkedTimelineEvent': _linkedTimelineEvent,
        'submitted': _submitted,
        if (_submitted) 'submittedAt': DateTime.now().toUtc().toIso8601String(),
      },
    ];
    var ok = false;
    if (_entryId == null) {
      final entry = await widget.projectsRepo.createJournalEntry(
        projectId: widget.projectId,
        title: title,
        progress: 'discover',
        content: content,
      );
      _entryId = entry?.id;
      ok = entry != null;
    } else {
      ok = await widget.projectsRepo.updateJournalEntry(
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
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() {
      _stage = _DiscoveryStage.analyze;
      if (_rootCauses.isEmpty) _rootCauses.add(_RootCauseDraft.empty());
    });
  }

  // ignore: unused_element
  Future<void> _openAnalyzePreview() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    final advance = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AnalyzePreviewPage(
          rootCauses: _rootCauses.where((item) => item.hasContent).toList(),
          patternChange: _selectedPatternChange,
          patternExplanation: _patternExplanation.text.trim(),
        ),
      ),
    );
    if (!mounted || advance != true) return;
    setState(() => _stage = _DiscoveryStage.question);
  }

  Future<void> _goToQuestion() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _DiscoveryStage.question);
  }

  void _addQuestion() {
    final type = _selectedQuestionType;
    final text = _questionText.text.trim();
    if (type == null || text.isEmpty) return;
    setState(() {
      _questions.add(_QuestionDraft(type: type, text: text));
      _questionText.clear();
    });
  }

  void _deleteQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  Future<void> _finishQuestionStage() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _DiscoveryStage.learning);
  }

  Future<void> _finishLearningStage() async {
    final ok = await _save();
    if (!mounted || !ok) return;
    setState(() => _stage = _DiscoveryStage.nextAction);
  }

  Future<void> _finishNextActionStage() async {
    _submitted = true;
    final ok = await _save();
    if (!mounted || !ok) return;
    final navigator = Navigator.of(context);
    navigator.pop(true);
    navigator.pop(true);
  }

  Future<void> _createTimelineEvent() async {
    if (_entryId == null) {
      final saved = await _save();
      if (!mounted || !saved) return;
    }
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateDiscoveryTimelineEventSheet(
        members: _members,
        entryId: _entryId,
        entryTitle: 'Entry: Discovery',
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
    setState(() => _linkedTimelineEvent = event);
    await _save();
  }

  Future<void> _linkExistingTimelineEvent() async {
    final timeline = await widget.projectsRepo.getTimeline(widget.projectId);
    if (!mounted) return;
    final event = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExistingTimelineEventSheet(events: timeline ?? const []),
    );
    if (event == null || !mounted) return;
    setState(() => _linkedTimelineEvent = event);
    await _save();
  }

  void _unlinkTimelineEvent() {
    setState(() => _linkedTimelineEvent = null);
  }

  void _toggleLearningSelection(Set<String> target, String value) {
    setState(() {
      if (!target.add(value)) target.remove(value);
    });
  }

  Future<void> _openAffectedChoices() async {
    final result = await showModalBottomSheet<_AffectedCommunity>(
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

  void _addRootCause() {
    setState(() => _rootCauses.add(_RootCauseDraft.empty()));
  }

  void _deleteRootCause(int index) {
    setState(() {
      final removed = _rootCauses.removeAt(index);
      removed.dispose();
      if (_rootCauses.isEmpty) _rootCauses.add(_RootCauseDraft.empty());
    });
  }

  Future<void> _openEvidencePicker(_RootCauseDraft rootCause) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
      final result = await Navigator.of(context).push<ImageBlockData>(
        MaterialPageRoute(
          builder: (_) => ImageBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.imageData,
            showAssessment: false,
            showInquiryLens: false,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.images(result);
    } else if (type == 'Sketch') {
      final result = await Navigator.of(context).push<SketchBlockData>(
        MaterialPageRoute(
          builder: (_) => SketchBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.sketchData,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.sketch(result);
    } else if (type == 'Link') {
      final result = await Navigator.of(context).push<LinkBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              LinkBlockEditorScreen(initialData: existing?.linkData),
        ),
      );
      if (result != null) block = _EvidenceBlock.link(result);
    } else if (type == 'Video') {
      final result = await Navigator.of(context).push<VideoBlockData>(
        MaterialPageRoute(
          builder: (_) => VideoBlockEditorScreen(
            moduleId: _entryId ?? widget.projectId,
            initialData: existing?.videoData,
          ),
        ),
      );
      if (result != null) block = _EvidenceBlock.video(result);
    } else if (type == 'Graph') {
      final result = await Navigator.of(context).push<GraphBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              GraphBlockEditorScreen(initialData: existing?.graphData),
        ),
      );
      if (result != null) block = _EvidenceBlock.graph(result);
    } else if (type == 'Table') {
      final result = await Navigator.of(context).push<TableBlockData>(
        MaterialPageRoute(
          builder: (_) =>
              TableBlockEditorScreen(initialData: existing?.tableData),
        ),
      );
      if (result != null) block = _EvidenceBlock.table(result);
    }
    if (!mounted || block == null) return;
    setState(() {
      if (index == null) {
        rootCause.evidence.add(block!);
      } else {
        rootCause.evidence[index] = block!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(43, 31, 50, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_hasSavedChanges),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          top: 33,
                          child: Text(
                            'Entry: Discovery',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          top: 39,
                          child: GestureDetector(
                            onTap: _isSaving ? null : () => _save(),
                            child: Text(
                              _isSaving ? 'Saving...' : 'Save',
                              style: const TextStyle(
                                color: _devGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StageHeader(activeIndex: _stage.index),
                  const SizedBox(height: 30),
                  switch (_stage) {
                    _DiscoveryStage.observe => _ObserveStageBody(
                      observed: _observed,
                      location: _location,
                      known: _known,
                      members: _members,
                      involvedIds: _involvedIds,
                      affectedCommunities: _affectedCommunities,
                      onAddAffected: _openAffectedChoices,
                      onToggleMember: _toggleInvolvedMember,
                      isSaving: _isSaving,
                      onNext: _goToAnalyze,
                    ),
                    _DiscoveryStage.analyze => _AnalyzeStageBody(
                      rootCauses: _rootCauses,
                      selectedPatternChange: _selectedPatternChange,
                      patternExplanation: _patternExplanation,
                      isSaving: _isSaving,
                      onAddRootCause: _addRootCause,
                      onDeleteRootCause: _deleteRootCause,
                      onAddEvidence: _openEvidencePicker,
                      onEditEvidence: _openEvidenceEditor,
                      onPatternChanged: (value) =>
                          setState(() => _selectedPatternChange = value),
                      onBack: () =>
                          setState(() => _stage = _DiscoveryStage.observe),
                      onNext: _goToQuestion,
                    ),
                    _DiscoveryStage.question => _QuestionStageBody(
                      selectedType: _selectedQuestionType,
                      questionController: _questionText,
                      questions: _questions,
                      isSaving: _isSaving,
                      onTypeSelected: (value) =>
                          setState(() => _selectedQuestionType = value),
                      onAddQuestion: _addQuestion,
                      onDeleteQuestion: _deleteQuestion,
                      onBack: () =>
                          setState(() => _stage = _DiscoveryStage.analyze),
                      onNext: _finishQuestionStage,
                    ),
                    _DiscoveryStage.learning => _LearningStageBody(
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
                      onAssessmentChanged: (value) =>
                          setState(() => _learningAssessment = value),
                      onBack: () =>
                          setState(() => _stage = _DiscoveryStage.question),
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
                      onLinkExistingTimelineEvent: _linkExistingTimelineEvent,
                      onCreateTimelineEvent: _createTimelineEvent,
                      onUnlinkTimelineEvent: _unlinkTimelineEvent,
                      onBack: () =>
                          setState(() => _stage = _DiscoveryStage.learning),
                      onSubmit: _finishNextActionStage,
                    ),
                  },
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

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.activeIndex, this.labels});

  final int activeIndex;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final stageLabels =
        labels ??
        const ['Observe', 'Analyze', 'Question', 'Learning', 'Next Action'];
    final stages = [
      (x: -27.0, label: stageLabels[0], width: 54.0),
      (x: 55.0, label: stageLabels[1], width: 60.0),
      (x: 126.0, label: stageLabels[2], width: 86.0),
      (x: 218.0, label: stageLabels[3], width: 70.0),
      (x: 312.0, label: stageLabels[4], width: 78.0),
    ];
    return SizedBox(
      height: 68,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < stages.length - 1; i++)
            Positioned(
              left: stages[i].x + (stages[i].width + 16) / 2,
              top: 16,
              width:
                  stages[i + 1].x -
                  stages[i].x +
                  (stages[i + 1].width - stages[i].width) / 2,
              child: Divider(
                height: 1,
                color: i < activeIndex ? _devGreen : const Color(0xFFD9D9D9),
                thickness: 1,
              ),
            ),
          for (var i = 0; i < stages.length; i++) ...[
            Positioned(
              left: stages[i].x + (stages[i].width - 16) / 2,
              top: 8,
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: i <= activeIndex ? _devGreen : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= activeIndex
                        ? _devGreen
                        : const Color(0xFFB7D7BF),
                  ),
                ),
              ),
            ),
            Positioned(
              left: stages[i].x,
              top: 38,
              width: stages[i].width,
              child: Text(
                stages[i].label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ObserveStageBody extends StatelessWidget {
  const _ObserveStageBody({
    required this.observed,
    required this.location,
    required this.known,
    required this.members,
    required this.involvedIds,
    required this.affectedCommunities,
    required this.onAddAffected,
    required this.onToggleMember,
    required this.isSaving,
    required this.onNext,
  });

  final TextEditingController observed;
  final TextEditingController location;
  final TextEditingController known;
  final List<UserProfile> members;
  final Set<String> involvedIds;
  final List<_AffectedCommunity> affectedCommunities;
  final VoidCallback onAddAffected;
  final ValueChanged<String> onToggleMember;
  final bool isSaving;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Observations',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 17),
        _LabeledBox(
          label: 'What was observed?',
          controller: observed,
          maxLines: 4,
        ),
        const SizedBox(height: 28),
        _LabeledBox(
          label: 'Location',
          optional: true,
          controller: location,
          height: 36,
        ),
        const SizedBox(height: 28),
        _AffectedCommunitiesField(
          communities: affectedCommunities,
          onAdd: onAddAffected,
        ),
        const SizedBox(height: 28),
        _LabeledBox(
          label: 'What is already known?',
          controller: known,
          maxLines: 4,
        ),
        const SizedBox(height: 35),
        const Text(
          'Who was Involved?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final member in members)
              _MemberChip(
                member: member,
                selected: involvedIds.contains(member.id),
                onTap: () => onToggleMember(member.id),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 11),
              child: Text(
                '+  Add People',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 56),
        Center(
          child: _SmallStageButton(
            label: isSaving ? 'Saving...' : 'Next',
            filled: true,
            onTap: isSaving ? null : onNext,
          ),
        ),
      ],
    );
  }
}

class _AnalyzeStageBody extends StatelessWidget {
  const _AnalyzeStageBody({
    required this.rootCauses,
    required this.selectedPatternChange,
    required this.patternExplanation,
    required this.isSaving,
    required this.onAddRootCause,
    required this.onDeleteRootCause,
    required this.onAddEvidence,
    required this.onEditEvidence,
    required this.onPatternChanged,
    required this.onBack,
    required this.onNext,
  });

  final List<_RootCauseDraft> rootCauses;
  final String? selectedPatternChange;
  final TextEditingController patternExplanation;
  final bool isSaving;
  final VoidCallback onAddRootCause;
  final ValueChanged<int> onDeleteRootCause;
  final ValueChanged<_RootCauseDraft> onAddEvidence;
  final void Function(_RootCauseDraft rootCause, String type, [int? index])
  onEditEvidence;
  final ValueChanged<String> onPatternChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final editor = rootCauses.firstWhere(
      (item) => !item.hasContent,
      orElse: () => rootCauses.first,
    );
    final saved = rootCauses.where((item) => item.hasContent).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Root Causes',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _RootCauseEditorCard(
          rootCause: editor,
          onAddEvidence: () => onAddEvidence(editor),
          onEditEvidence: (type, index) => onEditEvidence(editor, type, index),
        ),
        const SizedBox(height: 18),
        Center(
          child: GestureDetector(
            onTap: onAddRootCause,
            child: const Text(
              '+ Add Key Root Causes',
              style: TextStyle(
                color: _devGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final item in saved)
          _RootCauseCompactCard(
            rootCause: item,
            onDelete: () => onDeleteRootCause(rootCauses.indexOf(item)),
          ),
        const SizedBox(height: 30),
        const Text(
          'Pattern Changes',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'What could change or improve?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (final option in _patternChangeOptions) ...[
          _PatternChangeOptionTile(
            option: option,
            selected: selectedPatternChange == option.label,
            onTap: () => onPatternChanged(option.label),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 10),
        _LabeledBox(
          label: 'Why was this patterns selected?',
          controller: patternExplanation,
          maxLines: 4,
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Next',
              filled: true,
              onTap: isSaving ? null : onNext,
            ),
          ],
        ),
      ],
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
    required this.selectedType,
    required this.questionController,
    required this.questions,
    required this.isSaving,
    required this.onTypeSelected,
    required this.onAddQuestion,
    required this.onDeleteQuestion,
    required this.onBack,
    required this.onNext,
  });

  final String? selectedType;
  final TextEditingController questionController;
  final List<_QuestionDraft> questions;
  final bool isSaving;
  final ValueChanged<String> onTypeSelected;
  final VoidCallback onAddQuestion;
  final ValueChanged<int> onDeleteQuestion;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Question',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 27),
        const Text(
          'Create a new question',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 367,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final option in _questionTypeOptions)
                _QuestionTypeTile(
                  option: option,
                  selected: selectedType == option.label,
                  onTap: () => onTypeSelected(option.label),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 367,
          height: 41,
          child: TextField(
            controller: questionController,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: 'Write out you question...',
              hintStyle: const TextStyle(
                color: Color(0x80000000),
                fontSize: 10,
              ),
              counterText: '',
              contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0x33000000)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _devGreen),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${questionController.text.length}/100',
            style: const TextStyle(color: Colors.black, fontSize: 8),
          ),
        ),
        const SizedBox(height: 21),
        GestureDetector(
          onTap: onAddQuestion,
          child: Container(
            width: 367,
            height: 33,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _devGreen),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '+ Add Question',
              style: TextStyle(
                color: _devGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 33),
        const Text(
          'Questions to explore',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < questions.length; i++)
          _QuestionCard(
            question: questions[i],
            onDelete: () => onDeleteQuestion(i),
          ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Next',
              filled: true,
              onTap: isSaving ? null : onNext,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuestionTypeTile extends StatelessWidget {
  const _QuestionTypeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _QuestionTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 82,
        height: 98,
        padding: const EdgeInsets.fromLTRB(9, 13, 7, 9),
        decoration: BoxDecoration(
          color: selected ? option.fill.withValues(alpha: .45) : Colors.white,
          border: Border.all(color: _devGreen),
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
                        color: option.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
                color: Color(0x80000000),
                fontSize: 10,
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
  const _QuestionCard({required this.question, required this.onDelete});

  final _QuestionDraft question;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final option = _questionTypeOptions.firstWhere(
      (item) => item.label == question.type,
      orElse: () => _questionTypeOptions.first,
    );
    return Container(
      width: 367,
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
                    color: option.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
                color: Color(0x80000000),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFD12E2E)),
                ),
              ),
            ],
            child: const SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: Text(
                  '...',
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _LearningStageBody extends StatelessWidget {
  const _LearningStageBody({
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
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learning',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        _LearningPanel(
          title: 'Inquiry Lens',
          description:
              'Choose the lens that best describes your thinking for this entry.',
          child: Column(
            children: [
              _InquiryLensChoiceGrid(
                data: inquiryLensData,
                onChanged: onInquiryLensChanged,
              ),
              const SizedBox(height: 16),
              InquiryLensSelector(
                data: inquiryLensData,
                onChanged: onInquiryLensChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _LearningPanel(
          title: '3D Learning',
          description: 'Select NGSS components demonstrated in this entry.',
          child: Column(
            children: [
              _LearningCheckboxSection(
                title: 'DCI',
                subtitle: 'Disciplinary Core Ideas',
                iconAsset: 'assets/learning_module/summary_dci.svg',
                options: _discoveryDciOptions,
                selected: selectedDci,
                onToggle: onToggleDci,
              ),
              const SizedBox(height: 11),
              _LearningCheckboxSection(
                title: 'SEP',
                subtitle: 'Science and Engineering Practices',
                iconAsset: 'assets/learning_module/summary_sep.svg',
                options: _discoverySepOptions,
                selected: selectedSep,
                onToggle: onToggleSep,
              ),
              const SizedBox(height: 11),
              _LearningCheckboxSection(
                title: 'CCCs',
                subtitle: 'Crosscutting Concepts',
                iconAsset: 'assets/learning_module/summary_ccc.svg',
                options: _discoveryCccOptions,
                selected: selectedCcc,
                onToggle: onToggleCcc,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _LearningPanel(
          title: 'Assessment Type',
          description:
              'How can learning be demonstrated? Choose how someone could show their learning from this entry.',
          child: AssessmentBlockSection(
            value: assessment,
            onChanged: onAssessmentChanged,
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Next',
              filled: true,
              onTap: isSaving ? null : onNext,
            ),
          ],
        ),
      ],
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
      width: 367,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0x80000000),
              fontSize: 12,
              height: 1.35,
            ),
          ),
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
    final lensConfig = InquiryLensConfig.byValue(inquiryLensData.selectedLens);
    final lensState = lensConfig == null
        ? null
        : inquiryLensData.activeState(lensConfig);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(43, 64, 43, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Entry: Discovery',
                      style: TextStyle(
                        color: Color(0xFF1F2024),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const _StageHeader(activeIndex: 3),
                  const SizedBox(height: 30),
                  const Text(
                    'Learning',
                    style: TextStyle(
                      color: _devGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 392,
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _PreviewSectionHeader(
                          title: 'Inquiry Lens',
                          iconAsset:
                              'assets/learning_module/inquiry_design.svg',
                        ),
                        const SizedBox(height: 14),
                        if (lensConfig == null)
                          const _PreviewMutedText('No inquiry lens selected.')
                        else
                          _LearningPreviewLens(
                            config: lensConfig,
                            state: lensState!,
                          ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE5E5E5)),
                        const SizedBox(height: 18),
                        const Text(
                          'Three Dimensional Learning',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _LearningPreviewDimensionCard(
                          title: 'DCI',
                          subtitle: 'Disciplinary Core Ideas',
                          iconAsset: 'assets/learning_module/summary_dci.svg',
                          values: selectedDci,
                        ),
                        const SizedBox(height: 11),
                        _LearningPreviewDimensionCard(
                          title: 'SEP',
                          subtitle: 'Science and Engineering Practices',
                          iconAsset: 'assets/learning_module/summary_sep.svg',
                          values: selectedSep,
                        ),
                        const SizedBox(height: 11),
                        _LearningPreviewDimensionCard(
                          title: 'CCCs',
                          subtitle: 'Crosscutting Concepts',
                          iconAsset: 'assets/learning_module/summary_ccc.svg',
                          values: selectedCcc,
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFFE5E5E5)),
                        const SizedBox(height: 18),
                        _AssessmentPreviewCard(assessment: assessment),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
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
            Text(
              config.value,
              style: const TextStyle(
                color: _devText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          config.description,
          style: const TextStyle(
            color: Color(0x80000000),
            fontSize: 12,
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
  const _PreviewSectionHeader({required this.title, required this.iconAsset});

  final String title;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(iconAsset, width: 28, height: 27),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
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
    return Container(
      width: 329,
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
            children: [
              SvgPicture.asset(iconAsset, width: 29, height: 29),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _devGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0x80000000),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
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
  Widget build(BuildContext context) {
    final type = assessment.type;
    if (type == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewSectionHeader(
            title: 'Assessment',
            iconAsset: 'assets/learning_module/assessment_numeric.svg',
          ),
          SizedBox(height: 10),
          _PreviewMutedText('No assessment type selected.'),
        ],
      );
    }
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(type.iconAsset, width: 28, height: 27),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  type.title,
                  style: const TextStyle(
                    color: _devText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._assessmentPreviewLines(assessment).map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PreviewMutedText(line),
            ),
          ),
        ],
      ),
    );
  }
}

List<String> _assessmentPreviewLines(AssessmentBlockData assessment) {
  final data = assessment.data;
  String s(String key) => data[key]?.toString().trim() ?? '';
  switch (assessment.type) {
    case AssessmentType.numeric:
      return [
        if (s('question').isNotEmpty) s('question'),
        'Answer: ${s('correct_answer').isEmpty ? 'Not set' : s('correct_answer')}',
        if (s('min_value').isNotEmpty || s('max_value').isNotEmpty)
          'Range: ${s('min_value')} - ${s('max_value')}',
        if (s('explanation').isNotEmpty) s('explanation'),
      ];
    case AssessmentType.matching:
      final top = _previewStringList(data['top_items']);
      final bottom = _previewStringList(data['bottom_items']);
      return [
        if (top.isEmpty && bottom.isEmpty) 'No matching pairs entered.',
        for (var i = 0; i < top.length || i < bottom.length; i++)
          '${i < top.length ? top[i] : ''} -> ${i < bottom.length ? bottom[i] : ''}',
      ];
    case AssessmentType.trueFalse:
      final questions = data['questions'];
      if (questions is! List || questions.isEmpty) {
        return ['No true/false statements entered.'];
      }
      return [
        for (final item in questions.whereType<Map>())
          '${item['text']?.toString() ?? ''} (${item['correct_answer'] == true
              ? 'True'
              : item['correct_answer'] == false
              ? 'False'
              : 'Not set'})',
      ];
    case AssessmentType.paragraph:
      return [
        if (s('question').isNotEmpty) s('question') else 'No prompt entered.',
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
        if (options.isEmpty) 'No answer options entered.',
        if (s('explanation').isNotEmpty) s('explanation'),
      ];
    case null:
      return ['No assessment type selected.'];
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
        color: Color(0x80000000),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }
}

class _InquiryLensChoiceGrid extends StatelessWidget {
  const _InquiryLensChoiceGrid({required this.data, required this.onChanged});

  final InquiryLensData data;
  final ValueChanged<InquiryLensData> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final option in InquiryLensConfig.values)
          _InquiryLensChoiceTile(
            option: option,
            selected: data.selectedLens == option.value,
            onTap: () => onChanged(data.selectLens(option.value)),
          ),
      ],
    );
  }
}

class _InquiryLensChoiceTile extends StatelessWidget {
  const _InquiryLensChoiceTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final InquiryLensConfig option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        constraints: const BoxConstraints(minHeight: 77),
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
        decoration: BoxDecoration(
          color: selected ? _devGreen.withValues(alpha: .1) : Colors.white,
          border: Border.all(
            color: selected ? _devGreen : const Color(0x33000000),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SvgPicture.asset(option.iconAsset, width: 28, height: 27),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.value,
                    style: const TextStyle(
                      color: _devText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x80000000),
                      fontSize: 10,
                      height: 1.2,
                    ),
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

class _LearningCheckboxSection extends StatelessWidget {
  const _LearningCheckboxSection({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final String iconAsset;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 367,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAF5),
        border: Border.all(color: _devGreen),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _devGreen,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SvgPicture.asset(iconAsset, width: 29, height: 29),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0x80000000),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final option in options)
            _LearningCheckboxRow(
              label: option,
              selected: selected.contains(option),
              onTap: () => onToggle(option),
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
    return GestureDetector(
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
                style: const TextStyle(fontSize: 13, color: _devText),
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
    required this.onLinkExistingTimelineEvent,
    required this.onCreateTimelineEvent,
    required this.onUnlinkTimelineEvent,
    required this.onBack,
    required this.onSubmit,
  });

  final TextEditingController learned;
  final TextEditingController challenges;
  final TextEditingController nextSteps;
  final TextEditingController notes;
  final Map<String, String>? linkedTimelineEvent;
  final bool isSaving;
  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;
  final VoidCallback onLinkExistingTimelineEvent;
  final VoidCallback onCreateTimelineEvent;
  final VoidCallback onUnlinkTimelineEvent;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Next Action',
          style: TextStyle(
            color: _devGreen,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        _CounterTextBox(
          label: 'What did you learn today?',
          controller: learned,
        ),
        const SizedBox(height: 22),
        _CounterTextBox(
          label: 'What challenges or questions came up?',
          controller: challenges,
        ),
        const SizedBox(height: 22),
        _CounterTextBox(label: 'What are next steps?', controller: nextSteps),
        const SizedBox(height: 18),
        _TimelineLinkCard(
          event: linkedTimelineEvent,
          projectId: projectId,
          isOwner: isOwner,
          projectsRepo: projectsRepo,
          onLinkExisting: onLinkExistingTimelineEvent,
          onCreate: onCreateTimelineEvent,
          onUnlink: onUnlinkTimelineEvent,
        ),
        const SizedBox(height: 22),
        _CounterTextBox(label: 'Open Notes', optional: true, controller: notes),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallStageButton(label: 'Back', onTap: onBack),
            const SizedBox(width: 21),
            _SmallStageButton(
              label: isSaving ? 'Saving...' : 'Submit',
              filled: true,
              onTap: isSaving ? null : onSubmit,
            ),
          ],
        ),
      ],
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              optional ? '$label (Optional)' : label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${controller.text.length}/10000',
                style: const TextStyle(color: Colors.black, fontSize: 8),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 346,
              height: 93,
              child: TextField(
                controller: controller,
                maxLength: 10000,
                maxLines: 4,
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.all(12),
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
      },
    );
  }
}

class _TimelineLinkCard extends StatelessWidget {
  const _TimelineLinkCard({
    required this.event,
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
    required this.onLinkExisting,
    required this.onCreate,
    required this.onUnlink,
  });

  final Map<String, String>? event;
  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;
  final VoidCallback onLinkExisting;
  final VoidCallback onCreate;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 343,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(width: 32, height: 22, child: _JournalLineIcon()),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Timeline Link (Optional)',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (event == null) ...[
            const Text(
              'No timeline event linked yet. Link this entry to a timeline event or create a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0x80000000),
                fontSize: 14,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            _TimelineLinkButton(
              label: 'Link to Existing Event',
              onTap: onLinkExisting,
            ),
            const SizedBox(height: 10),
            _TimelineLinkButton(
              label: 'Create New Timeline Event',
              addIcon: true,
              onTap: onCreate,
            ),
          ] else ...[
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _ProjectTimelineRoutePage(
                    projectId: projectId,
                    isOwner: isOwner,
                    projectsRepo: projectsRepo,
                  ),
                ),
              ),
              child: _LinkedTimelineEventCard(event: event!),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUnlink,
              child: const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Unlink',
                  style: TextStyle(
                    color: _devGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 296,
        height: 39,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _devGreen),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (addIcon) ...[
              const Text(
                '+',
                style: TextStyle(
                  color: _devGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: _devGreen,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectTimelineRoutePage extends StatelessWidget {
  const _ProjectTimelineRoutePage({
    required this.projectId,
    required this.isOwner,
    required this.projectsRepo,
  });

  final String projectId;
  final bool isOwner;
  final ProjectsRepo projectsRepo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 402),
            child: Stack(
              children: [
                ProjectTimelineTab(
                  projectId: projectId,
                  isOwner: isOwner,
                  projectsRepo: projectsRepo,
                ),
                Positioned(
                  left: 16,
                  top: 24,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: _devGreen,
                      size: 34,
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

class _LinkedTimelineEventCard extends StatelessWidget {
  const _LinkedTimelineEventCard({required this.event});

  final Map<String, String> event;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse(event['start'] ?? '');
    return Container(
      width: 319,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48, height: 31, child: _CalendarMiniIcon()),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['name'] ?? event['event'] ?? 'Timeline Event',
                  style: const TextStyle(
                    color: _devText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  start == null
                      ? event['date'] ?? ''
                      : DateFormat('MMM d, yyyy').format(start),
                  style: const TextStyle(color: _devText, fontSize: 10),
                ),
                if ((event['assigneeNames'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    event['assigneeNames']!.split('|').join(', '),
                    style: const TextStyle(color: _devText, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingTimelineEventSheet extends StatelessWidget {
  const _ExistingTimelineEventSheet({required this.events});

  final List<Map<String, String>> events;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]
      ..sort((a, b) {
        final aStart = DateTime.tryParse(a['start'] ?? '') ?? DateTime.now();
        final bStart = DateTime.tryParse(b['start'] ?? '') ?? DateTime.now();
        return aStart.compareTo(bStart);
      });
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .68,
      maxChildSize: .86,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(25, 18, 25, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 20,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Link Event',
                style: TextStyle(
                  color: _devText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: sorted.isEmpty
                    ? const Center(
                        child: Text(
                          'No timeline events for this project yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x80000000),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final event = sorted[index];
                          return GestureDetector(
                            onTap: () => Navigator.of(context).pop(event),
                            child: _LinkedTimelineEventCard(event: event),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              _SmallStageButton(
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateDiscoveryTimelineEventSheet extends StatefulWidget {
  const _CreateDiscoveryTimelineEventSheet({
    required this.members,
    required this.entryId,
    required this.entryTitle,
  });

  final List<UserProfile> members;
  final String? entryId;
  final String entryTitle;

  @override
  State<_CreateDiscoveryTimelineEventSheet> createState() =>
      _CreateDiscoveryTimelineEventSheetState();
}

class _CreateDiscoveryTimelineEventSheetState
    extends State<_CreateDiscoveryTimelineEventSheet> {
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
      if (widget.entryId != null) 'journalEntryId': widget.entryId!,
      'journalEntryTitle': widget.entryTitle,
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
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Create Event',
                  style: TextStyle(
                    color: _devText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _TimelineSheetField(label: 'Event Name', controller: _name),
              const SizedBox(height: 14),
              _TimelineSheetField(
                label: 'Description',
                optional: true,
                controller: _description,
              ),
              const SizedBox(height: 14),
              _TimelineSheetField(
                label: 'Location',
                optional: true,
                controller: _location,
              ),
              const SizedBox(height: 18),
              const Text(
                'Start',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 14),
              const Text(
                'End',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'All Day',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _allDay,
                    activeThumbColor: _devGreen,
                    onChanged: (value) => setState(() => _allDay = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Assign To',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
              const SizedBox(height: 18),
              const Text(
                'Link Journal Entry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Container(
                height: 39,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border.all(color: _devGreen),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.entryTitle,
                  style: const TextStyle(fontSize: 12, color: _devText),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: _SmallStageButton(
                  label: 'Create',
                  filled: true,
                  onTap: _submit,
                ),
              ),
            ],
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
        Text(
          optional ? '$label (Optional)' : label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 39,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
    return GestureDetector(
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
            color: _devGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
    this.optional = false,
    this.helperText,
    this.height = 89,
    this.maxLines = 1,
  });

  final String label;
  final bool optional;
  final String? helperText;
  final double height;
  final int maxLines;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              if (optional)
                const TextSpan(
                  text: ' (Optional)',
                  style: TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 3),
          Text(
            helperText!,
            style: const TextStyle(
              color: Color(0x80000000),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
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
      'Sketch' => const Color(0xFFE2F4F5),
      'Video' => const Color(0xFFFFE2E2),
      'Link' => const Color(0xFFFFEFE7),
      _ => const Color(0xFFE8E8E8),
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
                  storagePath: item['storage_path']?.toString() ?? '',
                  publicUrl: item['public_url']?.toString() ?? '',
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
    required this.onAddEvidence,
    required this.onEditEvidence,
  });

  final _RootCauseDraft rootCause;
  final VoidCallback onAddEvidence;
  final void Function(String type, int index) onEditEvidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 382,
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 18),
      decoration: BoxDecoration(
        color: _devGreen.withValues(alpha: .06),
        border: Border.all(color: _devGreen),
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
          const Text(
            'Evidence',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (rootCause.evidence.isEmpty)
            const _EmptyEvidenceState()
          else
            for (var i = 0; i < rootCause.evidence.length; i++)
              _EvidenceSummaryCard(
                evidence: rootCause.evidence[i],
                onTap: () => onEditEvidence(rootCause.evidence[i].type, i),
              ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
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
                    color: _devGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: height,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.all(9),
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

class _EmptyEvidenceState extends StatelessWidget {
  const _EmptyEvidenceState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _CubesEvidenceIcon(),
          SizedBox(height: 18),
          Text(
            'Nothing yet...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            'Add your first block',
            style: TextStyle(color: Color(0xB3000000), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSummaryCard extends StatelessWidget {
  const _EvidenceSummaryCard({required this.evidence, this.onTap});

  final _EvidenceBlock evidence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    evidence.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x80000000),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _RootCauseCompactCard extends StatelessWidget {
  const _RootCauseCompactCard({
    required this.rootCause,
    required this.onDelete,
  });

  final _RootCauseDraft rootCause;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 67,
      margin: const EdgeInsets.only(bottom: 19),
      padding: const EdgeInsets.fromLTRB(25, 10, 13, 9),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rootCause.title.text.trim().isEmpty
                      ? 'Root Cause'
                      : rootCause.title.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rootCause.description.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x80000000),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFD12E2E)),
                ),
              ),
            ],
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Text(
                  '...',
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

class _PatternChangeOption {
  const _PatternChangeOption(this.label, this.assets);

  final String label;
  final List<String> assets;
}

const _patternChangeOptions = [
  _PatternChangeOption('Reduction', ['assets/discovery/pattern_reduction.svg']),
  _PatternChangeOption('Substitution', [
    'assets/discovery/pattern_substitution_1.svg',
    'assets/discovery/pattern_substitution_2.svg',
    'assets/discovery/pattern_substitution_3.svg',
    'assets/discovery/pattern_substitution_4.svg',
  ]),
  _PatternChangeOption('Behavior Change', [
    'assets/discovery/pattern_behavior_change.svg',
  ]),
  _PatternChangeOption('Capacity Building', [
    'assets/discovery/pattern_capacity_building.svg',
  ]),
  _PatternChangeOption('Regeneration', [
    'assets/discovery/pattern_regeneration_1.svg',
    'assets/discovery/pattern_regeneration_2.svg',
    'assets/discovery/pattern_regeneration_3.svg',
    'assets/discovery/pattern_regeneration_4.svg',
  ]),
];

class _PatternChangeOptionTile extends StatelessWidget {
  const _PatternChangeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _PatternChangeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0x80000000)),
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
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 91,
        height: 31,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? _devGreen : Colors.white,
          border: Border.all(color: _devGreen),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : _devGreen,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EvidenceBlockPicker extends StatelessWidget {
  const _EvidenceBlockPicker();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxHeight =
        MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.vertical -
        32;
    const items = ['Images', 'Sketch', 'Link', 'Video', 'Graph', 'Table'];
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: EdgeInsets.fromLTRB(36, 22, 36, 28 + bottomInset),
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
        child: Column(
          children: [
            SizedBox(
              height: 28,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _devGreen, size: 24),
                  ),
                  const Center(
                    child: Text(
                      'Select Evidence Block',
                      style: TextStyle(
                        color: _devGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 70,
                crossAxisSpacing: 81,
                childAspectRatio: 111 / 107,
                padding: EdgeInsets.zero,
                children: [
                  for (final item in items)
                    _EvidencePickerTile(
                      type: item,
                      onTap: () => Navigator.of(context).pop(item),
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

class _EvidencePickerTile extends StatelessWidget {
  const _EvidencePickerTile({required this.type, required this.onTap});

  final String type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final evidence = _EvidenceBlock._(type, const {});
    return GestureDetector(
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
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(37, 31, 39, 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 72,
                    child: Stack(
                      children: [
                        Positioned(
                          left: -12,
                          top: 29,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          top: 33,
                          child: Text(
                            'Entry: Discovery',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _StageHeader(activeIndex: 1),
                  const SizedBox(height: 30),
                  const Text(
                    'Root Causes',
                    style: TextStyle(
                      color: _devGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (rootCauses.isEmpty)
                    const Text(
                      'No root causes added yet.',
                      style: TextStyle(color: Color(0x80000000)),
                    )
                  else
                    for (final rootCause in rootCauses)
                      _RootCausePreviewCard(rootCause: rootCause),
                  const SizedBox(height: 26),
                  const Text(
                    'Pattern Changes',
                    style: TextStyle(
                      color: _devGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 353,
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
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'No pattern change selected.',
                            style: TextStyle(
                              color: Color(0x80000000),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 26),
                        const Text(
                          'Why was this patterns selected?',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          patternExplanation.isEmpty
                              ? 'No explanation added yet.'
                              : patternExplanation,
                          style: const TextStyle(
                            color: Color(0x80000000),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

class _RootCausePreviewCard extends StatelessWidget {
  const _RootCausePreviewCard({required this.rootCause});

  final _RootCauseDraft rootCause;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 382,
      margin: const EdgeInsets.only(bottom: 37),
      padding: const EdgeInsets.fromLTRB(90, 15, 23, 18),
      decoration: BoxDecoration(
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
              Text(
                rootCause.title.text.trim().isEmpty
                    ? 'Root Cause'
                    : rootCause.title.text.trim(),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rootCause.description.text.trim(),
                style: const TextStyle(
                  color: Color(0x80000000),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE1E1E1)),
              const SizedBox(height: 8),
              const Text(
                'Why does this occur?',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rootCause.reason.text.trim(),
                style: const TextStyle(
                  color: Color(0x80000000),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE1E1E1)),
              const SizedBox(height: 8),
              const Text(
                'Evidence',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              if (rootCause.evidence.isEmpty)
                const Text(
                  'No evidence added yet.',
                  style: TextStyle(color: Color(0x80000000), fontSize: 12),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EvidenceSummaryCard(evidence: evidence),
          if (images is List)
            for (var i = 0; i < images.length; i++)
              if (images[i] is Map)
                _ImageEvidencePreview(
                  index: i + 1,
                  image: Map<dynamic, dynamic>.from(images[i] as Map),
                ),
          if (evidence.type == 'Link') _LinkEvidencePreview(evidence: evidence),
          if (evidence.type == 'Video')
            _TextEvidencePreview(
              title: evidence.data['title']?.toString() ?? 'Video',
              body: evidence.data['external_url']?.toString().isNotEmpty == true
                  ? evidence.data['external_url'].toString()
                  : evidence.subtitle,
            ),
          if (evidence.type == 'Graph')
            _TextEvidencePreview(
              title: evidence.data['title']?.toString() ?? 'Graph',
              body: _graphPreviewText(evidence.data),
            ),
          if (evidence.type == 'Table')
            _TextEvidencePreview(
              title: evidence.data['title']?.toString() ?? 'Table',
              body: _tablePreviewText(evidence.data),
            ),
          if (evidence.type == 'Sketch')
            _SketchEvidencePreview(data: evidence.data),
        ],
      ),
    );
  }
}

class _LinkEvidencePreview extends StatelessWidget {
  const _LinkEvidencePreview({required this.evidence});

  final _EvidenceBlock evidence;

  @override
  Widget build(BuildContext context) {
    final url = evidence.data['url']?.toString() ?? '';
    final description = evidence.data['description']?.toString() ?? '';
    final host = Uri.tryParse(url)?.host ?? url;
    return Container(
      width: 208,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            host.isEmpty ? 'Website link' : host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0x80000000), fontSize: 10),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _TextEvidencePreview extends StatelessWidget {
  const _TextEvidencePreview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        border: Border.all(color: const Color(0x1A000000)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Evidence' : title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            body.trim().isEmpty ? 'No preview content added.' : body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0x80000000), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SketchEvidencePreview extends StatelessWidget {
  const _SketchEvidencePreview({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return _TextEvidencePreview(
      title: data['title']?.toString() ?? 'Sketch',
      body: data['caption']?.toString() ?? 'Sketch evidence added.',
    );
  }
}

String _graphPreviewText(Map<String, dynamic> data) {
  final caption = data['caption']?.toString() ?? '';
  if (caption.isNotEmpty) return caption;
  final rows = data['rows'];
  if (rows is List && rows.isNotEmpty) {
    return rows
        .whereType<Map>()
        .map((row) => '${row['x'] ?? ''}: ${row['y'] ?? ''}')
        .where((item) => item.trim() != ':')
        .take(4)
        .join(', ');
  }
  return data['graph_type']?.toString() ?? '';
}

String _tablePreviewText(Map<String, dynamic> data) {
  final columns = data['columns'];
  if (columns is List && columns.isNotEmpty) {
    return columns
        .whereType<Map>()
        .map((column) => column['name']?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  final rowCount = data['row_count']?.toString() ?? '';
  return rowCount.isEmpty ? '' : '$rowCount table rows';
}

class _ImageEvidencePreview extends StatelessWidget {
  const _ImageEvidencePreview({required this.index, required this.image});

  final int index;
  final Map<dynamic, dynamic> image;

  @override
  Widget build(BuildContext context) {
    final url = image['public_url']?.toString() ?? '';
    final description = image['description']?.toString() ?? '';
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
                  '$index',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: 208,
                height: 114,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 208,
                  height: 114,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x05000000),
                    border: Border.all(color: const Color(0x1A000000)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RootCauseIcon extends StatelessWidget {
  const _RootCauseIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RootCauseIconPainter());
  }
}

class _RootCauseIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _devGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = _devGreen
      ..style = PaintingStyle.fill;
    final top = Offset(size.width * .25, size.height * .2);
    final right = Offset(size.width * .72, size.height * .45);
    final bottom = Offset(size.width * .38, size.height * .78);
    canvas.drawLine(top, right, paint);
    canvas.drawLine(top, bottom, paint);
    canvas.drawCircle(top, 4, fill);
    canvas.drawCircle(right, 3, fill);
    canvas.drawCircle(bottom, 3, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CubesEvidenceIcon extends StatelessWidget {
  const _CubesEvidenceIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(100, 80), painter: _CubesPainter());
  }
}

class _CubesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _devGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    void cube(Offset center, double s) {
      final p1 = Offset(center.dx, center.dy - s * .45);
      final p2 = Offset(center.dx + s * .45, center.dy - s * .2);
      final p3 = Offset(center.dx + s * .45, center.dy + s * .3);
      final p4 = Offset(center.dx, center.dy + s * .55);
      final p5 = Offset(center.dx - s * .45, center.dy + s * .3);
      final p6 = Offset(center.dx - s * .45, center.dy - s * .2);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..lineTo(p5.dx, p5.dy)
        ..lineTo(p6.dx, p6.dy)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawLine(p1, center, paint);
      canvas.drawLine(p3, center, paint);
      canvas.drawLine(p5, center, paint);
    }

    cube(Offset(size.width * .28, size.height * .32), 32);
    cube(Offset(size.width * .53, size.height * .58), 32);
    cube(Offset(size.width * .76, size.height * .35), 32);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AffectedCommunitiesField extends StatelessWidget {
  const _AffectedCommunitiesField({
    required this.communities,
    required this.onAdd,
  });

  final List<_AffectedCommunity> communities;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who is affected?',
          style: TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
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
              const Text(
                'Identify groups or communities',
                style: TextStyle(color: Color(0x80000000), fontSize: 12),
              ),
              if (communities.isNotEmpty) const SizedBox(height: 14),
              for (final community in communities) ...[
                _AffectedCommunityRow(community: community),
                const SizedBox(height: 12),
              ],
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAdd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Add Communities',
                        style: TextStyle(
                          color: _devGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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
  const _AffectedCommunityRow({required this.community});

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
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Icon(Icons.more_horiz, color: Color(0x80000000), size: 18),
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
          padding: const EdgeInsets.fromLTRB(30, 22, 25, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
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
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
                  ],
                ),
                const SizedBox(height: 31),
                const Text(
                  'Choose an option',
                  style: TextStyle(color: Color(0x80000000), fontSize: 12),
                ),
                const SizedBox(height: 10),
                _AffectedChoiceCard(
                  icon: Icons.groups_outlined,
                  title: 'Choose an existing Juniper Journal Community',
                  subtitle: 'Find and add an organization that has an account.',
                  onTap: () async {
                    final result =
                        await showModalBottomSheet<_AffectedCommunity>(
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
                    final result = await Navigator.of(context)
                        .push<_AffectedCommunity>(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 286,
        height: 114,
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
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0x80000000),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
          width: 339,
          height: 326,
          padding: const EdgeInsets.fromLTRB(16, 18, 25, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: _devGreen, size: 22),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Communities',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Search',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 44,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Find Communities',
                    hintStyle: const TextStyle(color: Color(0x80000000)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
              const SizedBox(height: 34),
              const Text(
                'Your Communities',
                style: TextStyle(color: Colors.black, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No existing communities',
                          style: TextStyle(
                            color: Color(0x80000000),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          final community = filtered[index];
                          return _ExistingCommunityRow(
                            community: community,
                            onAdd: () => Navigator.of(
                              context,
                            ).pop(_AffectedCommunity.fromCommunity(community)),
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
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GestureDetector(
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 444),
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
                          left: -12,
                          top: 2,
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.chevron_left,
                              color: _devGreen,
                              size: 34,
                            ),
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Add New Organization',
                            style: TextStyle(
                              color: Color(0xFF1F2024),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 28),
                  _OrgField(
                    label: 'Location',
                    optional: true,
                    controller: _location,
                    height: 36,
                  ),
                  const SizedBox(height: 28),
                  _OrgField(
                    label: 'Description',
                    controller: _description,
                    height: 93,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 32),
                  Center(
                    child: GestureDetector(
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
                            color: Colors.white,
                            fontSize: 12,
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
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: [
              if (optional)
                const TextSpan(
                  text: ' (Optional)',
                  style: TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
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
      width: 328,
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
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        normalized,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0x80000000),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Website link',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0x80000000),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                const SizedBox(height: 14),
                const Text(
                  'Provide a link to\nsee preview.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x33000000),
                    fontSize: 14,
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
        child: Image.network(
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
    return GestureDetector(
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
                  color: _devGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              member.resolvedDisplayName,
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
            if (selected) const SizedBox(width: 10),
            if (selected) const Text('x', style: TextStyle(fontSize: 16)),
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

class _CollectionIcon extends StatelessWidget {
  const _CollectionIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CollectionPainter());
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

class _CollectionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _devGreen;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 7, size.width - 4, size.height - 7),
        const Radius.circular(2),
      ),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(6, 3, size.width - 12, 2), paint);
    canvas.drawRect(Rect.fromLTWH(8, 0, size.width - 16, 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _lastUpdatedDay(DateTime? date) {
  if (date == null) return 'Never';
  final now = DateTime.now();
  if (DateUtils.isSameDay(now, date)) return 'Today';
  return DateFormat('MMM d').format(date);
}

String _lastUpdatedTime(DateTime? date) {
  if (date == null) return '';
  return DateFormat('h:mm a').format(date);
}
