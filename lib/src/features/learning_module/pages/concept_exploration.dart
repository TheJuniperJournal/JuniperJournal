import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/db/repositories/learning_module_repo.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/concept_exploration_preview.dart';
import 'package:juniper_journal/src/features/learning_module/pages/graph_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/image_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';
import 'package:juniper_journal/src/features/learning_module/pages/link_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/module_dashboard.dart';
import 'package:juniper_journal/src/features/learning_module/pages/sketch_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/table_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/text_block_editor.dart';
import 'package:juniper_journal/src/features/learning_module/pages/video_block_editor.dart';

class ConceptExplorationScreen extends StatefulWidget {
  final Map<String, dynamic> module;

  const ConceptExplorationScreen({super.key, required this.module});

  @override
  State<ConceptExplorationScreen> createState() =>
      _ConceptExplorationScreenState();
}

class _ConceptExplorationScreenState extends State<ConceptExplorationScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _mutedText = Color(0xFF565656);
  static const _border = Color(0xFFD8D0D0);
  double get _screenWidth =>
      JournalPageLayout.widthFor(context, mobileWidth: 393);

  final List<_AddedBlock> _blocks = [];
  final _repo = LearningModuleRepo();
  bool _loading = true;

  final List<_BlockType> _contentBlocks = const [
    _BlockType(
      title: 'Text',
      description: 'Write and format text.',
      cardSubtitle: 'How the Earth gets heat.',
      iconAsset: 'assets/learning_module/concept_text.svg',
      tileColor: Color(0xFFE1EFFD),
      iconWidth: 43,
      iconHeight: 29,
    ),
    _BlockType(
      title: 'Images',
      description: 'Upload or create images.',
      cardSubtitle: 'The Greenhouse Effect',
      iconAsset: 'assets/learning_module/concept_image.svg',
      tileColor: Color(0xFFD8F0DF),
      iconWidth: 37,
      iconHeight: 37,
    ),
    _BlockType(
      title: 'Sketch',
      description: 'Create sketches.',
      iconAsset: 'assets/learning_module/concept_sketch.svg',
      tileColor: Color(0xFFE2F4F5),
      iconWidth: 24,
      iconHeight: 19,
    ),
    _BlockType(
      title: 'Video',
      description: 'Upload or embed a video.',
      cardSubtitle: 'How Greenhouse gases capture...',
      iconAsset: 'assets/learning_module/concept_video.svg',
      tileColor: Color(0xFFFFE2E2),
      iconWidth: 41,
      iconHeight: 25,
    ),
    _BlockType(
      title: 'Link',
      description: 'Embed a website link or PDF.',
      iconAsset: 'assets/learning_module/concept_link.svg',
      tileColor: Color(0xFFFFEFE7),
      iconWidth: 26,
      iconHeight: 13,
    ),
  ];

  final List<_BlockType> _dataBlocks = const [
    _BlockType(
      title: 'Graph',
      description: 'Visualize data and trends.',
      iconAsset: 'assets/learning_module/concept_graph.svg',
      tileColor: Color(0xFFE8E8E8),
      iconWidth: 21,
      iconHeight: 18,
    ),
    _BlockType(
      title: 'Table',
      description: 'Organize data in rows and columns.',
      iconAsset: 'assets/learning_module/concept_table.svg',
      tileColor: Color(0xFFE8E8E8),
      iconWidth: 20,
      iconHeight: 20,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  _BlockType? _typeForTitle(String title) {
    for (final type in [..._contentBlocks, ..._dataBlocks]) {
      if (type.title == title) return type;
    }
    return null;
  }

  Future<void> _loadBlocks() async {
    final moduleId = widget.module['id']?.toString();
    if (moduleId == null || moduleId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final freshModule = await _repo.getModule(moduleId);
    final raw = freshModule?['concept_exploration'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final rows = decoded is Map<String, dynamic> ? decoded['blocks'] : null;
        if (rows is List) {
          for (final row in rows) {
            if (row is! Map) continue;
            final json = Map<String, dynamic>.from(row);
            final type = _typeForTitle(json['type']?.toString() ?? '');
            if (type == null) continue;
            final block = _AddedBlock.fromJson(type, json);
            if (block != null) _blocks.add(block);
          }
        }
      } catch (_) {
        // Preserve compatibility with older concept-exploration document data.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _persistBlocks() async {
    final moduleId = widget.module['id']?.toString();
    if (moduleId == null || moduleId.isEmpty) return false;
    final now = DateTime.now().toUtc().toIso8601String();
    final document = {
      'version': 1,
      'module_id': moduleId,
      'section_id': 'concept-exploration-$moduleId',
      'updated_at': now,
      'blocks': [
        for (var index = 0; index < _blocks.length; index++)
          _blocks[index].toJson(
            moduleId: moduleId,
            orderIndex: index,
            updatedAt: now,
          ),
      ],
    };
    return _repo.updateConceptExploration(
      id: moduleId,
      conceptExplorationJson: jsonEncode(document),
    );
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

  Future<void> _openAddBlockSheet() async {
    final blockType = await showAppModalBottomSheet<_BlockType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddBlockSheet(
          contentBlocks: _contentBlocks,
          dataBlocks: _dataBlocks,
          onSelected: (selected) => Navigator.of(context).pop(selected),
        );
      },
    );

    if (!mounted || blockType == null) return;
    if (blockType.title == 'Text') {
      await _openTextBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Images') {
      await _openImageBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Sketch') {
      await _openSketchBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Video') {
      await _openVideoBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Link') {
      await _openLinkBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Table') {
      await _openTableBlockEditor(blockType);
      return;
    }
    if (blockType.title == 'Graph') {
      await _openGraphBlockEditor(blockType);
      return;
    }
    setState(() => _blocks.add(_AddedBlock(type: blockType)));
    await _persistBlocks();
  }

  Future<void> _openTextBlockEditor(_BlockType type, [int? index]) async {
    final moduleId = widget.module['id']?.toString() ?? '';
    final result = await pushAppRoute<TextBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => TextBlockEditorScreen(
          moduleId: moduleId,
          initialData: index == null ? null : _blocks[index].textData,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }

    setState(() {
      final block = _AddedBlock(type: type, textData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    await _persistBlocks();
  }

  Future<void> _openImageBlockEditor(_BlockType type, [int? index]) async {
    final moduleId = widget.module['id']?.toString() ?? '';
    final result = await pushAppRoute<ImageBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageBlockEditorScreen(
          moduleId: moduleId,
          initialData: index == null ? null : _blocks[index].imageData,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }

    setState(() {
      final block = _AddedBlock(type: type, imageData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    await _persistBlocks();
  }

  Future<void> _openSketchBlockEditor(_BlockType type, [int? index]) async {
    final moduleId = widget.module['id']?.toString() ?? '';
    final result = await pushAppRoute<SketchBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => SketchBlockEditorScreen(
          moduleId: moduleId,
          initialData: index == null ? null : _blocks[index].sketchData,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }

    setState(() {
      final block = _AddedBlock(type: type, sketchData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    await _persistBlocks();
  }

  Future<void> _openVideoBlockEditor(_BlockType type, [int? index]) async {
    final moduleId = widget.module['id']?.toString();
    if (moduleId == null || moduleId.isEmpty) {
      _showError('Save the module before adding a video block.');
      return;
    }
    final result = await pushAppRoute<VideoBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => VideoBlockEditorScreen(
          moduleId: moduleId,
          initialData: index == null ? null : _blocks[index].videoData,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }
    setState(() {
      final block = _AddedBlock(type: type, videoData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('Video block could not be saved. Your draft is still open.');
    }
  }

  Future<void> _openTableBlockEditor(_BlockType type, [int? index]) async {
    final result = await pushAppRoute<TableBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => TableBlockEditorScreen(
          initialData: index == null ? null : _blocks[index].tableData,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }
    setState(() {
      final block = _AddedBlock(type: type, tableData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('Table block could not be saved. Your draft is still open.');
    }
  }

  Future<void> _openLinkBlockEditor(_BlockType type, [int? index]) async {
    final result = await pushAppRoute<LinkBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => LinkBlockEditorScreen(
          initialData: index == null ? null : _blocks[index].linkData,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }
    setState(() {
      final block = _AddedBlock(type: type, linkData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('Link block could not be saved. Your draft is still open.');
    }
  }

  Future<void> _openGraphBlockEditor(_BlockType type, [int? index]) async {
    final result = await pushAppRoute<GraphBlockData>(
      context,
      MaterialPageRoute(
        builder: (context) => GraphBlockEditorScreen(
          initialData: index == null ? null : _blocks[index].graphData,
        ),
      ),
    );
    if (!mounted) return;
    if (result == null) {
      await _openAddBlockSheet();
      return;
    }
    setState(() {
      final block = _AddedBlock(type: type, graphData: result);
      if (index == null) {
        _blocks.add(block);
      } else {
        _blocks[index] = block;
      }
    });
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('Graph block could not be saved. Your draft is still open.');
    }
  }

  void _openPreview() {
    pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ConceptExplorationPreviewScreen(module: widget.module),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFD12E2E),
      ),
    );
  }

  Future<void> _deleteBlock(int index) async {
    setState(() => _blocks.removeAt(index));
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('The block was removed locally but could not be saved.');
    }
  }

  Future<void> _openReorder() async {
    if (_blocks.length <= 1) return;
    final reordered = await showAppModalBottomSheet<List<_AddedBlock>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReorderSheet(blocks: _blocks),
    );
    if (!mounted || reordered == null) return;
    setState(() {
      _blocks
        ..clear()
        ..addAll(reordered);
    });
    final saved = await _persistBlocks();
    if (!saved && mounted) {
      _showError('Block order could not be saved.');
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
            child: SizedBox(
              width: _screenWidth,
              height: 852,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 21,
                    child: Text(
                      'Concept Exploration',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.headingFamily,
                        color: _text,
                        fontSize: AppTypography.sectionTitleSize,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 25,
                    top: 17,
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
                    top: 64,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE6E6E6),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 96,
                    bottom: 96,
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(color: _green),
                          )
                        : _blocks.isEmpty
                        ? _EmptyState(onAddBlock: _openAddBlockSheet)
                        : _BlockList(
                            blocks: _blocks,
                            onTextBlockTap: _openTextBlockEditor,
                            onImageBlockTap: _openImageBlockEditor,
                            onSketchBlockTap: _openSketchBlockEditor,
                            onVideoBlockTap: _openVideoBlockEditor,
                            onTableBlockTap: _openTableBlockEditor,
                            onLinkBlockTap: _openLinkBlockEditor,
                            onGraphBlockTap: _openGraphBlockEditor,
                            onDelete: _deleteBlock,
                          ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 96,
                    child: _BottomActions(
                      onAddBlock: _openAddBlockSheet,
                      onReorder: _openReorder,
                      canReorder: _blocks.length > 1,
                      onPreview: _blocks.isEmpty ? null : _openPreview,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockType {
  final String title;
  final String description;
  final String? cardSubtitle;
  final String iconAsset;
  final Color tileColor;
  final double iconWidth;
  final double iconHeight;

  const _BlockType({
    required this.title,
    required this.description,
    this.cardSubtitle,
    required this.iconAsset,
    required this.tileColor,
    required this.iconWidth,
    required this.iconHeight,
  });
}

class _AddedBlock {
  final _BlockType type;
  final TextBlockData? textData;
  final ImageBlockData? imageData;
  final SketchBlockData? sketchData;
  final VideoBlockData? videoData;
  final TableBlockData? tableData;
  final LinkBlockData? linkData;
  final GraphBlockData? graphData;

  const _AddedBlock({
    required this.type,
    this.textData,
    this.imageData,
    this.sketchData,
    this.videoData,
    this.tableData,
    this.linkData,
    this.graphData,
  });

  Map<String, dynamic> toJson({
    required String moduleId,
    required int orderIndex,
    required String updatedAt,
  }) {
    final data = switch (type.title) {
      'Text' => {
        'title': textData?.title ?? '',
        'content': textData?.content ?? '',
        'inquiry_lens': textData?.inquiryLens ?? 'None',
        'inquiry_lens_data':
            textData?.inquiryLensData.toJson() ?? <String, dynamic>{},
        'inquiry':
            textData?.inquiryLensData.toPreviewJson() ?? <String, dynamic>{},
        'caption': textData?.caption ?? '',
        'font_size': textData?.fontSize ?? '10',
        'bold': textData?.bold ?? false,
        'italic': textData?.italic ?? false,
        'underline': textData?.underline ?? false,
        'alignment': textData?.alignment ?? 'left',
        'assessment': textData?.assessment.toJson() ?? <String, dynamic>{},
        'media_items': [
          for (final item in textData?.mediaItems ?? const [])
            {
              'label': item.label,
              'has_placeholder_image': item.hasPlaceholderImage,
              'storage_path': item.storagePath,
              'public_url': item.publicUrl,
              'file_name': item.fileName,
            },
        ],
      },
      'Images' => {
        'title': imageData?.title ?? '',
        'caption': imageData?.caption ?? '',
        'inquiry_lens': imageData?.inquiryLens ?? 'None',
        'inquiry_lens_data':
            imageData?.inquiryLensData.toJson() ?? <String, dynamic>{},
        'inquiry':
            imageData?.inquiryLensData.toPreviewJson() ?? <String, dynamic>{},
        'assessment': imageData?.assessment.toJson() ?? <String, dynamic>{},
        'images': [
          for (final item in imageData?.images ?? const [])
            {
              'description': item.description,
              'has_placeholder_image': item.hasPlaceholderImage,
              'storage_path': item.storagePath,
              'public_url': item.publicUrl,
              'file_name': item.fileName,
            },
        ],
      },
      'Sketch' => sketchData?.toJson() ?? <String, dynamic>{},
      'Video' => videoData?.toJson() ?? <String, dynamic>{},
      'Table' => tableData?.toJson() ?? <String, dynamic>{},
      'Link' => linkData?.toJson() ?? <String, dynamic>{},
      'Graph' => graphData?.toJson() ?? <String, dynamic>{},
      _ => <String, dynamic>{},
    };
    return {
      'id':
          videoData?.id ??
          linkData?.id ??
          graphData?.id ??
          '${type.title.toLowerCase()}-$orderIndex-${DateTime.now().microsecondsSinceEpoch}',
      'module_id': moduleId,
      'section_id': 'concept-exploration-$moduleId',
      'order_index': orderIndex,
      'type': type.title,
      'data': data,
      'updated_at': updatedAt,
    };
  }

  static _AddedBlock? fromJson(_BlockType type, Map<String, dynamic> json) {
    final rawData = json['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    switch (type.title) {
      case 'Text':
        final media = data['media_items'];
        return _AddedBlock(
          type: type,
          textData: TextBlockData(
            title: data['title']?.toString() ?? '',
            content: data['content']?.toString() ?? '',
            inquiryLens: data['inquiry_lens']?.toString() ?? 'None',
            inquiryLensData: InquiryLensData.fromJson(
              data['inquiry_lens_data'],
              legacyLens: data['inquiry_lens']?.toString() ?? 'None',
            ),
            caption: data['caption']?.toString() ?? '',
            fontSize: data['font_size']?.toString() ?? '10',
            bold: data['bold'] == true,
            italic: data['italic'] == true,
            underline: data['underline'] == true,
            alignment: data['alignment']?.toString() ?? 'left',
            assessment: AssessmentBlockData.fromJson(data['assessment']),
            mediaItems: media is List
                ? [
                    for (final item in media)
                      if (item is Map)
                        TextBlockMediaItem(
                          label: item['label']?.toString() ?? '',
                          hasPlaceholderImage:
                              item['has_placeholder_image'] == true,
                          storagePath: item['storage_path']?.toString() ?? '',
                          publicUrl: item['public_url']?.toString() ?? '',
                          fileName: item['file_name']?.toString() ?? '',
                        ),
                  ]
                : const [],
          ),
        );
      case 'Images':
        final images = data['images'];
        return _AddedBlock(
          type: type,
          imageData: ImageBlockData(
            title: data['title']?.toString() ?? '',
            caption: data['caption']?.toString() ?? '',
            inquiryLens: data['inquiry_lens']?.toString() ?? 'None',
            inquiryLensData: InquiryLensData.fromJson(
              data['inquiry_lens_data'],
              legacyLens: data['inquiry_lens']?.toString() ?? 'None',
            ),
            assessment: AssessmentBlockData.fromJson(data['assessment']),
            images: images is List
                ? [
                    for (final item in images)
                      if (item is Map)
                        ImageBlockItem(
                          description: item['description']?.toString() ?? '',
                          hasPlaceholderImage:
                              item['has_placeholder_image'] == true,
                          storagePath: item['storage_path']?.toString() ?? '',
                          publicUrl: item['public_url']?.toString() ?? '',
                          fileName: item['file_name']?.toString() ?? '',
                        ),
                  ]
                : const [],
          ),
        );
      case 'Sketch':
        return _AddedBlock(
          type: type,
          sketchData: SketchBlockData.fromJson(data),
        );
      case 'Video':
        return _AddedBlock(
          type: type,
          videoData: VideoBlockData.fromJson(data),
        );
      case 'Table':
        return _AddedBlock(
          type: type,
          tableData: TableBlockData.fromJson(data),
        );
      case 'Link':
        return _AddedBlock(type: type, linkData: LinkBlockData.fromJson(data));
      case 'Graph':
        return _AddedBlock(
          type: type,
          graphData: GraphBlockData.fromJson(data),
        );
      default:
        return _AddedBlock(type: type);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddBlock;

  const _EmptyState({required this.onAddBlock});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 136),
        const _ThreeCubesIllustration(),
        const SizedBox(height: AppMetrics.sectionGap),
        const Text(
          'Nothing yet...',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: _ConceptExplorationScreenState._text,
            fontSize: AppTypography.bodySize,
            height: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 11),
        const Text('Add your first block', style: AppTypography.helper),
        const SizedBox(height: AppMetrics.sectionGap),
        SizedBox(
          width: 345,
          height: 48,
          child: OutlinedButton(
            onPressed: onAddBlock,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ConceptExplorationScreenState._green,
              side: const BorderSide(
                color: _ConceptExplorationScreenState._green,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '+  Add Block',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.buttonSize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BlockList extends StatelessWidget {
  final List<_AddedBlock> blocks;
  final void Function(_BlockType type, int index) onTextBlockTap;
  final void Function(_BlockType type, int index) onImageBlockTap;
  final void Function(_BlockType type, int index) onSketchBlockTap;
  final void Function(_BlockType type, int index) onVideoBlockTap;
  final void Function(_BlockType type, int index) onTableBlockTap;
  final void Function(_BlockType type, int index) onLinkBlockTap;
  final void Function(_BlockType type, int index) onGraphBlockTap;
  final ValueChanged<int> onDelete;

  const _BlockList({
    required this.blocks,
    required this.onTextBlockTap,
    required this.onImageBlockTap,
    required this.onSketchBlockTap,
    required this.onVideoBlockTap,
    required this.onTableBlockTap,
    required this.onLinkBlockTap,
    required this.onGraphBlockTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PageScrollWithFooter(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(33, 47, 32, 24),
        itemCount: blocks.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppMetrics.fieldGap),
        itemBuilder: (context, index) {
          final block = blocks[index];
          VoidCallback? onTap;
          if (block.type.title == 'Text') {
            onTap = () => onTextBlockTap(block.type, index);
          } else if (block.type.title == 'Images') {
            onTap = () => onImageBlockTap(block.type, index);
          } else if (block.type.title == 'Sketch') {
            onTap = () => onSketchBlockTap(block.type, index);
          } else if (block.type.title == 'Video') {
            onTap = () => onVideoBlockTap(block.type, index);
          } else if (block.type.title == 'Table') {
            onTap = () => onTableBlockTap(block.type, index);
          } else if (block.type.title == 'Link') {
            onTap = () => onLinkBlockTap(block.type, index);
          } else if (block.type.title == 'Graph') {
            onTap = () => onGraphBlockTap(block.type, index);
          }
          return _BlockCard(
            block: block,
            onTap: onTap,
            onDelete: () => onDelete(index),
          );
        },
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final _AddedBlock block;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _BlockCard({required this.block, required this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${block.type.title} editor coming soon'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(milliseconds: 1200),
              ),
            );
          },
      child: Container(
        width: 328,
        height: 94,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _ConceptExplorationScreenState._border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 19,
              top: 15,
              width: 63,
              height: 61,
              child: _IconTile(block: block.type),
            ),
            Positioned(
              left: 105,
              top: 24,
              child: Text(
                block.type.title,
                style: const TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  color: _ConceptExplorationScreenState._text,
                  fontSize: AppTypography.sectionTitleSize,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Positioned(
              left: 106,
              top: 47,
              width: 194,
              child: Text(
                block.textData?.cardSubtitle ??
                    block.imageData?.cardSubtitle ??
                    block.sketchData?.cardSubtitle ??
                    block.videoData?.cardSubtitle ??
                    block.tableData?.cardSubtitle ??
                    block.linkData?.cardSubtitle ??
                    block.graphData?.cardSubtitle ??
                    block.type.cardSubtitle ??
                    block.type.description,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _ConceptExplorationScreenState._mutedText,
                  fontSize: AppTypography.bodySize,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Positioned(
              right: 20,
              top: 7,
              child: ItemActionMenu(onEdit: onTap, onDelete: onDelete),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddBlockSheet extends StatelessWidget {
  final List<_BlockType> contentBlocks;
  final List<_BlockType> dataBlocks;
  final ValueChanged<_BlockType> onSelected;

  const _AddBlockSheet({
    required this.contentBlocks,
    required this.dataBlocks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(13, 11, 13, 18 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'Add Block',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: _ConceptExplorationScreenState._green,
                        fontSize: AppTypography.buttonSize,
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 1,
                    width: 24,
                    height: 22,
                    child: AppTapTarget(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: _BackChevron(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 19),
            _MenuSection(
              title: 'Content Blocks',
              blocks: contentBlocks,
              onSelected: onSelected,
            ),
            const SizedBox(height: 12),
            _MenuSection(
              title: 'Data Blocks',
              blocks: dataBlocks,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_BlockType> blocks;
  final ValueChanged<_BlockType> onSelected;

  const _MenuSection({
    required this.title,
    required this.blocks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 367,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E1E1)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 14, 19, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _ConceptExplorationScreenState._text,
                fontSize: AppTypography.bodySize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          for (var index = 0; index < blocks.length; index++) ...[
            _BlockMenuRow(
              block: blocks[index],
              onTap: () => onSelected(blocks[index]),
            ),
            if (index != blocks.length - 1)
              const Divider(height: 1, color: Color(0xFFE7E7E7)),
          ],
        ],
      ),
    );
  }
}

class _BlockMenuRow extends StatelessWidget {
  final _BlockType block;
  final VoidCallback onTap;

  const _BlockMenuRow({required this.block, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 19),
            SizedBox(width: 34, height: 33, child: _IconTile(block: block)),
            const SizedBox(width: 23),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _ConceptExplorationScreenState._text,
                      fontSize: AppTypography.bodySize,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    block.description,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: _ConceptExplorationScreenState._mutedText,
                      fontSize: AppTypography.helperSize,
                      height: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const _RightChevron(),
            const SizedBox(width: 17),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final _BlockType block;

  const _IconTile({required this.block});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: block.tileColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        block.iconAsset,
        width: block.iconWidth,
        height: block.iconHeight,
      ),
    );
  }
}

class _ReorderSheet extends StatefulWidget {
  final List<_AddedBlock> blocks;

  const _ReorderSheet({required this.blocks});

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late final List<_AddedBlock> _draftBlocks = List<_AddedBlock>.from(
    widget.blocks,
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return SafeArea(
      top: false,
      child: Container(
        height: 470 + bottomInset,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + bottomInset),
        child: Column(
          children: [
            Container(
              width: 30,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppMetrics.labelGap),
            const Text(
              'Reorder',
              style: TextStyle(
                fontFamily: AppTypography.headingFamily,
                color: _ConceptExplorationScreenState._text,
                fontSize: AppTypography.sectionTitleSize,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),
            Expanded(
              child: ReorderableListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _draftBlocks.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final block = _draftBlocks.removeAt(oldIndex);
                    _draftBlocks.insert(newIndex, block);
                  });
                },
                itemBuilder: (context, index) {
                  final block = _draftBlocks[index];
                  return Container(
                    key: ValueKey('${block.type.title}-$index'),
                    height: 58,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: _ConceptExplorationScreenState._border,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        _IconTile(block: block.type),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            block.type.title,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _ConceptExplorationScreenState._text,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: SvgPicture.asset(
                            'assets/learning_module/concept_reorder.svg',
                            width: 28,
                            height: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: 345,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_draftBlocks),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ConceptExplorationScreenState._green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onAddBlock;
  final VoidCallback onReorder;
  final bool canReorder;
  final VoidCallback? onPreview;

  const _BottomActions({
    required this.onAddBlock,
    required this.onReorder,
    required this.canReorder,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDADADA))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomAction(
            label: 'Add Block',
            isActive: true,
            onTap: onAddBlock,
            icon: const _AddBlockIcon(size: 40),
          ),
          _BottomAction(
            label: 'Reorder',
            onTap: canReorder ? onReorder : null,
            icon: SvgPicture.asset(
              'assets/learning_module/concept_reorder.svg',
              width: 40,
              height: 36,
            ),
          ),
          _BottomAction(
            label: 'Preview',
            onTap: onPreview,
            icon: const _PreviewIcon(),
          ),
        ],
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _BottomAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? const Color(0xFFB8B8B8)
        : isActive
        ? _ConceptExplorationScreenState._green
        : Colors.black;

    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 42, height: 42, child: icon),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: color,
                fontSize: AppTypography.bodySize,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreeCubesIllustration extends StatelessWidget {
  const _ThreeCubesIllustration();

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 3.45,
      child: const SizedBox(
        width: 39.484375,
        height: 25.71484375,
        child: Stack(
          children: [
            _CubePart(left: 13.0390625, top: 9.572265625, isDot: true),
            _CubePart(left: 10.64453125, top: 7.1787109375),
            _CubePart(left: 22.609375, top: 0),
            _CubePart(left: -0.125, top: 0),
          ],
        ),
      ),
    );
  }
}

class _CubePart extends StatelessWidget {
  final double left;
  final double top;
  final bool isDot;

  const _CubePart({required this.left, required this.top, this.isDot = false});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: isDot ? 2.392857074737549 : 16.75,
      height: isDot ? 2.392857074737549 : 19.14285659790039,
      child: SvgPicture.asset(
        isDot
            ? 'assets/create_menu/learning_module_cube_dot.svg'
            : 'assets/create_menu/learning_module_cube.svg',
        fit: BoxFit.fill,
      ),
    );
  }
}

class _AddBlockIcon extends StatelessWidget {
  final double size;

  const _AddBlockIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            'assets/learning_module/concept_addblock.svg',
            width: size,
            height: size,
            colorFilter: const ColorFilter.mode(
              _ConceptExplorationScreenState._green,
              BlendMode.srcIn,
            ),
          ),
          SvgPicture.asset(
            'assets/learning_module/concept_addblock_vertical.svg',
            width: size * 0.08,
            height: size * 0.5,
            colorFilter: const ColorFilter.mode(
              _ConceptExplorationScreenState._green,
              BlendMode.srcIn,
            ),
          ),
          SvgPicture.asset(
            'assets/learning_module/concept_addblock_horizontal.svg',
            width: size * 0.5,
            height: size * 0.08,
            colorFilter: const ColorFilter.mode(
              _ConceptExplorationScreenState._green,
              BlendMode.srcIn,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewIcon extends StatelessWidget {
  const _PreviewIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        children: [
          Positioned(
            left: 3,
            top: 3,
            child: SvgPicture.asset(
              'assets/learning_module/concept_preview_outer.svg',
              width: 36,
              height: 36,
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: SvgPicture.asset(
              'assets/learning_module/concept_preview_cursor.svg',
              width: 21,
              height: 21,
            ),
          ),
        ],
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
      ..color = _ConceptExplorationScreenState._green
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

class _RightChevron extends StatelessWidget {
  const _RightChevron();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(8, 13),
      painter: _RightChevronPainter(),
    );
  }
}

class _RightChevronPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB6B6B6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(1, size.height - 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
