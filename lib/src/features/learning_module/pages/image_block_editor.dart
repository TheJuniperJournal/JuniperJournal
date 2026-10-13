import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

class ImageBlockData {
  final String title;
  final String caption;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final List<ImageBlockItem> images;
  final AssessmentBlockData assessment;

  const ImageBlockData({
    this.title = '',
    this.caption = '',
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.images = const [],
    this.assessment = const AssessmentBlockData(),
  });

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (caption.trim().isNotEmpty) return caption.trim();
    return 'Upload or create images.';
  }
}

class ImageBlockItem {
  final String description;
  final bool hasPlaceholderImage;
  final String storagePath;
  final String publicUrl;
  final String fileName;

  const ImageBlockItem({
    this.description = '',
    this.hasPlaceholderImage = false,
    this.storagePath = '',
    this.publicUrl = '',
    this.fileName = '',
  });

  ImageBlockItem copyWith({
    String? description,
    bool? hasPlaceholderImage,
    String? storagePath,
    String? publicUrl,
    String? fileName,
  }) {
    return ImageBlockItem(
      description: description ?? this.description,
      hasPlaceholderImage: hasPlaceholderImage ?? this.hasPlaceholderImage,
      storagePath: storagePath ?? this.storagePath,
      publicUrl: publicUrl ?? this.publicUrl,
      fileName: fileName ?? this.fileName,
    );
  }
}

class ImageBlockEditorScreen extends StatefulWidget {
  final String moduleId;
  final ImageBlockData? initialData;

  /// Whether to show the Assessment section. Assessment belongs to the Learning
  /// module; it is hidden when this editor is reused for generic Evidence
  /// (e.g. Prototyping Build/Test logs).
  final bool showAssessment;

  /// Whether to show the Inquiry Lens selector. Like Assessment, it belongs to
  /// the Learning module and is hidden for generic Evidence content blocks.
  final bool showInquiryLens;

  const ImageBlockEditorScreen({
    super.key,
    required this.moduleId,
    this.initialData,
    this.showAssessment = true,
    this.showInquiryLens = true,
  });

  @override
  State<ImageBlockEditorScreen> createState() => _ImageBlockEditorScreenState();
}

class _ImageBlockEditorScreenState extends State<ImageBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _lightBorder = Color(0xFFD8D0D0);
  static const _screenWidth = 393.0;

  late final TextEditingController _titleController;
  late final TextEditingController _captionController;
  late List<ImageBlockItem> _images;
  late List<TextEditingController> _imageControllers;
  late AssessmentBlockData _assessment;
  late InquiryLensData _inquiryLensData;
  final _picker = ImagePicker();
  final _storage = StorageService();
  final Set<int> _uploadingIndexes = {};
  String? _uploadError;
  bool _showValidation = false;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _captionController = TextEditingController(text: data?.caption ?? '');
    _inquiryLensData = data == null
        ? const InquiryLensData()
        : data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data?.assessment ?? const AssessmentBlockData();
    _images = List<ImageBlockItem>.from(
      data?.images.isNotEmpty == true ? data!.images : const [ImageBlockItem()],
    );
    _imageControllers = _images
        .map((image) => TextEditingController(text: image.description))
        .toList();
    _titleController.addListener(_refresh);
    _captionController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _captionController.dispose();
    for (final controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _addImage() {
    if (_images.length >= 10) return;
    setState(() {
      _images.add(const ImageBlockItem());
      _imageControllers.add(TextEditingController());
    });
  }

  void _removeImage(int index) {
    if (_images.length == 1) {
      setState(() {
        _images[0] = const ImageBlockItem();
        _imageControllers[0].clear();
      });
      return;
    }

    setState(() {
      _images.removeAt(index);
      _imageControllers.removeAt(index).dispose();
    });
  }

  void _showUploadSheet(int index) {
    showModalBottomSheet<void>(
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
                  label: 'Open Library',
                  top: true,
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
            'learning-modules/$userId/${widget.moduleId}/concept-exploration/images',
      );
      if (!mounted || index >= _images.length) return;
      setState(() {
        _images[index] = _images[index].copyWith(
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

  void _saveBlock() {
    if (widget.showAssessment && !_assessment.isValid) {
      setState(() => _showValidation = true);
      return;
    }

    Navigator.of(context).pop(
      ImageBlockData(
        title: _titleController.text.trim(),
        caption: _captionController.text.trim(),
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        images: [
          for (var index = 0; index < _images.length; index++)
            _images[index].copyWith(
              description: _imageControllers[index].text.trim(),
            ),
        ],
        assessment: _assessment,
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
            constraints: const BoxConstraints(maxWidth: _screenWidth),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 18, 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel(label: 'Content'),
                        const SizedBox(height: 17),
                        _FieldLabel(label: 'Title', optional: true),
                        const SizedBox(height: 11),
                        _TextFieldBox(
                          controller: _titleController,
                          maxLength: 100,
                          height: 35,
                          singleLine: true,
                        ),
                        const SizedBox(height: 14),
                        _ImagesSection(
                          images: _images,
                          controllers: _imageControllers,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _FieldLabel(label: 'Caption', optional: true),
                        const SizedBox(height: 11),
                        _TextFieldBox(
                          controller: _captionController,
                          maxLength: 300,
                          height: 56,
                          maxLines: 2,
                          hintText: 'Write a caption...',
                        ),
                        if (widget.showInquiryLens) ...[
                          const SizedBox(height: 20),
                          InquiryLensSelector(
                            data: _inquiryLensData,
                            onChanged: (value) =>
                                setState(() => _inquiryLensData = value),
                          ),
                        ],
                        if (widget.showAssessment) ...[
                          const SizedBox(height: 20),
                          _FieldLabel(label: 'Assessment', optional: true),
                          const SizedBox(height: 11),
                          AssessmentBlockSection(
                            value: _assessment,
                            showValidation: _showValidation,
                            onChanged: (value) {
                              setState(() => _assessment = value);
                            },
                          ),
                        ],
                        const SizedBox(height: 26),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _saveBlock,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                _isEditing ? 'Save' : 'Add Block',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 27,
            child: Text(
              'Image Block',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ImageBlockEditorScreenState._text,
                fontSize: 17,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            left: 25,
            top: 23,
            width: 20,
            height: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: const _BackChevron(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFD1D1D1)),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const _FieldLabel({required this.label, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          color: _ImageBlockEditorScreenState._text,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (optional)',
              style: TextStyle(
                color: _ImageBlockEditorScreenState._muted,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _TextFieldBox extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final int? maxLines;
  final bool singleLine;
  final String? hintText;

  const _TextFieldBox({
    required this.controller,
    required this.maxLength,
    required this.height,
    this.maxLines,
    this.singleLine = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + 14,
      child: Stack(
        children: [
          SizedBox(
            height: height,
            child: TextField(
              controller: controller,
              maxLength: maxLength,
              maxLines: singleLine ? 1 : maxLines,
              decoration: InputDecoration(
                counterText: '',
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFFBEBEBE),
                  fontSize: 13,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: singleLine ? 7 : 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: _ImageBlockEditorScreenState._green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: _ImageBlockEditorScreenState._green,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 0,
            child: Text(
              '${controller.text.length}/$maxLength',
              style: const TextStyle(
                color: _ImageBlockEditorScreenState._text,
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagesSection extends StatelessWidget {
  final List<ImageBlockItem> images;
  final List<TextEditingController> controllers;
  final Set<int> uploadingIndexes;
  final VoidCallback onAddImage;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onUpload;

  const _ImagesSection({
    required this.images,
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
              'Images (${images.length} of 10)',
              style: const TextStyle(
                color: _ImageBlockEditorScreenState._text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 120,
              height: 22,
              child: OutlinedButton(
                onPressed: images.length >= 10 ? null : onAddImage,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: _ImageBlockEditorScreenState._text,
                  side: const BorderSide(
                    color: _ImageBlockEditorScreenState._lightBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '+  Add Image',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _ImageBlockEditorScreenState._lightBorder,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              for (var index = 0; index < images.length; index++) ...[
                _ImageRow(
                  index: index,
                  image: images[index],
                  controller: controllers[index],
                  uploading: uploadingIndexes.contains(index),
                  onRemove: () => onRemove(index),
                  onUpload: () => onUpload(index),
                ),
                if (index != images.length - 1)
                  const Divider(
                    height: 1,
                    color: _ImageBlockEditorScreenState._lightBorder,
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
  final ImageBlockItem image;
  final TextEditingController controller;
  final bool uploading;
  final VoidCallback onRemove;
  final VoidCallback onUpload;

  const _ImageRow({
    required this.index,
    required this.image,
    required this.controller,
    required this.uploading,
    required this.onRemove,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Row(
        children: [
          const SizedBox(width: 7),
          _NumberBadge(number: index + 1),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onUpload,
            child: Container(
              width: 106,
              height: 59,
              decoration: BoxDecoration(
                color: image.hasPlaceholderImage
                    ? const Color(0xFFD8F0DF)
                    : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE4E4E4)),
              ),
              alignment: Alignment.center,
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _ImageBlockEditorScreenState._green,
                      ),
                    )
                  : image.publicUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        image.publicUrl,
                        width: 98,
                        height: 51,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : image.hasPlaceholderImage
                  ? Container(
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
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/learning_module/concept_image.svg',
                          width: 30,
                          height: 25,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Click to upload',
                          style: TextStyle(
                            color: Color(0xFFC8C8C8),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
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
                    color: _ImageBlockEditorScreenState._text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 35,
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: _ImageBlockEditorScreenState._green,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(
                          color: _ImageBlockEditorScreenState._green,
                        ),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
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
          const SizedBox(width: 12),
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
        border: Border.all(color: _ImageBlockEditorScreenState._green),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: _ImageBlockEditorScreenState._green,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _DropdownField extends StatelessWidget {
  final String displayValue;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;

  const _DropdownField({
    required this.displayValue,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onSelected,
      offset: const Offset(0, 47),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(value: option, height: 38, child: Text(option)),
      ],
      child: _DropdownShell(label: displayValue),
    );
  }
}

class _DropdownShell extends StatelessWidget {
  final String label;

  const _DropdownShell({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _ImageBlockEditorScreenState._green),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _ImageBlockEditorScreenState._text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: top ? const Radius.circular(12) : Radius.zero,
        bottom: isCancel ? const Radius.circular(12) : Radius.zero,
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 55,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: !top && !isCancel
                ? const Border(top: BorderSide(color: Color(0xFFE5E5E5)))
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isCancel
                  ? const Color(0xFFD12E2E)
                  : _ImageBlockEditorScreenState._text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      size: const Size(12, 20),
      painter: _BackChevronPainter(),
    );
  }
}

class _BackChevronPainter extends CustomPainter {
  const _BackChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ImageBlockEditorScreenState._green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.75, 1)
      ..lineTo(size.width * 0.2, size.height / 2)
      ..lineTo(size.width * 0.75, size.height - 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
