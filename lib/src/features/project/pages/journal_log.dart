import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'project_development_flow.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import '../../../shared/widgets/journal_completion_tag.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/shared/widgets/user_avatar.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/journal_entry_editor.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

// ── EcoPoints helpers ─────────────────────────────────────────────────────────

const _progressBase = {
  'Discovering': 10.0,
  'Ideating': 20.0,
  'Prototyping': 50.0,
  'Testing & Iterating': 75.0,
  'Implemented': 100.0,
};

const _scaleMult = {'Small': 1.00, 'Medium': 1.40, 'Large': 1.90};

const _diffMult = {'Easy': 1.00, 'Medium': 1.25, 'Hard': 1.50};

double _progressEcoPoints(String? progress, String? scale, String? difficulty) {
  final base = _progressBase[progress] ?? 0.0;
  if (base == 0) return 0.0;
  final s = _scaleMult[scale] ?? 1.0;
  final d = _diffMult[difficulty] ?? 1.0;
  return double.parse((base * s * d).toStringAsFixed(2));
}

class JournalLogScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;

  /// When true, skips the Scaffold/AppBar so this widget can be embedded
  /// directly inside a TabBarView or other parent scaffold.
  final bool embedded;

  /// When false, hides create/delete controls and prevents editing.
  final bool isOwner;

  const JournalLogScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.tags,
    this.embedded = false,
    this.isOwner = true,
  });

  @override
  State<JournalLogScreen> createState() => _JournalLogScreenState();
}

class _JournalLogScreenState extends State<JournalLogScreen> {
  final _projectsRepo = ProjectsRepo();

  bool _isLoading = true;
  List<JournalEntry> _entries = const [];
  Map<String, double> _impactTotals = const {};
  String? _projectScale;
  String? _projectDifficulty;

  // Selection mode state
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);

    final futures = await Future.wait([
      _projectsRepo.getJournalEntries(projectId: widget.projectId),
      _projectsRepo.getImpactEntries(projectId: widget.projectId),
      _projectsRepo.getProjectById(widget.projectId),
    ]);

    if (!mounted) return;

    final entries =
        (futures[0] as List<JournalEntry>?) ?? const <JournalEntry>[];
    final impactEntries =
        (futures[1] as List<ImpactEntry>?) ?? const <ImpactEntry>[];
    final project = futures[2] as Project?;

    final totals = <String, double>{};
    for (final impact in impactEntries) {
      final linkedId = impact.linkedJournalEntryId;
      if (linkedId != null) {
        totals[linkedId] = (totals[linkedId] ?? 0.0) + impact.ecoPoints;
      }
    }

    setState(() {
      _entries = entries;
      _impactTotals = totals;
      _projectScale = project?.projectScale;
      _projectDifficulty = project?.difficulty;
      _isLoading = false;
    });
  }

  Future<void> _loadEntries() => _loadAll();

  void _enterSelectMode() => setState(() {
    _isSelecting = true;
    _selectedIds.clear();
  });

  void _exitSelectMode() => setState(() {
    _isSelecting = false;
    _selectedIds.clear();
  });

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $count ${count == 1 ? 'entry' : 'entries'}?'),
        content: Text(
          '$count journal ${count == 1 ? 'entry' : 'entries'} will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    int failed = 0;
    for (final id in _selectedIds) {
      final ok = await _projectsRepo.deleteJournalEntry(entryId: id);
      if (!ok) failed++;
    }

    if (!mounted) return;
    _exitSelectMode();
    _loadEntries();

    if (failed > 0) {
      showTopSnackBar(
        context,
        'Failed to delete $failed entries',
        isError: true,
      );
    }
  }

  Future<void> _createEntry() async {
    final project = await _projectsRepo.getProjectById(widget.projectId);
    if (!mounted) return;
    await openNewProjectJournal(
      context,
      projectId: widget.projectId,
      phase: project?.progress,
      projectsRepo: _projectsRepo,
    );
    if (mounted) await _loadEntries();
  }

  Future<void> _openEntry(JournalEntry entry) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => JournalEntryEditorScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          tags: widget.tags,
          entryId: entry.id,
          initialTitle: entry.title.isNotEmpty ? entry.title : 'Entry',
          initialContent: entry.content.isNotEmpty ? entry.content : const [],
          initialProgress: entry.progress,
          readOnly: !widget.isOwner,
        ),
      ),
    );

    if (!mounted) return;
    if (widget.isOwner) _loadEntries();
  }

  String _formattedDate(DateTime? value) {
    if (value == null) return 'No date';
    return DateFormat('MMM d, yyyy • h:mm a').format(value.toLocal());
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final imageUrls = entry.content
        .whereType<Map>()
        .where((b) => b['type'] == 'image')
        .map((b) => b['url']?.toString() ?? '')
        .where((u) => u.isNotEmpty)
        .toList();

    final progressPts = _progressEcoPoints(
      entry.progress,
      _projectScale,
      _projectDifficulty,
    );
    final impactPts = _impactTotals[entry.id] ?? 0.0;
    final totalPts = double.parse((progressPts + impactPts).toStringAsFixed(2));

    final isSelected = _selectedIds.contains(entry.id);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isSelecting
          ? () => _toggleSelection(entry.id)
          : () => _openEntry(entry),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  height: 140,
                  child: Row(
                    children: [
                      for (int i = 0; i < imageUrls.length && i < 3; i++)
                        Expanded(
                          child: Container(
                            decoration: i > 0
                                ? const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  )
                                : null,
                            child: Image.network(
                              imageUrls[i],
                              fit: BoxFit.cover,
                              height: 140,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade100,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.black26,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  if (_isSelecting)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.book_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title.isNotEmpty
                              ? entry.title
                              : 'Untitled Entry',
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontWeight: FontWeight.w500,
                            fontSize: AppTypography.bodySize,
                          ),
                        ),
                        const SizedBox(height: 8),
                        JournalCompletionTag(entry: entry),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _formattedDate(
                                  entry.updatedAt ?? entry.createdAt,
                                ),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: AppTypography.helperSize,
                                ),
                              ),
                            ),
                            if (entry.progress != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  entry.progress!,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.helperSize,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (entry.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: entry.tags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.captionSize,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!_isSelecting) ...[
                    if (totalPts > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              totalPts.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.primary,
                              ),
                            ),
                            const Text(
                              'EP',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.captionSize,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    _AuthorAvatar(
                      avatarUrl: entry.authorAvatarUrl,
                      displayName: entry.authorDisplayName,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No journal entries yet.', textAlign: TextAlign.center),
            if (widget.isOwner) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _createEntry,
                icon: const Icon(Icons.add),
                label: const Text('New Entry'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => _buildEntryCard(_entries[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Embedded mode ─────────────────────────────────────────────────────────
    if (widget.embedded) {
      return Stack(
        children: [
          _buildBody(),
          if (widget.isOwner && !_isLoading && _entries.isNotEmpty) ...[
            if (_isSelecting)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _exitSelectMode,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : _deleteSelected,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          _selectedIds.isEmpty
                              ? 'Delete'
                              : 'Delete (${_selectedIds.length})',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor: AppColors.error.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  backgroundColor: AppColors.primary,
                  onPressed: _createEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('New Entry'),
                ),
              ),
          ],
        ],
      );
    }

    // ── Full-screen mode ──────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 56,
        leadingWidth: _isSelecting ? 72 : 84,
        leading: _isSelecting
            ? TextButton(
                onPressed: _exitSelectMode,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Cancel', maxLines: 1),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 40),
                child: ContentAlignedBackButton(
                  onPressed: () => Navigator.pop(context),
                ),
              ),
        title: Text(
          _isSelecting
              ? (_selectedIds.isEmpty
                    ? 'Select entries'
                    : '${_selectedIds.length} selected')
              : '${widget.projectName} Journal',
          style: AppTypography.pageTitle,
        ),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
        actions: [
          if (widget.isOwner && _entries.isNotEmpty)
            if (_isSelecting)
              TextButton(
                onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                child: Text(
                  _selectedIds.isEmpty
                      ? 'Delete'
                      : 'Delete (${_selectedIds.length})',
                  style: TextStyle(
                    color: _selectedIds.isEmpty
                        ? Colors.black26
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              TextButton(
                onPressed: _enterSelectMode,
                child: const Text('Edit'),
              ),
        ],
      ),
      floatingActionButton: widget.isOwner && !_isSelecting
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _createEntry,
              icon: const Icon(Icons.add),
              label: const Text('New Entry'),
            )
          : null,
      body: SafeArea(child: _buildBody()),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.avatarUrl, this.displayName});

  final String? avatarUrl;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: displayName ?? '',
      child: UserAvatar(avatarUrl: avatarUrl, radius: 14),
    );
  }
}
