import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'community_project_invitations.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/services/media_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';

// Preset banner colors
const _bannerColors = [
  ('Forest', '#1E4620'),
  ('Navy', '#1A237E'),
  ('Maroon', '#880E4F'),
  ('Teal', '#00695C'),
  ('Slate', '#37474F'),
  ('Indigo', '#283593'),
  ('Burgundy', '#7B1FA2'),
  ('Rust', '#BF360C'),
];

const _subjects = [
  'Environment & Sustainability',
  'Engineering & Design',
  'Energy & Systems',
  'Community & Built Environment',
];

class CommunitySettingsScreen extends StatefulWidget {
  final Community community;

  const CommunitySettingsScreen({super.key, required this.community});

  @override
  State<CommunitySettingsScreen> createState() =>
      _CommunitySettingsScreenState();
}

class _CommunitySettingsScreenState extends State<CommunitySettingsScreen> {
  final _communitiesRepo = CommunitiesRepo();
  final _mediaService = MediaService();
  final _nameController = TextEditingController();

  late String? _imageUrl;
  late String? _selectedVisibility;
  late String? _selectedColorHex;
  String? _activeDomain;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.community.name;
    _imageUrl = widget.community.imageUrl;
    _selectedVisibility = widget.community.visibility.toLowerCase() == 'private'
        ? 'Private'
        : 'Public';
    _selectedColorHex = widget.community.bannerColorHex;
    final existing = widget.community.subjectFocus
        ?.split(RegExp(r'[:|]'))
        .first
        .trim();
    _activeDomain = _subjects.contains(existing) ? existing : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Community Image'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = await _mediaService.pickAndUploadImage(
                ImageSource.camera,
                folder: 'community-images',
              );
              if (mounted && url != null) setState(() => _imageUrl = url);
            },
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = await _mediaService.pickAndUploadImage(
                ImageSource.gallery,
                folder: 'community-images',
              );
              if (mounted && url != null) setState(() => _imageUrl = url);
            },
            child: const Text('Choose from Gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showTopSnackBar(context, 'Community name cannot be empty');
      return;
    }
    setState(() => _isSaving = true);
    final subjectFocus = _activeDomain;

    final ok = await _communitiesRepo.updateCommunity(
      id: widget.community.id,
      name: name,
      imageUrl: _imageUrl,
      visibility: _selectedVisibility?.toLowerCase(),
      subjectFocus: subjectFocus,
      bannerColorHex: _selectedColorHex,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!ok) {
      showTopSnackBar(context, 'Failed to save settings', isError: true);
      return;
    }
    // Return updated community to caller
    final updated = widget.community.copyWith(
      name: name,
      imageUrl: _imageUrl,
      visibility: _selectedVisibility?.toLowerCase(),
      subjectFocus: subjectFocus,
      bannerColorHex: _selectedColorHex,
    );
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  Future<void> _handleDelete() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Community?'),
        content: Text(
          'This will permanently delete "${widget.community.name}", '
          'remove all members, and delete the group chat and all its messages. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _communitiesRepo.deleteCommunity(widget.community);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      showTopSnackBar(context, 'Failed to delete community', isError: true);
      return;
    }

    // Pop settings, then pop community home — back to the home feed
    Navigator.of(context).pop('deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Community Settings', style: AppTypography.pageTitle),
        centerTitle: true,
      ),
      body: PageScrollWithFooter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityProjectInvitationsButton(
                communityId: widget.community.id,
              ),
              const SizedBox(height: 16),
              // ── Image ──────────────────────────────────────────────────────
              Center(
                child: AppTapTarget(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: _selectedColorHex != null
                            ? widget.community
                                  .copyWith(bannerColorHex: _selectedColorHex)
                                  .bannerColor
                            : widget.community.bannerColor,
                        backgroundImage:
                            (_imageUrl != null && _imageUrl!.isNotEmpty)
                            ? NetworkImage(_imageUrl!)
                            : null,
                        child: (_imageUrl == null || _imageUrl!.isEmpty)
                            ? const Icon(
                                Icons.group,
                                size: 32,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Tap to update image',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.helperSize,
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Banner Color ────────────────────────────────────────────────
              _sectionLabel('Banner Color'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _bannerColors.map((entry) {
                  final (label, hex) = entry;
                  final color = Color(
                    int.parse('FF${hex.replaceFirst('#', '')}', radix: 16),
                  );
                  final isSelected =
                      (_selectedColorHex ?? '#1E4620').toUpperCase() ==
                      hex.toUpperCase();
                  return AppTapTarget(
                    onTap: () => setState(() => _selectedColorHex = hex),
                    child: Tooltip(
                      message: label,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Name ────────────────────────────────────────────────────────
              _sectionLabel('Community Name'),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                ),
                decoration: InputDecoration(
                  constraints: const BoxConstraints(minHeight: 64),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              // ── Visibility ──────────────────────────────────────────────────
              _sectionLabel('Visibility'),
              const SizedBox(height: 10),
              PillSelector(
                value: _selectedVisibility,
                placeholder: 'Select',
                items: const ['Public', 'Private'],
                onChanged: (v) => setState(() => _selectedVisibility = v),
              ),
              const SizedBox(height: AppMetrics.fieldGap),

              _sectionLabel('Subject'),
              const SizedBox(height: 10),
              PillSelector(
                value: _activeDomain,
                placeholder: 'Select a subject',
                items: _subjects,
                onChanged: (value) => setState(() => _activeDomain = value),
              ),
              const SizedBox(height: AppMetrics.sectionGap),

              const SizedBox(height: 48),
              SubmitButton(
                label: 'Save Settings',
                isLoading: _isSaving,
                backgroundColor: AppColors.primary,
                onPressed: _saveSettings,
              ),
              const SizedBox(height: AppMetrics.fieldGap),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete Community',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    ),
  );
}

// ── _MemberRow ────────────────────────────────────────────────────────────────

class CommunityMemberSearchDialog extends StatefulWidget {
  const CommunityMemberSearchDialog({super.key, required this.excludeIds});
  final Set<String> excludeIds;

  @override
  State<CommunityMemberSearchDialog> createState() =>
      CommunityMemberSearchDialogState();
}

class CommunityMemberSearchDialogState
    extends State<CommunityMemberSearchDialog> {
  final _controller = TextEditingController();
  final _usersRepo = UsersRepo();
  Timer? _debounce;
  List<UserProfile> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _controller.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _results = []);
        return;
      }
      if (mounted) setState(() => _isSearching = true);
      final all = await _usersRepo.searchPublicUsers(query: q) ?? [];
      final excluded = {
        ...widget.excludeIds,
        if (AuthService.instance.currentUser != null)
          AuthService.instance.currentUser!.id,
      };
      if (mounted) {
        setState(() {
          _results = all.where((u) => !excluded.contains(u.id)).toList();
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AppTapTarget(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Invite Member',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.pageTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 22),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
              ),
              decoration: InputDecoration(
                hintText: '',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 12,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: PageScrollWithFooter(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: _results
                        .map(
                          (u) => ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  (u.avatarUrl != null &&
                                      u.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(u.avatarUrl!)
                                  : null,
                              child:
                                  (u.avatarUrl == null || u.avatarUrl!.isEmpty)
                                  ? const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              u.resolvedDisplayName,
                              style: const TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontWeight: FontWeight.w500,
                                fontSize: AppTypography.bodySize,
                              ),
                            ),
                            subtitle: u.username != null
                                ? Text(
                                    '@${u.username!}',
                                    style: const TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.helperSize,
                                    ),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, u),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
