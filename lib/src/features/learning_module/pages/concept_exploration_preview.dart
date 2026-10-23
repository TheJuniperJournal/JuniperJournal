import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';

class ConceptExplorationPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> module;

  const ConceptExplorationPreviewScreen({super.key, required this.module});

  @override
  State<ConceptExplorationPreviewScreen> createState() =>
      _ConceptExplorationPreviewScreenState();
}

class _ConceptExplorationPreviewScreenState
    extends State<ConceptExplorationPreviewScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF1F2024);
  static const _border = Color(0xFFD8D0D0);
  double get _screenWidth =>
      JournalPageLayout.widthFor(context, mobileWidth: 393);

  final _repo = LearningModuleRepo();
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _writeControllers = {};
  final Map<String, TextEditingController> _paragraphControllers = {};
  final Map<String, TextEditingController> _numericControllers = {};
  final Map<String, _GraphResponseState> _graphResponses = {};
  final Map<String, _TableResponseState> _tableResponses = {};
  final Map<String, XFile> _photoResponses = {};
  final Map<String, List<Offset>> _sketchResponses = {};
  final Map<String, dynamic> _assessmentAnswers = {};
  final Map<String, _AssessmentResult> _assessmentResults = {};

  List<_PreviewBlock> _blocks = [];
  int? _selectedIndex;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    for (final controller in _writeControllers.values) {
      controller.dispose();
    }
    for (final controller in _paragraphControllers.values) {
      controller.dispose();
    }
    for (final controller in _numericControllers.values) {
      controller.dispose();
    }
    for (final state in _graphResponses.values) {
      state.dispose();
    }
    for (final state in _tableResponses.values) {
      state.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBlocks() async {
    final moduleId = widget.module['id']?.toString();
    if (moduleId == null || moduleId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Module data is unavailable.';
        });
      }
      return;
    }

    final freshModule = await _repo.getModule(moduleId);
    final raw = freshModule?['concept_exploration'];
    final parsedBlocks = <_PreviewBlock>[];

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final rows = decoded is Map<String, dynamic> ? decoded['blocks'] : null;
        if (rows is List) {
          for (final row in rows) {
            if (row is Map) {
              parsedBlocks.add(
                _PreviewBlock.fromJson(Map<String, dynamic>.from(row)),
              );
            }
          }
        }
      } catch (_) {
        _error = 'Preview data could not be loaded.';
      }
    }

    parsedBlocks.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (!mounted) return;
    setState(() {
      _blocks = parsedBlocks;
      _loading = false;
    });
  }

  TextEditingController _controllerFor(
    Map<String, TextEditingController> bucket,
    String key, {
    String text = '',
  }) {
    return bucket.putIfAbsent(key, () => TextEditingController(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _screenWidth),
            child: SizedBox(
              width: _screenWidth,
              child: Column(
                children: [
                  _Header(
                    title: 'Concept Exploration',
                    onBack: selectedIndex == null
                        ? () => Navigator.of(context).pop()
                        : () => setState(() => _selectedIndex = null),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _green),
                          )
                        : selectedIndex == null
                        ? _buildSelection()
                        : _buildDetail(selectedIndex),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelection() {
    if (_error != null) {
      return _EmptyPreviewState(message: _error!);
    }
    if (_blocks.isEmpty) {
      return const _EmptyPreviewState(
        message: 'No Concept Exploration blocks have been saved yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      itemCount: _blocks.length,
      separatorBuilder: (_, _) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final block = _blocks[index];
        return _PreviewListCard(
          block: block,
          number: index + 1,
          onTap: () => setState(() => _selectedIndex = index),
        );
      },
    );
  }

  Widget _buildDetail(int index) {
    final block = _blocks[index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Block ${index + 1} of ${_blocks.length}',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _text,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 12),
        _ProgressDots(current: index, total: _blocks.length),
        SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            children: [
              _PreviewDetailCard(
                block: block,
                inquiry: _buildInquiry(block),
                assessment: _buildAssessment(block),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 0, 64, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(
                label: 'Back',
                leading: true,
                onTap: () {
                  if (index == 0) {
                    setState(() => _selectedIndex = null);
                  } else {
                    setState(() => _selectedIndex = index - 1);
                  }
                },
              ),
              _NavButton(
                label: index == _blocks.length - 1 ? 'Done' : 'Next',
                leading: false,
                onTap: () {
                  if (index == _blocks.length - 1) {
                    setState(() => _selectedIndex = null);
                  } else {
                    setState(() => _selectedIndex = index + 1);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildInquiry(_PreviewBlock block) {
    final inquiry = block.inquiry;
    if (inquiry == null || inquiry.studentResponse.isEmpty) return null;
    final response = inquiry.studentResponse.toLowerCase();
    final content = switch (response) {
      'write' => _WriteResponse(
        controller: _controllerFor(_writeControllers, 'write-${block.id}'),
      ),
      'draw/sketch' || 'draw' || 'sketch' => _SketchResponse(
        strokes: _sketchResponses[block.id] ?? const [],
        onChanged: (points) =>
            setState(() => _sketchResponses[block.id] = points),
      ),
      'photograph' || 'photo' => _PhotoResponse(
        image: _photoResponses[block.id],
        onPick: () => _pickPreviewImage(block.id),
        onRemove: () => setState(() => _photoResponses.remove(block.id)),
      ),
      'graph' => _GraphResponse(
        state: _graphResponses.putIfAbsent(block.id, _GraphResponseState.new),
        onChanged: () => setState(() {}),
      ),
      'table' => _TableResponse(
        state: _tableResponses.putIfAbsent(block.id, _TableResponseState.new),
        onChanged: () => setState(() {}),
      ),
      _ => _WriteResponse(
        controller: _controllerFor(_writeControllers, 'write-${block.id}'),
      ),
    };

    return _InquiryPreviewSection(inquiry: inquiry, response: content);
  }

  Future<void> _pickPreviewImage(String blockId) async {
    final source = await showAppModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _green),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _green),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() => _photoResponses[blockId] = image);
  }

  Widget? _buildAssessment(_PreviewBlock block) {
    if (!assessmentFeaturesEnabled) return null;
    final assessment = block.assessment;
    if (assessment.isEmpty || assessment.type == null) return null;
    return _AssessmentPreviewSection(
      blockId: block.id,
      assessment: assessment,
      answer: _assessmentAnswers[block.id],
      result: _assessmentResults[block.id],
      numericController: _controllerFor(
        _numericControllers,
        'numeric-${block.id}',
      ),
      paragraphController: _controllerFor(
        _paragraphControllers,
        'paragraph-${block.id}',
      ),
      onAnswerChanged: (value) {
        setState(() {
          _assessmentAnswers[block.id] = value;
          _assessmentResults.remove(block.id);
        });
      },
      onSubmit: () {
        setState(() {
          _assessmentResults[block.id] = _checkAssessment(
            assessment,
            _assessmentAnswers[block.id],
            numericText: _numericControllers['numeric-${block.id}']?.text ?? '',
            paragraphText:
                _paragraphControllers['paragraph-${block.id}']?.text ?? '',
          );
        });
      },
    );
  }

  _AssessmentResult _checkAssessment(
    AssessmentBlockData assessment,
    Object? answer, {
    required String numericText,
    required String paragraphText,
  }) {
    final data = assessment.data;
    switch (assessment.type) {
      case AssessmentType.multipleChoice:
        return _AssessmentResult(
          answer is int && answer == _intValue(data['correct_index']),
        );
      case AssessmentType.trueFalse:
        final questions = _maps(data['questions']);
        final responses = answer is Map<int, bool> ? answer : <int, bool>{};
        final complete =
            questions.isNotEmpty && responses.length == questions.length;
        final correct =
            complete &&
            questions.asMap().entries.every(
              (entry) => responses[entry.key] == entry.value['correct_answer'],
            );
        return _AssessmentResult(correct);
      case AssessmentType.matching:
        final top = _strings(data['top_items']);
        final responses = answer is Map<int, int> ? answer : <int, int>{};
        final complete = top.isNotEmpty && responses.length == top.length;
        final correct =
            complete &&
            responses.entries.every((entry) => entry.key == entry.value);
        return _AssessmentResult(correct);
      case AssessmentType.numeric:
        final value = num.tryParse(numericText.trim());
        final exact = num.tryParse(data['correct_answer']?.toString() ?? '');
        final min = num.tryParse(data['min_value']?.toString() ?? '');
        final max = num.tryParse(data['max_value']?.toString() ?? '');
        if (value == null) return const _AssessmentResult(false);
        if (min != null && max != null) {
          return _AssessmentResult(value >= min && value <= max);
        }
        return _AssessmentResult(exact != null && value == exact);
      case AssessmentType.paragraph:
        return _AssessmentResult(
          paragraphText.trim().isNotEmpty,
          message: 'Response submitted.',
        );
      case null:
        return const _AssessmentResult(false);
    }
  }
}

class _PreviewBlock {
  final String id;
  final int orderIndex;
  final String type;
  final Map<String, dynamic> data;

  const _PreviewBlock({
    required this.id,
    required this.orderIndex,
    required this.type,
    required this.data,
  });

  factory _PreviewBlock.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return _PreviewBlock(
      id: json['id']?.toString().trim().isNotEmpty == true
          ? json['id'].toString()
          : '${json['type'] ?? 'block'}-${json['order_index'] ?? 0}',
      orderIndex: _intValue(json['order_index']) ?? 0,
      type: json['type']?.toString() ?? 'Block',
      data: rawData is Map ? Map<String, dynamic>.from(rawData) : {},
    );
  }

  String get displayType => type == 'Images' ? 'Image' : type;

  String get iconAsset {
    return switch (type) {
      'Text' => 'assets/learning_module/concept_text.svg',
      'Images' => 'assets/learning_module/concept_image.svg',
      'Sketch' => 'assets/learning_module/concept_sketch.svg',
      'Video' => 'assets/learning_module/concept_video.svg',
      'Table' => 'assets/learning_module/concept_table.svg',
      'Graph' => 'assets/learning_module/concept_graph.svg',
      'Link' => 'assets/learning_module/concept_link.svg',
      _ => 'assets/learning_module/concept_text.svg',
    };
  }

  Color get tileColor {
    return switch (type) {
      'Text' => const Color(0xFFE1EFFD),
      'Images' => const Color(0xFFD8F0DF),
      'Sketch' => const Color(0xFFE2F4F5),
      'Video' => const Color(0xFFFFE2E2),
      'Link' => const Color(0xFFFFEFE7),
      _ => const Color(0xFFE8E8E8),
    };
  }

  String get title {
    final value = data['title']?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return switch (type) {
      'Text' => _previewText(data['content']),
      'Images' => _previewText(data['caption']),
      'Video' => _previewText(data['external_url'] ?? data['file_name']),
      'Table' => 'Table',
      'Graph' => 'Graph',
      'Link' => _previewText(data['url']),
      _ => displayType,
    };
  }

  String get subtitle {
    final value = switch (type) {
      'Text' => data['content'],
      'Images' => data['caption'],
      'Video' =>
        data['description'] ?? data['external_url'] ?? data['file_name'],
      'Table' => _strings(data['columns']).join(', '),
      'Graph' => data['caption'] ?? data['graph_type'],
      'Link' => data['description'] ?? data['url'],
      _ => data['caption'],
    };
    return _previewText(value);
  }

  String get firstImageUrl {
    final media = data['media_items'];
    if (media is List) {
      for (final item in media) {
        if (item is Map &&
            (item['public_url']?.toString().isNotEmpty ?? false)) {
          return item['public_url'].toString();
        }
      }
    }
    final images = data['images'];
    if (images is List) {
      for (final item in images) {
        if (item is Map &&
            (item['public_url']?.toString().isNotEmpty ?? false)) {
          return item['public_url'].toString();
        }
      }
    }
    final sketchImages = data['image_placeholders'];
    if (sketchImages is List) {
      for (final item in sketchImages) {
        if (item is Map &&
            (item['public_url']?.toString().isNotEmpty ?? false)) {
          return item['public_url'].toString();
        }
      }
    }
    return '';
  }

  _InquiryPreviewData? get inquiry {
    final preview = data['inquiry'];
    if (preview is Map) {
      final parsed = _InquiryPreviewData.fromJson(
        Map<String, dynamic>.from(preview),
      );
      if (parsed != null) return parsed;
    }
    final lensData = InquiryLensData.fromJson(
      data['inquiry_lens_data'],
      legacyLens: data['inquiry_lens']?.toString() ?? 'None',
    );
    final parsed = _InquiryPreviewData.fromJson(lensData.toPreviewJson());
    return parsed;
  }

  AssessmentBlockData get assessment {
    return AssessmentBlockData.fromJson(data['assessment']);
  }
}

class _InquiryPreviewData {
  final String lens;
  final List<String> thinkingFocus;
  final List<String> customFocus;
  final String studentResponse;
  final String studentInstruction;

  const _InquiryPreviewData({
    required this.lens,
    required this.thinkingFocus,
    required this.customFocus,
    required this.studentResponse,
    required this.studentInstruction,
  });

  static _InquiryPreviewData? fromJson(Map<String, dynamic> json) {
    final lens = json['lens']?.toString().trim() ?? '';
    if (lens.isEmpty || lens == InquiryLensData.noneValue) return null;
    return _InquiryPreviewData(
      lens: lens,
      thinkingFocus: _strings(json['thinking_focus']),
      customFocus: _strings(json['custom_focus']),
      studentResponse: json['student_response']?.toString() ?? '',
      studentInstruction: json['student_instruction']?.toString() ?? '',
    );
  }

  String get iconAsset {
    final value = lens.toLowerCase();
    if (value.contains('wonder')) {
      return 'assets/learning_module/inquiry_wonder.svg';
    }
    if (value.contains('investigate')) {
      return 'assets/learning_module/inquiry_investigate.svg';
    }
    if (value.contains('explain')) {
      return 'assets/learning_module/inquiry_explain.svg';
    }
    if (value.contains('design')) {
      return 'assets/learning_module/inquiry_design.svg';
    }
    if (value.contains('systems')) {
      return 'assets/learning_module/inquiry_systems.svg';
    }
    return 'assets/learning_module/inquiry_observe.svg';
  }
}

class _GraphResponseState {
  GraphType type = GraphType.line;
  final xAxis = TextEditingController();
  final yAxis = TextEditingController();
  final rows = <List<TextEditingController>>[
    [TextEditingController(), TextEditingController()],
  ];

  List<GraphDataRow> get graphRows {
    return [
      for (final row in rows)
        GraphDataRow(x: row[0].text.trim(), y: row[1].text.trim()),
    ];
  }

  void dispose() {
    xAxis.dispose();
    yAxis.dispose();
    for (final row in rows) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }
}

class _TableResponseState {
  final columns = <TextEditingController>[
    TextEditingController(text: 'X'),
    TextEditingController(text: 'Y'),
  ];
  final rows = <List<TextEditingController>>[
    [TextEditingController(), TextEditingController()],
  ];

  void dispose() {
    for (final controller in columns) {
      controller.dispose();
    }
    for (final row in rows) {
      for (final controller in row) {
        controller.dispose();
      }
    }
  }
}

class _AssessmentResult {
  final bool correct;
  final String? message;

  const _AssessmentResult(this.correct, {this.message});

  String get label => message ?? (correct ? 'Correct!' : 'Try again.');
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _ConceptExplorationPreviewScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 22,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const Icon(
                Icons.chevron_left,
                color: _ConceptExplorationPreviewScreenState._green,
                size: 28,
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

class _PreviewListCard extends StatelessWidget {
  final _PreviewBlock block;
  final int number;
  final VoidCallback onTap;

  const _PreviewListCard({
    required this.block,
    required this.number,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = block.firstImageUrl;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 105,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _MediaPlaceholder(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BlockTypeBadge(block: block),
                        const SizedBox(height: 7),
                        Text(
                          block.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (block.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            block.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: AppTypography.helperSize,
                              color: Color(0x99000000),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _NumberCircle(number: number),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewDetailCard extends StatelessWidget {
  final _PreviewBlock block;
  final Widget? inquiry;
  final Widget? assessment;

  const _PreviewDetailCard({
    required this.block,
    required this.inquiry,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BlockTypeBadge(block: block),
            const SizedBox(height: AppMetrics.labelGap),
            _BlockContent(block: block),
          ],
        ),
      ),
    );
  }
}

class _BlockContent extends StatelessWidget {
  final _PreviewBlock block;

  const _BlockContent({required this.block});

  @override
  Widget build(BuildContext context) {
    return switch (block.type) {
      'Text' => _TextContent(block: block),
      'Images' => _ImageContent(block: block),
      'Sketch' => _SketchContent(block: block),
      'Video' => _VideoContent(block: block),
      'Table' => _TableContent(block: block),
      'Graph' => _GraphContent(block: block),
      'Link' => _LinkContent(block: block),
      _ => const _MalformedContent(),
    };
  }
}

class _TextContent extends StatelessWidget {
  final _PreviewBlock block;

  const _TextContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final media = _maps(block.data['media_items']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        if ((block.data['content']?.toString().trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            block.data['content'].toString(),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              height: 1.25,
            ),
          ),
        ],
        for (final item in media) ...[
          const SizedBox(height: AppMetrics.labelGap),
          if ((item['public_url']?.toString().isNotEmpty ?? false))
            _RoundedNetworkImage(url: item['public_url'].toString()),
          if ((item['label']?.toString().trim() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item['label'].toString(),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
        if ((block.data['caption']?.toString().trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: AppMetrics.labelGap),
          Text(
            block.data['caption'].toString(),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageContent extends StatelessWidget {
  final _PreviewBlock block;

  const _ImageContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final images = _maps(block.data['images']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        if (images.isEmpty) const _MediaPlaceholder(),
        for (var index = 0; index < images.length; index++) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _ConceptExplorationPreviewScreenState._green,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  images[index]['description']?.toString() ?? '',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          (images[index]['public_url']?.toString().isNotEmpty ?? false)
              ? _RoundedNetworkImage(
                  url: images[index]['public_url'].toString(),
                )
              : const _MediaPlaceholder(),
        ],
        if ((block.data['caption']?.toString().trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: AppMetrics.labelGap),
          Text(
            block.data['caption'].toString(),
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
        ],
      ],
    );
  }
}

class _SketchContent extends StatelessWidget {
  final _PreviewBlock block;

  const _SketchContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final data = SketchBlockData.fromJson(block.data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        const SizedBox(height: 12),
        _ReadOnlySketchCanvas(data: data),
        if (data.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            data.caption,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoContent extends StatelessWidget {
  final _PreviewBlock block;

  const _VideoContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block.data['external_url']?.toString() ?? '';
    final fileName = block.data['file_name']?.toString() ?? '';
    final description = block.data['description']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        const SizedBox(height: 12),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F4F4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _ConceptExplorationPreviewScreenState._border,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.play_circle_fill,
              color: _ConceptExplorationPreviewScreenState._green,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          url.isNotEmpty
              ? url
              : fileName.isNotEmpty
              ? fileName
              : 'Video unavailable.',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
        ],
      ],
    );
  }
}

class _TableContent extends StatelessWidget {
  final _PreviewBlock block;

  const _TableContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final columns = _maps(block.data['columns']);
    final rows = _maps(block.data['rows']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        const SizedBox(height: 12),
        _ReadOnlyTable(columns: columns, rows: rows),
      ],
    );
  }
}

class _GraphContent extends StatelessWidget {
  final _PreviewBlock block;

  const _GraphContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final data = GraphBlockData.fromJson(block.data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(data.title.trim().isEmpty ? block.title : data.title),
        if (data.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            data.caption,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
            ),
          ),
        ],
        const SizedBox(height: AppMetrics.labelGap),
        _ChartBox(
          rows: data.rows,
          graphType: data.graphType,
          title: data.title,
          xAxisLabel: data.xAxisLabel,
          yAxisLabel: data.yAxisLabel,
        ),
      ],
    );
  }
}

class _LinkContent extends StatelessWidget {
  final _PreviewBlock block;

  const _LinkContent({required this.block});

  @override
  Widget build(BuildContext context) {
    final url = block.data['url']?.toString() ?? '';
    final description = block.data['description']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(block.title),
        const SizedBox(height: 8),
        Text(
          description.isEmpty
              ? 'Open the link to view the following material.'
              : description,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        const SizedBox(height: AppMetrics.sectionGap),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(
              color: _ConceptExplorationPreviewScreenState._border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.link,
                  color: Color(0xFFFF7B54),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title,
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      url.isEmpty ? 'Link unavailable.' : url,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF777777),
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Color(0xFF606060)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InquiryPreviewSection extends StatelessWidget {
  final _InquiryPreviewData inquiry;
  final Widget response;

  const _InquiryPreviewSection({required this.inquiry, required this.response});

  @override
  Widget build(BuildContext context) {
    final focus = [
      ...inquiry.thinkingFocus,
      ...inquiry.customFocus,
    ].where((item) => item.trim().isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFD8F0DF),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(4),
              child: SvgPicture.asset(inquiry.iconAsset),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inquiry.lens,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (focus.isNotEmpty)
                  Text(
                    focus,
                    style: const TextStyle(
                      fontSize: AppTypography.captionSize,
                      color: Color(0xFF333333),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (inquiry.studentInstruction.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            inquiry.studentInstruction,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              height: 1.25,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          _responseTitle(inquiry.studentResponse),
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Respond below.',
          style: TextStyle(
            fontSize: AppTypography.captionSize,
            color: Color(0xFF777777),
          ),
        ),
        const SizedBox(height: 8),
        response,
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Save',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _ConceptExplorationPreviewScreenState._green,
              fontSize: AppTypography.buttonSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static String _responseTitle(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('photo')) return 'Photo';
    if (normalized.contains('draw') || normalized.contains('sketch')) {
      return 'Canvas';
    }
    return value.isEmpty ? 'Text' : value;
  }
}

class _WriteResponse extends StatelessWidget {
  final TextEditingController controller;

  const _WriteResponse({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 5,
      maxLines: 7,
      decoration: _inputDecoration(),
    );
  }
}

class _PhotoResponse extends StatelessWidget {
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoResponse({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 135,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD8D0D0),
                style: BorderStyle.solid,
              ),
            ),
            child: image == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        color: _ConceptExplorationPreviewScreenState._green,
                        size: 58,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Click to upload.',
                        style: TextStyle(color: Color(0xFFCECECE)),
                      ),
                    ],
                  )
                : _PickedImagePreview(image: image!),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SmallOutlineButton(
              label: 'Remove',
              color: Colors.red,
              onTap: image == null ? null : onRemove,
            ),
            _SmallOutlineButton(
              label: 'Replace',
              color: _ConceptExplorationPreviewScreenState._green,
              onTap: onPick,
            ),
          ],
        ),
      ],
    );
  }
}

class _PickedImagePreview extends StatelessWidget {
  final XFile image;

  const _PickedImagePreview({required this.image});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: _ConceptExplorationPreviewScreenState._green,
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            snapshot.data!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}

class _SketchResponse extends StatelessWidget {
  final List<Offset> strokes;
  final ValueChanged<List<Offset>> onChanged;

  const _SketchResponse({required this.strokes, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onChanged([...strokes, box.globalToLocal(details.globalPosition)]);
      },
      onPanUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onChanged([...strokes, box.globalToLocal(details.globalPosition)]);
      },
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          border: Border.all(
            color: _ConceptExplorationPreviewScreenState._green,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _LearnerSketchPainter(strokes),
                child: const SizedBox.expand(),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(
              height: 42,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Icon(
                    Icons.edit,
                    color: _ConceptExplorationPreviewScreenState._green,
                  ),
                  Icon(Icons.palette_outlined),
                  Icon(Icons.text_fields),
                  Icon(Icons.crop_square),
                  Icon(Icons.arrow_forward),
                  Icon(Icons.image_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraphResponse extends StatelessWidget {
  final _GraphResponseState state;
  final VoidCallback onChanged;

  const _GraphResponse({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<GraphType>(
          initialValue: state.type,
          decoration: _inputDecoration(label: 'Graph Type'),
          items: [
            for (final type in GraphType.values)
              DropdownMenuItem(value: type, child: Text(type.label)),
          ],
          onChanged: (value) {
            if (value == null) return;
            state.type = value;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _EditableGraphRows(state: state, onChanged: onChanged),
        const SizedBox(height: 12),
        TextField(
          controller: state.xAxis,
          decoration: _inputDecoration(label: 'X-Axis Label'),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: state.yAxis,
          decoration: _inputDecoration(label: 'Y-Axis Label'),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        _ChartBox(
          rows: state.graphRows,
          graphType: state.type,
          title: 'Blank',
          xAxisLabel: state.xAxis.text,
          yAxisLabel: state.yAxis.text,
        ),
      ],
    );
  }
}

class _EditableGraphRows extends StatelessWidget {
  final _GraphResponseState state;
  final VoidCallback onChanged;

  const _EditableGraphRows({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Table(
          border: TableBorder.all(color: const Color(0xFFD8D0D0)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
              children: [
                _TableHeaderCell(
                  state.type == GraphType.pie ? 'Item/Label' : 'X-Value',
                ),
                _TableHeaderCell(
                  state.type == GraphType.pie ? 'Percent of Pie' : 'Y-Value',
                ),
              ],
            ),
            for (final row in state.rows)
              TableRow(
                children: [
                  _TableInputCell(controller: row[0], onChanged: onChanged),
                  _TableInputCell(controller: row[1], onChanged: onChanged),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        _SmallOutlineButton(
          label: '+ Add Row',
          color: _ConceptExplorationPreviewScreenState._green,
          onTap: () {
            state.rows.add([TextEditingController(), TextEditingController()]);
            onChanged();
          },
        ),
      ],
    );
  }
}

class _TableResponse extends StatelessWidget {
  final _TableResponseState state;
  final VoidCallback onChanged;

  const _TableResponse({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Table(
          border: TableBorder.all(color: const Color(0xFFD8D0D0)),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
              children: [
                for (final column in state.columns)
                  _TableInputCell(controller: column, onChanged: onChanged),
              ],
            ),
            for (final row in state.rows)
              TableRow(
                children: [
                  for (var index = 0; index < state.columns.length; index++)
                    _TableInputCell(
                      controller: row[index],
                      onChanged: onChanged,
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _SmallOutlineButton(
              label: '+ Add Column',
              color: _ConceptExplorationPreviewScreenState._green,
              onTap: () {
                state.columns.add(TextEditingController());
                for (final row in state.rows) {
                  row.add(TextEditingController());
                }
                onChanged();
              },
            ),
            _SmallOutlineButton(
              label: '+ Add Row',
              color: _ConceptExplorationPreviewScreenState._green,
              onTap: () {
                state.rows.add([
                  for (var i = 0; i < state.columns.length; i++)
                    TextEditingController(),
                ]);
                onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _AssessmentPreviewSection extends StatelessWidget {
  final String blockId;
  final AssessmentBlockData assessment;
  final Object? answer;
  final _AssessmentResult? result;
  final TextEditingController numericController;
  final TextEditingController paragraphController;
  final ValueChanged<Object?> onAnswerChanged;
  final VoidCallback onSubmit;

  const _AssessmentPreviewSection({
    required this.blockId,
    required this.assessment,
    required this.answer,
    required this.result,
    required this.numericController,
    required this.paragraphController,
    required this.onAnswerChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final type = assessment.type;
    if (type == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssessmentHeader(type: type),
        const SizedBox(height: AppMetrics.labelGap),
        switch (type) {
          AssessmentType.multipleChoice => _MultipleChoicePreview(
            data: assessment.data,
            selected: answer is int ? answer as int : null,
            onChanged: onAnswerChanged,
          ),
          AssessmentType.trueFalse => _TrueFalsePreview(
            data: assessment.data,
            answers: answer is Map<int, bool> ? answer as Map<int, bool> : {},
            onChanged: onAnswerChanged,
          ),
          AssessmentType.matching => _MatchingPreview(
            data: assessment.data,
            answers: answer is Map<int, int> ? answer as Map<int, int> : {},
            result: result,
            onChanged: onAnswerChanged,
          ),
          AssessmentType.numeric => _NumericPreview(
            data: assessment.data,
            controller: numericController,
            onChanged: (_) => onAnswerChanged(numericController.text),
          ),
          AssessmentType.paragraph => _ParagraphPreview(
            data: assessment.data,
            controller: paragraphController,
            onChanged: (_) => onAnswerChanged(paragraphController.text),
          ),
        },
        if (result != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: result!.correct
                    ? const Color(0xFFE6F4EA)
                    : const Color(0xFFFFE2E2),
                border: Border.all(
                  color: result!.correct
                      ? _ConceptExplorationPreviewScreenState._green
                      : Colors.red,
                ),
              ),
              child: Text(
                result!.label,
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: result!.correct
                      ? _ConceptExplorationPreviewScreenState._green
                      : Colors.red,
                  fontWeight: FontWeight.w400,
                  fontSize: AppTypography.helperSize,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppMetrics.labelGap),
        Center(
          child: SizedBox(
            width: 180,
            height: 30,
            child: ElevatedButton(
              onPressed: _canSubmit(type) ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _ConceptExplorationPreviewScreenState._green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB8B8B8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                type == AssessmentType.trueFalse ? 'Check' : 'Submit',
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _canSubmit(AssessmentType type) {
    switch (type) {
      case AssessmentType.multipleChoice:
        return answer is int;
      case AssessmentType.trueFalse:
        final questions = _maps(assessment.data['questions']);
        return answer is Map<int, bool> &&
            (answer as Map<int, bool>).length == questions.length;
      case AssessmentType.matching:
        final top = _strings(assessment.data['top_items']);
        return answer is Map<int, int> &&
            (answer as Map<int, int>).length == top.length;
      case AssessmentType.numeric:
        return numericController.text.trim().isNotEmpty;
      case AssessmentType.paragraph:
        return paragraphController.text.trim().isNotEmpty;
    }
  }
}

class _MultipleChoicePreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final int? selected;
  final ValueChanged<Object?> onChanged;

  const _MultipleChoicePreview({
    required this.data,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = _strings(data['options']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['question']?.toString() ?? '',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < options.length; index++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ConceptExplorationPreviewScreenState._green,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: selected == index
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _ConceptExplorationPreviewScreenState._green,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  _LetterBadge(index),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      options[index],
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TrueFalsePreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<int, bool> answers;
  final ValueChanged<Object?> onChanged;

  const _TrueFalsePreview({
    required this.data,
    required this.answers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final questions = _maps(data['questions']);
    return Column(
      children: [
        for (var index = 0; index < questions.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(
                color: _ConceptExplorationPreviewScreenState._border,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    questions[index]['text']?.toString() ?? '',
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                ),
                _SegmentButton(
                  label: 'T',
                  selected: answers[index] == true,
                  onTap: () => onChanged({...answers, index: true}),
                ),
                _SegmentButton(
                  label: 'F',
                  selected: answers[index] == false,
                  onTap: () => onChanged({...answers, index: false}),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MatchingPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<int, int> answers;
  final _AssessmentResult? result;
  final ValueChanged<Object?> onChanged;

  const _MatchingPreview({
    required this.data,
    required this.answers,
    required this.result,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final top = _strings(data['top_items']);
    final bottom = _strings(data['bottom_items']);
    final count = math.min(top.length, bottom.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Match the following terms.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        const SizedBox(height: AppMetrics.labelGap),
        for (var index = 0; index < count; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Draggable<int>(
                  data: index,
                  feedback: Material(
                    color: Colors.transparent,
                    child: _MatchBox(
                      text: top[index],
                      state: _matchState(index),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.4,
                    child: _MatchBox(
                      text: top[index],
                      state: _matchState(index),
                    ),
                  ),
                  child: _MatchBox(text: top[index], state: _matchState(index)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DragTarget<int>(
                    onAcceptWithDetails: (details) {
                      onChanged({...answers, details.data: index});
                    },
                    builder: (context, candidate, rejected) {
                      final matched = answers.entries
                          .where((entry) => entry.value == index)
                          .map((entry) => entry.key)
                          .firstOrNull;
                      return _MatchBox(
                        text: matched == null
                            ? bottom[index]
                            : '${top[matched]} -> ${bottom[index]}',
                        state: _matchState(matched ?? index),
                        compact: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  _MatchState _matchState(int index) {
    if (result == null) return _MatchState.neutral;
    final matched = answers[index];
    if (matched == null) return _MatchState.neutral;
    return matched == index ? _MatchState.correct : _MatchState.wrong;
  }
}

class _NumericPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NumericPreview({
    required this.data,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['question']?.toString() ?? '',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration(label: 'Answer'),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ParagraphPreview extends StatelessWidget {
  final Map<String, dynamic> data;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ParagraphPreview({
    required this.data,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final max = _intValue(data['max_characters']) ?? 300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['question']?.toString() ?? '',
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          controller: controller,
          maxLength: max,
          minLines: 5,
          maxLines: 7,
          decoration: _inputDecoration(label: 'Response'),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AssessmentHeader extends StatelessWidget {
  final AssessmentType type;

  const _AssessmentHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFEECFFF),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(5),
          child: SvgPicture.asset(type.iconAsset),
        ),
        const SizedBox(width: 8),
        Text(
          type.selectorTitle,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlySketchCanvas extends StatelessWidget {
  final SketchBlockData data;

  const _ReadOnlySketchCanvas({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _ConceptExplorationPreviewScreenState._border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CustomPaint(
            painter: _ReadOnlySketchPainter(data),
            child: const SizedBox.expand(),
          ),
          for (final image in data.imagePlaceholders)
            if (image.publicUrl.isNotEmpty)
              Positioned.fromRect(
                rect: _scaleRect(image.rect, 305, 190),
                child: Image.network(
                  image.publicUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
        ],
      ),
    );
  }
}

class _ReadOnlyTable extends StatelessWidget {
  final List<Map<String, dynamic>> columns;
  final List<Map<String, dynamic>> rows;

  const _ReadOnlyTable({required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    final normalizedColumns = columns.isEmpty
        ? [
            {'id': 'column_1', 'name': 'Column 1'},
            {'id': 'column_2', 'name': 'Column 2'},
          ]
        : columns;
    final labels = [
      for (final column in normalizedColumns)
        column['name']?.toString().trim().isEmpty == false
            ? column['name'].toString()
            : 'Column',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(105),
        border: TableBorder.all(color: const Color(0xFFD8D0D0)),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFD9D9D9)),
            children: [for (final label in labels) _TableHeaderCell(label)],
          ),
          for (final row in rows)
            TableRow(
              children: [
                for (final column in normalizedColumns)
                  _TableBodyCell(
                    row[column['id']?.toString()]?.toString() ?? '',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartBox extends StatelessWidget {
  final List<GraphDataRow> rows;
  final GraphType graphType;
  final String title;
  final String xAxisLabel;
  final String yAxisLabel;

  const _ChartBox({
    required this.rows,
    required this.graphType,
    required this.title,
    required this.xAxisLabel,
    required this.yAxisLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8D0D0)),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PreviewGraphPainter(
          rows: rows,
          type: graphType,
          title: title.trim().isEmpty ? 'Blank' : title,
          xLabel: xAxisLabel.trim().isEmpty ? 'Blank' : xAxisLabel,
          yLabel: yAxisLabel.trim().isEmpty ? 'Blank' : yAxisLabel,
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;

  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.isEmpty ? 'Untitled Block' : text,
      style: const TextStyle(
        fontFamily: AppTypography.headingFamily,
        color: AppColors.textPrimary,
        fontSize: AppTypography.sectionTitleSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _BlockTypeBadge extends StatelessWidget {
  final _PreviewBlock block;

  const _BlockTypeBadge({required this.block});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 27,
          decoration: BoxDecoration(
            color: block.tileColor,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(5),
          child: SvgPicture.asset(block.iconAsset),
        ),
        const SizedBox(width: 7),
        Text(
          block.displayType,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textPrimary,
            fontSize: AppTypography.helperSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final count = math.max(total, 1);
    return SizedBox(
      width: 242,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 1,
            color: _ConceptExplorationPreviewScreenState._green,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < count; index++)
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: index <= current
                        ? _ConceptExplorationPreviewScreenState._green
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _ConceptExplorationPreviewScreenState._green,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final bool leading;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 31,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _ConceptExplorationPreviewScreenState._green,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading) const Icon(Icons.chevron_left, size: 18),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.buttonSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!leading) const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NumberCircle extends StatelessWidget {
  final int number;

  const _NumberCircle({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _ConceptExplorationPreviewScreenState._green),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _ConceptExplorationPreviewScreenState._green,
          fontSize: AppTypography.captionSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _RoundedNetworkImage extends StatelessWidget {
  final String url;

  const _RoundedNetworkImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _MediaPlaceholder(),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Media unavailable',
        style: TextStyle(
          color: Color(0xFF777777),
          fontSize: AppTypography.helperSize,
        ),
      ),
    );
  }
}

class _MalformedContent extends StatelessWidget {
  const _MalformedContent();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'This block could not be previewed, but the rest of the module is still available.',
      style: TextStyle(
        fontSize: AppTypography.bodySize,
        color: Color(0xFF666666),
      ),
    );
  }
}

class _EmptyPreviewState extends StatelessWidget {
  final String message;

  const _EmptyPreviewState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: AppTypography.bodySize,
            color: Color(0xFF666666),
          ),
        ),
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SmallOutlineButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: onTap == null ? const Color(0xFFCCCCCC) : color,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

class _TableHeaderCell extends StatelessWidget {
  final String text;

  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _TableBodyCell extends StatelessWidget {
  final String text;

  const _TableBodyCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
        ),
      ),
    );
  }
}

class _TableInputCell extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _TableInputCell({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final int index;

  const _LetterBadge(this.index);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: _ConceptExplorationPreviewScreenState._green,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text(
        String.fromCharCode(65 + index),
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: Colors.white,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD8F0DF) : Colors.white,
          border: Border.all(color: const Color(0xFFCCCCCC)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

enum _MatchState { neutral, correct, wrong }

class _MatchBox extends StatelessWidget {
  final String text;
  final _MatchState state;
  final bool compact;

  const _MatchBox({
    required this.text,
    required this.state,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _MatchState.correct => _ConceptExplorationPreviewScreenState._green,
      _MatchState.wrong => Colors.red,
      _MatchState.neutral => _ConceptExplorationPreviewScreenState._green,
    };
    return Container(
      width: compact ? double.infinity : 96,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: state == _MatchState.wrong
            ? const Color(0xFFFFD7D7)
            : state == _MatchState.correct
            ? const Color(0xFFE2F1E6)
            : Colors.white,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _ReadOnlySketchPainter extends CustomPainter {
  final SketchBlockData data;

  const _ReadOnlySketchPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 305;
    final scaleY = size.height / 190;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    for (final stroke in data.strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (var i = 1; i < stroke.points.length; i++) {
        canvas.drawLine(stroke.points[i - 1], stroke.points[i], paint);
      }
    }
    for (final shape in data.shapes) {
      final paint = Paint()
        ..color = shape.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      switch (shape.type) {
        case 'circle':
          canvas.drawOval(shape.rect, paint);
          break;
        case 'triangle':
          final path = Path()
            ..moveTo(shape.rect.center.dx, shape.rect.top)
            ..lineTo(shape.rect.right, shape.rect.bottom)
            ..lineTo(shape.rect.left, shape.rect.bottom)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case 'line':
          canvas.drawLine(shape.rect.topLeft, shape.rect.bottomRight, paint);
          break;
        default:
          canvas.drawRect(shape.rect, paint);
      }
    }
    for (final arrow in data.arrows) {
      final paint = Paint()
        ..color = arrow.color
        ..strokeWidth = 3;
      canvas.drawLine(arrow.start, arrow.end, paint);
      final angle = math.atan2(
        arrow.end.dy - arrow.start.dy,
        arrow.end.dx - arrow.start.dx,
      );
      const head = 10.0;
      canvas.drawLine(
        arrow.end,
        Offset(
          arrow.end.dx - head * math.cos(angle - math.pi / 6),
          arrow.end.dy - head * math.sin(angle - math.pi / 6),
        ),
        paint,
      );
      canvas.drawLine(
        arrow.end,
        Offset(
          arrow.end.dx - head * math.cos(angle + math.pi / 6),
          arrow.end.dy - head * math.sin(angle + math.pi / 6),
        ),
        paint,
      );
    }
    for (final item in data.textItems) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.color,
            fontSize: item.fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 180);
      painter.paint(canvas, item.position);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReadOnlySketchPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _LearnerSketchPainter extends CustomPainter {
  final List<Offset> points;

  const _LearnerSketchPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var index = 1; index < points.length; index++) {
      canvas.drawLine(points[index - 1], points[index], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LearnerSketchPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PreviewGraphPainter extends CustomPainter {
  final List<GraphDataRow> rows;
  final GraphType type;
  final String title;
  final String xLabel;
  final String yLabel;

  const _PreviewGraphPainter({
    required this.rows,
    required this.type,
    required this.title,
    required this.xLabel,
    required this.yLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawText(canvas, title, const Offset(24, 18), 16, FontWeight.w700);
    if (type == GraphType.pie) {
      _drawPie(canvas, size);
      return;
    }
    final points = [
      for (final row in rows)
        if (double.tryParse(row.x) != null && double.tryParse(row.y) != null)
          Offset(double.parse(row.x), double.parse(row.y)),
    ];
    final left = 62.0;
    final top = 58.0;
    final width = size.width - 94;
    final height = size.height - 104;
    final axis = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = const Color(0xFFE2E2E2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 5; i++) {
      final y = top + height * i / 5;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
    }
    canvas.drawLine(Offset(left, top), Offset(left, top + height), axis);
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + width, top + height),
      axis,
    );
    _drawText(
      canvas,
      xLabel,
      Offset(size.width / 2 - 24, size.height - 26),
      11,
      FontWeight.w700,
    );
    canvas.save();
    canvas.translate(18, size.height - 74);
    canvas.rotate(-math.pi / 2);
    _drawText(canvas, yLabel, Offset.zero, 11, FontWeight.w700);
    canvas.restore();
    if (points.isEmpty) return;
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final maxY = points.map((point) => point.dy).reduce(math.max);
    Offset mapPoint(Offset point) {
      final xRange = maxX == minX ? 1 : maxX - minX;
      final yRange = maxY <= 0 ? 1 : maxY;
      return Offset(
        left + ((point.dx - minX) / xRange) * width,
        top + height - (point.dy / yRange) * height,
      );
    }

    final mapped = points.map(mapPoint).toList();
    final green = _ConceptExplorationPreviewScreenState._green;
    if (type == GraphType.bar) {
      final barWidth = math.min(24.0, width / (points.length * 2));
      for (final point in points) {
        final mappedPoint = mapPoint(point);
        canvas.drawRect(
          Rect.fromLTWH(
            mappedPoint.dx - barWidth / 2,
            mappedPoint.dy,
            barWidth,
            top + height - mappedPoint.dy,
          ),
          Paint()..color = green,
        );
      }
      return;
    }
    if (type == GraphType.line && mapped.length > 1) {
      final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
      for (final point in mapped.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = green
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
    for (final point in mapped) {
      canvas.drawCircle(point, 4, Paint()..color = green);
    }
  }

  void _drawPie(Canvas canvas, Size size) {
    final valid = [
      for (final row in rows)
        if (row.x.trim().isNotEmpty && double.tryParse(row.y) != null)
          MapEntry(row.x.trim(), double.parse(row.y)),
    ];
    final total = valid.fold<double>(0, (sum, row) => sum + row.value);
    if (valid.isEmpty || total <= 0) return;
    final colors = [
      const Color(0xFF5DB075),
      const Color(0xFF49ACC7),
      const Color(0xFFC9A64A),
      const Color(0xFF9B6AD6),
      const Color(0xFF7FBF7A),
    ];
    final rect = Rect.fromLTWH(28, 60, 132, 132);
    var start = -math.pi / 2;
    for (var index = 0; index < valid.length; index++) {
      final sweep = valid[index].value / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = colors[index % colors.length],
      );
      start += sweep;
    }
    for (var index = 0; index < valid.length; index++) {
      final y = 70.0 + index * 30;
      canvas.drawRect(
        Rect.fromLTWH(188, y, 18, 18),
        Paint()..color = colors[index % colors.length],
      );
      _drawText(canvas, valid[index].key, Offset(216, y), 11, FontWeight.w700);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double size,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 190);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PreviewGraphPainter oldDelegate) => true;
}

InputDecoration _inputDecoration({String? label}) {
  return InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: _ConceptExplorationPreviewScreenState._green,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: _ConceptExplorationPreviewScreenState._green,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
  );
}

String _previewText(Object? value) {
  if (value == null) return '';
  if (value is List) {
    return value.map(_previewText).where((item) => item.isNotEmpty).join(', ');
  }
  if (value is Map) {
    return value.values
        .map(_previewText)
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  return value.toString().trim();
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) item.toString()];
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

Rect _scaleRect(Rect rect, double baseWidth, double baseHeight) {
  return Rect.fromLTWH(
    rect.left,
    rect.top,
    rect.width,
    rect.height,
  ).intersect(Rect.fromLTWH(0, 0, baseWidth, baseHeight));
}
