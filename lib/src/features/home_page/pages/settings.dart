import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/profile_photo_actions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.usersRepo,
    this.email,
    this.uploadProfilePhoto,
  });
  final UsersRepo? usersRepo;
  final String? email;
  final Future<String?> Function(ImageSource)? uploadProfilePhoto;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService.instance;
  late final _usersRepo = widget.usersRepo ?? UsersRepo();

  late final TextEditingController _displayNameController;

  final _bioController = TextEditingController();
  String? _avatarUrl;
  bool _savingBio = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPublicProfile = true;
  bool _savingVisibility = false;
  bool _changingPhoto = false;
  String _email = '';
  String _username = '';

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _usersRepo.getCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _displayNameController.text =
          profile?.displayName?.trim() ?? profile?.username?.trim() ?? '';
      _bioController.text = profile?.bio ?? '';
      _avatarUrl = profile?.avatarUrl;
      _isPublicProfile = profile?.isPublicProfile ?? true;
      _email = widget.email ?? _authService.currentUser?.email ?? '';
      _username = profile?.username?.trim() ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveDisplayName() async {
    final name = _displayNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    final ok = await _usersRepo.updateCurrentUserProfile(displayName: name);
    if (!mounted) return;
    setState(() => _isSaving = false);
    showTopSnackBar(context, ok ? 'Name updated' : 'Failed to update name');
  }

  Future<void> _saveBio() async {
    setState(() => _savingBio = true);
    final ok = await _usersRepo.updateCurrentUserProfile(
      bio: _bioController.text,
    );
    if (!mounted) return;
    setState(() => _savingBio = false);
    showTopSnackBar(
      context,
      ok ? 'Bio updated' : 'Could not save bio. Please try again.',
      isError: !ok,
    );
  }

  Future<void> _toggleVisibility(bool value) async {
    if (_savingVisibility || value == _isPublicProfile) return;
    final previous = _isPublicProfile;
    setState(() {
      _isPublicProfile = value;
      _savingVisibility = true;
    });
    final ok = await _usersRepo.updateCurrentUserProfile(
      isPublicProfile: value,
    );
    if (!mounted) return;
    setState(() {
      if (!ok) _isPublicProfile = previous;
      _savingVisibility = false;
    });
    showTopSnackBar(
      context,
      ok
          ? 'Profile is now ${value ? 'public' : 'private'}'
          : 'Could not update profile visibility',
      isError: !ok,
    );
  }

  Future<void> _changePhoto() async {
    if (_changingPhoto) return;
    await changeProfilePhoto(
      context,
      usersRepo: _usersRepo,
      uploadPhoto: widget.uploadProfilePhoto,
      onUploadStarted: () {
        if (mounted) setState(() => _changingPhoto = true);
      },
    );
    if (mounted) {
      setState(() => _changingPhoto = false);
      await _loadProfile();
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    DesktopShellScope.of(context)?.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JuniperAuthScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account, profile, and all your data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Second confirmation — must type DELETE
    final confirmController = TextEditingController();
    final doubleConfirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Type DELETE to confirm'),
        content: TextField(
          controller: confirmController,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, confirmController.text.trim() == 'DELETE'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    confirmController.dispose();
    if (doubleConfirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    final ok = await _authService.deleteAccount();
    if (!mounted) return;

    if (!ok) {
      setState(() => _isSaving = false);
      showTopSnackBar(
        context,
        'Failed to delete account. Please try again.',
        isError: true,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JuniperAuthScreen()),
      (route) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: AppColors.border,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile settings', style: AppTypography.pageTitle),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PageScrollWithFooter(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _changingPhoto ? null : _changePhoto,
                              customBorder: const CircleBorder(),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundImage: _avatarUrl?.isNotEmpty == true
                                    ? NetworkImage(_avatarUrl!)
                                    : null,
                                child: _avatarUrl?.isNotEmpty == true
                                    ? null
                                    : const Icon(
                                        Icons.person_outline,
                                        size: 40,
                                      ),
                              ),
                            ),
                            TextButton(
                              onPressed: _changingPhoto ? null : _changePhoto,
                              child: const Text('Change profile photo'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _sectionHeader('Profile'),
                      _card([
                        ListTile(
                          title: const Text(
                            'Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black38,
                            ),
                          ),
                          trailing: Text(
                            _email,
                            style: const TextStyle(color: Colors.black38),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: const Text(
                            'Username',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black38,
                            ),
                          ),
                          trailing: Text(
                            _username.isNotEmpty ? '@$_username' : '',
                            style: const TextStyle(color: Colors.black38),
                          ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _displayNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Display Name',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _isSaving ? null : _saveDisplayName,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppMetrics.fieldGap),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _bioController,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 500,
                              decoration: const InputDecoration(
                                labelText: 'Bio',
                                hintText:
                                    'Tell people about yourself and your interests.',
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _savingBio ? null : _saveBio,
                                child: Text(
                                  _savingBio ? 'Saving…' : 'Save bio',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _sectionHeader('Privacy'),
                      _card([
                        const ListTile(
                          title: Text(
                            'Profile visibility',
                            style: AppTypography.fieldLabel,
                          ),
                        ),
                        RadioGroup<bool>(
                          groupValue: _isPublicProfile,
                          onChanged: (value) {
                            if (!_savingVisibility && value != null)
                              _toggleVisibility(value);
                          },
                          child: Column(
                            children: [
                              RadioListTile<bool>(
                                value: true,

                                title: const Text(
                                  'Public',
                                  style: AppTypography.fieldLabel,
                                ),
                                subtitle: const Text(
                                  'Anyone in Juniper can find and view your profile.',
                                  style: AppTypography.helper,
                                ),
                                enabled: !_savingVisibility,
                              ),
                              RadioListTile<bool>(
                                value: false,

                                title: const Text(
                                  'Private',
                                  style: AppTypography.fieldLabel,
                                ),
                                subtitle: const Text(
                                  'Only friends can view your profile. Hidden from people search. Your name and photo remain visible in shared projects and chats.',
                                  style: AppTypography.helper,
                                ),
                                enabled: !_savingVisibility,
                              ),
                            ],
                          ),
                        ),
                        if (_savingVisibility)
                          const LinearProgressIndicator(minHeight: 2),
                      ]),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _sectionHeader('Account'),
                      _card([
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => pushAppRoute(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.logout,
                            color: Colors.black54,
                          ),
                          title: const Text('Sign Out'),
                          onTap: _signOut,
                        ),
                      ]),
                      const SizedBox(height: AppMetrics.fieldGap),
                      _sectionHeader('Danger Zone'),
                      _card([
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever,
                            color: AppColors.error,
                          ),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Permanently remove your account and all data',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.error,
                          ),
                          onTap: _isSaving ? null : _deleteAccount,
                        ),
                      ]),
                    ],
                  ),
                ),
                if (_isSaving)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black12,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
