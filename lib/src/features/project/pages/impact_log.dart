import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/impact_entry_form.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ImpactLogScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final bool isOwner;

  const ImpactLogScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.isOwner = true,
  });

  @override
  State<ImpactLogScreen> createState() => _ImpactLogScreenState();
}

class _ImpactLogScreenState extends State<ImpactLogScreen> {
  final _repo = ProjectsRepo();

  bool _isLoading = true;
  List<ImpactEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await _repo.getImpactEntries(projectId: widget.projectId);
    if (!mounted) return;
    setState(() {
      _entries = result ?? const [];
      _isLoading = false;
    });
  }

  Future<void> _createEntry() async {
    final number = _entries.length + 1;
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ImpactEntryFormScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          initialTitle: 'Ecological Impact $number',
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _editEntry(ImpactEntry entry) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ImpactEntryFormScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: entry,
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _viewEntry(ImpactEntry entry) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ImpactEntryFormScreen(
          projectId: widget.projectId,
          projectName: widget.projectName,
          existing: entry,
          readOnly: true,
        ),
      ),
    );
  }

  Future<void> _deleteEntry(ImpactEntry entry) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete entry?'),
        content: const Text('This impact entry will be permanently removed.'),
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
    if (confirmed != true) return;

    final ok = await _repo.deleteImpactEntry(entryId: entry.id);
    if (!mounted) return;
    if (!ok) {
      showTopSnackBar(context, 'Failed to delete entry', isError: true);
      return;
    }
    _load();
  }

  String _formattedDate(DateTime? value) {
    if (value == null) return 'No date';
    return DateFormat('MMM d, yyyy • h:mm a').format(value.toLocal());
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No impact entries yet.', textAlign: TextAlign.center),
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

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    widget.isOwner ? _editEntry(entry) : _viewEntry(entry),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      // EcoPoints circle
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              entry.ecoPoints.toStringAsFixed(2),
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
                      const SizedBox(width: 12),
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
                            const SizedBox(height: 2),
                            // Metric + pattern chips
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _Chip(entry.metric, color: AppColors.primary),
                                _Chip(entry.patternType, color: Colors.black54),
                                _Chip(entry.impactScale, color: Colors.black38),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formattedDate(
                                entry.updatedAt ?? entry.createdAt,
                              ),
                              style: const TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                color: AppColors.textSecondary,
                                fontSize: AppTypography.helperSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isOwner)
                        IconButton(
                          tooltip: 'Delete entry',
                          onPressed: () => _deleteEntry(entry),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.black45,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.isOwner)
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: ContentAlignedBackButton(
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          '${widget.projectName} Impact',
          style: AppTypography.pageTitle,
        ),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          color: color,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
