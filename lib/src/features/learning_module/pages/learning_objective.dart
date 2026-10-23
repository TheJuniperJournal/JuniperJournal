import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/features/learning_module/pages/module_dashboard.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

/// Purpose: To clearly define what students will know or be able to do by the
/// end of the lesson.
class LearningObjectiveScreen extends StatefulWidget {
  final Map<String, dynamic> module;

  const LearningObjectiveScreen({super.key, required this.module});

  @override
  State<LearningObjectiveScreen> createState() =>
      _LearningObjectiveScreenState();
}

class _LearningObjectiveScreenState extends State<LearningObjectiveScreen> {
  static const _green = Color(0xFF5DB075);
  static const _textPrimary = Color(0xFF151515);
  static const _textSecondary = Color(0xFF555555);
  static const _border = Color(0xFFCFCFCF);
  static const _error = Color(0xFFFD1212);
  double get _screenWidth =>
      JournalPageLayout.widthFor(context, mobileWidth: 427);
  static const _maxObjectives = 4;

  final List<_ObjectiveRowData> _rows = [];
  bool _showValidation = false;

  final List<String> _learningObjectiveOptions = const [
    'Analyze',
    'Evaluate',
    'Design',
    'Explore',
  ];

  final List<String> _subjectDomainOptions = const [
    'Environment & Sustainability',
    'Engineering & Design',
    'Energy & Systems',
    'Community & Built Environment',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialRows(widget.module);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFreshModuleData();
      }
    });
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFreshModuleData() async {
    final id = widget.module['id'];
    if (id == null) {
      return;
    }

    final freshData = await LearningModuleRepo().getModule(id.toString());
    if (!mounted || freshData == null) {
      return;
    }

    setState(() {
      _replaceRows(_rowsFromModule(freshData));
    });
  }

  void _loadInitialRows(Map<String, dynamic> moduleData) {
    final rows = _rowsFromModule(moduleData);
    _replaceRows(rows);
  }

  List<_ObjectiveRowData> _rowsFromModule(Map<String, dynamic> moduleData) {
    final objectives = _objectiveRowsFromValue(
      moduleData['learning_objectives'],
    );

    if (objectives.isEmpty) {
      return [];
    }

    return objectives.take(_maxObjectives).toList();
  }

  List<_ObjectiveRowData> _objectiveRowsFromValue(dynamic value) {
    final entries = _stringListFromModuleValue(value);
    return [
      for (var index = 0; index < entries.length; index++)
        _objectiveRowFromStoredString(entries[index], index),
    ];
  }

  _ObjectiveRowData _objectiveRowFromStoredString(String value, int index) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final json = Map<String, dynamic>.from(decoded);
        return _ObjectiveRowData(
          objectiveType: _normalizeObjective(
            json['action']?.toString() ??
                json['objective_action']?.toString() ??
                '',
          ),
          subjectDomain: _normalizeDomain(
            json['subject_domain']?.toString() ??
                json['domain']?.toString() ??
                '',
          ),
          description:
              json['description']?.toString() ??
              json['objective_text']?.toString() ??
              '',
        );
      }
    } catch (_) {
      // Older rows were plain action strings.
    }
    return _ObjectiveRowData(
      objectiveType: _normalizeObjective(value),
      subjectDomain: null,
      description: '',
    );
  }

  List<String> _stringListFromModuleValue(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value
          .map((entry) => entry?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList();
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return [];
    }

    if (text.startsWith('[') && text.endsWith(']')) {
      return text
          .substring(1, text.length - 1)
          .split(',')
          .map((entry) => entry.trim().replaceAll('"', '').replaceAll("'", ''))
          .where((entry) => entry.isNotEmpty)
          .toList();
    }

    return [text];
  }

  String? _normalizeObjective(String value) {
    if (_learningObjectiveOptions.contains(value)) {
      return value;
    }
    return null;
  }

  String? _normalizeDomain(String value) {
    if (value == 'Environmental Sustainability') {
      return 'Environment & Sustainability';
    }
    if (value == 'Community & The Built Environment') {
      return 'Community & Built Environment';
    }
    if (_subjectDomainOptions.contains(value)) {
      return value;
    }
    return null;
  }

  void _replaceRows(List<_ObjectiveRowData> rows) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(rows);
  }

  void _addObjective() {
    if (_rows.length >= _maxObjectives) {
      return;
    }

    setState(() {
      _rows.add(
        _ObjectiveRowData(
          objectiveType: null,
          subjectDomain: null,
          description: '',
        ),
      );
    });
  }

  void _removeObjective(int index) {
    if (index < 0 || index >= _rows.length) {
      return;
    }

    setState(() {
      final row = _rows.removeAt(index);
      row.dispose();
    });
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      setState(() {
        _showValidation = true;
      });
      showTopSnackBar(
        context,
        'Please add at least one learning objective',
        isError: true,
      );
      return;
    }

    final isValid = _rows.every((row) => row.isComplete);
    if (!isValid) {
      setState(() {
        _showValidation = true;
      });
      showTopSnackBar(
        context,
        'Complete every objective before saving',
        isError: true,
      );
      return;
    }

    final id = widget.module['id'];
    if (id == null) {
      showTopSnackBar(
        context,
        'Failed to save learning objectives',
        isError: true,
      );
      return;
    }

    final repo = LearningModuleRepo();

    final objectivesSuccess = await repo.updateLearningObjectiveRows(
      id: id.toString(),
      rows: [
        for (var index = 0; index < _rows.length; index++)
          _rows[index].toStorageJson(index),
      ],
    );

    if (!mounted) {
      return;
    }

    if (objectivesSuccess) {
      _returnToDashboard();
    } else {
      showTopSnackBar(
        context,
        'Failed to save learning objectives',
        isError: true,
      );
    }
  }

  void _returnToDashboard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ModuleDashboardScreen(module: widget.module),
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
            constraints: BoxConstraints(maxWidth: _screenWidth),
            child: SingleChildScrollView(
              child: SizedBox(
                width: _screenWidth,
                height: 812,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 22,
                      child: Text(
                        'Learning Objectives',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          color: _textPrimary,
                          fontSize: AppTypography.sectionTitleSize,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 41,
                      top: 18,
                      width: 20,
                      height: 20,
                      child: AppTapTarget(
                        behavior: HitTestBehavior.opaque,
                        onTap: _returnToDashboard,
                        child: const _BackChevron(),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 63,
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE6E6E6),
                      ),
                    ),
                    Positioned(
                      left: 31,
                      top: 93,
                      child: Text(
                        'Learning Objectives (${_rows.length}/$_maxObjectives)',
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: _textPrimary,
                          fontSize: AppTypography.bodySize,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 31,
                      top: 114,
                      width: _screenWidth - 76,
                      child: Text(
                        'Add specific description of why this answer is correct.',
                        style: AppTypography.helper,
                      ),
                    ),
                    Positioned(
                      left: 29,
                      top: 156,
                      width: _screenWidth - 73,
                      child: _ObjectiveList(
                        rows: _rows,
                        objectiveOptions: _learningObjectiveOptions,
                        domainOptions: _subjectDomainOptions,
                        onDelete: _removeObjective,
                        onChanged: () => setState(() {}),
                        showValidation: _showValidation,
                      ),
                    ),
                    Positioned(
                      left: 82,
                      top: 433,
                      width: 242,
                      height: 33,
                      child: OutlinedButton(
                        onPressed: _rows.length >= _maxObjectives
                            ? null
                            : _addObjective,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          disabledForegroundColor: _green.withValues(
                            alpha: 0.45,
                          ),
                          side: BorderSide(
                            color: _rows.length >= _maxObjectives
                                ? _green.withValues(alpha: 0.45)
                                : _green,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          '+ Add Objective',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.buttonSize,
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 40,
                      top: 513,
                      width: _screenWidth - 82,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: Colors.white,
                            fontSize: AppTypography.buttonSize,
                            height: 1,
                            fontWeight: FontWeight.w500,
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

class _ObjectiveRowData {
  String? objectiveType;
  String? subjectDomain;
  final TextEditingController descriptionController;

  _ObjectiveRowData({
    required this.objectiveType,
    required this.subjectDomain,
    required String description,
  }) : descriptionController = TextEditingController(text: description);

  bool get isComplete {
    return objectiveType != null &&
        subjectDomain != null &&
        descriptionController.text.trim().isNotEmpty;
  }

  Map<String, dynamic> toStorageJson(int index) {
    return {
      'order': index + 1,
      'action': objectiveType,
      'subject_domain': subjectDomain,
      'description': descriptionController.text.trim(),
    };
  }

  void dispose() {
    descriptionController.dispose();
  }
}

class _ObjectiveList extends StatelessWidget {
  final List<_ObjectiveRowData> rows;
  final List<String> objectiveOptions;
  final List<String> domainOptions;
  final ValueChanged<int> onDelete;
  final VoidCallback onChanged;
  final bool showValidation;

  const _ObjectiveList({
    required this.rows,
    required this.objectiveOptions,
    required this.domainOptions,
    required this.onDelete,
    required this.onChanged,
    required this.showValidation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _LearningObjectiveScreenState._border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ObjectiveRow(
              index: index,
              row: rows[index],
              objectiveOptions: objectiveOptions,
              domainOptions: domainOptions,
              onDelete: () => onDelete(index),
              onChanged: onChanged,
              showValidation: showValidation,
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
          ],
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  final int index;
  final _ObjectiveRowData row;
  final List<String> objectiveOptions;
  final List<String> domainOptions;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final bool showValidation;

  const _ObjectiveRow({
    required this.index,
    required this.row,
    required this.objectiveOptions,
    required this.domainOptions,
    required this.onDelete,
    required this.onChanged,
    required this.showValidation,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Stack(
        children: [
          Positioned(
            left: 13,
            top: 13,
            width: 19,
            height: 19,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _LearningObjectiveScreenState._green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: Colors.white,
                  fontSize: AppTypography.helperSize,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Positioned(
            left: 52,
            top: 12,
            width: 69,
            height: 24,
            child: _AnchoredChipMenu(
              value: row.objectiveType,
              hint: 'Select',
              options: objectiveOptions,
              showError: showValidation && row.objectiveType == null,
              onSelected: (value) {
                row.objectiveType = value;
                onChanged();
              },
            ),
          ),
          Positioned(
            left: 130,
            top: 12,
            width: 177,
            height: 26,
            child: _AnchoredChipMenu(
              value: row.subjectDomain,
              hint: 'Select Domain',
              options: domainOptions,
              showError: showValidation && row.subjectDomain == null,
              onSelected: (value) {
                row.subjectDomain = value;
                onChanged();
              },
            ),
          ),
          Positioned(
            left: 52,
            top: 47,
            width: 254,
            height: 152,
            child: TextField(
              controller: row.descriptionController,
              onChanged: (_) => onChanged(),
              minLines: 5,
              maxLines: null,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _LearningObjectiveScreenState._textPrimary,
                fontSize: AppTypography.bodySize,
                height: 1.2,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        showValidation &&
                            row.descriptionController.text.trim().isEmpty
                        ? _LearningObjectiveScreenState._error
                        : _LearningObjectiveScreenState._border,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        showValidation &&
                            row.descriptionController.text.trim().isEmpty
                        ? _LearningObjectiveScreenState._error
                        : _LearningObjectiveScreenState._border,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          Positioned(
            right: 13,
            top: 111,
            width: 20,
            height: 22,
            child: AppTapTarget(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: SvgPicture.asset(
                'assets/learning_module/learning_objective_trash.svg',
                width: 20,
                height: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchoredChipMenu extends StatefulWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final bool showError;
  final ValueChanged<String> onSelected;

  const _AnchoredChipMenu({
    required this.value,
    required this.hint,
    required this.options,
    required this.showError,
    required this.onSelected,
  });

  @override
  State<_AnchoredChipMenu> createState() => _AnchoredChipMenuState();
}

class _AnchoredChipMenuState extends State<_AnchoredChipMenu> {
  final _chipKey = GlobalKey();

  Future<void> _openMenu() async {
    final chipContext = _chipKey.currentContext;
    if (chipContext == null) {
      return;
    }

    final chipBox = chipContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chipTopLeft = chipBox.localToGlobal(Offset.zero, ancestor: overlay);
    final chipRect = chipTopLeft & chipBox.size;

    final selected = await showMenu<String>(
      context: context,
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(chipRect.left, chipRect.bottom + 4, chipRect.width, 0),
        Offset.zero & overlay.size,
      ),
      items: widget.options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              height: 32,
              child: Text(
                option,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _LearningObjectiveScreenState._textPrimary,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null && selected != widget.value) {
      widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      key: _chipKey,
      behavior: HitTestBehavior.opaque,
      onTap: _openMenu,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: widget.showError
                ? _LearningObjectiveScreenState._error
                : _LearningObjectiveScreenState._border,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.only(left: 8, right: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value ?? widget.hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: widget.value == null
                      ? _LearningObjectiveScreenState._textSecondary
                      : _LearningObjectiveScreenState._textPrimary,
                  fontSize: AppTypography.captionSize,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const _ChevronDown(),
          ],
        ),
      ),
    );
  }
}

class _BackChevron extends StatelessWidget {
  const _BackChevron();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _BackChevronPainter(),
    );
  }
}

class _BackChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _LearningObjectiveScreenState._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.68, size.height * 0.08)
      ..lineTo(size.width * 0.28, size.height * 0.5)
      ..lineTo(size.width * 0.68, size.height * 0.92);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChevronDown extends StatelessWidget {
  const _ChevronDown();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(7, 4), painter: _ChevronDownPainter());
  }
}

class _ChevronDownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _LearningObjectiveScreenState._textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0.5, 0.6)
      ..lineTo(size.width / 2, size.height - 0.6)
      ..lineTo(size.width - 0.5, 0.6);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
