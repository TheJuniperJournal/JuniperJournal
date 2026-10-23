import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/widgets/impact_icon.dart';
import 'package:juniper_journal/src/shared/widgets/optional_field_label.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/pill_selector.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

// ── Option lists ──────────────────────────────────────────────────────────────

const _metrics = ['Biological Growth', 'Energy', 'Education', 'Waste', 'Water'];

const _scales = [
  'Seed (Very Small)',
  'Sapling (Small)',
  'Grove (Moderate)',
  'Forest (Large)',
  'Watershed (Very Large)',
];

const _evidenceTypes = ['Photo', 'Measurement', 'Calculation Estimate'];

const _confidenceScores = ['Low', 'Medium', 'High'];

/// Valid metric → pattern → measurement unit combinations.
/// Pattern options are taken exactly from the Figma pattern-change frames
/// (Energy/Water/Waste 8484:38069/38119/38094, Biological 8484:38028,
/// Educational 8484:38053). Units cascade from this map only.
const _combinations = {
  'Energy': {
    'Reduction': ['kWh'],
    'Substitution': ['kWh'],
    'Behavior Change': ['people', 'units'],
    'Capacity Building': ['people'],
  },
  'Water': {
    'Reduction': ['kg'],
    'Substitution': ['kg'],
    'Behavior Change': ['people', 'kg'],
    'Capacity Building': ['people'],
  },
  'Waste': {
    'Reduction': ['kg', 'units'],
    'Substitution': ['kg', 'units'],
    'Behavior Change': ['people', 'units'],
    'Capacity Building': ['people'],
  },
  'Biological Growth': {
    'Regeneration': ['sq.ft', 'units'],
    'Behavior Change': ['people'],
    'Capacity Building': ['people'],
  },
  'Education': {
    'Behavior Change': ['people'],
    'Capacity Building': ['people'],
  },
};

const _metricDescriptions = {
  'Education': 'Measures learning and knowledge outcomes',
  'Energy': 'Measures energy use and consumption',
  'Waste': 'Measures waste diverted and generated',
  'Water': 'Measures water use and consumption',
  'Biological Growth': 'Measures ecological growth and restoration',
};

String _metricIcon(String metric) => impactIconAsset('Metrics', metric);
String _patternIcon(String pattern) => impactIconAsset('Pattern', pattern);
String _scaleIcon(String scale) => impactIconAsset('Impact', scale);

/// The size suffix shown under each scale name, e.g. "Grove" → "(Medium)".
/// Figma labels Grove as "(Medium)" even though the eco-points key is
/// "Grove (Moderate)".
String _scaleSize(String scale) => switch (scale) {
  'Seed (Very Small)' => '(Very Small)',
  'Sapling (Small)' => '(Small)',
  'Grove (Moderate)' => '(Medium)',
  'Forest (Large)' => '(Large)',
  _ => '(Very Large)',
};

String _scaleName(String scale) => scale.split(' (').first;

// ── Screen ────────────────────────────────────────────────────────────────────

class ImpactEntryFormScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String? initialTitle;
  final ImpactEntry? existing;
  final bool readOnly;

  /// When set, the impact is scoped to this journal entry and the
  /// "Link to Journal Log" picker is hidden (used by the Implementation
  /// Assessment stage).
  final String? lockedJournalEntryId;

  const ImpactEntryFormScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.initialTitle,
    this.existing,
    this.readOnly = false,
    this.lockedJournalEntryId,
  });

  @override
  State<ImpactEntryFormScreen> createState() => _ImpactEntryFormScreenState();
}

class _ImpactEntryFormScreenState extends State<ImpactEntryFormScreen> {
  final _repo = ProjectsRepo();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _measurementCtrl;

  String? _metric;
  String? _patternType;
  String? _impactScale;
  String? _evidenceType;
  String? _confidenceScore;
  String? _measurementUnit;
  String? _linkedJournalEntryId;

  List<JournalEntry> _journalEntries = const [];
  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  List<String> get _validPatterns =>
      _metric == null ? [] : List<String>.from(_combinations[_metric]!.keys);

  List<String> get _validUnits => (_metric == null || _patternType == null)
      ? []
      : List<String>.from((_combinations[_metric]?[_patternType]) ?? const []);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(
      text: e?.title ?? widget.initialTitle ?? '',
    );
    _titleCtrl.addListener(() => setState(() {}));
    _measurementCtrl = TextEditingController(
      text: e?.measurement?.toString() ?? '',
    );
    _measurementCtrl.addListener(() => setState(() {}));

    _metric = e?.metric;
    _patternType = e?.patternType;
    _impactScale = e?.impactScale;
    _evidenceType = e?.evidenceType;
    _confidenceScore = e?.confidenceScore;
    _measurementUnit = e?.measurementUnit;
    _linkedJournalEntryId =
        e?.linkedJournalEntryId ?? widget.lockedJournalEntryId;

    _loadJournalEntries();
  }

  Future<void> _loadJournalEntries() async {
    final entries = await _repo.getJournalEntries(projectId: widget.projectId);
    if (!mounted) return;
    setState(() {
      _journalEntries = entries ?? const [];
      // Default to most recent entry if none pre-selected
      if (_linkedJournalEntryId == null && _journalEntries.isNotEmpty) {
        _linkedJournalEntryId = _journalEntries.first.id;
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _measurementCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _missingFields.isEmpty;

  List<String> get _missingFields {
    final missing = <String>[];
    if (_titleCtrl.text.trim().isEmpty) missing.add('Title');
    if (_metric == null) missing.add('Metric');
    if (_patternType == null) missing.add('Pattern Type');
    if (_impactScale == null) missing.add('Impact Scale');
    if (_evidenceType == null) missing.add('Evidence Type');
    if (_confidenceScore == null) missing.add('Confidence Score');
    if (_linkedJournalEntryId == null) missing.add('Link to Journal Log');
    return missing;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSaving) return;
    setState(() => _isSaving = true);

    final measurement = double.tryParse(_measurementCtrl.text.trim());
    // The server validates and calculates the reward.
    const pts = 0.0;

    bool ok;
    if (_isEdit) {
      ok = await _repo.updateImpactEntry(
        entryId: widget.existing!.id,
        title: _titleCtrl.text.trim(),
        metric: _metric!,
        impactScale: _impactScale!,
        patternType: _patternType!,
        evidenceType: _evidenceType!,
        confidenceScore: _confidenceScore!,
        measurement: measurement,
        measurementUnit: measurement != null ? _measurementUnit : null,
        ecoPoints: pts,
        linkedJournalEntryId: _linkedJournalEntryId,
      );
    } else {
      final created = await _repo.createImpactEntry(
        projectId: widget.projectId,
        title: _titleCtrl.text.trim(),
        metric: _metric!,
        impactScale: _impactScale!,
        patternType: _patternType!,
        evidenceType: _evidenceType!,
        confidenceScore: _confidenceScore!,
        measurement: measurement,
        measurementUnit: measurement != null ? _measurementUnit : null,
        ecoPoints: pts,
        linkedJournalEntryId: _linkedJournalEntryId,
      );
      ok = created != null;
    }

    // Add metric as tag to linked journal entry
    if (ok && _linkedJournalEntryId != null) {
      await _repo.addTagToJournalEntry(
        journalEntryId: _linkedJournalEntryId!,
        tag: _metric!,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      showTopSnackBar(context, 'Failed to save impact entry', isError: true);
      return;
    }
    Navigator.of(context).pop();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: ContentAlignedBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('Impact Entry', style: AppTypography.pageTitle),
        actions: widget.readOnly
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      'Read Only',
                      style: TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        fontSize: AppTypography.pageTitleSize,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ]
            : null,
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      body: AbsorbPointer(
        absorbing: widget.readOnly,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Impact Title'),
              const SizedBox(height: AppMetrics.labelGap),
              TextField(
                controller: _titleCtrl,
                readOnly: widget.readOnly,
                textAlign: TextAlign.left,
                style: AppTypography.inputText,
                decoration: const InputDecoration(
                  hintText: 'Name this impact',
                  constraints: BoxConstraints(minHeight: 64),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.sectionGap),
              // ── Metric ──────────────────────────────────────────────────────
              _label('Metric'),
              const SizedBox(height: 4),
              const Text(
                'What type of impact does this represent?',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              for (final metric in _metrics)
                _MetricCard(
                  metric: metric,
                  description: _metricDescriptions[metric] ?? '',
                  selected: _metric == metric,
                  onTap: () => _selectMetric(metric),
                ),
              const SizedBox(height: AppMetrics.labelGap),

              // ── Pattern Type ────────────────────────────────────────────────
              _label('Pattern Type'),
              const SizedBox(height: 4),
              const Text(
                'What kind of change did you create?',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_metric == null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Select a metric to choose a pattern type.',
                    style: AppTypography.helper,
                  ),
                ),
              const SizedBox(height: 8),
              _PatternField(
                value: _patternType,
                options: _validPatterns,
                enabled: _metric != null,
                onSelected: _selectPattern,
              ),
              const SizedBox(height: AppMetrics.labelGap),

              // ── Impact Scale ────────────────────────────────────────────────
              _label('Impact Scale'),
              const SizedBox(height: 4),
              const Text(
                'How big was the impact of your project?',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 560
                      ? 5
                      : constraints.maxWidth >= 360
                      ? 3
                      : 2;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Column(
                    children: [
                      for (
                        var start = 0;
                        start < _scales.length;
                        start += columns
                      ) ...[
                        if (start > 0) const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var index = start;
                                index < _scales.length &&
                                    index < start + columns;
                                index++
                              ) ...[
                                if (index > start) const SizedBox(width: 12),
                                SizedBox(
                                  width: width,
                                  child: _ScaleCard(
                                    scale: _scales[index],
                                    selected: _impactScale == _scales[index],
                                    onTap: () => setState(
                                      () => _impactScale = _scales[index],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Measurement ─────────────────────────────────────────────────
              _label('Measurement (optional)'),
              const SizedBox(height: 4),
              const Text(
                'Add a number to quantify your impact.',
                style: AppTypography.helper,
              ),
              const SizedBox(height: 8),
              // Locked until pattern is chosen (unit list drives valid units)
              AbsorbPointer(
                absorbing: _patternType == null,
                child: Opacity(
                  opacity: _patternType == null ? 0.4 : 1.0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _measurementCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PillSelector(
                          value: _measurementUnit,
                          placeholder: 'Unit',
                          items: _validUnits,
                          onChanged: (v) =>
                              setState(() => _measurementUnit = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Evidence Type (left) + Confidence Score (right) ─────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Evidence Type'),
                        const SizedBox(height: 2),
                        const Text(
                          'How did you verify this?',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.helperSize,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        PillSelector(
                          value: _evidenceType,
                          placeholder: 'Select',
                          items: _evidenceTypes,
                          onChanged: (v) => setState(() => _evidenceType = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Confidence Score'),
                        const SizedBox(height: 2),
                        const Text(
                          'How confident are you?',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.helperSize,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        PillSelector(
                          value: _confidenceScore,
                          placeholder: 'Select',
                          items: _confidenceScores,
                          onChanged: (v) =>
                              setState(() => _confidenceScore = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Link to Journal ──────────────────────────────────────────────
              if (widget.lockedJournalEntryId == null) ...[
                _label('Link to Journal Log'),
                const SizedBox(height: 6),
                if (_journalEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.orange.shade50,
                    ),
                    child: const Text(
                      'No journal entries yet — create one first.',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        color: Colors.deepOrange,
                      ),
                    ),
                  )
                else
                  PillSelector(
                    value: _journalEntries
                        .where((e) => e.id == _linkedJournalEntryId)
                        .map(
                          (e) =>
                              e.title.isNotEmpty ? e.title : 'Untitled Entry',
                        )
                        .firstOrNull,
                    placeholder: 'None',
                    items: _journalEntries
                        .map(
                          (e) =>
                              e.title.isNotEmpty ? e.title : 'Untitled Entry',
                        )
                        .toList(),
                    onChanged: (title) {
                      final entry = _journalEntries
                          .where(
                            (e) =>
                                (e.title.isNotEmpty
                                    ? e.title
                                    : 'Untitled Entry') ==
                                title,
                          )
                          .firstOrNull;
                      setState(() => _linkedJournalEntryId = entry?.id);
                    },
                  ),
                const SizedBox(height: AppMetrics.fieldGap),
              ],

              if (!widget.readOnly)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _canSubmit && !_isSaving ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isEdit ? 'Save' : 'Add Impact',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.buttonSize,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
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

  void _selectMetric(String metric) {
    setState(() {
      _metric = metric;
      // Cascade: clear pattern/unit if no longer valid for the new metric.
      if (_patternType != null &&
          !(_combinations[metric]?.containsKey(_patternType) ?? false)) {
        _patternType = null;
        _measurementUnit = null;
      } else if (_measurementUnit != null && _patternType != null) {
        if (!(_combinations[metric]?[_patternType]?.contains(
              _measurementUnit,
            ) ??
            false)) {
          _measurementUnit = null;
        }
      }
    });
  }

  void _selectPattern(String pattern) {
    setState(() {
      _patternType = pattern;
      if (_measurementUnit != null &&
          !(_combinations[_metric]?[pattern]?.contains(_measurementUnit) ??
              false)) {
        _measurementUnit = null;
      }
      final units = _combinations[_metric]?[pattern] ?? const [];
      if (units.length == 1) _measurementUnit = units.first;
    });
  }

  Widget _label(String text) => OptionalFieldLabel(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
  );
}

// ── Metric / Scale / Pattern selectors (icon-based, from Figma) ───────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String metric;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: AppColors.primary,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SvgPicture.asset(_metricIcon(metric), width: 34, height: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      color: AppColors.textSecondary,
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

class _ScaleCard extends StatelessWidget {
  const _ScaleCard({
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  final String scale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: AppColors.primary,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SvgPicture.asset(_scaleIcon(scale), width: 40, height: 40),
            const SizedBox(height: 8),
            Text(
              _scaleName(scale),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
            Text(
              _scaleSize(scale),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _patternExplanation(String value) => switch (value) {
  'Reduction' =>
    'Use fewer resources or create less waste. For example, reduce water use or food waste.',
  'Substitution' =>
    'Replace a material or process with a lower-impact alternative. For example, use reusable containers instead of disposables.',
  'Regeneration' =>
    'Restore or renew natural systems. For example, improve soil health or plant native habitat.',
  'Behavior Change' =>
    'Help people adopt more sustainable habits. For example, encourage regular composting or switching off unused lights.',
  'Capacity Building' =>
    'Build the skills, tools, or support people need to keep making progress. For example, teach composting skills or provide shared equipment.',
  _ => '',
};

class _PatternField extends StatelessWidget {
  const _PatternField({
    required this.value,
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final String? value;
  final List<String> options;
  final bool enabled;
  final ValueChanged<String> onSelected;

  Future<void> _open(BuildContext context) async {
    final selected = await showAppModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      showDragHandle: true,
      enableDrag: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pattern Type',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close pattern chooser',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how your project creates change.',
                style: AppTypography.helper,
              ),
              const SizedBox(height: 16),
              for (final option in options)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  minLeadingWidth: 32,
                  leading: SvgPicture.asset(
                    _patternIcon(option),
                    width: 26,
                    height: 26,
                  ),
                  title: Text(option, style: AppTypography.fieldLabel),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _patternExplanation(option),
                      style: AppTypography.helper,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => _open(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (value != null) ...[
              SvgPicture.asset(_patternIcon(value!), width: 22, height: 22),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                value ??
                    (enabled ? 'Select a pattern' : 'Select a metric above'),
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: value == null ? Colors.black38 : Colors.black87,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}
