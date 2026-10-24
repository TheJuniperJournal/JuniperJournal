import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';
import '../../../backend/db/repositories/projects_repo.dart';

// Domain → Focus options (shared constant)
const _focusByDomain = <String, List<String>>{
  'Environment & Sustainability': [
    'Ecosystems & Biodiversity',
    'Climate & Weather Patterns',
    'Human Impact on Natural Systems',
    'Natural Resources & Conservation',
    'Pollution and Waste Management',
  ],
  'Engineering & Design': [
    'Defining and Delimiting Engineering Problems',
    'Designing Solutions and Prototyping',
    'Materials and Their Properties',
    'Iteration and Improvement Processes',
    'Sustainable Innovation and Practices',
  ],
  'Energy & Systems': [
    'Energy Sources and Forms',
    'Energy Transfer and Transformation',
    'Renewable and Nonrenewable Resources',
    'Efficiency and Conservation of Energy',
    'Energy Flow in Natural and Engineered Systems',
  ],
  'Community & Built Environment': [
    'Sustainable Communities and Urban Planning',
    'Green Building and Infrastructure',
    'Transportation and Mobility Systems',
    'Public Space Design and Equity',
    'Interaction Between Human and Natural Environments',
  ],
};

typedef _SubjectTag = ({String domain, String focus});

class DefineProblemStatementScreen extends StatefulWidget {
  final String projectId;

  const DefineProblemStatementScreen({super.key, required this.projectId});

  @override
  State<DefineProblemStatementScreen> createState() =>
      _DefineProblemStatementScreenState();
}

class _DefineProblemStatementScreenState
    extends State<DefineProblemStatementScreen> {
  final _problemController = TextEditingController();
  final _projectsRepo = ProjectsRepo();

  bool _isSaving = false;
  bool _hasChanges = false;
  DateTime? _lastSavedAt;
  Timer? _autoSaveTimer;
  String _projectName = '';

  // Subject tags
  String? _activeDomain;
  String? _activeFocus;
  final List<_SubjectTag> _subjectTags = [];

  String? _selectedDifficulty;
  String? _selectedScale;
  String? _selectedVisibility;

  @override
  void initState() {
    super.initState();
    _problemController.addListener(() => _hasChanges = true);
    _autoSaveTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _autoSave(),
    );
    _loadProject();
  }

  Future<void> _loadProject() async {
    final project = await _projectsRepo.getProjectById(widget.projectId);
    if (!mounted) return;

    _problemController.removeListener(() => _hasChanges = true);
    _problemController.text = project?.problemStatement ?? '';
    _problemController.addListener(() => _hasChanges = true);

    // Parse stored "Domain|Focus" tag strings
    final tags = (project?.tags ?? [])
        .map((s) {
          final parts = s.split('|');
          if (parts.length == 2) {
            return (domain: parts[0].trim(), focus: parts[1].trim());
          }
          return null;
        })
        .whereType<_SubjectTag>()
        .toList();

    setState(() {
      _projectName = project?.projectName ?? '';
      _subjectTags
        ..clear()
        ..addAll(tags);
      _selectedDifficulty = project?.difficulty;
      _selectedScale = project?.projectScale;
      _selectedVisibility = project?.visibility;
      _hasChanges = false;
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _problemController.dispose();
    super.dispose();
  }

  String? get _savedLabel {
    if (_lastSavedAt == null) return null;
    final h = _lastSavedAt!.hour % 12 == 0 ? 12 : _lastSavedAt!.hour % 12;
    final m = _lastSavedAt!.minute.toString().padLeft(2, '0');
    final ampm = _lastSavedAt!.hour < 12 ? 'AM' : 'PM';
    return 'Saved $h:$m $ampm';
  }

  Future<bool> _persist() async {
    final tags = _subjectTags.map((t) => '${t.domain}|${t.focus}').toList();
    return _projectsRepo.updateProjectConfiguration(
      id: widget.projectId,
      problemStatement: _problemController.text.trim(),
      difficulty: _selectedDifficulty,
      tags: tags,
      projectScale: _selectedScale,
      visibility: _selectedVisibility,
    );
  }

  Future<void> _autoSave() async {
    if (_isSaving || !_hasChanges) return;
    setState(() => _isSaving = true);
    final ok = await _persist();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) {
        _lastSavedAt = DateTime.now();
        _hasChanges = false;
      }
    });
  }

  Future<void> _saveAndPop() async {
    if (_isSaving) return;
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    await _persist();
    if (!mounted) return;
    setState(() => _isSaving = false);
    navigator.pop();
  }

  void _addSubjectTag() {
    if (_activeDomain == null || _activeFocus == null) return;
    final domain = _activeDomain!;
    final focus = _activeFocus!;
    if (_subjectTags.any((t) => t.domain == domain && t.focus == focus)) {
      setState(() {
        _activeDomain = null;
        _activeFocus = null;
      });
      return;
    }
    setState(() {
      _subjectTags.add((domain: domain, focus: focus));
      _activeDomain = null;
      _activeFocus = null;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final canAddTag = _activeDomain != null && _activeFocus != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 60,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: ContentAlignedBackButton(onPressed: _saveAndPop),
          ),
          centerTitle: false,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _projectName,
                style: const TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  fontSize: AppTypography.pageTitleSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                dateStr,
                style: TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  fontSize: AppTypography.pageTitleSize,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          bottom: _savedLabel == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(28),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        _savedLabel!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          fontSize: AppTypography.pageTitleSize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: PageScrollWithFooter(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Problem Statement ─────────────────────────────────────────
                _sectionLabel('Problem Statement'),
                const SizedBox(height: 10),
                TextFormField(
                  minLines: 5,
                  controller: _problemController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: '',
                    hintStyle: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: AppColors.hintText,
                      fontSize: AppTypography.helperSize,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.borderLight,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppMetrics.fieldGap),

                // ── Subject Domain & Focus ────────────────────────────────────
                _sectionLabel('Subject Domain & Focus'),
                const SizedBox(height: 10),

                if (_subjectTags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _subjectTags
                        .map(
                          (t) => _SubjectTagChip(
                            domain: t.domain,
                            focus: t.focus,
                            onRemove: () => setState(() {
                              _subjectTags.remove(t);
                              _hasChanges = true;
                            }),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domain',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      PillSelector(
                        value: _activeDomain,
                        placeholder: 'Select',
                        items: _focusByDomain.keys.toList(),
                        onChanged: (v) => setState(() {
                          _activeDomain = v;
                          _activeFocus = null;
                          _hasChanges = true;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Icon(
                          Icons.add,
                          size: 18,
                          color: AppColors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Focus',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      PillSelector(
                        value: _activeFocus,
                        placeholder: _activeDomain == null
                            ? 'Pick domain first'
                            : 'Select',
                        items: _activeDomain != null
                            ? _focusByDomain[_activeDomain]!
                            : [],
                        onChanged: (v) => setState(() => _activeFocus = v),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canAddTag ? _addSubjectTag : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: Colors.grey.shade200,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: Icon(
                            Icons.add,
                            size: 16,
                            color: canAddTag
                                ? Colors.white
                                : Colors.grey.shade400,
                          ),
                          label: Text(
                            'Add Combination',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.buttonSize,
                              fontWeight: FontWeight.w500,
                              color: canAddTag
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppMetrics.fieldGap),

                // ── Difficulty ────────────────────────────────────────────────
                _sectionLabel('Difficulty'),
                const SizedBox(height: 10),
                PillSelector(
                  value: _selectedDifficulty,
                  placeholder: 'Select Difficulty',
                  items: const ['Easy', 'Medium', 'Hard'],
                  onChanged: (v) => setState(() {
                    _selectedDifficulty = v;
                    _hasChanges = true;
                  }),
                ),

                const SizedBox(height: AppMetrics.fieldGap),

                // ── Project Scale ─────────────────────────────────────────────
                _sectionLabel('Project Scale'),
                const SizedBox(height: 10),
                PillSelector(
                  value: _selectedScale,
                  placeholder: 'Select Scale',
                  items: const ['Small', 'Medium', 'Large'],
                  onChanged: (v) => setState(() {
                    _selectedScale = v;
                    _hasChanges = true;
                  }),
                ),

                const SizedBox(height: AppMetrics.fieldGap),

                // ── Visibility ────────────────────────────────────────────────
                _sectionLabel('Visibility'),
                const SizedBox(height: 10),
                if (_selectedVisibility == 'Community Only')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Community Only',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  PillSelector(
                    value: _selectedVisibility,
                    placeholder: 'Select Visibility',
                    items: const ['Private', 'Friends Only', 'Public'],
                    onChanged: (v) => setState(() {
                      _selectedVisibility = v;
                      _hasChanges = true;
                    }),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
  );
}

// ── _SubjectTagChip ──────────────────────────────────────────────────────────

class _SubjectTagChip extends StatelessWidget {
  const _SubjectTagChip({
    required this.domain,
    required this.focus,
    required this.onRemove,
  });

  final String domain;
  final String focus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$domain • $focus',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AppTapTarget(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
