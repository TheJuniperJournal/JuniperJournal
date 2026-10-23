import '../../../shared/widgets/evidence_description_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

class TextBlockData {
  final String title;
  final String content;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final String caption;
  final List<TextBlockMediaItem> mediaItems;
  final AssessmentBlockData assessment;
  final String fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final String alignment;

  const TextBlockData({
    this.title = '',
    this.content = '',
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.caption = '',
    this.mediaItems = const [],
    this.assessment = const AssessmentBlockData(),
    this.fontSize = '10',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.alignment = 'left',
  });

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (content.trim().isNotEmpty) return content.trim();
    if (mediaItems.isNotEmpty) return 'Text block with media';
    return 'Write and format text.';
  }
}

class TextBlockMediaItem {
  final String label;
  final bool hasPlaceholderImage;
  final String storagePath;
  final String publicUrl;
  final String fileName;

  const TextBlockMediaItem({
    required this.label,
    this.hasPlaceholderImage = false,
    this.storagePath = '',
    this.publicUrl = '',
    this.fileName = '',
  });

  TextBlockMediaItem copyWith({
    String? label,
    bool? hasPlaceholderImage,
    String? storagePath,
    String? publicUrl,
    String? fileName,
  }) {
    return TextBlockMediaItem(
      label: label ?? this.label,
      hasPlaceholderImage: hasPlaceholderImage ?? this.hasPlaceholderImage,
      storagePath: storagePath ?? this.storagePath,
      publicUrl: publicUrl ?? this.publicUrl,
      fileName: fileName ?? this.fileName,
    );
  }
}

class TextBlockEditorScreen extends StatefulWidget {
  final String moduleId;
  final TextBlockData? initialData;

  const TextBlockEditorScreen({
    super.key,
    required this.moduleId,
    this.initialData,
  });

  @override
  State<TextBlockEditorScreen> createState() => _TextBlockEditorScreenState();
}

class _TextBlockEditorScreenState extends State<TextBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _mutedText = Color(0xFF565656);
  static const _border = Color(0xFF5DB075);
  static const _lightBorder = Color(0xFFD8D0D0);
  static const _screenWidth = 393.0;

  static const _fontSizes = ['10', '12', '14', '16', '18'];

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _captionController;
  late List<TextEditingController> _mediaControllers;
  late List<TextBlockMediaItem> _mediaItems;
  late AssessmentBlockData _assessment;
  late InquiryLensData _inquiryLensData;
  final _picker = ImagePicker();
  final _storage = StorageService();
  final Set<int> _uploadingIndexes = {};
  String _fontSize = '10';
  String? _uploadError;
  bool _showValidation = false;
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  String _alignment = 'left';

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _contentController = TextEditingController(text: data?.content ?? '');
    _captionController = TextEditingController(text: data?.caption ?? '');
    _inquiryLensData = data == null
        ? const InquiryLensData()
        : data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data?.assessment ?? const AssessmentBlockData();
    _fontSize = data?.fontSize ?? '10';
    _bold = data?.bold ?? false;
    _italic = data?.italic ?? false;
    _underline = data?.underline ?? false;
    _alignment = data?.alignment ?? 'left';
    _mediaItems = List<TextBlockMediaItem>.from(data?.mediaItems ?? const []);
    _mediaControllers = _mediaItems
        .map((item) => TextEditingController(text: item.label))
        .toList();
    _titleController.addListener(_refresh);
    _contentController.addListener(_refresh);
    _captionController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _captionController.dispose();
    for (final controller in _mediaControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _hasContent =>
      _contentController.text.trim().isNotEmpty || _mediaItems.isNotEmpty;

  void _saveBlock() {
    if (!_hasContent) {
      setState(() => _showValidation = true);
      return;
    }

    Navigator.of(context).pop(
      TextBlockData(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        caption: _captionController.text.trim(),
        mediaItems: [
          for (var index = 0; index < _mediaItems.length; index++)
            _mediaItems[index].copyWith(
              label: _mediaControllers[index].text.trim(),
            ),
        ],
        assessment: _assessment,
        fontSize: _fontSize,
        bold: _bold,
        italic: _italic,
        underline: _underline,
        alignment: _alignment,
      ),
    );
  }

  void _addImage() {
    if (_mediaItems.length >= 10) return;
    setState(() {
      final number = _mediaItems.length + 1;
      _mediaItems.add(TextBlockMediaItem(label: 'Image $number'));
      _mediaControllers.add(TextEditingController());
    });
  }

  void _removeImage(int index) {
    setState(() {
      _mediaItems.removeAt(index);
      _mediaControllers.removeAt(index).dispose();
    });
  }

  void _showUploadSheet(int index) {
    showAppModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(19, 0, 19, 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _UploadAction(
                  top: true,
                  label: 'Open Library',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(index, ImageSource.gallery);
                  },
                ),
                _UploadAction(
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(index, ImageSource.camera);
                  },
                ),
                const SizedBox(height: 13),
                _UploadAction(
                  label: 'Cancel',
                  isCancel: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(int index, ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final userId = SupabaseDatabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _uploadError = 'Sign in before uploading an image.');
      return;
    }

    setState(() {
      _uploadingIndexes.add(index);
      _uploadError = null;
    });
    try {
      final uploaded = await _storage.uploadImageFile(
        picked,
        bucketName: 'images',
        folder:
            'learning-modules/$userId/${widget.moduleId}/concept-exploration/text-media',
      );
      if (!mounted || index >= _mediaItems.length) return;
      setState(() {
        _mediaItems[index] = _mediaItems[index].copyWith(
          hasPlaceholderImage: true,
          storagePath: uploaded.path,
          publicUrl: uploaded.publicUrl,
          fileName: uploaded.fileName,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadError = 'Image upload failed. Your draft was not cleared.';
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingIndexes.remove(index));
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 18, 27),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(label: 'Content'),
                        const SizedBox(height: AppMetrics.labelGap),
                        _LabeledField(
                          label: 'Title',
                          optional: true,
                          child: _TextInputBox(
                            controller: _titleController,
                            maxLength: 100,
                            height: 64,
                            singleLine: true,
                          ),
                        ),
                        const SizedBox(height: AppMetrics.labelGap),
                        _SectionLabel(label: 'Text Content'),
                        const SizedBox(height: 10),
                        _TextContentEditor(
                          controller: _contentController,
                          maxLength: 5000,
                          showError: _showValidation && !_hasContent,
                          fontSize: _fontSize,
                          bold: _bold,
                          italic: _italic,
                          underline: _underline,
                          alignment: _alignment,
                          onFontSizeChanged: (value) {
                            setState(() => _fontSize = value);
                          },
                          onBold: () => setState(() => _bold = !_bold),
                          onItalic: () => setState(() => _italic = !_italic),
                          onUnderline: () {
                            setState(() => _underline = !_underline);
                          },
                          onAlignmentChanged: (value) {
                            setState(() => _alignment = value);
                          },
                        ),
                        if (_showValidation && !_hasContent) ...[
                          const SizedBox(height: 7),
                          const Text(
                            'Add text content or supporting media.',
                            style: AppTypography.helper,
                          ),
                        ],
                        const SizedBox(height: 23),
                        const _SectionLabel(
                          label: 'Supporting Media',
                          optional: true,
                        ),
                        const SizedBox(height: AppMetrics.labelGap),
                        Row(
                          children: [
                            _SmallOutlineButton(
                              label: 'Add Image',
                              filled: _mediaItems.isNotEmpty,
                              onTap: _addImage,
                            ),
                            const Spacer(),
                            _SmallOutlineButton(
                              label: 'Add Sketch',
                              onTap: () {},
                            ),
                          ],
                        ),
                        if (_mediaItems.isNotEmpty) ...[
                          const SizedBox(height: AppMetrics.sectionGap),
                          _ImagesSection(
                            items: _mediaItems,
                            controllers: _mediaControllers,
                            uploadingIndexes: _uploadingIndexes,
                            onAddImage: _addImage,
                            onRemove: _removeImage,
                            onUpload: _showUploadSheet,
                          ),
                          if (_uploadError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _uploadError!,
                              style: const TextStyle(
                                color: Color(0xFFD12E2E),
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppMetrics.labelGap),
                          _LabeledField(
                            label: 'Evidence description',
                            optional: true,
                            child: _TextInputBox(
                              controller: _captionController,
                              maxLength: 200,
                              height: 56,
                              maxLines: 2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 27),

                        const SizedBox(height: AppMetrics.sectionGap),
                        Center(
                          child: _PrimaryActionButton(
                            label: _isEditing ? 'Save' : 'Add Block',
                            onTap: _saveBlock,
                          ),
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
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      EvidenceBlockHeader(title: 'Text Block', onBack: onBack);
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool optional;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.child,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label, optional: optional),
        const SizedBox(height: 11),
        child,
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _SectionLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _TextBlockEditorScreenState._text,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                color: Color(0xFFC8C8C8),
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _TextInputBox extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final bool singleLine;
  final int? maxLines;

  const _TextInputBox({
    required this.controller,
    required this.maxLength,
    required this.height,
    this.singleLine = false,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (!singleLine) return EvidenceDescriptionField(controller: controller);
    return SizedBox(
      height: height + 17,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height,
            child: TextField(
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              controller: controller,
              maxLength: maxLength,
              maxLines: singleLine ? 1 : maxLines,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: _TextBlockEditorScreenState._border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: _TextBlockEditorScreenState._border,
                  ),
                ),
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _TextBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(right: 2, bottom: 0, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _TextContentEditor extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final bool showError;
  final String fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final String alignment;
  final ValueChanged<String> onFontSizeChanged;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final ValueChanged<String> onAlignmentChanged;

  const _TextContentEditor({
    required this.controller,
    required this.maxLength,
    required this.showError,
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.alignment,
    required this.onFontSizeChanged,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onAlignmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = showError
        ? const Color(0xFFD12E2E)
        : _TextBlockEditorScreenState._border;

    return SizedBox(
      height: 206,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 11,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 42,
                    child: _Toolbar(
                      fontSize: fontSize,
                      bold: bold,
                      italic: italic,
                      underline: underline,
                      alignment: alignment,
                      onFontSizeChanged: onFontSizeChanged,
                      onBold: onBold,
                      onItalic: onItalic,
                      onUnderline: onUnderline,
                      onAlignmentChanged: onAlignmentChanged,
                    ),
                  ),
                  Container(height: 1, color: borderColor),
                  Expanded(
                    child: TextField(
                      buildCounter:
                          (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                      controller: controller,
                      maxLength: maxLength,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      textAlign: switch (alignment) {
                        'center' => TextAlign.center,
                        'right' => TextAlign.right,
                        _ => TextAlign.left,
                      },
                      decoration: const InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: _TextBlockEditorScreenState._text,
                        fontSize: double.tryParse(fontSize) ?? 10,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                        decoration: underline
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(right: 4, bottom: 0, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final String fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final String alignment;
  final ValueChanged<String> onFontSizeChanged;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final ValueChanged<String> onAlignmentChanged;

  const _Toolbar({
    required this.fontSize,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.alignment,
    required this.onFontSizeChanged,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onAlignmentChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 13),
        const _ToolbarIcon(
          asset: 'assets/learning_module/text_block_bullets.svg',
        ),
        const SizedBox(width: 19),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_bold.svg',
          selected: bold,
          onTap: onBold,
        ),
        const SizedBox(width: 19),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_italic.svg',
          selected: italic,
          onTap: onItalic,
        ),
        const SizedBox(width: 19),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_underline.svg',
          selected: underline,
          onTap: onUnderline,
        ),
        const SizedBox(width: 18),
        _TinyDropdown(
          value: fontSize,
          options: _TextBlockEditorScreenState._fontSizes,
          onSelected: onFontSizeChanged,
        ),
        const SizedBox(width: 21),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_align_left.svg',
          selected: alignment == 'left',
          onTap: () => onAlignmentChanged('left'),
        ),
        const SizedBox(width: 23),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_align_center.svg',
          selected: alignment == 'center',
          onTap: () => onAlignmentChanged('center'),
        ),
        const SizedBox(width: 23),
        _ToolbarIcon(
          asset: 'assets/learning_module/text_block_align_right.svg',
          selected: alignment == 'right',
          onTap: () => onAlignmentChanged('right'),
        ),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final String asset;
  final bool selected;
  final VoidCallback? onTap;

  const _ToolbarIcon({required this.asset, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 21,
        height: 28,
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(5),
              )
            : null,
        child: SvgPicture.asset(asset),
      ),
    );
  }
}

class _TinyDropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _TinyDropdown({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, height: 34, child: Text(option)),
      ],
      child: Container(
        width: 36,
        height: 29,
        decoration: BoxDecoration(
          color: const Color(0xFFE6E6E6),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _TextBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            SvgPicture.asset(
              'assets/learning_module/text_block_chevron.svg',
              width: 8,
              height: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallOutlineButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SmallOutlineButton({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: label == 'Add Sketch' ? 140 : 130,
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? const Color(0xFFDDF2E4) : Colors.white,
          foregroundColor: _TextBlockEditorScreenState._green,
          side: const BorderSide(color: _TextBlockEditorScreenState._green),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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

class _ImagesSection extends StatelessWidget {
  final List<TextBlockMediaItem> items;
  final List<TextEditingController> controllers;
  final Set<int> uploadingIndexes;
  final VoidCallback onAddImage;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onUpload;

  const _ImagesSection({
    required this.items,
    required this.controllers,
    required this.uploadingIndexes,
    required this.onAddImage,
    required this.onRemove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Images (${items.length} of 10)',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _TextBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 120,
              height: 20,
              child: OutlinedButton(
                onPressed: items.length >= 10 ? null : onAddImage,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: _TextBlockEditorScreenState._text,
                  side: const BorderSide(
                    color: _TextBlockEditorScreenState._lightBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '+  Add Image',
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _TextBlockEditorScreenState._lightBorder),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _ImageRow(
                  index: index,
                  item: items[index],
                  controller: controllers[index],
                  uploading: uploadingIndexes.contains(index),
                  onRemove: () => onRemove(index),
                  onUpload: () => onUpload(index),
                ),
                if (index != items.length - 1)
                  const Divider(
                    height: 1,
                    color: _TextBlockEditorScreenState._lightBorder,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageRow extends StatelessWidget {
  final int index;
  final TextBlockMediaItem item;
  final TextEditingController controller;
  final bool uploading;
  final VoidCallback onRemove;
  final VoidCallback onUpload;

  const _ImageRow({
    required this.index,
    required this.item,
    required this.controller,
    required this.uploading,
    required this.onRemove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _NumberBadge(number: index + 1),
          const SizedBox(width: 11),
          GestureDetector(
            onTap: onUpload,
            child: Container(
              width: 106,
              height: 59,
              decoration: BoxDecoration(
                color: item.hasPlaceholderImage
                    ? const Color(0xFFD8F0DF)
                    : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: item.hasPlaceholderImage
                      ? Colors.transparent
                      : const Color(0xFFD8D8D8),
                  style: BorderStyle.solid,
                ),
              ),
              alignment: Alignment.center,
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _TextBlockEditorScreenState._green,
                      ),
                    )
                  : item.publicUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        item.publicUrl,
                        width: 98,
                        height: 51,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : item.hasPlaceholderImage
                  ? const _PlaceholderImage()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _ImagePlaceholderIcon(),
                        SizedBox(height: 2),
                        Text(
                          'Click to upload',
                          style: TextStyle(
                            color: Color(0xFFC8C8C8),
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Image ${index + 1}',
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _TextBlockEditorScreenState._text,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 9),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 100),
                  child: TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: null,
                    decoration: InputDecoration(
                      labelText: 'Image ${index + 1} caption',
                      hintText: 'Explain what this image shows.',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: _TextBlockEditorScreenState._border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: _TextBlockEditorScreenState._border,
                        ),
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: SvgPicture.asset(
              'assets/learning_module/learning_objective_trash.svg',
              width: 15,
              height: 16,
            ),
          ),
          const SizedBox(width: 13),
        ],
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;

  const _NumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _TextBlockEditorScreenState._green),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _TextBlockEditorScreenState._green,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _ImagePlaceholderIcon extends StatelessWidget {
  const _ImagePlaceholderIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 25),
      painter: _ImagePlaceholderPainter(
        color: _TextBlockEditorScreenState._green,
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          colors: [Color(0xFF78B88A), Color(0xFFD4B275)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _ImagePlaceholderPainter extends CustomPainter {
  final Color color;

  const _ImagePlaceholderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawRect(rect, paint);
    canvas.drawCircle(Offset(size.width * 0.68, size.height * 0.34), 3, paint);
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.76)
      ..lineTo(size.width * 0.43, size.height * 0.48)
      ..lineTo(size.width * 0.61, size.height * 0.66)
      ..lineTo(size.width * 0.78, size.height * 0.52)
      ..lineTo(size.width * 0.92, size.height * 0.76);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ignore: unused_element
class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _DropdownField({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      offset: const Offset(0, 47),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, height: 38, child: Text(option)),
      ],
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          border: Border.all(color: _TextBlockEditorScreenState._border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _TextBlockEditorScreenState._text,
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
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 32,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _TextBlockEditorScreenState._green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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

class _UploadAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool top;
  final bool isCancel;

  const _UploadAction({
    required this.label,
    required this.onTap,
    this.top = false,
    this.isCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: isCancel ? 49 : 73,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(top || isCancel ? 9 : 0),
            bottom: Radius.circular(isCancel ? 9 : 0),
          ),
          border: top
              ? null
              : const Border(top: BorderSide(color: Color(0xFFE0E0E0))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCancel
                ? const Color(0xFF007AFF)
                : _TextBlockEditorScreenState._text,
            fontSize: AppTypography.sectionTitleSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
