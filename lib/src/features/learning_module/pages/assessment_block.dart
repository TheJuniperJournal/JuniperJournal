import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Temporarily disable assessment authoring and responses without removing data.
const assessmentFeaturesEnabled = false;

enum AssessmentType {
  numeric(
    storageValue: 'numeric',
    title: 'Numeric Response',
    selectorTitle: 'Numeric Response',
    description: 'Collect a number or measurement from students.',
    iconAsset: 'assets/learning_module/assessment_numeric.svg',
  ),
  matching(
    storageValue: 'matching',
    title: 'Matching',
    selectorTitle: 'Matching',
    description: 'Match related terms, concepts, or images together.',
    iconAsset: 'assets/learning_module/assessment_list_mock.svg',
  ),
  trueFalse(
    storageValue: 'true_false',
    title: 'True/False',
    selectorTitle: 'True/False',
    description: 'Choose whether a statement is true or false.',
    iconAsset: 'assets/learning_module/assessment_check_mock.svg',
  ),
  paragraph(
    storageValue: 'paragraph',
    title: 'Paragraph',
    selectorTitle: 'Paragraph',
    description: 'Write a detailed explanation or reflection.',
    iconAsset: 'assets/learning_module/assessment_paragraph_mock.svg',
  ),
  multipleChoice(
    storageValue: 'multiple_choice',
    title: 'Multiple Choice',
    selectorTitle: 'Multiple Choice',
    description: 'Select the best answer from multiple options.',
    iconAsset: 'assets/learning_module/assessment_list_mock.svg',
  );

  final String storageValue;
  final String title;
  final String selectorTitle;
  final String description;
  final String iconAsset;

  const AssessmentType({
    required this.storageValue,
    required this.title,
    required this.selectorTitle,
    required this.description,
    required this.iconAsset,
  });

  static AssessmentType? fromStorage(String? value) {
    for (final type in values) {
      if (type.storageValue == value || type.title == value) return type;
    }
    return null;
  }
}

class AssessmentBlockData {
  final String? assessmentId;
  final AssessmentType? type;
  final Map<String, dynamic> data;

  const AssessmentBlockData({
    this.type,
    this.data = const {},
    this.assessmentId,
  });

  bool get isEmpty => type == null && data.isEmpty;

  bool get hasDraft {
    if (type == null) return false;
    final inputs = Map<String, dynamic>.from(data)
      ..remove('allow_multiple')
      ..remove('authoring_finalized')
      ..remove('correct_mapping')
      ..remove('response_length')
      ..remove('max_characters');
    return _hasMeaningfulValue(inputs);
  }

  bool get isValid {
    final selectedType = type;
    if (selectedType == null) return true;
    if (assessmentId != null && data['answer_key_redacted'] == true)
      return true;
    switch (selectedType) {
      case AssessmentType.numeric:
        final answer = num.tryParse(_string('correct_answer'));
        final minimum = num.tryParse(_string('min_value'));
        final maximum = num.tryParse(_string('max_value'));
        return _string('question').isNotEmpty &&
            answer != null &&
            answer.isFinite &&
            minimum != null &&
            minimum.isFinite &&
            maximum != null &&
            maximum.isFinite &&
            minimum <= maximum &&
            answer >= minimum &&
            answer <= maximum;
      case AssessmentType.matching:
        final top = _stringList('top_items');
        final bottom = _stringList('bottom_items');
        return top.length >= 2 &&
            top.length == bottom.length &&
            top.every((item) => item.trim().isNotEmpty) &&
            bottom.every((item) => item.trim().isNotEmpty);
      case AssessmentType.trueFalse:
        final questions = _maps('questions');
        return questions.length >= 2 &&
            questions.every(
              (question) =>
                  (question['text'] ?? '').toString().trim().isNotEmpty &&
                  question['correct_answer'] is bool,
            );
      case AssessmentType.paragraph:
        return _string('question').isNotEmpty &&
            ['short', 'medium', 'long'].contains(_string('response_length'));
      case AssessmentType.multipleChoice:
        final options = _options;
        final correctIndex = data['correct_index'];
        return _string('question').isNotEmpty &&
            options.length >= 2 &&
            options.every((option) => option.trim().isNotEmpty) &&
            (data['allow_multiple'] == true
                ? data['correct_indices'] is List &&
                      (data['correct_indices'] as List).isNotEmpty &&
                      (data['correct_indices'] as List).every(
                        (i) => i is int && i >= 0 && i < options.length,
                      )
                : correctIndex is int &&
                      correctIndex >= 0 &&
                      correctIndex < options.length);
    }
  }

  Map<String, dynamic> toJson() {
    final selectedType = type;
    if (selectedType == null) return <String, dynamic>{};
    return {
      if (assessmentId != null) 'assessment_id': assessmentId,
      'type': selectedType.storageValue,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  bool contentEquals(AssessmentBlockData other) {
    return type == other.type && _canonical(data) == _canonical(other.data);
  }

  factory AssessmentBlockData.fromJson(dynamic raw) {
    if (raw is! Map || raw.isEmpty) return const AssessmentBlockData();
    final json = Map<String, dynamic>.from(raw);
    final type = AssessmentType.fromStorage(json['type']?.toString());
    final rawData = json['data'];
    return AssessmentBlockData(
      type: type,
      assessmentId: json['assessment_id']?.toString(),
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : {},
    );
  }

  String _string(String key) => data[key]?.toString().trim() ?? '';

  List<Map<String, dynamic>> _maps(String key) {
    final raw = data[key];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  List<String> _stringList(String key) {
    final raw = data[key];
    if (raw is! List) return const [];
    return [for (final item in raw) item.toString()];
  }

  List<String> get _options {
    final raw = data['options'];
    if (raw is! List) return const [];
    return [for (final item in raw) item.toString()];
  }

  static bool _hasMeaningfulValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is bool || value is num) return true;
    if (value is List) return value.any(_hasMeaningfulValue);
    if (value is Map) return value.values.any(_hasMeaningfulValue);
    return true;
  }

  static String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return '{${keys.map((key) => '$key:${_canonical(value[key])}').join(',')}}';
    }
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    return value?.toString() ?? '';
  }
}

class AssessmentBlockSection extends StatefulWidget {
  final AssessmentBlockData value;
  final ValueChanged<AssessmentBlockData> onChanged;
  final bool showValidation;
  final Future<bool> Function()? onSave;

  const AssessmentBlockSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.showValidation = false,
    this.onSave,
  });

  @override
  State<AssessmentBlockSection> createState() => _AssessmentBlockSectionState();
}

class _AssessmentBlockSectionState extends State<AssessmentBlockSection> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _error = Color(0xFFD12E2E);
  static const _purpleTile = Color(0x339027BD);

  bool _selectorExpanded = false;
  bool _resettingAssessment = false;
  bool _saveAttempted = false,
      _savingAssessment = false,
      _assessmentSaved = false;
  String? _saveError;
  bool _finalized = false;
  AssessmentType? _type;
  late TextEditingController _questionController;
  late TextEditingController _numericAnswerController;
  late TextEditingController _numericMinController;
  late TextEditingController _numericMaxController;
  late TextEditingController _explanationController;
  late List<TextEditingController> _matchingTopControllers;
  late List<TextEditingController> _matchingBottomControllers;
  late List<int> _matchingBottomOrder;
  late List<TextEditingController> _trueFalseQuestionControllers;
  late List<bool?> _trueFalseAnswers;
  late List<TextEditingController> _optionControllers;
  String _paragraphLength = 'short';
  int? _correctOptionIndex;
  bool _allowMultiple = false;
  Set<int> _correctIndices = {};

  @override
  void initState() {
    super.initState();
    _hydrate(widget.value);
  }

  @override
  void didUpdateWidget(covariant AssessmentBlockSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.value.contentEquals(_buildData())) {
      _disposeDynamicControllers();
      _hydrate(widget.value);
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _numericAnswerController.dispose();
    _numericMinController.dispose();
    _numericMaxController.dispose();
    _explanationController.dispose();
    _disposeDynamicControllers();
    super.dispose();
  }

  void _hydrate(AssessmentBlockData value) {
    _type = value.hasDraft ? value.type : null;
    _finalized = value.data['authoring_finalized'] == true && value.isValid;
    final data = value.data;
    _allowMultiple = data['allow_multiple'] == true;
    _correctIndices = {
      for (final i in (data['correct_indices'] as List? ?? []))
        if (i is int) i,
    };
    _questionController = TextEditingController(
      text: data['question']?.toString() ?? '',
    )..addListener(_emit);
    _numericAnswerController = TextEditingController(
      text: data['correct_answer']?.toString() ?? '',
    )..addListener(_emit);
    _numericMinController = TextEditingController(
      text: data['min_value']?.toString() ?? '',
    )..addListener(_emit);
    _numericMaxController = TextEditingController(
      text: data['max_value']?.toString() ?? '',
    )..addListener(_emit);
    _explanationController = TextEditingController(
      text: data['explanation']?.toString() ?? '',
    )..addListener(_emit);
    _paragraphLength =
        [
          'short',
          'medium',
          'long',
        ].contains(data['response_length']?.toString())
        ? data['response_length'].toString()
        : 'short';
    final oldPairs = data['pairs'] is List ? data['pairs'] as List : const [];
    final topItems = data['top_items'] is List
        ? List<String>.from(data['top_items'])
        : [
            for (final pair in oldPairs)
              if (pair is Map) '${pair['left'] ?? ''}',
          ];
    final bottomItems = data['bottom_items'] is List
        ? List<String>.from(data['bottom_items'])
        : [
            for (final pair in oldPairs)
              if (pair is Map) '${pair['right'] ?? ''}',
          ];
    while (topItems.length < 2) {
      topItems.add('');
    }
    while (bottomItems.length < topItems.length) {
      bottomItems.add('');
    }
    _matchingTopControllers = [
      for (final item in topItems)
        TextEditingController(text: item)..addListener(_emit),
    ];
    _matchingBottomControllers = [
      for (final item in bottomItems.take(topItems.length))
        TextEditingController(text: item)..addListener(_emit),
    ];
    _matchingBottomOrder = [
      for (var index = 0; index < _matchingTopControllers.length; index++)
        index,
    ];
    final rawQuestions = data['questions'] is List
        ? data['questions'] as List
        : const [];
    final normalizedQuestions = rawQuestions.isNotEmpty
        ? rawQuestions
        : [
            {
              'text': data['question']?.toString() ?? '',
              'correct_answer': data['correct_answer'],
            },
            {'text': '', 'correct_answer': null},
          ];
    _trueFalseQuestionControllers = [
      for (final item in normalizedQuestions)
        TextEditingController(
          text: item is Map ? item['text']?.toString() ?? '' : '',
        )..addListener(_emit),
    ];
    _trueFalseAnswers = [
      for (final item in normalizedQuestions)
        item is Map && item['correct_answer'] is bool
            ? item['correct_answer'] as bool
            : null,
    ];
    final options = data['options'] is List
        ? data['options'] as List
        : const [];
    final normalizedOptions = options.isEmpty ? const ['', ''] : options;
    _optionControllers = [
      for (final option in normalizedOptions)
        TextEditingController(text: option.toString())..addListener(_emit),
    ];
    _correctOptionIndex = data['correct_index'] is int
        ? data['correct_index'] as int
        : null;
  }

  void _disposeDynamicControllers() {
    for (final controller in _matchingTopControllers) {
      controller.dispose();
    }
    for (final controller in _matchingBottomControllers) {
      controller.dispose();
    }
    for (final controller in _trueFalseQuestionControllers) {
      controller.dispose();
    }
    for (final controller in _optionControllers) {
      controller.dispose();
    }
  }

  Future<void> _selectType(AssessmentType? type) async {
    if (_type == type) return;
    final current = _buildData();
    if (current.hasDraft) {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            type == null ? 'Remove assessment?' : 'Change assessment type?',
          ),
          content: Text(
            type == null
                ? 'Remove this assessment and its entered content?'
                : 'Changing the assessment type will clear the current assessment inputs.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(type == null ? 'Remove' : 'Change'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _resettingAssessment = true;
      _type = type;
      _selectorExpanded = false;
      _finalized = false;
      _saveAttempted = false;
      _assessmentSaved = false;
      _saveError = null;
      _allowMultiple = false;
      _correctIndices = {};
      _questionController.clear();
      _numericAnswerController.clear();
      _numericMinController.clear();
      _numericMaxController.clear();
      _explanationController.clear();
      _paragraphLength = 'short';
      _correctOptionIndex = null;
      for (final controller in _matchingTopControllers) {
        controller.dispose();
      }
      for (final controller in _matchingBottomControllers) {
        controller.dispose();
      }
      for (final controller in _trueFalseQuestionControllers) {
        controller.dispose();
      }
      for (final controller in _optionControllers) {
        controller.dispose();
      }
      _matchingTopControllers = List.generate(
        2,
        (_) => TextEditingController()..addListener(_emit),
      );
      _matchingBottomControllers = List.generate(
        2,
        (_) => TextEditingController()..addListener(_emit),
      );
      _matchingBottomOrder = [0, 1];
      _trueFalseQuestionControllers = List.generate(
        2,
        (_) => TextEditingController()..addListener(_emit),
      );
      _trueFalseAnswers = [null, null];
      _optionControllers = [
        TextEditingController()..addListener(_emit),
        TextEditingController()..addListener(_emit),
      ];
      _resettingAssessment = false;
    });
    _emit();
  }

  AssessmentBlockData _buildData() {
    final selectedType = _type;
    if (selectedType == null) return const AssessmentBlockData();
    final data = switch (selectedType) {
      AssessmentType.numeric => {
        'question': _questionController.text.trim(),
        'correct_answer': _numericAnswerController.text.trim(),
        'min_value': _numericMinController.text.trim(),
        'max_value': _numericMaxController.text.trim(),
        'explanation': _explanationController.text.trim(),
      },
      AssessmentType.matching => {
        'top_items': [
          for (final item in _matchingTopControllers) item.text.trim(),
        ],
        'bottom_items': [
          for (final item in _matchingBottomControllers) item.text.trim(),
        ],
        'correct_mapping': {
          for (var index = 0; index < _matchingTopControllers.length; index++)
            String.fromCharCode(65 + index): String.fromCharCode(65 + index),
        },
      },
      AssessmentType.trueFalse => {
        'questions': [
          for (
            var index = 0;
            index < _trueFalseQuestionControllers.length;
            index++
          )
            {
              'text': _trueFalseQuestionControllers[index].text.trim(),
              'correct_answer': _trueFalseAnswers[index],
            },
        ],
      },
      AssessmentType.paragraph => {
        'question': _questionController.text.trim(),
        'response_length': _paragraphLength,
        'max_characters': _paragraphLimit(_paragraphLength),
      },
      AssessmentType.multipleChoice => {
        'question': _questionController.text.trim(),
        'options': [
          for (final controller in _optionControllers) controller.text.trim(),
        ],
        'correct_index': _correctOptionIndex,
        'allow_multiple': _allowMultiple,
        if (_allowMultiple) 'correct_indices': _correctIndices.toList()..sort(),
        'explanation': _explanationController.text.trim(),
      },
    };
    return AssessmentBlockData(
      type: selectedType,
      data: {...data, if (_finalized) 'authoring_finalized': true},
      assessmentId: widget.value.assessmentId,
    );
  }

  void _emit() {
    if (!mounted || _resettingAssessment) return;
    setState(() {
      _assessmentSaved = false;
      _saveError = null;
    });
    widget.onChanged(_buildData());
  }

  Future<void> _saveAssessment() async {
    if (_savingAssessment) return;
    setState(() {
      _saveAttempted = true;
      _saveError = null;
    });
    final data = _buildData();
    if (!data.isValid) return;
    _finalized = true;
    widget.onChanged(_buildData());
    FocusScope.of(context).unfocus();
    setState(() => _savingAssessment = true);
    try {
      final saved = await widget.onSave?.call() ?? true;
      if (!mounted) return;
      setState(() {
        _assessmentSaved = saved;
        _finalized = saved;
        if (!saved)
          _saveError = 'Could not save the assessment. Please try again.';
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _finalized = false;
          _saveError = 'Could not save the assessment. Please try again.';
        });
    } finally {
      if (mounted) {
        setState(() => _savingAssessment = false);
        if (!_finalized) widget.onChanged(_buildData());
      }
    }
  }

  void _addTrueFalseQuestion() {
    setState(() {
      _trueFalseQuestionControllers.add(
        TextEditingController()..addListener(_emit),
      );
      _trueFalseAnswers.add(null);
    });
    _emit();
  }

  void _removeTrueFalseQuestion(int index) {
    if (_trueFalseQuestionControllers.length <= 2) return;
    setState(() {
      _trueFalseQuestionControllers.removeAt(index).dispose();
      _trueFalseAnswers.removeAt(index);
    });
    _emit();
  }

  void _addOption() {
    if (_optionControllers.length >= 4) return;
    setState(() {
      _optionControllers.add(TextEditingController()..addListener(_emit));
    });
    _emit();
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers.removeAt(index).dispose();
      _correctIndices = {
        for (final value in _correctIndices)
          if (value != index) value > index ? value - 1 : value,
      };
      if (_correctOptionIndex == index) {
        _correctOptionIndex = null;
      } else if (_correctOptionIndex != null && _correctOptionIndex! > index) {
        _correctOptionIndex = _correctOptionIndex! - 1;
      }
    });
    _emit();
  }

  void _addMatchingRow() {
    setState(() {
      final index = _matchingTopControllers.length;
      _matchingTopControllers.add(TextEditingController()..addListener(_emit));
      _matchingBottomControllers.add(
        TextEditingController()..addListener(_emit),
      );
      _matchingBottomOrder.add(index);
    });
    _emit();
  }

  void _removeMatchingRow(int index) {
    if (_matchingTopControllers.length <= 2) return;
    setState(() {
      _matchingTopControllers.removeAt(index).dispose();
      _matchingBottomControllers.removeAt(index).dispose();
      _matchingBottomOrder = [
        for (var next = 0; next < _matchingTopControllers.length; next++) next,
      ];
    });
    _emit();
  }

  Widget _removeAssessmentButton() => TextButton.icon(
    onPressed: _savingAssessment ? null : () => _selectType(null),
    icon: const Icon(Icons.close, size: 18),
    label: const Text('Remove assessment'),
  );

  Widget _savedAssessmentCard() {
    final data = _buildData().data;
    final questions = switch (_type!) {
      AssessmentType.matching => [
        for (final item in _matchingTopControllers) item.text.trim(),
      ],
      AssessmentType.trueFalse => [
        for (final item in _trueFalseQuestionControllers) item.text.trim(),
      ],
      _ => [_questionController.text.trim()],
    };
    return _AssessmentFormCard(
      showError: false,
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.smallGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SvgPicture.asset(_type!.iconAsset, width: 28, height: 28),
                const SizedBox(width: AppMetrics.contentGap),
                Expanded(
                  child: Text(_type!.title, style: AppTypography.fieldLabel),
                ),
              ],
            ),
            const SizedBox(height: AppMetrics.contentGap),
            for (final question in questions) ...[
              Text(question, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: AppMetrics.smallGap),
            ],
            if (_type == AssessmentType.multipleChoice)
              for (final option in _optionControllers)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppMetrics.smallGap),
                  child: Text('•  ${option.text.trim()}'),
                ),
            if (_type == AssessmentType.paragraph)
              Text('Response length: ${data['response_length']}'),
            const SizedBox(height: AppMetrics.contentGap),
            const Center(
              child: Text('Assessment saved', style: TextStyle(color: _green)),
            ),
            const SizedBox(height: AppMetrics.contentGap),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit Assessment'),
                onPressed: () {
                  setState(() {
                    _finalized = false;
                    _assessmentSaved = false;
                    _saveAttempted = false;
                  });
                  widget.onChanged(_buildData());
                },
              ),
            ),
            Center(child: _removeAssessmentButton()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!assessmentFeaturesEnabled) return const SizedBox.shrink();
    if (_finalized && !_savingAssessment) return _savedAssessmentCard();
    final currentData = _buildData();
    final showError =
        (widget.showValidation || _saveAttempted) && !currentData.isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: showError ? _error : _green),
            borderRadius: BorderRadius.circular(9),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AssessmentSelectorShell(
                type: _type,
                showError: showError,
                expanded: _selectorExpanded,
                onToggle: () =>
                    setState(() => _selectorExpanded = !_selectorExpanded),
              ),
              if (_selectorExpanded)
                Container(
                  key: const ValueKey('assessment-type-dropdown'),
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: PageScrollWithFooter(
                    child: ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      itemCount: AssessmentType.values.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) => index == 0
                          ? Material(
                              color: Colors.white,
                              child: ListTile(
                                key: const ValueKey('no-assessment-option'),
                                title: const Text('—'),
                                subtitle: const Text('No assessment'),
                                onTap: () async {
                                  setState(() => _selectorExpanded = false);
                                  await _selectType(null);
                                },
                              ),
                            )
                          : SizedBox(
                              height: 76,
                              child: _SelectorPanelRow(
                                type: AssessmentType.values[index - 1],
                                selected:
                                    _type == AssessmentType.values[index - 1],
                                onTap: () async {
                                  setState(() => _selectorExpanded = false);
                                  await _selectType(
                                    AssessmentType.values[index - 1],
                                  );
                                },
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_type != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: _removeAssessmentButton(),
          ),
          const SizedBox(height: 16),
          _AssessmentFormCard(
            showError: showError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                switch (_type!) {
                  AssessmentType.numeric => _NumericForm(
                    questionController: _questionController,
                    answerController: _numericAnswerController,
                    minController: _numericMinController,
                    maxController: _numericMaxController,
                    explanationController: _explanationController,
                    showError: showError,
                  ),
                  AssessmentType.matching => _MatchingForm(
                    topControllers: _matchingTopControllers,
                    bottomControllers: _matchingBottomControllers,
                    bottomOrder: _matchingBottomOrder,
                    showError: showError,
                    onAddRow: _addMatchingRow,
                    onRemoveRow: _removeMatchingRow,
                  ),
                  AssessmentType.trueFalse => _TrueFalseForm(
                    questionControllers: _trueFalseQuestionControllers,
                    selectedAnswers: _trueFalseAnswers,
                    showError: showError,
                    onAddQuestion: _addTrueFalseQuestion,
                    onRemoveQuestion: _removeTrueFalseQuestion,
                    onAnswerChanged: (index, value) {
                      setState(() => _trueFalseAnswers[index] = value);
                      _emit();
                    },
                  ),
                  AssessmentType.paragraph => _ParagraphForm(
                    questionController: _questionController,
                    responseLength: _paragraphLength,
                    showError: showError,
                    onLengthChanged: (value) {
                      final limit = _paragraphLimit(value);
                      setState(() {
                        _paragraphLength = value;
                        if (_questionController.text.length > limit) {
                          _questionController.text = _questionController.text
                              .substring(0, limit);
                          _questionController.selection =
                              TextSelection.collapsed(offset: limit);
                        }
                      });
                      _emit();
                    },
                  ),
                  AssessmentType.multipleChoice => _MultipleChoiceForm(
                    questionController: _questionController,
                    optionControllers: _optionControllers,
                    explanationController: _explanationController,
                    correctIndex: _correctOptionIndex,
                    allowMultiple: _allowMultiple,
                    correctIndices: _correctIndices,
                    onMultipleChanged: (v) {
                      setState(() => _allowMultiple = v);
                      _emit();
                    },
                    showError: showError,
                    onAddOption: _addOption,
                    onRemoveOption: _removeOption,
                    onCorrectChanged: (index) {
                      setState(() {
                        if (_allowMultiple) {
                          if (!_correctIndices.add(index))
                            _correctIndices.remove(index);
                        } else
                          _correctOptionIndex = index;
                      });
                      _emit();
                    },
                  ),
                },
                const SizedBox(height: 16),
                Center(
                  child: FilledButton(
                    onPressed: _savingAssessment ? null : _saveAssessment,
                    child: Text(
                      _savingAssessment ? 'Saving…' : 'Save Assessment',
                    ),
                  ),
                ),
                if (_assessmentSaved) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Assessment saved',
                      style: TextStyle(color: _green),
                    ),
                  ),
                ],
                if (_saveError != null) ...[
                  const SizedBox(height: 8),
                  Text(_saveError!, style: const TextStyle(color: _error)),
                ],
                if (showError) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Complete the selected assessment before saving this block.',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _error,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  static int _paragraphLimit(String length) => switch (length) {
    'medium' => 300,
    'long' => 450,
    _ => 150,
  };
}

class _AssessmentSelectorShell extends StatelessWidget {
  final AssessmentType? type;
  final bool showError;
  final bool expanded;
  final VoidCallback onToggle;

  const _AssessmentSelectorShell({
    required this.type,
    required this.showError,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 47,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (type != null) ...[
                _AssessmentIcon(type: type!, size: 31),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  type?.title ?? 'Select Assessment',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _AssessmentBlockSectionState._text,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: expanded
                    ? 'Close assessment types'
                    : 'Choose assessment type',
                onPressed: onToggle,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: _AssessmentBlockSectionState._green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorPanelRow extends StatelessWidget {
  final AssessmentType type;
  final VoidCallback onTap;

  final bool selected;
  const _SelectorPanelRow({
    required this.type,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 10, 0),
          child: Row(
            children: [
              _AssessmentIcon(type: type, size: 33),
              const SizedBox(width: 21),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      type.selectorTitle,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _AssessmentBlockSectionState._text,
                        fontSize: AppTypography.bodySize,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: AppTypography.captionSize,
                        height: 1,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check,
                  color: _AssessmentBlockSectionState._green,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssessmentIcon extends StatelessWidget {
  final AssessmentType type;
  final double size;

  const _AssessmentIcon({required this.type, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _AssessmentBlockSectionState._purpleTile,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        type.iconAsset,
        width: size * .62,
        height: size * .62,
      ),
    );
  }
}

class _AssessmentFormCard extends StatelessWidget {
  final Widget child;
  final bool showError;

  const _AssessmentFormCard({required this.child, required this.showError});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: showError
              ? _AssessmentBlockSectionState._error
              : const Color(0xFFD8D0D0),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _NumericForm extends StatelessWidget {
  final TextEditingController questionController;
  final TextEditingController answerController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final TextEditingController explanationController;
  final bool showError;

  const _NumericForm({
    required this.questionController,
    required this.answerController,
    required this.minController,
    required this.maxController,
    required this.explanationController,
    required this.showError,
  });

  @override
  Widget build(BuildContext context) {
    final answer = num.tryParse(answerController.text.trim());
    final minimum = num.tryParse(minController.text.trim());
    final maximum = num.tryParse(maxController.text.trim());
    final hasAnswer = answer?.isFinite == true;
    final hasMinimum = minimum?.isFinite == true;
    final hasMaximum = maximum?.isFinite == true;
    final reversed = hasMinimum && hasMaximum && minimum! > maximum!;
    final validRange = hasMinimum && hasMaximum && !reversed;
    final below = validRange && hasAnswer && answer! < minimum!;
    final above = validRange && hasAnswer && answer! > maximum!;
    final rangeMessage = reversed
        ? 'The minimum must be less than or equal to the maximum.'
        : below || above
        ? 'The correct answer ($answer) is outside the acceptable range ($minimum to $maximum). Adjust the answer or the range so they match.'
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssessmentInput(
          label: 'Question',
          helper: 'Enter a numeric response question.',
          controller: questionController,
          maxLength: 300,
          height: 76,
          maxLines: 3,
          error: showError && questionController.text.trim().isEmpty,
        ),
        const SizedBox(height: 12),
        _AssessmentInput(
          label: 'Correct Answer',
          controller: answerController,
          maxLength: 80,
          height: 42,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          error: (showError && !hasAnswer) || below || above,
        ),
        const SizedBox(height: 12),
        const _SmallLabel('Acceptable Range'),
        const SizedBox(height: 4),
        const Text(
          'Set the minimum and maximum accepted values.',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: AppTypography.helperSize,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CompactTextField(
                controller: minController,
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                error: (showError && !hasMinimum) || reversed || below,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'to',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                ),
              ),
            ),
            Expanded(
              child: _CompactTextField(
                controller: maxController,
                hintText: '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                error: (showError && !hasMaximum) || reversed || above,
              ),
            ),
          ],
        ),
        if (rangeMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                rangeMessage,
                style: AppTypography.helper.copyWith(
                  color: _AssessmentBlockSectionState._error,
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        _AssessmentInput(
          label: 'Explanation',
          optional: true,
          controller: explanationController,
          maxLength: 300,
          height: 76,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _MatchingForm extends StatelessWidget {
  final List<TextEditingController> topControllers;
  final List<TextEditingController> bottomControllers;
  final List<int> bottomOrder;
  final bool showError;
  final VoidCallback onAddRow;
  final ValueChanged<int> onRemoveRow;

  const _MatchingForm({
    required this.topControllers,
    required this.bottomControllers,
    required this.bottomOrder,
    required this.showError,
    required this.onAddRow,
    required this.onRemoveRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Left Column (Terms)'),
        const SizedBox(height: 4),
        const Text(
          'What users will match from.',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: AppTypography.helperSize,
          ),
        ),
        const SizedBox(height: 8),
        _MatchingGroup(
          controllers: topControllers,
          badgeColor: _AssessmentBlockSectionState._green,
          showError: showError,
          onDelete: onRemoveRow,
        ),
        const SizedBox(height: 16),
        const _SmallLabel('Right Column (Definitions)'),
        const SizedBox(height: 4),
        const Text(
          'What users will match to.',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: AppTypography.helperSize,
          ),
        ),
        const SizedBox(height: 8),
        _MatchingGroup(
          controllers: bottomControllers,
          labels: bottomOrder,
          badgeColor: const Color(0xFF5B8DEF),
          showError: showError,
          onDelete: onRemoveRow,
        ),
        const SizedBox(height: 10),
        _MiniOutlineButton(label: '+ Add Rows', onTap: onAddRow),
      ],
    );
  }
}

class _MatchingGroup extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<int>? labels;
  final Color badgeColor;
  final bool showError;
  final ValueChanged<int>? onDelete;

  const _MatchingGroup({
    required this.controllers,
    required this.badgeColor,
    required this.showError,
    this.labels,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final children = List.generate(
      controllers.length,
      (index) => _MatchingItemRow(
        key: ValueKey(controllers[index]),
        index: index,
        controller: controllers[index],
        letterIndex: labels?[index] ?? index,
        badgeColor: badgeColor,
        showError: showError,
        canDelete: controllers.length > 2,
        onDelete: onDelete == null ? null : () => onDelete!(index),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8D0D0)),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _MatchingItemRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final int letterIndex;
  final Color badgeColor;
  final bool showError;
  final bool canDelete;
  final VoidCallback? onDelete;

  const _MatchingItemRow({
    super.key,
    required this.index,
    required this.controller,
    required this.letterIndex,
    required this.badgeColor,
    required this.showError,
    this.canDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const SizedBox(width: 15),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              String.fromCharCode(65 + letterIndex.clamp(0, 25)),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: Colors.white,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _CompactTextField(
              controller: controller,
              expandText: true,
              hintText: '',
              error: showError && controller.text.trim().isEmpty,
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: 1,
            child: AppTapTarget(
              onTap: canDelete ? onDelete : null,
              child: SvgPicture.asset(
                'assets/learning_module/learning_objective_trash.svg',
                width: 14,
                height: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TrueFalseForm extends StatelessWidget {
  final List<TextEditingController> questionControllers;
  final List<bool?> selectedAnswers;
  final bool showError;
  final VoidCallback onAddQuestion;
  final ValueChanged<int> onRemoveQuestion;
  final void Function(int index, bool value) onAnswerChanged;

  const _TrueFalseForm({
    required this.questionControllers,
    required this.selectedAnswers,
    required this.showError,
    required this.onAddQuestion,
    required this.onRemoveQuestion,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Question and Answer'),
        const SizedBox(height: 4),
        const Text(
          'Add statements and select whether each is true or false.',
          style: AppTypography.helper,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8D0D0)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              for (
                var index = 0;
                index < questionControllers.length;
                index++
              ) ...[
                _TrueFalseQuestionRow(
                  controller: questionControllers[index],
                  selectedAnswer: selectedAnswers[index],
                  showError: showError,
                  canDelete: questionControllers.length > 2,
                  onDelete: () => onRemoveQuestion(index),
                  onAnswerChanged: (value) => onAnswerChanged(index, value),
                ),
                if (index != questionControllers.length - 1)
                  const Divider(height: 1, color: Color(0xFFE6E6E6)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MiniOutlineButton(label: '+ Add Question', onTap: onAddQuestion),
      ],
    );
  }
}

class _TrueFalseQuestionRow extends StatelessWidget {
  final TextEditingController controller;
  final bool? selectedAnswer;
  final bool showError;
  final bool canDelete;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAnswerChanged;

  const _TrueFalseQuestionRow({
    required this.controller,
    required this.selectedAnswer,
    required this.showError,
    required this.canDelete,
    required this.onDelete,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: _CompactTextField(
              controller: controller,
              multiline: true,
              hintText: '',
              error: showError && controller.text.trim().isEmpty,
            ),
          ),
          const SizedBox(width: 8),
          _TinyChoice(
            label: 'T',
            selected: selectedAnswer == true,
            onTap: () => onAnswerChanged(true),
          ),
          _TinyChoice(
            label: 'F',
            selected: selectedAnswer == false,
            onTap: () => onAnswerChanged(false),
          ),
          const SizedBox(width: 6),
          Opacity(
            opacity: 1,
            child: AppTapTarget(
              onTap: canDelete ? onDelete : null,
              child: SvgPicture.asset(
                'assets/learning_module/learning_objective_trash.svg',
                width: 14,
                height: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TinyChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        width: 31,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x245DB075) : Colors.white,
          border: Border.all(
            color: selected
                ? _AssessmentBlockSectionState._green
                : const Color(0xFFD8D0D0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? _AssessmentBlockSectionState._green
                : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ParagraphForm extends StatelessWidget {
  final TextEditingController questionController;
  final String responseLength;
  final bool showError;
  final ValueChanged<String> onLengthChanged;

  const _ParagraphForm({
    required this.questionController,
    required this.responseLength,
    required this.showError,
    required this.onLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SmallLabel('Response Type'),
        const SizedBox(height: 8),
        PopupMenuButton<String>(
          initialValue: responseLength,
          onSelected: onLengthChanged,
          offset: const Offset(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'short',
              child: _LengthOption(title: 'Short', subtitle: '150 characters'),
            ),
            PopupMenuItem(
              value: 'medium',
              child: _LengthOption(title: 'Medium', subtitle: '300 characters'),
            ),
            PopupMenuItem(
              value: 'long',
              child: _LengthOption(title: 'Long', subtitle: '450 characters'),
            ),
          ],
          child: _DropdownLikeBox(label: _lengthLabel(responseLength)),
        ),
        const SizedBox(height: 12),
        _AssessmentInput(
          label: 'Question',
          controller: questionController,
          maxLength: _AssessmentBlockSectionState._paragraphLimit(
            responseLength,
          ),
          height: 76,
          maxLines: 3,
          error: showError && questionController.text.trim().isEmpty,
        ),
      ],
    );
  }

  static String _lengthLabel(String value) => switch (value) {
    'medium' => 'Medium',
    'long' => 'Long',
    _ => 'Short',
  };
}

class _MultipleChoiceForm extends StatelessWidget {
  final TextEditingController questionController;
  final List<TextEditingController> optionControllers;
  final TextEditingController explanationController;
  final int? correctIndex;
  final bool allowMultiple;
  final Set<int> correctIndices;
  final ValueChanged<bool> onMultipleChanged;
  final bool showError;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final ValueChanged<int> onCorrectChanged;

  const _MultipleChoiceForm({
    required this.questionController,
    required this.optionControllers,
    required this.explanationController,
    required this.correctIndex,
    required this.allowMultiple,
    required this.correctIndices,
    required this.onMultipleChanged,
    required this.showError,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onCorrectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssessmentInput(
          label: 'Question',
          controller: questionController,
          maxLength: 300,
          height: 76,
          maxLines: 3,
          error: showError && questionController.text.trim().isEmpty,
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: allowMultiple,
          onChanged: (v) => onMultipleChanged(v ?? false),
          title: const Text('Allow multiple selections'),
        ),
        const _SmallLabel('Answer Options'),
        const SizedBox(height: 4),
        Text(
          allowMultiple
              ? 'Mark every correct option below. Learners will not see the answer key.'
              : 'Mark one option as the correct answer below. Learners will not see the answer key.',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            color: Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < optionControllers.length; index++) ...[
          _OptionRow(
            index: index,
            multiple: allowMultiple,
            controller: optionControllers[index],
            selected: allowMultiple
                ? correctIndices.contains(index)
                : correctIndex == index,
            canDelete: optionControllers.length > 2,
            showError: showError,
            onSelected: () => onCorrectChanged(index),
            onDelete: () => onRemoveOption(index),
          ),
          if (index != optionControllers.length - 1)
            const SizedBox(height: AppMetrics.contentGap),
        ],
        const SizedBox(height: AppMetrics.contentGap),
        Center(
          child: _MiniOutlineButton(
            label: '+ Add Option',
            onTap: optionControllers.length >= 4 ? null : onAddOption,
          ),
        ),
        if (showError &&
            (allowMultiple
                ? correctIndices.isEmpty
                : correctIndex == null)) ...[
          const SizedBox(height: 8),
          const Text(
            'Select the correct answer.',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _AssessmentBlockSectionState._error,
              fontSize: AppTypography.helperSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
        const SizedBox(height: AppMetrics.fieldGap),
        _AssessmentInput(
          label: 'Explanation',
          optional: true,
          controller: explanationController,
          maxLength: 300,
          height: 76,
          maxLines: 3,
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final bool selected;
  final bool multiple;
  final bool canDelete;
  final bool showError;
  final VoidCallback onSelected;
  final VoidCallback onDelete;

  const _OptionRow({
    required this.index,
    required this.controller,
    required this.selected,
    this.multiple = false,
    required this.canDelete,
    required this.showError,
    required this.onSelected,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppTapTarget(
              onTap: onSelected,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected
                      ? _AssessmentBlockSectionState._green
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? _AssessmentBlockSectionState._green
                        : const Color(0xFFD8D0D0),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF777777),
                    fontSize: AppTypography.helperSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _CompactTextField(
                controller: controller,
                hintText: '',
                error: showError && controller.text.trim().isEmpty,
              ),
            ),
            const SizedBox(width: 6),
            AppTapTarget(
              behavior: HitTestBehavior.opaque,
              onTap: canDelete ? onDelete : null,
              child: Opacity(
                opacity: 1,
                child: SvgPicture.asset(
                  'assets/learning_module/learning_objective_trash.svg',
                  width: 14,
                  height: 16,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, AppMetrics.smallGap, 20, 0),
          child: Align(
            alignment: Alignment.center,
            child: Semantics(
              button: true,
              selected: selected,
              label:
                  'Mark option ${String.fromCharCode(65 + index)} as correct',
              child: TextButton.icon(
                onPressed: onSelected,
                icon: Icon(
                  selected
                      ? (multiple ? Icons.check_box : Icons.check_circle)
                      : (multiple
                            ? Icons.check_box_outline_blank
                            : Icons.radio_button_unchecked),
                  size: 20,
                ),
                label: Text(selected ? 'Correct answer' : 'Mark as correct'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppMetrics.controlHeight),
                  foregroundColor: selected
                      ? _AssessmentBlockSectionState._green
                      : const Color(0xFF555555),
                  backgroundColor: selected ? const Color(0xFFE8F5EB) : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.contentGap,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssessmentInput extends StatelessWidget {
  final String label;
  final String? helper;
  final bool optional;
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final int maxLines;
  final bool error;
  final TextInputType? keyboardType;

  const _AssessmentInput({
    required this.label,
    this.helper,
    required this.controller,
    required this.maxLength,
    required this.height,
    this.optional = false,
    this.maxLines = 1,
    this.error = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SmallLabel(label, optional: optional),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper!,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: AppTypography.helperSize,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          controller: controller,
          maxLength: maxLength,
          minLines: maxLines > 1 ? AppMetrics.longResponseLines : 1,
          maxLines: maxLines > 1 ? null : 1,
          textAlignVertical: maxLines > 1
              ? TextAlignVertical.top
              : TextAlignVertical.center,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == null
              ? null
              : [
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        RegExp(r'^-?\d*(\.\d*)?$').hasMatch(newValue.text)
                        ? newValue
                        : oldValue,
                  ),
                ],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: error
                    ? _AssessmentBlockSectionState._error
                    : _AssessmentBlockSectionState._green,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: error
                    ? _AssessmentBlockSectionState._error
                    : _AssessmentBlockSectionState._green,
              ),
            ),
          ),
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
      ],
    );
  }
}

class _CompactTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool error;
  final bool multiline;
  final bool expandText;
  final TextInputType? keyboardType;

  const _CompactTextField({
    required this.controller,
    required this.hintText,
    required this.error,
    this.keyboardType,
    this.multiline = false,
    this.expandText = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: multiline ? 76 : 40),
      child: TextField(
        controller: controller,
        minLines: multiline ? 2 : 1,
        maxLines: multiline || expandText ? null : 1,
        textAlignVertical: multiline
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        keyboardType: keyboardType,
        inputFormatters: keyboardType == null
            ? null
            : [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^-?\d*(\.\d*)?$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
        decoration: InputDecoration(
          hintText: hintText,
          isDense: true,
          constraints: const BoxConstraints(minHeight: 40),
          hintStyle: const TextStyle(
            color: Color(0xFFBEBEBE),
            fontSize: AppTypography.helperSize,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
              color: error
                  ? _AssessmentBlockSectionState._error
                  : _AssessmentBlockSectionState._green,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(
              color: error
                  ? _AssessmentBlockSectionState._error
                  : _AssessmentBlockSectionState._green,
            ),
          ),
        ),
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.bodySize,
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _SmallLabel(this.label, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _AssessmentBlockSectionState._text,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                color: _AssessmentBlockSectionState._muted,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MiniOutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 28,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: _AssessmentBlockSectionState._text,
          disabledForegroundColor: const Color(0xFF9A9A9A),
          side: const BorderSide(color: Color(0xFFD8D0D0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.buttonSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DropdownLikeBox extends StatelessWidget {
  final String label;

  const _DropdownLikeBox({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _AssessmentBlockSectionState._green),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/learning_module/text_block_chevron.svg',
            width: 13,
            height: 13,
            colorFilter: const ColorFilter.mode(
              Color(0xFF8BD5A0),
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthOption extends StatelessWidget {
  final String title;
  final String subtitle;

  const _LengthOption({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: AppTypography.helperSize,
          ),
        ),
      ],
    );
  }
}
