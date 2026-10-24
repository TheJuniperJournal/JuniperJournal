import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/evidence_description_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

enum VideoSourceMode { upload, url }

class VideoBlockData {
  final String id;
  final String title;
  final VideoSourceMode sourceMode;
  final String storagePath;
  final String storageBucket;
  final String signedUrl;
  final String externalUrl;
  final String fileName;
  final String description;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoBlockData({
    required this.id,
    this.title = '',
    this.sourceMode = VideoSourceMode.upload,
    this.storagePath = '',
    this.storageBucket = 'learning-module-videos',
    this.signedUrl = '',
    this.externalUrl = '',
    this.fileName = '',
    this.description = '',
    this.inquiryLens = 'None',
    this.inquiryLensData = const InquiryLensData(),
    this.assessment = const AssessmentBlockData(),
    required this.createdAt,
    required this.updatedAt,
  });

  String get cardSubtitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (description.trim().isNotEmpty) return description.trim();
    return fileName.isNotEmpty ? fileName : externalUrl;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'source_mode': sourceMode.name,
    'storage_path': storagePath,
    'storage_bucket': storageBucket,
    'external_url': externalUrl,
    'file_name': fileName,
    'description': description,
    'inquiry_lens': inquiryLens,
    'inquiry_lens_data': inquiryLensData.toJson(),
    'inquiry': inquiryLensData.toPreviewJson(),
    'assessment_type': assessment.type?.storageValue ?? '',
    'assessment': assessment.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory VideoBlockData.fromJson(Map<String, dynamic> json) {
    final sourceMode = json['source_mode'] == 'url'
        ? VideoSourceMode.url
        : VideoSourceMode.upload;
    return VideoBlockData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      sourceMode: sourceMode,
      storagePath: json['storage_path']?.toString() ?? '',
      storageBucket:
          json['storage_bucket']?.toString() ?? 'learning-module-videos',
      signedUrl: '',
      externalUrl: json['external_url']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      inquiryLens: json['inquiry_lens']?.toString() ?? 'None',
      inquiryLensData: InquiryLensData.fromJson(
        json['inquiry_lens_data'],
        legacyLens: json['inquiry_lens']?.toString() ?? 'None',
      ),
      assessment: _assessmentFromVideoJson(json),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static AssessmentBlockData _assessmentFromVideoJson(
    Map<String, dynamic> json,
  ) {
    final assessment = AssessmentBlockData.fromJson(json['assessment']);
    if (!assessment.isEmpty) return assessment;
    final legacyType = AssessmentType.fromStorage(
      json['assessment_type']?.toString(),
    );
    return legacyType == null
        ? const AssessmentBlockData()
        : AssessmentBlockData(type: legacyType);
  }
}

class VideoBlockEditorScreen extends StatefulWidget {
  final String moduleId;
  final String? projectId;
  final VideoBlockData? initialData;

  const VideoBlockEditorScreen({
    super.key,
    required this.moduleId,
    this.projectId,
    this.initialData,
  });

  @override
  State<VideoBlockEditorScreen> createState() => _VideoBlockEditorScreenState();
}

class _VideoBlockEditorScreenState extends State<VideoBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _error = Color(0xFFFD1212);
  static const _screenWidth = 393.0;
  late String _storageBucket = widget.initialData?.storageBucket ?? _bucket;
  String get _bucket => widget.projectId == null
      ? 'learning-module-videos'
      : 'journal-attachments';

  final _picker = ImagePicker();
  final _storage = StorageService();
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _descriptionController;
  late VideoSourceMode _mode;
  String _storagePath = '';
  String _signedUrl = '';
  String _fileName = '';
  late InquiryLensData _inquiryLensData;
  AssessmentBlockData _assessment = const AssessmentBlockData();
  String? _uploadError;
  bool _uploading = false;
  bool _saving = false;
  bool _showValidation = false;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _urlController = TextEditingController(text: data?.externalUrl ?? '');
    _descriptionController = TextEditingController(
      text: data?.description ?? '',
    );
    _mode = data?.sourceMode ?? VideoSourceMode.upload;
    _storagePath = data?.storagePath ?? '';
    _fileName = data?.fileName ?? '';
    _inquiryLensData = data == null
        ? const InquiryLensData()
        : data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data?.assessment ?? const AssessmentBlockData();
    _titleController.addListener(_refresh);
    _urlController.addListener(_refresh);
    _descriptionController.addListener(_refresh);
    if (_storagePath.isNotEmpty) _restoreSignedUrl();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _validUrl {
    final uri = Uri.tryParse(_urlController.text.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool get _hasRequiredVideo => _mode == VideoSourceMode.upload
      ? _storagePath.isNotEmpty && !_uploading
      : _validUrl;

  Future<void> _restoreSignedUrl() async {
    try {
      final url = await _storage.createSignedUrl(
        _storagePath,
        bucketName: _storageBucket,
      );
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {
      if (mounted) setState(() => _signedUrl = '');
    }
  }

  Future<void> _pickAndUploadVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final userId = SupabaseDatabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _uploadError = 'Sign in before uploading a video.');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
      _fileName = picked.name;
    });
    try {
      final uploaded = await _storage.uploadVideo(
        picked,
        bucketName: _bucket,
        folder: widget.projectId == null
            ? '$userId/${widget.moduleId}'
            : '${widget.projectId}/video/${widget.moduleId}',
      );
      if (!mounted) return;
      setState(() {
        _storagePath = uploaded.path;
        _storageBucket = _bucket;
        _signedUrl = uploaded.signedUrl;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storagePath = '';
        _signedUrl = '';
        _uploadError = 'Video upload failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeVideo() {
    setState(() {
      if (_mode == VideoSourceMode.upload) {
        _storagePath = '';
        _signedUrl = '';
        _fileName = '';
      } else {
        _urlController.clear();
      }
      _uploadError = null;
    });
  }

  void _save() {
    setState(() => _showValidation = true);
    if (!_hasRequiredVideo || _saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final initial = widget.initialData;
    Navigator.of(context).pop(
      VideoBlockData(
        id: initial?.id.isNotEmpty == true
            ? initial!.id
            : '${now.microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        sourceMode: _mode,
        storagePath: _mode == VideoSourceMode.upload ? _storagePath : '',
        storageBucket: _storageBucket,
        signedUrl: _mode == VideoSourceMode.upload ? _signedUrl : '',
        externalUrl: _mode == VideoSourceMode.url
            ? _urlController.text.trim()
            : '',
        fileName: _mode == VideoSourceMode.upload ? _fileName : '',
        description: _descriptionController.text.trim(),
        inquiryLens: _inquiryLensData.selectedLens,
        inquiryLensData: _inquiryLensData,
        assessment: _assessment,
        createdAt: initial?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showError = _showValidation && !_hasRequiredVideo;
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Content'),
                        const SizedBox(height: AppMetrics.labelGap),
                        const _Label('Title', optional: true),
                        const SizedBox(height: 11),
                        _InputBox(
                          controller: _titleController,
                          maxLength: 100,
                          height: 64,
                        ),
                        const SizedBox(height: AppMetrics.labelGap),
                        Center(
                          child: _ModeControl(
                            mode: _mode,
                            onChanged: (mode) => setState(() => _mode = mode),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_mode == VideoSourceMode.url) ...[
                          const _Label('Video URL'),
                          const SizedBox(height: 10),
                          _InputBox(
                            controller: _urlController,
                            maxLength: 2000,
                            height: 35,
                            showCounter: false,
                            error: showError && !_validUrl,
                          ),
                          const SizedBox(height: AppMetrics.labelGap),
                        ],
                        _VideoPreview(
                          mode: _mode,
                          validUrl: _validUrl,
                          url: _urlController.text.trim(),
                          fileName: _fileName,
                          uploading: _uploading,
                          hasUpload: _storagePath.isNotEmpty,
                          error: showError,
                          onPick: _pickAndUploadVideo,
                        ),
                        if (_uploadError != null) ...[
                          const SizedBox(height: 7),
                          Text(
                            _uploadError!,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _error,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ] else if (showError) ...[
                          const SizedBox(height: 7),
                          Text(
                            _mode == VideoSourceMode.upload
                                ? 'Upload a video before adding this block.'
                                : 'Enter a valid http or https video URL.',
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _error,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _SmallButton(
                              label: 'Remove',
                              color: _error,
                              onTap: _removeVideo,
                            ),
                            _SmallButton(
                              label: 'Replace',
                              color: _green,
                              onTap: _mode == VideoSourceMode.upload
                                  ? _pickAndUploadVideo
                                  : () {
                                      _urlController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset:
                                            _urlController.text.length,
                                      );
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        const _Label('Description', optional: true),
                        const SizedBox(height: 11),
                        _InputBox(
                          controller: _descriptionController,
                          maxLength: 300,
                          height: 56,
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        const SizedBox(height: AppMetrics.sectionGap),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _hasRequiredVideo && !_saving
                                  ? _save
                                  : null,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _green,
                                disabledBackgroundColor: const Color(
                                  0xFFB8D8C1,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                _saving
                                    ? 'Saving...'
                                    : (_isEditing ? 'Save' : 'Add Block'),
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.buttonSize,
                                  fontWeight: FontWeight.w500,
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
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) =>
      EvidenceBlockHeader(title: 'Video Block', onBack: onBack);
}

class _Label extends StatelessWidget {
  final String text;
  final bool optional;
  const _Label(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _VideoBlockEditorScreenState._text,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(color: _VideoBlockEditorScreenState._muted),
            ),
        ],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final double height;
  final int maxLines;
  final bool showCounter;
  final bool error;

  const _InputBox({
    required this.controller,
    required this.maxLength,
    required this.height,
    this.maxLines = 1,
    this.showCounter = true,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    if (maxLines > 1) return EvidenceDescriptionField(controller: controller);
    return SizedBox(
      height: height + (showCounter ? 14 : 0),
      child: Stack(
        children: [
          SizedBox(
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
              maxLines: maxLines,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: error
                        ? _VideoBlockEditorScreenState._error
                        : _VideoBlockEditorScreenState._green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide(
                    color: error
                        ? _VideoBlockEditorScreenState._error
                        : _VideoBlockEditorScreenState._green,
                  ),
                ),
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
              ),
            ),
          ),
          if (showCounter)
            Positioned(right: 4, bottom: 0, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _ModeControl extends StatelessWidget {
  final VideoSourceMode mode;
  final ValueChanged<VideoSourceMode> onChanged;
  const _ModeControl({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 234,
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          for (final option in VideoSourceMode.values)
            Expanded(
              child: AppTapTarget(
                onTap: () => onChanged(option),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == mode
                        ? const Color(0xFFDDEEE3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option == VideoSourceMode.upload
                        ? 'Upload Video'
                        : 'Video URL',
                    style: TextStyle(
                      color: option == mode
                          ? _VideoBlockEditorScreenState._text
                          : const Color(0xFF777777),
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  final VideoSourceMode mode;
  final bool validUrl;
  final String url;
  final String fileName;
  final bool uploading;
  final bool hasUpload;
  final bool error;
  final VoidCallback onPick;

  const _VideoPreview({
    required this.mode,
    required this.validUrl,
    required this.url,
    required this.fileName,
    required this.uploading,
    required this.hasUpload,
    required this.error,
    required this.onPick,
  });

  String? get _youtubeThumbnail {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    String? id;
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else if (uri.host.contains('youtube.com')) {
      id = uri.queryParameters['v'];
      if (id == null && uri.pathSegments.contains('embed')) {
        final index = uri.pathSegments.indexOf('embed');
        if (index + 1 < uri.pathSegments.length) {
          id = uri.pathSegments[index + 1];
        }
      }
    }
    return id == null || id.isEmpty
        ? null
        : 'https://img.youtube.com/vi/$id/hqdefault.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = mode == VideoSourceMode.url && validUrl
        ? _youtubeThumbnail
        : null;
    return AppTapTarget(
      onTap: mode == VideoSourceMode.upload && !uploading ? onPick : null,
      child: Container(
        width: double.infinity,
        height: mode == VideoSourceMode.url ? 197 : 155,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: error
                ? _VideoBlockEditorScreenState._error
                : const Color(0xFFE4E4E4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: uploading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF5DB075)),
                    SizedBox(height: 12),
                    Text('Uploading video...'),
                  ],
                ),
              )
            : thumbnail != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ProtectedImage.network(
                    thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _UrlPreviewPlaceholder(),
                  ),
                ],
              )
            : mode == VideoSourceMode.url && validUrl
            ? const _UrlPreviewPlaceholder()
            : hasUpload
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/learning_module/concept_video.svg',
                      width: 48,
                      height: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/learning_module/concept_image.svg',
                      width: 68,
                      height: 55,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Click to add\nvideos',
                      textAlign: TextAlign.center,
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
    );
  }
}

class _UrlPreviewPlaceholder extends StatelessWidget {
  const _UrlPreviewPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 54, height: 36, child: _VideoUrlIcon()),
          const SizedBox(height: 8),
          const Text(
            'Video URL',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _VideoUrlIcon extends StatelessWidget {
  const _VideoUrlIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/learning_module/concept_video.svg');
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 22,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: color,
          side: BorderSide(color: color),
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
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem(value: option, child: Text(option)),
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
        border: Border.all(color: _VideoBlockEditorScreenState._green),
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
