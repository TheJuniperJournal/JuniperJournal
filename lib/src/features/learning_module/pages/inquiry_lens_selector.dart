import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InquiryLensData {
  static const noneValue = 'None';

  final String selectedLens;
  final Map<String, InquiryLensState> lensStates;

  const InquiryLensData({
    this.selectedLens = noneValue,
    this.lensStates = const {},
  });

  bool get hasLens =>
      selectedLens != noneValue && selectedLens.trim().isNotEmpty;

  InquiryLensState activeState(InquiryLensConfig config) {
    return lensStates[config.value] ?? InquiryLensState.defaultsFor(config);
  }

  Map<String, dynamic> toPreviewJson() {
    final config = InquiryLensConfig.byValue(selectedLens);
    if (config == null) {
      return {
        'lens': '',
        'thinking_focus': <String>[],
        'custom_focus': <String>[],
        'student_response': '',
        'student_instruction': '',
      };
    }
    final state = activeState(config);
    return {
      'lens': selectedLens,
      'thinking_focus': state.checkedFocusItems,
      'custom_focus': state.customFocusItems
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'student_response': state.selectedStudentResponse,
      'student_instruction': state.studentInstruction.trim(),
    };
  }

  InquiryLensData selectLens(String value) {
    if (value == noneValue) {
      return InquiryLensData(
        selectedLens: noneValue,
        lensStates: Map<String, InquiryLensState>.from(lensStates),
      );
    }
    final config = InquiryLensConfig.byValue(value);
    if (config == null) return this;
    final nextStates = Map<String, InquiryLensState>.from(lensStates);
    nextStates.putIfAbsent(value, () => InquiryLensState.defaultsFor(config));
    return InquiryLensData(selectedLens: value, lensStates: nextStates);
  }

  InquiryLensData updateActiveState(InquiryLensState state) {
    if (!hasLens) return this;
    final nextStates = Map<String, InquiryLensState>.from(lensStates);
    nextStates[selectedLens] = state;
    return InquiryLensData(selectedLens: selectedLens, lensStates: nextStates);
  }

  Map<String, dynamic> toJson() => {
    'selected_lens': selectedLens,
    'lens_states': {
      for (final entry in lensStates.entries) entry.key: entry.value.toJson(),
    },
  };

  factory InquiryLensData.fromJson(
    Object? raw, {
    String legacyLens = noneValue,
  }) {
    final cleanLegacy = _normalizeLens(legacyLens);
    if (raw is! Map) {
      return const InquiryLensData().selectLens(cleanLegacy);
    }
    final map = Map<String, dynamic>.from(raw);
    final selected = _normalizeLens(
      map['selected_lens']?.toString() ?? cleanLegacy,
    );
    final states = <String, InquiryLensState>{};
    final rawStates = map['lens_states'];
    if (rawStates is Map) {
      for (final entry in rawStates.entries) {
        final key = _normalizeLens(entry.key.toString());
        final config = InquiryLensConfig.byValue(key);
        if (config != null && entry.value is Map) {
          states[key] = InquiryLensState.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
            config,
          );
        }
      }
    }
    final data = InquiryLensData(selectedLens: selected, lensStates: states);
    return selected == noneValue ? data : data.selectLens(selected);
  }

  static String _normalizeLens(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == noneValue) return noneValue;
    final config = InquiryLensConfig.byValue(trimmed);
    return config?.value ?? noneValue;
  }
}

class InquiryLensState {
  final List<String> checkedFocusItems;
  final List<String> customFocusItems;
  final String selectedStudentResponse;
  final String studentInstruction;
  final DateTime? updatedAt;

  const InquiryLensState({
    this.checkedFocusItems = const [],
    this.customFocusItems = const [],
    this.selectedStudentResponse = '',
    this.studentInstruction = '',
    this.updatedAt,
  });

  factory InquiryLensState.defaultsFor(InquiryLensConfig config) {
    return InquiryLensState(
      selectedStudentResponse: config.responses.first.value,
    );
  }

  InquiryLensState copyWith({
    List<String>? checkedFocusItems,
    List<String>? customFocusItems,
    String? selectedStudentResponse,
    String? studentInstruction,
    DateTime? updatedAt,
  }) {
    return InquiryLensState(
      checkedFocusItems: checkedFocusItems ?? this.checkedFocusItems,
      customFocusItems: customFocusItems ?? this.customFocusItems,
      selectedStudentResponse:
          selectedStudentResponse ?? this.selectedStudentResponse,
      studentInstruction: studentInstruction ?? this.studentInstruction,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'checked_focus_items': checkedFocusItems,
    'custom_focus_items': customFocusItems,
    'selected_student_response': selectedStudentResponse,
    'student_instruction': studentInstruction,
    'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
  };

  factory InquiryLensState.fromJson(
    Map<String, dynamic> json,
    InquiryLensConfig config,
  ) {
    final hasCheckedFocus = json.containsKey('checked_focus_items');
    final checked = _stringList(json['checked_focus_items']);
    final custom = _stringList(json['custom_focus_items']);
    final response = json['selected_student_response']?.toString() ?? '';
    return InquiryLensState(
      checkedFocusItems: hasCheckedFocus ? checked : const [],
      customFocusItems: custom,
      selectedStudentResponse:
          config.responses.any((item) => item.value == response)
          ? response
          : config.responses.first.value,
      studentInstruction: json['student_instruction']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item != null) item.toString(),
    ];
  }
}

class InquiryLensConfig {
  final String value;
  final String description;
  final String iconAsset;
  final String purpose;
  final List<String> focusOptions;
  final List<InquiryResponseOption> responses;
  final String instructionPlaceholder;

  const InquiryLensConfig({
    required this.value,
    required this.description,
    required this.iconAsset,
    required this.purpose,
    required this.focusOptions,
    required this.responses,
    required this.instructionPlaceholder,
  });

  static const writeResponse = InquiryResponseOption(
    value: 'Write',
    iconAsset: 'assets/learning_module/inquiry_response_write.svg',
  );
  static const drawResponse = InquiryResponseOption(
    value: 'Draw/Sketch',
    iconAsset: 'assets/learning_module/inquiry_response_draw.svg',
  );
  static const photoResponse = InquiryResponseOption(
    value: 'Photograph',
    iconAsset: 'assets/learning_module/inquiry_response_photograph.svg',
  );
  static const graphResponse = InquiryResponseOption(
    value: 'Graph',
    iconAsset: 'assets/learning_module/inquiry_response_graph.svg',
  );
  static const tableResponse = InquiryResponseOption(
    value: 'Table',
    iconAsset: 'assets/learning_module/inquiry_response_table.svg',
  );

  static const values = [
    InquiryLensConfig(
      value: 'Observe',
      description: 'Notice patterns, details, and relationships.',
      iconAsset: 'assets/learning_module/inquiry_observe.svg',
      purpose:
          'This inquiry lens helps users know notice patterns, details, structures, and changes in what they see.',
      focusOptions: [
        'Notice',
        'Identify patterns',
        'Compare',
        'Describe changes',
        'Make connections',
      ],
      responses: [writeResponse, drawResponse, photoResponse],
      instructionPlaceholder:
          'Example: Observe the solar panel installation diagram and identify patterns in how energy moves from the sun to the building.',
    ),
    InquiryLensConfig(
      value: 'Wonder',
      description: 'Ask questions and wonder about phenomena.',
      iconAsset: 'assets/learning_module/inquiry_wonder.svg',
      purpose:
          'This inquiry lens helps users generate questions and identify what they want to learn.',
      focusOptions: [
        'Ask questions',
        'Identify what is unclear',
        'Form a hypothesis',
        'Consider the possibility',
        'Make a prediction',
      ],
      responses: [writeResponse],
      instructionPlaceholder:
          'Example: After exploring the compost system, write two questions about how food waste becomes healthy soil.',
    ),
    InquiryLensConfig(
      value: 'Investigate',
      description: 'Plan and conduct investigation to collect evidence.',
      iconAsset: 'assets/learning_module/inquiry_investigate.svg',
      purpose:
          'This inquiry lens helps users gather evidence and explore information.',
      focusOptions: [
        'Collect data',
        'Research',
        'Measure',
        'Record information',
      ],
      responses: [
        writeResponse,
        drawResponse,
        photoResponse,
        graphResponse,
        tableResponse,
      ],
      instructionPlaceholder:
          'Example: Measure the temperature of shaded and unshaded surfaces and record the differences you observe.',
    ),
    InquiryLensConfig(
      value: 'Explain',
      description: 'Explain ideas and reasoning using evidence.',
      iconAsset: 'assets/learning_module/inquiry_explain.svg',
      purpose:
          'This inquiry lens helps users explain ideas using evidence and reasoning.',
      focusOptions: [
        'Provide evidence',
        'Explain reasoning',
        'Support claim',
        'Communicate findings',
        'Make a conclusion',
      ],
      responses: [writeResponse, drawResponse],
      instructionPlaceholder:
          'Example: Use your observations to explain why native plants require less watering than traditional lawns.',
    ),
    InquiryLensConfig(
      value: 'Systems',
      description: 'Understand how parts of a system interact.',
      iconAsset: 'assets/learning_module/inquiry_systems.svg',
      purpose:
          'This inquiry lens helps users understand how parts of a system interact.',
      focusOptions: [
        'Identify components',
        'Analyze interactions',
        'Identify cause and effect',
        'Consider the whole system',
        'Identify input and output',
      ],
      responses: [writeResponse, drawResponse, photoResponse],
      instructionPlaceholder:
          'Example: Identify how rainfall, soil, plants, and runoff interact within a rain garden system.',
    ),
    InquiryLensConfig(
      value: 'Design',
      description: 'Create, test, and improve solutions through design.',
      iconAsset: 'assets/learning_module/inquiry_design.svg',
      purpose:
          'This inquiry lens helps users create and improve designs or solutions.',
      focusOptions: [
        'Design',
        'Brainstorm',
        'Prototype',
        'Test & Evaluate',
        'Iterate',
      ],
      responses: [writeResponse, drawResponse, photoResponse],
      instructionPlaceholder:
          'Example: Design a school recycling station that makes it easier for students to sort waste correctly.',
    ),
  ];

  static InquiryLensConfig? byValue(String value) {
    for (final config in values) {
      if (config.value == value) return config;
    }
    return null;
  }
}

class InquiryResponseOption {
  final String value;
  final String iconAsset;

  const InquiryResponseOption({required this.value, required this.iconAsset});
}

class InquiryLensSelector extends StatefulWidget {
  static const noneValue = InquiryLensData.noneValue;
  static const green = Color(0xFF5DB075);
  static const text = Color(0xFF141414);
  static const muted = Color(0xFFCECECE);

  final InquiryLensData data;
  final ValueChanged<InquiryLensData> onChanged;

  const InquiryLensSelector({
    super.key,
    required this.data,
    required this.onChanged,
  });

  @override
  State<InquiryLensSelector> createState() => _InquiryLensSelectorState();
}

class _InquiryLensSelectorState extends State<InquiryLensSelector> {
  late final TextEditingController _instructionController;
  final List<TextEditingController> _customControllers = [];

  InquiryLensConfig? get _selected =>
      InquiryLensConfig.byValue(widget.data.selectedLens);

  InquiryLensState? get _activeState {
    final selected = _selected;
    if (selected == null) return null;
    return widget.data.activeState(selected);
  }

  @override
  void initState() {
    super.initState();
    _instructionController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant InquiryLensSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    for (final controller in _customControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final state = _activeState;
    final instruction = state?.studentInstruction ?? '';
    if (_instructionController.text != instruction) {
      _instructionController.value = TextEditingValue(
        text: instruction,
        selection: TextSelection.collapsed(offset: instruction.length),
      );
    }
    final customItems = state?.customFocusItems ?? const <String>[];
    while (_customControllers.length < customItems.length) {
      _customControllers.add(TextEditingController());
    }
    while (_customControllers.length > customItems.length) {
      _customControllers.removeLast().dispose();
    }
    for (var index = 0; index < customItems.length; index++) {
      final controller = _customControllers[index];
      if (controller.text != customItems[index]) {
        controller.value = TextEditingValue(
          text: customItems[index],
          selection: TextSelection.collapsed(offset: customItems[index].length),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _selected;
    final state = _activeState;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: config == null || state == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel(),
                const SizedBox(height: 11),
                _buildField(),
              ],
            )
          : Container(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6EF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(),
                  const SizedBox(height: 11),
                  _buildField(),
                  const SizedBox(height: AppMetrics.sectionGap),
                  _buildSectionTitle('Purpose (for you)'),
                  const SizedBox(height: AppMetrics.labelGap),
                  _PurposeCard(config: config),
                  const SizedBox(height: AppMetrics.fieldGap),
                  _buildSectionTitle('Thinking Focus'),
                  const SizedBox(height: 9),
                  const Text(
                    'Choose how you want users to focus.',
                    style: TextStyle(
                      color: Color(0xB3000000),
                      fontSize: AppTypography.bodySize,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.fieldGap),
                  for (final item in config.focusOptions) ...[
                    _FocusCheckRow(
                      label: item,
                      checked: state.checkedFocusItems.contains(item),
                      onTap: () => _toggleFocus(item),
                    ),
                    const SizedBox(height: AppMetrics.labelGap),
                  ],
                  for (
                    var index = 0;
                    index < state.customFocusItems.length;
                    index++
                  ) ...[
                    _CustomFocusRow(
                      controller: _customControllers[index],
                      onChanged: (value) => _updateCustomFocus(index, value),
                      onDelete: () => _deleteCustomFocus(index),
                    ),
                    const SizedBox(height: AppMetrics.labelGap),
                  ],
                  _AddFocusRow(onTap: _addCustomFocus),
                  const SizedBox(height: 27),
                  _buildSectionTitle('Student Responses'),
                  const SizedBox(height: 9),
                  const Text(
                    'Choose how students should respond.',
                    style: TextStyle(
                      color: Color(0xB3000000),
                      fontSize: AppTypography.bodySize,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.labelGap),
                  _ResponseGrid(
                    options: config.responses,
                    selected: state.selectedStudentResponse,
                    onSelected: _selectResponse,
                  ),
                  const SizedBox(height: 27),
                  _buildSectionTitle('Student Instruction'),
                  const SizedBox(height: 9),
                  const Text(
                    'Add specific instructions for students to interact with this inquiry.',
                    style: AppTypography.helper,
                  ),
                  const SizedBox(height: 12),
                  _InstructionBox(
                    controller: _instructionController,
                    hintText: '',
                    onChanged: _updateInstruction,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel() {
    return const Text.rich(
      TextSpan(
        text: 'Inquiry Lens',
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: InquiryLensSelector.text,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
        ),
        children: [
          TextSpan(
            text: ' (Optional)',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: InquiryLensSelector.muted,
              fontSize: AppTypography.helperSize,
              height: 1,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InquiryLensChoiceGrid(data: widget.data, onChanged: widget.onChanged),
      if (widget.data.hasLens)
        TextButton(
          onPressed: () => widget.onChanged(
            widget.data.selectLens(InquiryLensData.noneValue),
          ),
          child: const Text(
            'Clear Inquiry Lens',
            style: TextStyle(color: Color(0xFFD12E2E)),
          ),
        ),
    ],
  );

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      color: InquiryLensSelector.text,
      fontSize: AppTypography.bodySize,
      height: 1.1,
      fontWeight: FontWeight.w500,
    ),
  );

  void _toggleFocus(String item) {
    final state = _activeState;
    if (state == null) return;
    final checked = [...state.checkedFocusItems];
    if (checked.contains(item)) {
      checked.remove(item);
    } else {
      checked.add(item);
    }
    _updateState(state.copyWith(checkedFocusItems: checked));
  }

  void _addCustomFocus() {
    final state = _activeState;
    if (state == null) return;
    _updateState(
      state.copyWith(customFocusItems: [...state.customFocusItems, '']),
    );
  }

  void _updateCustomFocus(int index, String value) {
    final state = _activeState;
    if (state == null || index >= state.customFocusItems.length) return;
    final custom = [...state.customFocusItems];
    custom[index] = value;
    _updateState(state.copyWith(customFocusItems: custom));
  }

  void _deleteCustomFocus(int index) {
    final state = _activeState;
    if (state == null || index >= state.customFocusItems.length) return;
    final custom = [...state.customFocusItems]..removeAt(index);
    _updateState(state.copyWith(customFocusItems: custom));
  }

  void _selectResponse(String value) {
    final state = _activeState;
    if (state == null) return;
    _updateState(state.copyWith(selectedStudentResponse: value));
  }

  void _updateInstruction(String value) {
    final state = _activeState;
    if (state == null) return;
    _updateState(state.copyWith(studentInstruction: value));
  }

  void _updateState(InquiryLensState state) {
    widget.onChanged(
      widget.data.updateActiveState(state.copyWith(updatedAt: DateTime.now())),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  final InquiryLensConfig config;

  const _PurposeCard({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0x1A5DB075),
        border: Border.all(color: InquiryLensSelector.green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/learning_module/inquiry_purpose_bulb.svg',
            width: 33,
            height: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              config.purpose,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: InquiryLensSelector.text,
                fontSize: AppTypography.helperSize,
                height: 1.24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusCheckRow extends StatelessWidget {
  final String label;
  final bool checked;
  final VoidCallback onTap;

  const _FocusCheckRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          _CheckBox(checked: checked),
          const SizedBox(width: 21),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: InquiryLensSelector.text,
                fontSize: AppTypography.bodySize,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomFocusRow extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  const _CustomFocusRow({
    required this.controller,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _CheckBox(checked: true),
        const SizedBox(width: 21),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              height: 1.1,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '',
              hintStyle: TextStyle(color: Color(0x66000000)),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
          icon: const Icon(
            Icons.close,
            size: 18,
            color: InquiryLensSelector.green,
          ),
        ),
      ],
    );
  }
}

class _AddFocusRow extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFocusRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const Row(
        children: [
          SizedBox(width: 4),
          Icon(Icons.add, color: InquiryLensSelector.green, size: 14),
          SizedBox(width: 5),
          Text(
            'Add your own',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: InquiryLensSelector.green,
              fontSize: AppTypography.buttonSize,
              height: 1.1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool checked;

  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: checked ? const Color(0x1A5DB075) : Colors.transparent,
        border: Border.all(color: InquiryLensSelector.green),
        borderRadius: BorderRadius.circular(2),
      ),
      child: checked
          ? const Icon(Icons.check, color: InquiryLensSelector.green, size: 14)
          : null,
    );
  }
}

class _ResponseGrid extends StatelessWidget {
  final List<InquiryResponseOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ResponseGrid({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 13,
        alignment: WrapAlignment.center,
        children: [
          for (final option in options)
            _ResponseCard(
              option: option,
              selected: selected == option.value,
              onTap: () => onSelected(option.value),
            ),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final InquiryResponseOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ResponseCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 162,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: InquiryLensSelector.green),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SvgPicture.asset(option.iconAsset, width: 20, height: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                option.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.bodySize,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: InquiryLensSelector.green),
      ),
      child: selected
          ? Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: InquiryLensSelector.green,
              ),
            )
          : null,
    );
  }
}

class _InstructionBox extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _InstructionBox({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: InquiryLensSelector.green),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Stack(
        children: [
          TextField(
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            expands: true,
            maxLength: 300,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              height: 1.24,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '',
              hintMaxLines: 4,
              hintStyle: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
                height: 1.24,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(9, 8, 9, 22),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 6,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One inquiry-lens design shared by all journal and learning entry surfaces.
class InquiryLensChoiceGrid extends StatelessWidget {
  const InquiryLensChoiceGrid({
    super.key,
    required this.data,
    required this.onChanged,
    this.showError = false,
  });
  final InquiryLensData data;
  final ValueChanged<InquiryLensData> onChanged;
  final bool showError;
  static const displayOrder = [
    'Design',
    'Observe',
    'Investigate',
    'Wonder',
    'Systems',
    'Explain',
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 332.0;
      final columns = width >= 600
          ? 3
          : width >= 300
          ? 2
          : 1;
      Widget card(String value) => _InquiryLensChoiceCard(
        option: InquiryLensConfig.byValue(value)!,
        selected: data.selectedLens == value,
        showError: showError,
        onTap: () => onChanged(data.selectLens(value)),
      );
      return Column(
        children: [
          for (
            var index = 0;
            index < displayOrder.length;
            index += columns
          ) ...[
            if (index > 0) const SizedBox(height: AppMetrics.contentGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var offset = 0;
                    offset < columns && index + offset < displayOrder.length;
                    offset++
                  ) ...[
                    if (offset > 0)
                      const SizedBox(width: AppMetrics.contentGap),
                    Expanded(child: card(displayOrder[index + offset])),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _InquiryLensChoiceCard extends StatelessWidget {
  const _InquiryLensChoiceCard({
    required this.option,
    required this.selected,
    required this.showError,
    required this.onTap,
  });
  final InquiryLensConfig option;
  final bool selected;
  final bool showError;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: AppTapTarget(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x195DB075) : Colors.white,
          border: Border.all(
            color: showError ? Colors.red : InquiryLensSelector.green,
          ),
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF0E4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(option.iconAsset),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(option.value, style: AppTypography.fieldLabel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              option.description,
              style: AppTypography.helper.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}
