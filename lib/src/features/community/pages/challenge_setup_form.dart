import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/picked_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_requirements_form.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ChallengeSetupForm extends StatefulWidget {
  final String communityId;
  final String type;

  const ChallengeSetupForm({
    super.key,
    required this.communityId,
    required this.type,
  });

  @override
  State<ChallengeSetupForm> createState() => _ChallengeSetupFormState();
}

class _ChallengeSetupFormState extends State<ChallengeSetupForm> {
  final _nameCtrl = TextEditingController();
  final _promptCtrl = TextEditingController();
  final _storage = StorageService();
  final _picker = ImagePicker();

  String? _scale;
  String? _difficulty;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _allDay = false;
  XFile? _imageFile;
  bool _uploading = false;

  static const _scaleOptions = ['Small', 'Medium', 'Large'];
  static const _difficultyOptions = ['Easy', 'Moderate', 'Hard'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit Challenge Creation?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Pop this + the type picker
      Navigator.of(context).pop();
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _imageFile = file);
  }

  Future<void> _pickDateOnly(bool isStart) async {
    final existing = isStart ? _startsAt : _endsAt;
    final result = await showWheelDatePicker(
      context,
      existing ?? DateTime.now(),
    );
    if (result == null) return;
    final h = existing?.hour ?? (isStart ? 8 : 17);
    final m = existing?.minute ?? 0;
    setState(
      () => isStart
          ? _startsAt = DateTime(result.year, result.month, result.day, h, m)
          : _endsAt = DateTime(result.year, result.month, result.day, h, m),
    );
  }

  Future<void> _pickTimeOnly(bool isStart) async {
    final existing = isStart ? _startsAt : _endsAt;
    final rawH = existing?.hour ?? (isStart ? 8 : 17);
    final hour12 = rawH % 12 == 0 ? 12 : rawH % 12;
    final amPm = rawH < 12 ? 'AM' : 'PM';
    final result = await showWheelTimePicker(
      context,
      hour12,
      existing?.minute ?? 0,
      amPm,
    );
    if (result == null) return;
    final h = result['hour'] as int;
    final m = result['minute'] as int;
    final ap = result['amPm'] as String;
    final hour24 = ap == 'AM' ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12);
    final base = existing ?? DateTime.now();
    setState(
      () => isStart
          ? _startsAt = DateTime(base.year, base.month, base.day, hour24, m)
          : _endsAt = DateTime(base.year, base.month, base.day, hour24, m),
    );
  }

  Future<void> _next() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showTopSnackBar(context, 'Please enter a challenge name', isError: true);
      return;
    }
    if (_scale == null) {
      showTopSnackBar(context, 'Please select a scale', isError: true);
      return;
    }
    if (_difficulty == null) {
      showTopSnackBar(
        context,
        'Please select a difficulty level',
        isError: true,
      );
      return;
    }
    if (_endsAt == null) {
      showTopSnackBar(context, 'Please set an end date', isError: true);
      return;
    }
    if (_startsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      showTopSnackBar(
        context,
        'End date must be after start date',
        isError: true,
      );
      return;
    }
    setState(() => _uploading = true);
    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await _storage.uploadImage(
        _imageFile!,
        bucketName: 'images',
        folder: 'challenges',
      );
    }
    if (!mounted) return;
    setState(() => _uploading = false);
    pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeRequirementsForm(
          communityId: widget.communityId,
          type: widget.type,
          name: name,
          prompt: _promptCtrl.text.trim().isEmpty
              ? null
              : _promptCtrl.text.trim(),
          imageUrl: imageUrl,
          scale: _scale,
          difficulty: _difficulty,
          startsAt: _startsAt,
          endsAt: _endsAt,
          allDay: _allDay,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}';
    if (_allDay) return date;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$date $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 28,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Create Design Challenge',
          style: AppTypography.pageTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 22,
              color: AppColors.textSecondary,
            ),
            onPressed: _confirmExit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            AppTapTarget(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageFile != null
                    ? PickedImagePreview(file: _imageFile!)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 36,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Cover Photo',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.buttonSize,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            _label('Design Challenge Name'),
            const SizedBox(height: 10),
            _field(_nameCtrl, 'e.g. Terrarium Project'),
            const SizedBox(height: AppMetrics.fieldGap),

            _label('Design Prompt (100 word limit)'),
            const SizedBox(height: 10),
            TextField(
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              controller: _promptCtrl,
              minLines: 5,
              maxLines: null,
              maxLength: 600,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: AppColors.textPrimary,
              ),
              decoration: _inputDec('Design a... for... with the goal of...'),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            _label('Set Scale'),
            const SizedBox(height: 10),
            _dropdownPill(
              _scale,
              'Scale',
              _scaleOptions,
              (v) => setState(() => _scale = v),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            _label('Set Difficulty'),
            const SizedBox(height: 10),
            _dropdownPill(
              _difficulty,
              'Difficulty',
              _difficultyOptions,
              (v) => setState(() => _difficulty = v),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            _labelGreen('Start'),
            const SizedBox(height: 10),
            _buildDateTimeRow(_startsAt, true),
            const SizedBox(height: AppMetrics.fieldGap),

            _labelGreen('End'),
            const SizedBox(height: 10),
            _buildDateTimeRow(_endsAt, false),
            const SizedBox(height: AppMetrics.fieldGap),

            Row(
              children: [
                _label('All Day'),
                const Spacer(),
                Switch.adaptive(
                  value: _allDay,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => _allDay = v),
                ),
              ],
            ),
            const SizedBox(height: AppMetrics.sectionGap),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _uploading ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _uploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );

  Widget _field(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      color: AppColors.textPrimary,
    ),
    decoration: _inputDec(hint),
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: '',
    hintStyle: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      color: AppColors.hintText,
      fontSize: AppTypography.bodySize,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borderLight),
    ),
  );

  Widget _dropdownPill(
    String? value,
    String hint,
    List<String> options,
    void Function(String) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(
        hint,
        style: TextStyle(
          fontSize: AppTypography.bodySize,
          fontWeight: FontWeight.w500,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        fontSize: AppTypography.bodySize,
        fontWeight: FontWeight.w500,
        color: AppColors.primary,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: AppColors.primary,
        size: 18,
      ),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildDateTimeRow(DateTime? dt, bool isStart) {
    final dateLabel = dt != null
        ? '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}'
        : 'Date';
    final timeLabel = dt != null
        ? () {
            final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final m = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour < 12 ? 'AM' : 'PM';
            return '$h:$m $ampm';
          }()
        : 'Time';
    return Row(
      children: [
        _smallPill(dateLabel, () => _pickDateOnly(isStart)),
        if (!_allDay) ...[
          const SizedBox(width: 8),
          _smallPill(timeLabel, () => _pickTimeOnly(isStart)),
        ],
      ],
    );
  }

  Widget _smallPill(String label, VoidCallback onTap) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _labelGreen(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: AppColors.primary,
    ),
  );
}
