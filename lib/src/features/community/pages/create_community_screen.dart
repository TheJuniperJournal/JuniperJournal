import '../../../shared/widgets/creation_navigation_guard.dart';
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import '../../../shared/widgets/creation_page_layout.dart';
import '../../../shared/widgets/journal_section_header.dart'
    show JournalPageLayout;
import '../../project/pages/create_project.dart'
    show ProjectMembersSection, ProjectMemberPicker;
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/features/community/pages/community_home_screen.dart';
import 'package:juniper_journal/src/services/media_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';
import 'package:image_picker/image_picker.dart';

const _communitySubjects = [
  (
    'Environment & Sustainability',
    'Understand natural systems, ecosystems, climate, water, and resources to support environmental health.',
    'environment',
  ),
  (
    'Engineering & Design',
    'Design, build, and improve solutions through creativity, prototyping, and problem-solving.',
    'engineering',
  ),
  (
    'Energy & Systems',
    'Explore how energy is produced, used, and optimized through systems thinking and renewable technologies.',
    'energy',
  ),
  (
    'Community & Built Environment',
    'Improve communities and shared spaces through sustainable design, infrastructure, and local action.',
    'community',
  ),
];

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({super.key, this.loadFriends, this.searchPeople});
  final Future<List<UserProfile>> Function()? loadFriends;
  final Future<List<UserProfile>> Function(String)? searchPeople;

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _nameController = TextEditingController();
  final _communitiesRepo = CommunitiesRepo();
  late final _mediaService = MediaService();

  String? _imageUrl;
  String _selectedVisibility = 'public';
  String? _activeDomain;
  List<UserProfile> _pendingMembers = [];
  bool _isCreating = false;
  bool _showValidation = false;
  final _nameKey = GlobalKey();
  final _subjectKey = GlobalKey();
  bool get _missingName => _nameController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_showValidation) setState(() {});
    });
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

  Future<void> _openAddMemberDialog() async {
    final result = await showAppDialog<List<UserProfile>>(
      context: context,
      builder: (_) => ProjectMemberPicker(
        existingMembers: List.from(_pendingMembers),
        loadFriends: widget.loadFriends,
        searchPeople: widget.searchPeople,
      ),
    );
    if (result != null) setState(() => _pendingMembers = result);
  }

  Future<void> _handleCreate() async {
    if (_isCreating) return;
    setState(() => _showValidation = true);
    if (_missingName || _activeDomain == null) {
      final target = _missingName ? _nameKey : _subjectKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && target.currentContext != null) {
          Scrollable.ensureVisible(
            target.currentContext!,
            alignment: 0.15,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
      return;
    }
    final name = _nameController.text.trim();
    setState(() => _isCreating = true);

    try {
      final community = await _communitiesRepo.createCommunity(
        name: name,
        imageUrl: _imageUrl,
        visibility: _selectedVisibility,
        subjectFocus: _activeDomain,
        memberIds: _pendingMembers.map((m) => m.id).toList(),
      );

      if (!mounted) return;
      setState(() => _isCreating = false);

      if (community == null) {
        showTopSnackBar(context, 'Failed to create community', isError: true);
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CommunityHomeScreen(community: community),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      showTopSnackBar(
        context,
        'Failed to create community. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = TextPainter(
      text: const TextSpan(text: 'Ag', style: AppTypography.inputText),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final namePadding = ((64 - line.height) / 2).clamp(0.0, 64.0);
    line.dispose();
    final nameInvalid = _showValidation && _missingName;
    return CreationNavigationGuard(
      fingerprint: () => [
        _nameController.text,
        _imageUrl,
        _selectedVisibility,
        _activeDomain,
        _pendingMembers.map((p) => p.id).join(','),
      ].toString(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CreationPageFrame(
          child: PageScrollWithFooter(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CreationPageHeader(
                    title: 'Create Community',
                    onClose: () => Navigator.of(context).pop(false),
                  ),
                  CreationImagePicker(
                    imageUrl: _imageUrl,
                    onTap: _pickImage,
                    label: 'Update community image',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: JournalPageLayout.horizontalInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Community Name
                        _label('Community Name'),
                        const SizedBox(height: AppMetrics.labelGap),
                        TextField(
                          key: _nameKey,
                          textAlignVertical: TextAlignVertical.center,
                          controller: _nameController,
                          style: AppTypography.inputText,
                          decoration: InputDecoration(
                            constraints: const BoxConstraints(minHeight: 64),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: namePadding,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: nameInvalid
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: nameInvalid
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: nameInvalid
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        if (nameInvalid)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Community name is required',
                              style: AppTypography.requirement,
                            ),
                          ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        _label('Visibility'),
                        const SizedBox(height: AppMetrics.labelGap),
                        _optionCard(
                          title: 'Public',
                          description: 'Visible to everyone.',
                          asset: 'assets/project_setup/visibility_public.svg',
                          selected: _selectedVisibility == 'public',
                          onTap: () =>
                              setState(() => _selectedVisibility = 'public'),
                        ),
                        const SizedBox(height: 12),
                        _optionCard(
                          title: 'Private',
                          description: 'Visible to community members.',
                          asset: 'assets/project_setup/visibility_private.svg',
                          selected: _selectedVisibility == 'private',
                          onTap: () =>
                              setState(() => _selectedVisibility = 'private'),
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        KeyedSubtree(
                          key: _subjectKey,
                          child: _label('Subject'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose the main area your community belongs to.',
                          style: AppTypography.helper,
                        ),
                        if (_showValidation && _activeDomain == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Select a subject.',
                              style: AppTypography.requirement,
                            ),
                          ),
                        const SizedBox(height: 16),
                        for (final subject in _communitySubjects) ...[
                          _optionCard(
                            title: subject.$1,
                            description: subject.$2,
                            asset:
                                'assets/project_setup/subject_${subject.$3}.svg',
                            selected: _activeDomain == subject.$1,
                            showError: _showValidation && _activeDomain == null,
                            onTap: () =>
                                setState(() => _activeDomain = subject.$1),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: AppMetrics.fieldGap),
                        ProjectMembersSection(
                          members: _pendingMembers,
                          onAddPeople: _openAddMemberDialog,
                          onRemoveMember: (person) => setState(
                            () => _pendingMembers.removeWhere(
                              (member) => member.id == person.id,
                            ),
                          ),
                          roles: const {},
                          showRoles: false,
                          canManageRoles: true,
                          onRoleChanged: (_, __) {},
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),

                        // Create button
                        SubmitButton(
                          label: 'Create',
                          isLoading: _isCreating,
                          backgroundColor: AppColors.primary,
                          onPressed: _handleCreate,
                        ),
                      ],
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

  Widget _optionCard({
    required String title,
    required String description,
    required String asset,
    required bool selected,
    required VoidCallback onTap,
    bool showError = false,
  }) => CreationOptionCard(
    title: title,
    description: description,
    asset: asset,
    selected: selected,
    showError: showError,
    onTap: onTap,
  );
  Widget _label(String text) => Text(text, style: AppTypography.fieldLabel);
}
