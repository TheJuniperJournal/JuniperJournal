import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';

class Summary extends StatefulWidget {
  final Map<String, dynamic>? module;

  const Summary({super.key, this.module});

  @override
  State<Summary> createState() => _SummaryState();
}

class _SummaryState extends State<Summary> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFF666666);
  static const _border = Color(0xFFD8D0D0);
  static const _screenWidth = 393.0;

  static const _dciOptions = [
    'Ecosystems & Biodiversity',
    'Climate & Weather Patterns',
    'Human Impact on Natural Systems',
    'Natural Resources & Conservation',
    'Pollution and Waste Management',
  ];
  static const _sepOptions = [
    'Asking Questions & Defining Problems',
    'Planning & Conducting Investigations',
    'Analyzing & Interpreting Data',
    'Constructing Explanations',
    'Designing Solutions',
  ];
  static const _cccOptions = [
    'Patterns',
    'Cause & Effect',
    'Systems & System Models',
    'Energy & Matter',
    'Stability & Change',
  ];

  final _repo = LearningModuleRepo();
  Map<String, dynamic> _module = const {};
  Map<String, bool> _dci = {for (final option in _dciOptions) option: false};
  Map<String, bool> _sep = {for (final option in _sepOptions) option: false};
  Map<String, bool> _ccc = {for (final option in _cccOptions) option: false};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final base = widget.module ?? {};
    final moduleId = base['id']?.toString();
    final fresh = moduleId == null || moduleId.isEmpty
        ? null
        : await _repo.getModule(moduleId);
    final merged = {...base, if (fresh != null) ...fresh};
    _hydrateSummary(merged['summary']);
    if (mounted) {
      setState(() {
        _module = merged;
        _loading = false;
      });
    }
  }

  void _hydrateSummary(dynamic raw) {
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map) return;
      final checklist = decoded['checklist'];
      if (checklist is! Map) return;
      _dci = _mergeChecklist(_dciOptions, checklist['dci']);
      _sep = _mergeChecklist(_sepOptions, checklist['sep']);
      _ccc = _mergeChecklist(_cccOptions, checklist['ccc']);
    } catch (_) {
      // Legacy summary text is intentionally ignored.
    }
  }

  Map<String, bool> _mergeChecklist(List<String> options, dynamic raw) {
    final source = raw is Map ? raw : const {};
    return {
      for (final option in options)
        option:
            source[option] == true ||
            source[option]?.toString().toLowerCase() == 'true',
    };
  }

  Future<void> _toggle(String group, String option, bool value) async {
    setState(() {
      switch (group) {
        case 'dci':
          _dci[option] = value;
          break;
        case 'sep':
          _sep[option] = value;
          break;
        case 'ccc':
          _ccc[option] = value;
          break;
      }
    });
    await _persist();
  }

  Future<void> _persist() async {
    final moduleId = _module['id']?.toString();
    if (moduleId == null || moduleId.isEmpty) return;
    final document = {
      'version': 1,
      'checklist': {'dci': _dci, 'sep': _sep, 'ccc': _ccc},
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final saved = await _repo.updateSummary(
      id: moduleId,
      summary: jsonEncode(document),
    );
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save summary choices.'),
          backgroundColor: Color(0xFFD12E2E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _title =>
      _firstString(_module['module_name']) ??
      _firstString(_module['title']) ??
      '';

  String get _difficulty => _firstString(_module['difficulty']) ?? '';

  String get _subjectDomain {
    final raw = _module['subject_domain'] ?? _module['domains'];
    final values = _stringValues(raw);
    return values.isNotEmpty ? values.first : '';
  }

  String get _subjectFocus {
    final combined = _stringValues(_module['subject_domain']);
    if (combined.length > 1) return combined[1];
    return _stringValues(_module['subject_focus']).firstOrNull ?? '';
  }

  List<String> get _objectives {
    final raw = _module['learning_objectives'] ?? _module['learning_objective'];
    final entries = raw is List
        ? raw
        : raw == null
        ? const []
        : [raw];
    return [
      for (final entry in entries)
        if (_objectiveText(entry).isNotEmpty) _objectiveText(entry),
    ];
  }

  String _objectiveText(dynamic entry) {
    final text = entry?.toString().trim() ?? '';
    if (text.isEmpty) return '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded['description']?.toString().trim() ??
            decoded['objective_text']?.toString().trim() ??
            '';
      }
    } catch (_) {
      return text;
    }
    return text;
  }

  String? _firstString(dynamic value) {
    final values = _stringValues(value);
    return values.firstOrNull;
  }

  List<String> _stringValues(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return [
        for (final item in value)
          if (item?.toString().trim().isNotEmpty == true)
            item.toString().trim(),
      ];
    }
    final rawText = value.toString().trim();
    if (rawText.isEmpty) return const [];
    if (rawText.startsWith('[') || rawText.startsWith('{')) {
      try {
        final decoded = jsonDecode(rawText);
        if (decoded is List) return _stringValues(decoded);
        if (decoded is Map) {
          return [
            for (final entry in decoded.values)
              if (entry?.toString().trim().isNotEmpty == true)
                entry.toString().trim(),
          ];
        }
      } catch (_) {
        // Fall through to the cleaned legacy text below.
      }
    }
    return [rawText.replaceAll(RegExp(r'^\[|\]$'), '').replaceAll('"', '')];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: JournalPageLayout.widthFor(
                context,
                mobileWidth: _screenWidth,
              ),
            ),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _green),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(31, 25, 31, 45),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LearningCodeCard(
                                code: 'ENV-02B',
                                focus: _subjectFocus,
                              ),
                              const SizedBox(height: 29),
                              const _SectionTitle(
                                'The Three Dimensions of Learning',
                              ),
                              const SizedBox(height: 9),
                              const _SectionCopy(
                                'These NGSS 3D learning components have been generated based on your input.',
                              ),
                              const SizedBox(height: AppMetrics.labelGap),
                              _ChecklistCard(
                                title: 'DCI',
                                subtitle: 'Disciplinary Core Ideas',
                                iconAsset:
                                    'assets/learning_module/summary_dci.svg',
                                accent: const Color(0xFF0AA5FF),
                                generatedCount: _dci.values
                                    .where((v) => v)
                                    .length,
                                options: _dci,
                                onChanged: (option, value) =>
                                    _toggle('dci', option, value),
                              ),
                              const SizedBox(height: 29),
                              _ChecklistCard(
                                title: 'SEP',
                                subtitle: 'Science and Engineering Practices',
                                iconAsset:
                                    'assets/learning_module/summary_sep.svg',
                                accent: const Color(0xFF5B78AD),
                                generatedCount: _sep.values
                                    .where((v) => v)
                                    .length,
                                options: _sep,
                                onChanged: (option, value) =>
                                    _toggle('sep', option, value),
                              ),
                              const SizedBox(height: 29),
                              _ChecklistCard(
                                title: 'CCCs',
                                subtitle: 'Crosscutting Concepts',
                                iconAsset:
                                    'assets/learning_module/summary_ccc.svg',
                                accent: const Color(0xFF434AAB),
                                generatedCount: _ccc.values
                                    .where((v) => v)
                                    .length,
                                options: _ccc,
                                onChanged: (option, value) =>
                                    _toggle('ccc', option, value),
                              ),
                              const SizedBox(height: 31),
                              const _SectionTitle('Module Overview'),
                              const SizedBox(height: 11),
                              const _SectionCopy(
                                'Review the key details that define your learning module before it is generated.',
                              ),
                              const SizedBox(height: AppMetrics.fieldGap),
                              _ModuleOverviewCard(
                                title: _title,
                                subjectDomain: _subjectDomain,
                                subjectFocus: _subjectFocus,
                                difficulty: _difficulty,
                              ),
                              const SizedBox(height: 31),
                              const _SectionTitle('Learning Overview'),
                              const SizedBox(height: 11),
                              const _SectionCopy(
                                'Review the learning objectives that define the intended student outcomes.',
                              ),
                              const SizedBox(height: AppMetrics.fieldGap),
                              _ObjectivesCard(objectives: _objectives),
                              const SizedBox(height: 31),
                              const _SectionTitle(
                                'NGSS Performance Expectations',
                              ),
                              const SizedBox(height: AppMetrics.labelGap),
                              const _SectionCopy(
                                'The follow NGSS Performance Expectations align with the modules generated 3D components.',
                              ),
                              const SizedBox(height: 19),
                              const Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _NgssTag('MS-LS2-4'),
                                  _NgssTag('MS-ESS2-2'),
                                ],
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 97,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 43,
            child: Text(
              'Learning Summary',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: _SummaryState._text,
                fontSize: AppTypography.sectionTitleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 26,
            top: 36,
            child: AppTapTarget(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const Icon(
                Icons.chevron_left,
                color: _SummaryState._green,
                size: 34,
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, color: Color(0xFFE6E6E6)),
          ),
        ],
      ),
    );
  }
}

class _LearningCodeCard extends StatelessWidget {
  final String code;
  final String focus;

  const _LearningCodeCard({required this.code, required this.focus});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 122),
      padding: const EdgeInsets.fromLTRB(15, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F1E5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Juniper Learning Code',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _SummaryState._green,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _SummaryState._green),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.public,
                  color: _SummaryState._green,
                  size: 34,
                ),
              ),
              const SizedBox(width: 23),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _SummaryState._text,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      focus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _SummaryState._text,
                        fontSize: AppTypography.helperSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconAsset;
  final Color accent;
  final int generatedCount;
  final Map<String, bool> options;
  final void Function(String option, bool value) onChanged;

  const _ChecklistCard({
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.accent,
    required this.generatedCount,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(21, 17, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _SummaryState._border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SvgPicture.asset(iconAsset, width: 32, height: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: accent,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _SummaryState._muted,
                        fontSize: AppTypography.captionSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 27,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F1E5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$generatedCount Generated',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _SummaryState._green,
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppMetrics.labelGap),
          for (final entry in options.entries) ...[
            _ChecklistRow(
              label: entry.key,
              checked: entry.value,
              onChanged: (value) => onChanged(entry.key, value),
            ),
            const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;

  const _ChecklistRow({
    required this.label,
    required this.checked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _SummaryState._green, width: 1.6),
            ),
            child: checked
                ? const Icon(Icons.check, size: 15, color: _SummaryState._green)
                : null,
          ),
          const SizedBox(width: 21),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _SummaryState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleOverviewCard extends StatelessWidget {
  final String title;
  final String subjectDomain;
  final String subjectFocus;
  final String difficulty;

  const _ModuleOverviewCard({
    required this.title,
    required this.subjectDomain,
    required this.subjectFocus,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: [
        _InfoRow(
          iconAsset: 'assets/learning_module/summary_title.svg',
          label: 'Lesson Title',
          value: title,
        ),
        const SizedBox(height: AppMetrics.fieldGap),
        _InfoRow(
          iconAsset: 'assets/learning_module/summary_domain.svg',
          label: 'Subject Domain',
          value: subjectDomain,
        ),
        if (subjectFocus.isNotEmpty) ...[
          const SizedBox(height: AppMetrics.fieldGap),
          _InfoRow(
            iconAsset: 'assets/learning_module/summary_domain.svg',
            label: 'Subject Focus',
            value: subjectFocus,
          ),
        ],
        const SizedBox(height: AppMetrics.fieldGap),
        _InfoRow(
          iconAsset: 'assets/learning_module/summary_difficulty.svg',
          label: 'Difficulty',
          value: difficulty,
        ),
      ],
    );
  }
}

class _ObjectivesCard extends StatelessWidget {
  final List<String> objectives;

  const _ObjectivesCard({required this.objectives});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      children: [
        const Text(
          'Objectives',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: _SummaryState._muted,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        for (var index = 0; index < objectives.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _SummaryState._green,
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  objectives[index],
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _SummaryState._text,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (index != objectives.length - 1)
            const SizedBox(height: AppMetrics.labelGap),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _SummaryState._border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String iconAsset;
  final String label;
  final String value;

  const _InfoRow({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 55,
          child: Center(
            child: SvgPicture.asset(iconAsset, width: 32, height: 32),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _SummaryState._muted,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _SummaryState._text,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: _SummaryState._text,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _SectionCopy extends StatelessWidget {
  final String text;

  const _SectionCopy(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: _SummaryState._muted,
        fontSize: AppTypography.bodySize,
        height: 1.1,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _NgssTag extends StatelessWidget {
  final String label;

  const _NgssTag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFD4D4D4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _SummaryState._text,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
