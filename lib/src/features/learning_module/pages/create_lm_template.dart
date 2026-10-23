import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/features/learning_module/learning_module.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

/// **Purpose:**
/// Provides a clear and engaging title for the learning experience.
///
/// **Key Features:**
/// - Serves as the headline for the lesson or module.
/// - Displayed on module cards and schedules.
/// - Helps categorize and communicate the content scope.
///
/// **Creator Actions / Behaviors:**
/// - Enter a short, descriptive, and engaging title during module creation
///   (e.g., `"What is Photosynthesis?"`).
/// - Ensure the title reflects the key theme or learning objective of the lesson.
///
/// **User Behaviors:**
/// - View the lesson title when browsing or selecting learning modules.
/// - Use the title as a cue to determine relevance or interest.
/// - Search for lessons by title using the search bar.
class CreateTemplateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingModule;

  const CreateTemplateScreen({super.key, this.existingModule});

  @override
  State<CreateTemplateScreen> createState() => _CreateTemplateScreenState();
}

class _CreateTemplateScreenState extends State<CreateTemplateScreen> {
  static const _green = Color(0xFF5DB075);
  static const _textPrimary = Color(0xFF191919);
  static const _textSecondary = Color(0xFF606060);
  static const _softGreen = Color(0x1A5DB075);
  double get _screenWidth =>
      JournalPageLayout.widthFor(context, mobileWidth: 393);
  static const Map<String, List<String>> _focusByDomain = {
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

  final _formKey = GlobalKey<FormState>();
  final _moduleNameController = TextEditingController();
  final _inquiryTypeChipKey = GlobalKey();
  String _selectedInquiryType = 'What';
  String? _selectedDifficulty;
  String _selectedSubjectDomain = 'Environment & Sustainability';
  String _selectedSubjectFocus = 'Ecosystems & Biodiversity';

  final List<_DifficultyOption> _difficultyOptions = const [
    _DifficultyOption(
      label: 'Easy',
      storedValue: 'Easy',
      ecoPoints: 100,
      iconAsset: 'assets/learning_module/easy.svg',
      iconWidth: 23,
      iconHeight: 19,
    ),
    _DifficultyOption(
      label: 'Medium',
      storedValue: 'Medium',
      ecoPoints: 250,
      iconAsset: 'assets/learning_module/med.svg',
      iconWidth: 46,
      iconHeight: 25,
    ),
    _DifficultyOption(
      label: 'Hard',
      storedValue: 'Hard',
      ecoPoints: 500,
      iconAsset: 'assets/learning_module/hard.svg',
      iconWidth: 45,
      iconHeight: 34,
    ),
  ];

  @override
  void dispose() {
    _moduleNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // If editing, prefill data
    final module = widget.existingModule;
    if (module != null) {
      _moduleNameController.text = module['module_name'] ?? '';
      _selectedDifficulty = _normalizeDifficulty(module['difficulty']);
      final creatorAction = module['creator_action']?.toString();
      if (creatorAction != null && creatorAction.isNotEmpty) {
        _selectedInquiryType =
            creatorAction[0].toUpperCase() +
            creatorAction.substring(1).toLowerCase();
      }
      final inquiry = module['inquiry'];
      if (inquiry is List && inquiry.isNotEmpty) {
        _moduleNameController.text = inquiry.first?.toString() ?? '';
      }
      _selectedSubjectDomain = _normalizeSubjectDomain(
        _firstString(module['subject_domain']),
      );
      final subjectEntries = _stringList(module['subject_domain']);
      final focus = subjectEntries.length > 1
          ? subjectEntries[1]
          : module['subject_focus']?.toString();
      if (focus != null &&
          (_focusByDomain[_selectedSubjectDomain] ?? const []).contains(
            focus,
          )) {
        _selectedSubjectFocus = focus;
      } else {
        _selectedSubjectFocus = _focusByDomain[_selectedSubjectDomain]!.first;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _screenWidth),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: _screenWidth,
                  height: 935,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 21,
                        top: 40,
                        width: 23,
                        height: 23,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: SvgPicture.asset(
                            'assets/learning_module/x.svg',
                            colorFilter: const ColorFilter.mode(
                              _green,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 33,
                        child: Text(
                          'Module Setup',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTypography.headingFamily,
                            color: _textPrimary,
                            fontSize: AppTypography.sectionTitleSize,
                            height: 1.06,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 102,
                        child: Text(
                          'Anchoring\nPhenomena',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.bodySize,
                            height: 1.03,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 137,
                        child: Text(
                          'Add specific description of why this answer is correct.',
                          style: AppTypography.helper,
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 167,
                        width: 85,
                        height: 24,
                        child: _DropdownChip(
                          key: _inquiryTypeChipKey,
                          text: _selectedInquiryType,
                          onTap: _showInquiryTypeMenu,
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 248,
                        width: _screenWidth - 48,
                        height: 64,
                        child: TextFormField(
                          controller: _moduleNameController,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: _textPrimary,
                            fontSize: AppTypography.bodySize,
                            height: 1.15,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: '',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8C8C8C),
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 14,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _green),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _green),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.redAccent,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            errorStyle: const TextStyle(height: 0.85),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Module name must be completed';
                            }
                            return null;
                          },
                        ),
                      ),
                      Positioned(
                        left: 25,
                        top: 316,
                        child: Text(
                          'Difficulty',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.bodySize,
                            height: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        top: 335,
                        child: Text(
                          'Select a difficulty.',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: _textSecondary,
                            fontSize: AppTypography.bodySize,
                            height: 1,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 25,
                        top: 365,
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < _difficultyOptions.length;
                              index++
                            ) ...[
                              _DifficultyCard(
                                option: _difficultyOptions[index],
                                isSelected:
                                    _selectedDifficulty ==
                                    _difficultyOptions[index].storedValue,
                                onTap: () {
                                  setState(() {
                                    _selectedDifficulty =
                                        _difficultyOptions[index].storedValue;
                                  });
                                },
                              ),
                              if (index != _difficultyOptions.length - 1)
                                SizedBox(width: 15),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 23,
                        top: 504,
                        width: _screenWidth - 45,
                        height: 140,
                        child: _SubjectPanel(
                          selectedDomain: _selectedSubjectDomain,
                          selectedFocus: _selectedSubjectFocus,
                          domainOptions: _focusByDomain.keys.toList(),
                          focusOptions:
                              _focusByDomain[_selectedSubjectDomain] ??
                              const [],
                          onDomainSelected: (domain) {
                            setState(() {
                              _selectedSubjectDomain = domain;
                              _selectedSubjectFocus =
                                  _focusByDomain[domain]!.first;
                            });
                          },
                          onFocusSelected: (focus) {
                            setState(() {
                              _selectedSubjectFocus = focus;
                            });
                          },
                        ),
                      ),
                      Positioned(
                        left: 21,
                        top: 684,
                        width: _screenWidth - 48,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Next',
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
      ),
    );
  }

  Future<void> _showInquiryTypeMenu() async {
    final chipContext = _inquiryTypeChipKey.currentContext;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(chipRect.left, chipRect.bottom + 4, chipRect.width, 0),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: 'What', child: _InquiryMenuText('What')),
        PopupMenuItem(value: 'Why', child: _InquiryMenuText('Why')),
        PopupMenuItem(value: 'How', child: _InquiryMenuText('How')),
        PopupMenuItem(value: 'When', child: _InquiryMenuText('When')),
      ],
    );

    if (selected == null || selected == _selectedInquiryType) {
      return;
    }

    setState(() {
      _selectedInquiryType = selected;
    });
  }

  Future<void> _submit() async {
    final formIsValid = _formKey.currentState!.validate();
    if (!formIsValid) {
      return;
    }

    if (_selectedDifficulty == null) {
      showTopSnackBar(
        context,
        'Difficulty level must be selected',
        isError: true,
      );
      return;
    }

    final option = _difficultyOptions.firstWhere(
      (item) => item.storedValue == _selectedDifficulty,
    );
    final moduleName = _moduleNameController.text.trim();
    final inquiry = [moduleName];
    final navigator = Navigator.of(context);
    final repo = LearningModuleRepo();
    final authService = AuthService.instance;

    Map<String, dynamic>? moduleData;

    if (widget.existingModule == null) {
      final userId = authService.currentUser?.id;

      moduleData = await repo.createModule(
        moduleName: moduleName,
        difficulty: option.storedValue,
        ecoPoints: option.ecoPoints,
        authorId: userId,
        creatorAction: _selectedInquiryType.toUpperCase(),
        inquiry: inquiry,
        subjectDomain: _selectedSubjectDomain,
        subjectFocus: _selectedSubjectFocus,
      );
    } else {
      final success = await repo.updateModule(
        id: widget.existingModule!['id'].toString(),
        moduleName: moduleName,
        difficulty: option.storedValue,
        ecoPoints: option.ecoPoints,
        creatorAction: _selectedInquiryType.toUpperCase(),
        inquiry: inquiry,
        subjectDomain: _selectedSubjectDomain,
        subjectFocus: _selectedSubjectFocus,
      );
      if (success) {
        moduleData = Map<String, dynamic>.from(widget.existingModule!);
        moduleData['module_name'] = moduleName;
        moduleData['difficulty'] = option.storedValue;
        moduleData['eco_points'] = option.ecoPoints;
        moduleData['creator_action'] = _selectedInquiryType.toUpperCase();
        moduleData['inquiry'] = inquiry;
        moduleData['subject_domain'] = [
          _selectedSubjectDomain,
          _selectedSubjectFocus,
        ];
      }
    }

    if (!mounted) {
      return;
    }

    if (moduleData != null) {
      pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (context) => ModuleDashboardScreen(module: moduleData!),
        ),
      );
    } else {
      showTopSnackBar(context, 'Failed to save module', isError: true);
    }
  }

  String? _normalizeDifficulty(dynamic rawDifficulty) {
    if (rawDifficulty == null) {
      return null;
    }

    final difficulty = rawDifficulty.toString();
    if (difficulty.contains('Basic') || difficulty == 'Easy') {
      return 'Easy';
    }
    if (difficulty.contains('Intermediate') || difficulty == 'Medium') {
      return 'Medium';
    }
    if (difficulty.contains('Advanced') || difficulty == 'Hard') {
      return 'Hard';
    }
    return difficulty;
  }

  String _placeholderForInquiryType(String type) {
    return switch (type) {
      'When' => 'Add timing or context...',
      'Why' => 'Explain why this matters...',
      'How' => 'Describe how this happens...',
      _ => 'Explain the inquiry...',
    };
  }

  String _firstString(dynamic value) {
    final values = _stringList(value);
    return values.isEmpty ? '' : values.first;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return [
        for (final entry in value)
          if ((entry?.toString().trim() ?? '').isNotEmpty)
            entry.toString().trim(),
      ];
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? const [] : [text];
  }

  String _normalizeSubjectDomain(String value) {
    if (_focusByDomain.containsKey(value)) {
      return value;
    }
    if (value == 'Environmental Sustainability') {
      return 'Environment & Sustainability';
    }
    if (value == 'Community & The Built Environment') {
      return 'Community & Built Environment';
    }
    return 'Environment & Sustainability';
  }
}

class _DifficultyOption {
  final String label;
  final String storedValue;
  final int ecoPoints;
  final String iconAsset;
  final double iconWidth;
  final double iconHeight;

  const _DifficultyOption({
    required this.label,
    required this.storedValue,
    required this.ecoPoints,
    required this.iconAsset,
    required this.iconWidth,
    required this.iconHeight,
  });
}

class _DifficultyCard extends StatelessWidget {
  final _DifficultyOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = _CreateTemplateScreenState._green;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 99,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? _CreateTemplateScreenState._softGreen : null,
          border: Border.all(color: green),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 50,
              child: Center(
                child: SvgPicture.asset(
                  option.iconAsset,
                  width: option.iconWidth,
                  height: option.iconHeight,
                ),
              ),
            ),
            Text(
              option.label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _CreateTemplateScreenState._textPrimary,
                fontSize: AppTypography.bodySize,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${option.ecoPoints} EcoPoints',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _CreateTemplateScreenState._textPrimary,
                fontSize: AppTypography.captionSize,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _DropdownChip({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFBFBFBF)),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textPrimary,
                fontSize: AppTypography.captionSize,
                height: 1,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 6),
            const _ChevronDown(color: Colors.black),
          ],
        ),
      ),
    );
  }
}

class _InquiryMenuText extends StatelessWidget {
  final String text;

  const _InquiryMenuText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: AppColors.textPrimary,
        fontSize: AppTypography.helperSize,
        height: 1,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _SubjectPanel extends StatelessWidget {
  final String selectedDomain;
  final String selectedFocus;
  final List<String> domainOptions;
  final List<String> focusOptions;
  final ValueChanged<String> onDomainSelected;
  final ValueChanged<String> onFocusSelected;

  const _SubjectPanel({
    required this.selectedDomain,
    required this.selectedFocus,
    required this.domainOptions,
    required this.focusOptions,
    required this.onDomainSelected,
    required this.onFocusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CreateTemplateScreenState._softGreen,
        border: Border.all(color: _CreateTemplateScreenState._green),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Domain',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          _SubjectDropdown(
            text: selectedDomain,
            options: domainOptions,
            onSelected: onDomainSelected,
          ),
          const SizedBox(height: 12),
          const Text(
            'Subject Focus',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textPrimary,
              fontSize: AppTypography.bodySize,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          _SubjectDropdown(
            text: selectedFocus,
            options: focusOptions,
            onSelected: onFocusSelected,
          ),
        ],
      ),
    );
  }
}

class _SubjectDropdown extends StatefulWidget {
  final String text;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _SubjectDropdown({
    required this.text,
    required this.options,
    required this.onSelected,
  });

  @override
  State<_SubjectDropdown> createState() => _SubjectDropdownState();
}

class _SubjectDropdownState extends State<_SubjectDropdown> {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  color: _CreateTemplateScreenState._green,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null && selected != widget.text) {
      widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _chipKey,
      behavior: HitTestBehavior.opaque,
      onTap: _openMenu,
      child: Container(
        width: 331,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(color: _CreateTemplateScreenState._green),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.only(left: 17, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _CreateTemplateScreenState._green,
                  fontSize: AppTypography.captionSize,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const _ChevronDown(color: _CreateTemplateScreenState._green),
          ],
        ),
      ),
    );
  }
}

class _ChevronDown extends StatelessWidget {
  final Color color;

  const _ChevronDown({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(10, 6),
      painter: _ChevronDownPainter(color),
    );
  }
}

class _ChevronDownPainter extends CustomPainter {
  final Color color;

  const _ChevronDownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0.5, 0.8)
      ..lineTo(size.width / 2, size.height - 0.8)
      ..lineTo(size.width - 0.5, 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronDownPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
