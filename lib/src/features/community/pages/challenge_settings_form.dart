import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/picked_image_preview.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/shared/widgets/date_time_pickers.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/backend/storage/storage_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ChallengeSettingsForm extends StatefulWidget {
  final DesignChallenge challenge;

  const ChallengeSettingsForm({super.key, required this.challenge});

  @override
  State<ChallengeSettingsForm> createState() => _ChallengeSettingsFormState();
}

class _ChallengeSettingsFormState extends State<ChallengeSettingsForm> {
  final _repo = ChallengesRepo();
  final _storage = StorageService();
  final _picker = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _promptCtrl;
  late String _type;
  late String? _scale;
  late String? _difficulty;
  late DateTime? _startsAt;
  late DateTime? _endsAt;
  late bool _allDay;
  XFile? _newImage;
  bool _saving = false;
  bool _deleting = false;

  static const _types = [
    ('pattern_change', 'Pattern Change'),
    ('community_impact', 'Community Impact'),
    ('build_and_create', 'Build & Create'),
  ];
  static const _scaleOptions = ['Small', 'Medium', 'Large'];
  static const _difficultyOptions = ['Easy', 'Moderate', 'Hard'];

  @override
  void initState() {
    super.initState();
    final c = widget.challenge;
    _nameCtrl = TextEditingController(text: c.name);
    _promptCtrl = TextEditingController(text: c.prompt ?? '');
    _type = c.type;
    _scale = c.scale;
    _difficulty = c.difficulty;
    _startsAt = c.startsAt;
    _endsAt = c.endsAt;
    _allDay = c.allDay;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _newImage = file);
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

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showTopSnackBar(context, 'Challenge name is required');
      return;
    }
    setState(() => _saving = true);
    String? imageUrl = widget.challenge.imageUrl;
    if (_newImage != null) {
      imageUrl = await _storage.uploadImage(
        _newImage!,
        bucketName: 'images',
        folder: 'challenges',
      );
    }
    final ok = await _repo.updateChallengeSettings(
      id: widget.challenge.id,
      type: _type,
      name: name,
      prompt: _promptCtrl.text.trim().isEmpty ? null : _promptCtrl.text.trim(),
      imageUrl: imageUrl,
      scale: _scale,
      difficulty: _difficulty,
      startsAt: _startsAt,
      endsAt: _endsAt,
      allDay: _allDay,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      showTopSnackBar(context, 'Failed to save. Please try again.');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Challenge?'),
        content: const Text(
          'This will permanently delete the challenge and all participant data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final ok = await _repo.deleteChallenge(widget.challenge.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _deleting = false);
      showTopSnackBar(context, 'Failed to delete. Please try again.');
    }
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
    final existingImageUrl = widget.challenge.imageUrl;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Design Challenge Settings',
          style: AppTypography.pageTitle,
        ),
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
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _newImage != null
                    ? PickedImagePreview(file: _newImage!)
                    : (existingImageUrl?.isNotEmpty == true)
                    ? ProtectedImage.network(existingImageUrl!, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: AppColors.primary,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Change Cover Photo',
                            style: TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.bodySize,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            _label('Challenge Type'),
            const SizedBox(height: 10),
            _dropdownPill(
              _types.firstWhere((t) => t.$1 == _type).$2,
              'Type',
              _types.map((t) => t.$2).toList(),
              (label) => setState(
                () => _type = _types.firstWhere((t) => t.$2 == label).$1,
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
            const SizedBox(height: 16),

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

            // Delete button
            AppTapTarget(
              onTap: _deleting ? null : _delete,
              child: Center(
                child: _deleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Text(
                        'Delete Design Challenge',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
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
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
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
