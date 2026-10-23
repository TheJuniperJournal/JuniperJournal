import '../../../shared/widgets/evidence_description_field.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_block_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/features/learning_module/pages/assessment_block.dart';
import 'package:juniper_journal/src/features/learning_module/pages/inquiry_lens_selector.dart';

class LinkBlockData {
  final String id;
  final String title;
  final String url;
  final String description;
  final String inquiryLens;
  final InquiryLensData inquiryLensData;
  final AssessmentBlockData assessment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LinkBlockData({
    required this.id,
    this.title = '',
    this.url = '',
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
    return url;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'description': description,
    'inquiry_lens': inquiryLens,
    'inquiry_lens_data': inquiryLensData.toJson(),
    'inquiry': inquiryLensData.toPreviewJson(),
    'assessment': assessment.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory LinkBlockData.fromJson(Map<String, dynamic> json) {
    return LinkBlockData(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      inquiryLens: json['inquiry_lens']?.toString() ?? 'None',
      inquiryLensData: InquiryLensData.fromJson(
        json['inquiry_lens_data'],
        legacyLens: json['inquiry_lens']?.toString() ?? 'None',
      ),
      assessment: AssessmentBlockData.fromJson(json['assessment']),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class LinkBlockEditorScreen extends StatefulWidget {
  final LinkBlockData? initialData;

  const LinkBlockEditorScreen({super.key, this.initialData});

  @override
  State<LinkBlockEditorScreen> createState() => _LinkBlockEditorScreenState();
}

class _LinkBlockEditorScreenState extends State<LinkBlockEditorScreen> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF141414);
  static const _muted = Color(0xFFCECECE);
  static const _error = Color(0xFFFD1212);
  static const _screenWidth = 393.0;

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _descriptionController;
  late InquiryLensData _inquiryLensData;
  AssessmentBlockData _assessment = const AssessmentBlockData();
  bool _showValidation = false;
  bool _saving = false;

  bool get _isEditing => widget.initialData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '')
      ..addListener(_refresh);
    _urlController = TextEditingController(text: data?.url ?? '')
      ..addListener(_refresh);
    _descriptionController = TextEditingController(
      text: data?.description ?? '',
    )..addListener(_refresh);
    _inquiryLensData = data == null
        ? const InquiryLensData()
        : data.inquiryLensData.selectLens(data.inquiryLens);
    _assessment = data?.assessment ?? const AssessmentBlockData();
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

  void _removeLink() {
    setState(() {
      _urlController.clear();
      _showValidation = false;
    });
  }

  void _save() {
    setState(() => _showValidation = true);
    if (!_validUrl || _saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final initial = widget.initialData;
    Navigator.of(context).pop(
      LinkBlockData(
        id: initial?.id.isNotEmpty == true
            ? initial!.id
            : '${now.microsecondsSinceEpoch}',
        title: _titleController.text.trim(),
        url: _urlController.text.trim(),
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
    final showUrlError = _showValidation && !_validUrl;
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
                    padding: const EdgeInsets.fromLTRB(24, 23, 23, 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Label('Content'),
                        const SizedBox(height: AppMetrics.labelGap),
                        _Label('Title', optional: true),
                        const SizedBox(height: 10),
                        _InputBox(
                          controller: _titleController,
                          maxLength: 100,
                          height: 64,
                        ),
                        const SizedBox(height: 10),
                        const _Label('URL'),
                        const SizedBox(height: 10),
                        _InputBox(
                          controller: _urlController,
                          maxLength: 2000,
                          height: 34,
                          showCounter: false,
                          error: showUrlError,
                        ),
                        if (showUrlError) ...[
                          if (_validUrl)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final opened = await launchUrl(
                                    Uri.parse(_urlController.text.trim()),
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (!opened && context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not open this link.',
                                        ),
                                      ),
                                    );
                                },
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Open Link'),
                              ),
                            ),
                          const SizedBox(height: 7),
                          const Text(
                            'Enter a valid http or https URL.',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              color: _error,
                              fontSize: AppTypography.helperSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppMetrics.sectionGap),
                        _LinkPreview(
                          title: _titleController.text.trim(),
                          url: _urlController.text.trim(),
                          description: _descriptionController.text.trim(),
                          validUrl: _validUrl,
                        ),
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _SmallButton(
                              label: 'Remove',
                              color: const Color(0xFFE21704),
                              fill: const Color(0x33E21704),
                              onTap: _removeLink,
                            ),
                            _SmallButton(
                              label: 'Replace',
                              color: _green,
                              fill: Colors.white,
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: AppMetrics.sectionGap),
                        _Label('Description', optional: true),
                        const SizedBox(height: 10),
                        _InputBox(
                          controller: _descriptionController,
                          maxLength: 300,
                          height: 56,
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        const SizedBox(height: 44),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 32,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: _green,
                                disabledBackgroundColor: const Color(
                                  0xFFB8D8C1,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
      EvidenceBlockHeader(title: 'Link Block', onBack: onBack);
}

class _Label extends StatelessWidget {
  final String label;
  final bool optional;

  const _Label(this.label, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: _LinkBlockEditorScreenState._text,
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _LinkBlockEditorScreenState._muted,
                fontSize: AppTypography.helperSize,
              ),
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
      height: height + (showCounter ? 13 : 0),
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
              textAlignVertical: maxLines == 1
                  ? TextAlignVertical.center
                  : TextAlignVertical.top,
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.fromLTRB(
                  12,
                  maxLines == 1 ? 0 : 9,
                  12,
                  8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(
                    color: error
                        ? _LinkBlockEditorScreenState._error
                        : _LinkBlockEditorScreenState._green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide(
                    color: error
                        ? _LinkBlockEditorScreenState._error
                        : _LinkBlockEditorScreenState._green,
                  ),
                ),
              ),
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _LinkBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showCounter)
            Positioned(right: 0, bottom: 0, child: const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _LinkPreview extends StatelessWidget {
  final String title;
  final String url;
  final String description;
  final bool validUrl;

  const _LinkPreview({
    required this.title,
    required this.url,
    required this.description,
    required this.validUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 175,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: validUrl ? Colors.white : const Color(0x05000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x1A000000),
          style: validUrl ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: validUrl
          ? Row(
              children: [
                const SizedBox(width: 18),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EC),
                    borderRadius: BorderRadius.circular(56),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/learning_module/concept_link.svg',
                    width: 56,
                    height: 28,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? Uri.tryParse(url)?.host ?? url : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textPrimary,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description.isEmpty ? 'Website link' : description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: AppColors.textSecondary,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
            )
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MutedLinkIcon(),
                SizedBox(height: 12),
                Text(
                  'Provide a link to\nsee preview.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x33000000),
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }
}

class _MutedLinkIcon extends StatelessWidget {
  const _MutedLinkIcon();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.2,
      child: SvgPicture.asset(
        'assets/learning_module/concept_link.svg',
        width: 58,
        height: 36,
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color fill;
  final VoidCallback onTap;

  const _SmallButton({
    required this.label,
    required this.color,
    required this.fill,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: label == 'Replace' ? 92 : 85,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: color,
            fontSize: AppTypography.buttonSize,
            height: 1,
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
      tooltip: '',
      initialValue: value,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            height: 38,
            child: Text(
              option,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _LinkBlockEditorScreenState._text,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _LinkBlockEditorScreenState._green),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayValue,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _LinkBlockEditorScreenState._text,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: _LinkBlockEditorScreenState._green,
            ),
          ],
        ),
      ),
    );
  }
}
