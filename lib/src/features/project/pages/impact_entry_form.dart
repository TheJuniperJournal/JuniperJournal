import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/utils/eco_points_calculator.dart';
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

String _metricIcon(String metric) => switch (metric) {
  'Education' => 'assets/impact/metric_education.png',
  'Energy' => 'assets/impact/metric_energy.png',
  'Waste' => 'assets/impact/metric_waste.png',
  'Water' => 'assets/impact/metric_water.png',
  _ => 'assets/impact/metric_biological.png',
};

String _patternIcon(String pattern) => switch (pattern) {
  'Reduction' => 'assets/impact/pattern_reduction.png',
  'Substitution' => 'assets/impact/pattern_substitution.png',
  'Behavior Change' => 'assets/impact/pattern_behavior_change.png',
  'Capacity Building' => 'assets/impact/pattern_capacity_building.png',
  _ => 'assets/impact/pattern_regeneration.png',
};

String _scaleIcon(String scale) => switch (scale) {
  'Seed (Very Small)' => 'assets/impact/scale_seed.png',
  'Sapling (Small)' => 'assets/impact/scale_sapling.png',
  'Grove (Moderate)' => 'assets/impact/scale_grove.png',
  'Forest (Large)' => 'assets/impact/scale_forest.png',
  _ => 'assets/impact/scale_watershed.png',
};

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

  double get _ecoPoints => calculateEcoPoints(
    impactScale: _impactScale,
    confidenceScore: _confidenceScore,
    measurement: double.tryParse(_measurementCtrl.text),
    measurementUnit: _measurementUnit,
  );

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
    final pts = _ecoPoints;

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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.readOnly
            ? Text(
                _titleCtrl.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              )
            : TextField(
                controller: _titleCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
        actions: widget.readOnly
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Text(
                      'Read Only',
                      style: TextStyle(
                        fontSize: 12,
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
              // ── Metric ──────────────────────────────────────────────────────
              _label('Metric'),
              const SizedBox(height: 4),
              const Text(
                'What type of impact does this represent?',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              for (final metric in _metrics)
                _MetricCard(
                  metric: metric,
                  description: _metricDescriptions[metric] ?? '',
                  selected: _metric == metric,
                  onTap: () => _selectMetric(metric),
                ),
              const SizedBox(height: 18),

              // ── Pattern Type ────────────────────────────────────────────────
              _label('Pattern Type'),
              const SizedBox(height: 4),
              const Text(
                'What kind of change did you create?',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              _PatternField(
                value: _patternType,
                options: _validPatterns,
                enabled: _metric != null,
                onSelected: _selectPattern,
              ),
              const SizedBox(height: 18),

              // ── Impact Scale ────────────────────────────────────────────────
              _label('Impact Scale'),
              const SizedBox(height: 4),
              const Text(
                'How big was the impact of your project?',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: _patternType == null ? 0.4 : 1.0,
                child: AbsorbPointer(
                  absorbing: _patternType == null,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final scale in _scales)
                        _ScaleCard(
                          scale: scale,
                          selected: _impactScale == scale,
                          onTap: () => setState(() => _impactScale = scale),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Measurement ─────────────────────────────────────────────────
              _label('Measurement (Optional)'),
              const SizedBox(height: 4),
              const Text(
                'Add a number to quantify your impact.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
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
                            hintText: '0',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
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
                                color: AppColors.primary,
                                width: 1.5,
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
              const SizedBox(height: 24),

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
                          style: TextStyle(fontSize: 12, color: Colors.black54),
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
                          style: TextStyle(fontSize: 12, color: Colors.black54),
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
              const SizedBox(height: 24),

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
                      style: TextStyle(fontSize: 13, color: Colors.deepOrange),
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
                const SizedBox(height: 24),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
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
              : const Color(0xFFF7F7F7),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Image.asset(_metricIcon(metric), width: 34, height: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : const Color(0xFFF7F7F7),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE5E5E5),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Image.asset(_scaleIcon(scale), width: 40, height: 40),
            const SizedBox(height: 8),
            Text(
              _scaleName(scale),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            Text(
              _scaleSize(scale),
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              ListTile(
                leading: Image.asset(
                  _patternIcon(option),
                  width: 26,
                  height: 26,
                ),
                title: Text(
                  option,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
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
          color: enabled ? Colors.white : const Color(0xFFF2F2F2),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (value != null) ...[
              Image.asset(_patternIcon(value!), width: 22, height: 22),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                value ??
                    (enabled ? 'Select a pattern' : 'Select a metric above'),
                style: TextStyle(
                  fontSize: 14,
                  color: value == null ? Colors.black38 : Colors.black87,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
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
