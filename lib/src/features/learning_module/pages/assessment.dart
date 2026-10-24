import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/features/learning_module/learning_module.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class Assessment extends StatefulWidget {
  final Map<String, dynamic> module;

  const Assessment({super.key, required this.module});

  @override
  State<Assessment> createState() => _CreateAssessmentScreen();
}

class _CreateAssessmentScreen extends State<Assessment> {
  @override
  Widget build(BuildContext context) {
    return AssessmentScreen(module: widget.module);
  }
}

// -----------------------------
// Multi-question Assessment UI
// -----------------------------

class AssessmentScreen extends StatefulWidget {
  final Map<String, dynamic> module;

  const AssessmentScreen({super.key, required this.module});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final List<QuestionModel> _questions = [QuestionModel()];

  @override
  void dispose() {
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  /// Serializes the entire assessment to JSON format for Supabase storage
  Map<String, dynamic> _serializeAssessment() {
    return {
      'title': 'Basics of Climate Change',
      'tags': ['ASSESSMENT', 'ANALYZE: ENVIRONMENTAL SUSTAINABILITY'],
      'questions': _questions.asMap().entries.map((entry) {
        return _serializeQuestion(entry.value, entry.key);
      }).toList(),
    };
  }

  /// Serializes a single question to JSON
  Map<String, dynamic> _serializeQuestion(QuestionModel model, int index) {
    final baseData = {
      'order': index,
      'questionText': model.questionCtrl.text,
      'questionType': model.type.toString().split('.').last,
    };

    // Add type-specific data
    switch (model.type) {
      case QuestionType.multipleChoice:
      case QuestionType.checkboxes:
      case QuestionType.dropdown:
        baseData['options'] = model.options.map((ctrl) => ctrl.text).toList();
        baseData['correctAnswers'] = model.correctAnswers;
        break;
      case QuestionType.linearScale:
        baseData['scaleMin'] = model.scaleMin;
        baseData['scaleMax'] = model.scaleMax;
        break;
      case QuestionType.mcGrid:
      case QuestionType.cbGrid:
        baseData['gridRows'] = model.gridRows.map((ctrl) => ctrl.text).toList();
        baseData['gridColumns'] = model.gridCols
            .map((ctrl) => ctrl.text)
            .toList();
        break;
      default:
        // shortAnswer, paragraph, fileUpload, date, time don't need extra data
        break;
    }

    return baseData;
  }

  /// Saves the assessment to Supabase
  Future<void> _saveAssessment() async {
    try {
      final assessmentData = _serializeAssessment();
      final moduleId = widget.module['id'] as String;
      final repo = LearningModuleRepo();

      final success = await repo.updateAssessment(
        id: moduleId,
        assessmentData: assessmentData,
      );

      if (mounted) {
        if (success) {
          showTopSnackBar(context, 'Assessment saved successfully!');
        } else {
          showTopSnackBar(context, 'Failed to save assessment', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Error saving assessment: $e', isError: true);
      }
    }
  }

  void _addQuestion({int? insertAfter}) {
    setState(() {
      final idx = insertAfter == null ? _questions.length : insertAfter + 1;
      _questions.insert(idx, QuestionModel());
    });
  }

  // add another question using the same format (type) as an existing one
  void _addQuestionLike(int index) {
    final templateType = _questions[index].type;
    setState(() {
      _questions.insert(index + 1, QuestionModel.forType(templateType));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) return; // keep at least one
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
        title: const Text(
          'Basics of Climate Change',
          style: AppTypography.pageTitle,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: AppTapTarget(
                onTap: () async {
                  // Save the assessment first
                  await _saveAssessment();

                  // Then navigate to Summary
                  if (context.mounted) {
                    pushAppRoute(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Summary(module: widget.module),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageScrollWithFooter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag('ASSESSMENT'),
                  _buildTag(
                    'ANALYZE: ENVIRONMENTAL SUSTAINABILITY',
                    filled: true,
                  ),
                  _circleAdd(onTap: () => _addQuestion()),
                ],
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              for (int i = 0; i < _questions.length; i++) ...[
                QuestionCard(
                  index: i,
                  model: _questions[i],
                  onAddBelow: () =>
                      _addQuestionLike(i), // duplicates current format
                  onRemove: () => _removeQuestion(i),
                ),
                if (i != _questions.length - 1) const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, {bool filled = false}) => Container(
    decoration: BoxDecoration(
      color: filled ? AppColors.primary : AppColors.primaryTint,
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.helperSize,
        fontWeight: FontWeight.w400,
        color: filled ? Colors.white : Colors.black87,
      ),
    ),
  );

  Widget _circleAdd({required VoidCallback onTap}) => Container(
    decoration: const BoxDecoration(
      color: AppColors.primaryTint,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      tooltip: 'Add question',
      icon: const Icon(Icons.add, color: AppColors.primary),
      onPressed: onTap,
    ),
  );
}

/* ===========================
          DATA MODEL
=========================== */

enum QuestionType {
  shortAnswer,
  paragraph,
  multipleChoice,
  checkboxes,
  dropdown,
  fileUpload,
  linearScale,
  mcGrid,
  cbGrid,
  date,
  time,
}

String questionTypeLabel(QuestionType t) {
  switch (t) {
    case QuestionType.shortAnswer:
      return 'Short answer';
    case QuestionType.paragraph:
      return 'Paragraph';
    case QuestionType.multipleChoice:
      return 'Multiple choice';
    case QuestionType.checkboxes:
      return 'Checkboxes';
    case QuestionType.dropdown:
      return 'Dropdown';
    case QuestionType.fileUpload:
      return 'File upload';
    case QuestionType.linearScale:
      return 'Linear scale';
    case QuestionType.mcGrid:
      return 'Multiple choice grid';
    case QuestionType.cbGrid:
      return 'Checkbox grid';
    case QuestionType.date:
      return 'Date';
    case QuestionType.time:
      return 'Time';
  }
}

IconData questionTypeIcon(QuestionType t) {
  switch (t) {
    case QuestionType.shortAnswer:
      return Icons.notes_rounded;
    case QuestionType.paragraph:
      return Icons.reorder;
    case QuestionType.multipleChoice:
      return Icons.radio_button_checked;
    case QuestionType.checkboxes:
      return Icons.check_box_outlined;
    case QuestionType.dropdown:
      return Icons.arrow_drop_down_circle_outlined;
    case QuestionType.fileUpload:
      return Icons.cloud_upload_outlined;
    case QuestionType.linearScale:
      return Icons.linear_scale;
    case QuestionType.mcGrid:
      return Icons.grid_on;
    case QuestionType.cbGrid:
      return Icons.grid_on;
    case QuestionType.date:
      return Icons.calendar_today_outlined;
    case QuestionType.time:
      return Icons.access_time;
  }
}

class QuestionModel {
  QuestionType type;
  final TextEditingController questionCtrl = TextEditingController();

  // Options-based
  final List<TextEditingController> options;
  List<bool> correctAnswers; // tracks which options are correct

  // Grid-based
  final List<TextEditingController> gridRows;
  final List<TextEditingController> gridCols;

  // Linear scale
  double scaleMin;
  double scaleMax;
  double scaleValue; // current selected value

  // Date/time (for preview text)
  DateTime? date;
  TimeOfDay? time;

  // Default constructor: Multiple choice with one option
  QuestionModel()
    : type = QuestionType.multipleChoice,
      options = [TextEditingController(text: 'Option 1')],
      correctAnswers = [false],
      gridRows = [TextEditingController(text: 'Row 1')],
      gridCols = [
        TextEditingController(text: 'Very good'),
        TextEditingController(text: 'Good'),
      ],
      scaleMin = 1,
      scaleMax = 5,
      scaleValue = 3; // midpoint

  // Create a fresh model with the SAME TYPE (for duplicating format)
  QuestionModel.forType(this.type)
    : options = [TextEditingController(text: 'Option 1')],
      correctAnswers = [false],
      gridRows = [TextEditingController(text: 'Row 1')],
      gridCols = [
        TextEditingController(text: 'Col 1'),
        TextEditingController(text: 'Col 2'),
      ],
      scaleMin = 1,
      scaleMax = 5,
      scaleValue = 3; // midpoint

  void dispose() {
    questionCtrl.dispose();
    for (final c in options) {
      c.dispose();
    }
    for (final c in gridRows) {
      c.dispose();
    }
    for (final c in gridCols) {
      c.dispose();
    }
  }
}

/* ===========================
        QUESTION CARD
=========================== */

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.index,
    required this.model,
    required this.onAddBelow,
    required this.onRemove,
  });

  final int index;
  final QuestionModel model;
  final VoidCallback onAddBelow; // will add with same format
  final VoidCallback onRemove;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  @override
  Widget build(BuildContext context) {
    final m = widget.model;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE9DF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Q${widget.index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _typePill(m),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Remove question',
                        onPressed: widget.onRemove,
                        icon: SvgPicture.asset(
                          'assets/learning_module/learning_objective_trash.svg',
                          width: 14,
                          height: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: m.questionCtrl,
                    minLines: 5,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _answerArea(m),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: widget.onAddBelow, // duplicates current format
                      icon: const Icon(Icons.add),
                      label: const Text('Add another question'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typePill(QuestionModel m) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () async {
      final chosen = await showAppModalBottomSheet<QuestionType>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _TypePickerSheet(selected: m.type),
      );
      if (chosen != null) setState(() => m.type = chosen);
    },
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(questionTypeIcon(m.type), size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            questionTypeLabel(m.type),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    ),
  );

  Widget _answerArea(QuestionModel m) {
    switch (m.type) {
      case QuestionType.shortAnswer:
        return _shortOrParagraph(hint: 'Short answer');
      case QuestionType.paragraph:
        return _shortOrParagraph(hint: 'Long answer', minLines: 5);
      case QuestionType.multipleChoice:
        return _optionsList(m, choiceIcon: Icons.radio_button_unchecked);
      case QuestionType.checkboxes:
        return _optionsList(m, choiceIcon: Icons.check_box_outline_blank);
      case QuestionType.dropdown:
        return _optionsList(
          m,
          choiceIcon: Icons.arrow_drop_down_circle_outlined,
          showTrailingPlus: false,
        );
      case QuestionType.fileUpload:
        return OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Add file'),
        );
      case QuestionType.linearScale:
        return _linearScale(m); // now draggable
      case QuestionType.mcGrid:
        return _gridLikeGoogleForms(m, radio: true);
      case QuestionType.cbGrid:
        return _gridLikeGoogleForms(m, radio: false);
      case QuestionType.date:
        return _datePicker(m);
      case QuestionType.time:
        return _timePicker(m);
    }
  }

  Widget _shortOrParagraph({required String hint, int minLines = 1}) =>
      TextField(
        minLines: minLines,
        maxLines: minLines == 1 ? 1 : null,
        decoration: InputDecoration(
          hintText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12),
          ),
        ),
      );

  /// Options list with per-row "+" (insert new below), remove, and bottom "Add Option".
  Widget _optionsList(
    QuestionModel m, {
    required IconData choiceIcon,
    bool showTrailingPlus = true,
  }) {
    // Ensure correctAnswers list is initialized and in sync with options list
    if (m.correctAnswers.length != m.options.length) {
      m.correctAnswers = List.generate(
        m.options.length,
        (i) => i < m.correctAnswers.length ? m.correctAnswers[i] : false,
      );
    }

    final children = <Widget>[];

    for (int i = 0; i < m.options.length; i++) {
      children.add(
        Row(
          children: [
            Icon(choiceIcon, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: m.options[i],
                decoration: const InputDecoration(
                  hintText: '',
                  isDense: true,
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Star icon to mark correct answer
            IconButton(
              tooltip: m.correctAnswers[i]
                  ? 'Marked as correct'
                  : 'Mark as correct',
              icon: Icon(
                m.correctAnswers[i] ? Icons.star : Icons.star_border,
                color: m.correctAnswers[i]
                    ? const Color(0xFFFFB800)
                    : Colors.black38,
              ),
              onPressed: () => setState(() {
                // For multiple choice, only one answer can be correct
                if (m.type == QuestionType.multipleChoice) {
                  // Unmark all others and mark only this one
                  for (int j = 0; j < m.correctAnswers.length; j++) {
                    m.correctAnswers[j] = (j == i);
                  }
                } else {
                  // For checkboxes and dropdown, allow multiple correct answers
                  m.correctAnswers[i] = !m.correctAnswers[i];
                }
              }),
            ),
            if (showTrailingPlus)
              IconButton(
                tooltip: 'Add option',
                icon: const Icon(Icons.add_box_outlined, color: Colors.black54),
                onPressed: () => setState(() {
                  m.options.insert(i + 1, TextEditingController());
                  m.correctAnswers.insert(i + 1, false);
                }),
              ),
            if (m.options.length > 1) ...[
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Remove option',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  m.options.removeAt(i);
                  if (i < m.correctAnswers.length) {
                    m.correctAnswers.removeAt(i);
                  }
                }),
              ),
            ],
          ],
        ),
      );

      if (i != m.options.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }

    children
      ..add(const SizedBox(height: 12))
      ..add(
        Row(
          children: [
            Icon(choiceIcon, color: Colors.black26),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () => setState(() {
                m.options.add(TextEditingController());
                m.correctAnswers.add(false);
              }),
              icon: const Icon(Icons.add, color: AppColors.primary),
              label: const Text(
                'Add Option',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            const Spacer(),
          ],
        ),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  // ================== DRAGGABLE LINEAR SCALE ==================
  Widget _linearScale(QuestionModel m) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text('Min'),
          const SizedBox(width: 8),
          _miniNumberField(
            value: m.scaleMin,
            onChanged: (v) => setState(() {
              m.scaleMin = v;
              if (m.scaleMin >= m.scaleMax) m.scaleMax = m.scaleMin + 1;
              if (m.scaleValue < m.scaleMin) m.scaleValue = m.scaleMin;
            }),
          ),
          const SizedBox(width: 16),
          const Text('Max'),
          const SizedBox(width: 8),
          _miniNumberField(
            value: m.scaleMax,
            onChanged: (v) => setState(() {
              m.scaleMax = v;
              if (m.scaleMax <= m.scaleMin) m.scaleMin = m.scaleMax - 1;
              if (m.scaleValue > m.scaleMax) m.scaleValue = m.scaleMax;
            }),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Text(m.scaleMin.toStringAsFixed(0)),
          Expanded(
            child: Slider(
              value: m.scaleValue.clamp(m.scaleMin, m.scaleMax),
              min: m.scaleMin,
              max: m.scaleMax,
              divisions: (m.scaleMax - m.scaleMin).round().clamp(1, 1000),
              label: m.scaleValue.toStringAsFixed(0),
              onChanged: (v) =>
                  setState(() => m.scaleValue = v.roundToDouble()),
            ),
          ),
          Text(m.scaleMax.toStringAsFixed(0)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Selected: ${m.scaleValue.toStringAsFixed(0)}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ],
  );

  Widget _miniNumberField({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final ctrl = TextEditingController(text: value.toStringAsFixed(0));
    return SizedBox(
      width: 48,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (s) {
          final v = double.tryParse(s);
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  // ===== Google Forms–style GRID (Multiple choice grid & Checkbox grid) =====
  Widget _gridLikeGoogleForms(QuestionModel m, {required bool radio}) {
    const stripGrey = Color(0xFFF4F6F8);
    const borderGrey = Color(0xFFE2E6EA);
    const iconGrey = Color(0xFF70757A);

    // Editor (rows & columns with add/delete) + Pretty Preview
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columns editor (top headers)
        const Text('Columns (top headers)'),
        const SizedBox(height: 6),
        ...List.generate(m.gridCols.length, (i) {
          return _deletableTextRow(
            controller: m.gridCols[i],
            hint: 'Column ${i + 1}',
            onDelete: () => setState(() => m.gridCols.removeAt(i)),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
            () => m.gridCols.add(
              TextEditingController(text: 'Col ${m.gridCols.length + 1}'),
            ),
          ),
          icon: const Icon(Icons.add, color: AppColors.primary),
          label: const Text(
            'Add column',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),

        // Rows editor (left labels)
        const Text('Rows (left labels)'),
        const SizedBox(height: 6),
        ...List.generate(m.gridRows.length, (i) {
          return _deletableTextRow(
            controller: m.gridRows[i],
            hint: 'Row ${i + 1}',
            onDelete: () => setState(() => m.gridRows.removeAt(i)),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
            () => m.gridRows.add(
              TextEditingController(text: 'Row ${m.gridRows.length + 1}'),
            ),
          ),
          icon: const Icon(Icons.add, color: AppColors.primary),
          label: const Text(
            'Add row',
            style: TextStyle(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 12),

        // Preview matrix styled like Google Forms
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderGrey),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _gridHeaderBar(m.gridCols),
              Divider(height: 1, color: borderGrey),
              ...List.generate(m.gridRows.length, (rIndex) {
                final isAlt = rIndex.isEven; // subtle striping
                return Column(
                  children: [
                    Container(
                      color: isAlt ? stripGrey : Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left row label (wide column)
                          SizedBox(
                            width: 220,
                            child: Text(
                              m.gridRows[rIndex].text,
                              style: const TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.bodySize,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          // Choice cells
                          ...List.generate(m.gridCols.length, (i) {
                            return Expanded(
                              child: Center(
                                child: Icon(
                                  radio
                                      ? Icons.radio_button_unchecked
                                      : Icons.check_box_outline_blank,
                                  size: 26,
                                  color: iconGrey,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    if (rIndex != m.gridRows.length - 1)
                      Divider(height: 1, color: borderGrey),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Header bar with big top labels
  Widget _gridHeaderBar(List<TextEditingController> cols) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Row(
        children: [
          const SizedBox(
            width: 220,
            child: Text('', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ...List.generate(cols.length, (i) {
            return Expanded(
              child: Center(
                child: Text(
                  cols[i].text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: AppTypography.sectionTitleSize,
                    color: Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // One-line editable row with delete icon
  Widget _deletableTextRow({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '',
                isDense: true,
                border: const UnderlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Delete',
            icon: SvgPicture.asset(
              'assets/learning_module/learning_objective_trash.svg',
              width: 14,
              height: 16,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _datePicker(QuestionModel m) => OutlinedButton.icon(
    onPressed: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
        initialDate: now,
      );
      if (picked != null) setState(() => m.date = picked);
    },
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text(m.date == null ? 'Select date' : _fmtDate(m.date!)),
  );

  Widget _timePicker(QuestionModel m) => OutlinedButton.icon(
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) setState(() => m.time = picked);
    },
    icon: const Icon(Icons.access_time),
    label: Text(m.time == null ? 'Select time' : m.time!.format(context)),
  );

  String _fmtDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/* ===========================
       TYPE PICKER SHEET
=========================== */

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet({required this.selected});
  final QuestionType selected;

  @override
  Widget build(BuildContext context) {
    final items = QuestionType.values;

    // Cap height and make the list scrollable to prevent overflow.
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Assessment Form Types',
                style: TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  fontSize: AppTypography.sectionTitleSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: PageScrollWithFooter(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    final isSel = it == selected;
                    return Material(
                      color: isSel ? const Color(0xFFDCE9DF) : Colors.white,
                      child: ListTile(
                        leading: Icon(
                          questionTypeIcon(it),
                          color: Colors.black87,
                        ),
                        title: Text(questionTypeLabel(it)),
                        onTap: () => Navigator.pop(ctx, it),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
