import '../../../shared/widgets/creation_navigation_guard.dart';
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import '../../home_page/pages/public_user_profile.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/project_photo_dialog.dart';
import 'dart:typed_data';
import '../../../backend/security/input_validator.dart';
import '../../../shared/widgets/creation_page_layout.dart';
import '../../../shared/widgets/journal_section_header.dart'
    show JournalPageLayout;
import 'package:juniper_journal/src/shared/widgets/optional_field_label.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/item_action_menu.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'shared_visibility_picker.dart';
import 'dart:async';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/services/media_service.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';

const _projectSetupGreen = Color(0xFF5DB075);
const _projectSetupText = Color(0xFF1C1C1C);
const _projectSetupObjectiveBorder = Color(0x33000000);
const _projectSetupError = Color(0xFFFD1212);

const _objectiveActions = ['Analyze', 'Evaluate', 'Design', 'Explore'];

const _subjectOptions = [
  _ProjectSetupOption(
    label: 'Environment & Sustainability',
    value: 'Environment & Sustainability',
    description:
        'Understand natural systems, ecosystems, climate, water, '
        'and resources to support environmental health.',
    asset: 'assets/project_setup/subject_environment.svg',
  ),
  _ProjectSetupOption(
    label: 'Engineering & Design',
    value: 'Engineering & Design',
    description:
        'Design, build, and improve solutions through creativity, '
        'prototyping, and problem-solving.',
    asset: 'assets/project_setup/subject_engineering.svg',
  ),
  _ProjectSetupOption(
    label: 'Energy & Systems',
    value: 'Energy & Systems',
    description:
        'Explore how energy is produced, used, and optimized through '
        'systems thinking and renewable technologies.',
    asset: 'assets/project_setup/subject_energy.svg',
  ),
  _ProjectSetupOption(
    label: 'Community & Built Environment',
    value: 'Community & Built Environment',
    description:
        'Improve communities and shared spaces through sustainable design, '
        'infrastructure, and local action.',
    asset: 'assets/project_setup/subject_community.svg',
  ),
];

const _difficultyOptions = [
  _ProjectSetupOption(
    label: 'Easy',
    value: 'Easy',
    asset: 'assets/learning_module/easy.svg',
    iconWidth: 23,
    iconHeight: 19,
  ),
  _ProjectSetupOption(
    label: 'Moderate',
    value: 'Moderate',
    asset: 'assets/learning_module/med.svg',
    iconWidth: 46,
    iconHeight: 25,
  ),
  _ProjectSetupOption(
    label: 'Hard',
    value: 'Hard',
    asset: 'assets/learning_module/hard.svg',
    iconWidth: 45,
    iconHeight: 34,
  ),
];

const _scaleOptions = [
  _ProjectSetupOption(
    label: 'Small',
    value: 'Small',
    asset: 'assets/project_setup/scale_small.svg',
    iconWidth: 37,
    iconHeight: 37,
  ),
  _ProjectSetupOption(
    label: 'Medium',
    value: 'Medium',
    asset: '',
    iconWidth: 35,
    iconHeight: 32,
  ),
  _ProjectSetupOption(
    label: 'Large',
    value: 'Large',
    asset: '',
    iconWidth: 19,
    iconHeight: 44,
  ),
];

const _visibilityOptions = [
  _ProjectSetupOption(
    label: 'Private',
    description: 'Visible to project members and linked communities.',
    value: 'Private',
    asset: '',
    iconWidth: 29.33333396911621,
    iconHeight: 29.33333396911621,
  ),
  _ProjectSetupOption(
    label: 'Shared',
    description: 'Also visible to selected friends and communities.',
    value: 'Friends',
    asset: 'assets/project_setup/visibility_friends_full.svg',
    iconWidth: 41,
    iconHeight: 37,
  ),
  _ProjectSetupOption(
    label: 'Public',
    description: 'Visible to everyone.',
    value: 'Public',
    asset: '',
    iconWidth: 40,
    iconHeight: 22,
  ),
];

class CreateProjectScreen extends StatefulWidget {
  final Project? existingProject;
  final Community? initialCommunity;
  final ProjectsRepo? projectsRepo;
  final Future<void> Function(BuildContext context)? onDelete;
  final List<ProjectObjectiveSummary> initialObjectives;
  final String? challengeId;
  final String? lockedDifficulty;
  final String? lockedScale;

  const CreateProjectScreen({
    super.key,
    this.existingProject,
    this.initialCommunity,
    this.projectsRepo,
    this.onDelete,
    this.initialObjectives = const [],
    this.challengeId,
    this.lockedDifficulty,
    this.lockedScale,
  });

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _problemController = TextEditingController();
  late final _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
  late final _mediaService = MediaService();
  final List<_ObjectiveRowData> _objectiveRows = [];

  String? _selectedSubject;
  String? _selectedDifficulty;
  String? _selectedScale;
  String? _selectedVisibility;
  SharedProjectAudience _sharedAudience = const SharedProjectAudience();
  String? _projectImageUrl;
  Uint8List? _projectImagePreview;
  Project? _createdProject;
  List<UserProfile> _pendingMembers = [];
  String? _projectType;
  bool _showSetupValidation = false;
  UserProfile? _projectOwner;
  List<Map<String, dynamic>> _communityLinks = [];
  final Set<String> _initialMemberIds = {};
  final Map<String, String> _memberRoles = {};
  final Map<String, String> _initialMemberRoles = {};
  bool _canManageRoles = true;
  bool _loadingMembers = false;
  bool _memberLoadError = false;
  bool _isCreating = false;
  bool _isUploadingImage = false;
  bool _showObjectiveValidation = false;

  final _validationKeys = <String, GlobalKey>{
    for (final field in [
      'name',
      'type',
      'members',
      'problem',
      'subject',
      'difficulty',
      'scale',
      'visibility',
      'objectives',
    ])
      field: GlobalKey(),
  };

  Map<String, String> get _setupErrors => {
    if (InputValidator.projectName(_nameController.text)
        case final String error)
      'name': error,
    if (_projectType == null) 'type': 'Choose a project type.',
    if (_needsCollaborator) 'members': 'Add at least one other member.',
    if (InputValidator.problemStatement(_problemController.text)
        case final String error)
      'problem': error,
    if (_selectedSubject == null) 'subject': 'Select a subject.',
    if (_selectedDifficulty == null) 'difficulty': 'Select a difficulty level.',
    if (_selectedScale == null) 'scale': 'Select a project scale.',
    if (_selectedVisibility == null)
      'visibility': 'Select a visibility setting.',
    if (_objectiveRows.isEmpty || _objectiveRows.any((row) => !row.isComplete))
      'objectives': 'Complete at least one learning objective.',
  };

  Widget _validatedField(String field, Widget child) {
    final error = _showSetupValidation ? _setupErrors[field] : null;
    final textInput = field == 'name' || field == 'problem';
    final showMessage =
        error != null && !{'type', 'members', 'objectives'}.contains(field);
    Widget message() => Padding(
      padding: EdgeInsets.only(
        top: textInput ? 6 : 0,
        bottom: textInput ? 0 : 8,
      ),
      child: Text(error!, style: AppTypography.requirement),
    );
    return Column(
      key: _validationKeys[field],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showMessage && !textInput) message(),
        SizedBox(width: double.infinity, child: child),
        if (showMessage && textInput) message(),
      ],
    );
  }

  void _refreshValidation() {
    if (_showSetupValidation && mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshValidation);
    _problemController.addListener(_refreshValidation);
    _loadProjectOwner();
    final project = widget.existingProject;
    if (project != null) {
      _projectType = project.projectType;
      _sharedAudience = SharedProjectAudience(
        friends: project.shareFriends,
        communityIds: project.sharedCommunityIds.toSet(),
      );
      _communityLinks = project.communityLinks
          .map((link) => Map<String, dynamic>.from(link))
          .toList();
      _loadSetupMembers(project.id);
      _nameController.text = project.projectName;
      _problemController.text = project.problemStatement ?? '';
      _selectedSubject = project.tags.isEmpty
          ? null
          : project.tags.first.split('|').first.trim();
      _selectedVisibility = project.visibility == 'Community Only'
          ? 'Friends'
          : project.visibility;
      _projectImageUrl = project.imageUrl;
      final objectives = project.learningObjectives.isNotEmpty
          ? project.learningObjectives
                .map(
                  (item) => ProjectObjectiveSummary(
                    action: item['action']?.toString() ?? '',
                    subject: item['subject']?.toString() ?? '',
                    description: item['description']?.toString() ?? '',
                  ),
                )
                .toList()
          : widget.initialObjectives;
      for (final objective in objectives) {
        _objectiveRows.add(
          _ObjectiveRowData(
            objectiveType: objective.action,
            subjectDomain: objective.subject,
            description: objective.description,
          ),
        );
      }
    }
    if (project == null && widget.initialCommunity != null) {
      final community = widget.initialCommunity!;
      _communityLinks = [
        {
          'id': community.id,
          'name': community.name,
          'imageUrl': community.imageUrl,
          'description': community.subjectFocus,
          'role': 'home',
        },
      ];
    }
    _selectedDifficulty = widget.lockedDifficulty ?? project?.difficulty;
    _selectedScale = widget.lockedScale ?? project?.projectScale;
    if (widget.challengeId != null) {
      _selectedVisibility = 'Friends';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _problemController.dispose();
    for (final row in _objectiveRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _selectSubject(String value) {
    setState(() => _selectedSubject = value);
  }

  Future<void> _pickProjectImage(ImageSource source) async {
    if (_isUploadingImage) return;
    final previousPreview = _projectImagePreview;
    setState(() => _isUploadingImage = true);
    final imageUrl = await _mediaService.pickAndUploadImage(
      source,
      folder: 'project-images',
      onSelected: (bytes) {
        if (mounted) setState(() => _projectImagePreview = bytes);
      },
    );
    if (!mounted) return;
    setState(() {
      if (imageUrl != null)
        _projectImageUrl = imageUrl;
      else
        _projectImagePreview = previousPreview;
      _isUploadingImage = false;
    });
  }

  Future<void> _showImageSourceSheet() async {
    if (MediaService.usesDesktopImageUpload) {
      await _pickProjectImage(ImageSource.gallery);
      return;
    }
    final source = await showProjectPhotoDialog(
      context,
      onRemove: _projectImageUrl != null && _projectImageUrl!.isNotEmpty
          ? () => setState(() {
              _projectImageUrl = null;
              _projectImagePreview = null;
            })
          : null,
    );
    if (source != null && mounted) await _pickProjectImage(source);
  }

  void _addObjective() {
    if (_objectiveRows.length >= 4) return;
    setState(() {
      _objectiveRows.add(
        _ObjectiveRowData(
          objectiveType: null,
          subjectDomain: null,
          description: '',
        ),
      );
    });
  }

  void _removeObjective(int index) {
    if (index < 0 || index >= _objectiveRows.length) return;
    setState(() {
      final row = _objectiveRows.removeAt(index);
      row.dispose();
    });
  }

  Future<void> _loadProjectOwner() async {
    try {
      final repo = UsersRepo();
      final ownerId = widget.existingProject?.userId;
      final people = ownerId != null && ownerId.isNotEmpty
          ? await repo.getProfilesByIds([ownerId])
          : <UserProfile>[];
      final owner = ownerId != null && ownerId.isNotEmpty
          ? (people.isNotEmpty ? people.first : null)
          : await repo.getCurrentUserProfile();
      if (mounted) setState(() => _projectOwner = owner);
    } catch (e) {
      debugPrint('Could not load project creator: $e');
    }
  }

  Future<void> _loadSetupMembers(String id) async {
    _loadingMembers = true;
    final people = await _projectsRepo.getProjectInvitees(projectId: id);
    final roles = await _projectsRepo.getProjectMemberRoles(id);
    final canManage = await _projectsRepo.canManageProject(id);
    if (!mounted) return;
    setState(() {
      _memberLoadError = people == null;
      _canManageRoles = canManage;
      _memberRoles.addAll(roles);
      _initialMemberRoles.addAll(roles);
      _pendingMembers = people ?? [];
      _initialMemberIds.addAll((people ?? []).map((person) => person.id));
      _loadingMembers = false;
    });
  }

  Future<bool> _syncSetupMembers(String projectId) async {
    final desired = _projectType == 'collaborative'
        ? _pendingMembers.map((person) => person.id).toSet()
        : <String>{};
    var ok = true;
    for (final id in _initialMemberIds.difference(desired)) {
      final removed = await _projectsRepo.removeCollaborator(
        projectId: projectId,
        userId: id,
      );
      if (removed) {
        _initialMemberIds.remove(id);
      } else {
        ok = false;
      }
    }
    for (final id in desired.difference(_initialMemberIds)) {
      final invited = await _projectsRepo.inviteCollaborator(
        projectId: projectId,
        userId: id,
        role: _memberRoles[id] ?? 'project_member',
      );
      if (invited) {
        _initialMemberIds.add(id);
      } else {
        ok = false;
      }
    }
    for (final id in desired.intersection(_initialMemberIds)) {
      final role = _memberRoles[id] ?? 'project_member';
      if (role != (_initialMemberRoles[id] ?? 'project_member')) {
        if (await _projectsRepo.setProjectMemberRole(projectId, id, role)) {
          _initialMemberRoles[id] = role;
        } else {
          ok = false;
        }
      }
    }
    return ok;
  }

  bool get _needsCollaborator =>
      _projectType == 'collaborative' &&
      !_pendingMembers.any(
        (person) =>
            person.id != (_projectOwner?.id ?? widget.existingProject?.userId),
      );

  Future<void> _chooseVisibility(String visibility) async {
    if (_projectType == null) {
      setState(() => _showSetupValidation = true);
      return;
    }
    if (visibility != 'Friends') {
      setState(() => _selectedVisibility = visibility);
      return;
    }
    final audience = await showAppDialog<SharedProjectAudience>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SharedVisibilityPicker(
        projectType: _projectType!,
        linkedCommunities: _communityLinks,
        initial: _sharedAudience,
      ),
    );
    if (mounted && audience != null) {
      setState(() {
        _selectedVisibility = visibility;
        _sharedAudience = audience;
      });
    }
  }

  Future<void> _openCommunities() async {
    final result = await showAppDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => ProjectCommunityPicker(initial: _communityLinks),
    );
    if (result != null && mounted) setState(() => _communityLinks = result);
  }

  Future<void> _openAddMemberDialog() async {
    final result = await showAppDialog<List<UserProfile>>(
      context: context,
      builder: (_) => ProjectMemberPicker(
        existingMembers: List.from(_pendingMembers),
        communityIds: _communityLinks
            .map((link) => link['id'].toString())
            .toSet()
            .toList(),
      ),
    );
    if (result != null) {
      setState(() => _pendingMembers = result);
    }
  }

  Future<void> _handleCreate() async {
    await _persistProjectAndOpenDashboard();
  }

  Future<void> _persistProjectAndOpenDashboard() async {
    if (_isCreating) return;
    if (_loadingMembers) {
      _snack('Project members are still loading. Please wait and try again.');
      return;
    }
    if (_memberLoadError) {
      _snack(
        'Project members could not be loaded. Please reopen settings and try again.',
      );
      return;
    }
    setState(() {
      _showSetupValidation = true;
      _showObjectiveValidation = true;
    });
    final errors = _setupErrors;
    if (errors.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _validationKeys[errors.keys.first]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.15,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
      return;
    }
    final name = _nameController.text.trim();
    final problem = _problemController.text.trim();
    final tags = [_selectedSubject!, ...?widget.existingProject?.tags.skip(1)];
    final tagsError = InputValidator.tags(tags);
    if (tagsError != null) {
      _snack(tagsError);
      return;
    }

    final objectives = _objectiveRows
        .map(
          (row) => <String, dynamic>{
            'action': row.objectiveType ?? '',
            'subject': row.subjectDomain ?? '',
            'description': row.descriptionController.text.trim(),
          },
        )
        .toList();

    setState(() => _isCreating = true);

    if (widget.existingProject != null) {
      // Remove staged members before requesting Solo; the database rejects
      // Solo while another member still exists.
      if (_projectType == 'solo' &&
          _pendingMembers.any((m) => m.id != _projectOwner?.id)) {
        if (!mounted) return;
        setState(() => _isCreating = false);
        _snack('Could not remove members. Please retry.');
        return;
      }
      final ok = await _projectsRepo.updateProjectMetadata(
        id: widget.existingProject!.id,
        projectType: _projectType,
        communityLinks: _communityLinks,
        learningObjectives: objectives,
        projectName: name,
        problemStatement: problem,
        tags: tags,
        difficulty: _selectedDifficulty,
        projectScale: _selectedScale,
        visibility: _selectedVisibility,
        shareFriends: _sharedAudience.friends,
        sharedCommunityIds: _sharedAudience.communityIds.toList(),
        projectImageUrl: _projectImageUrl,
      );
      final membersOk = ok;
      if (!mounted) return;
      setState(() => _isCreating = false);
      if (membersOk) {
        Navigator.of(context).pop(true);
      } else {
        _snack(
          ok
              ? 'Project settings saved, but member changes could not be saved. Please retry.'
              : (_projectsRepo.lastProjectSaveError ??
                    'Failed to save project settings. Please try again.'),
        );
      }
      return;
    }

    final wasAlreadyCreated = _createdProject != null;
    final project =
        _createdProject ??
        await _projectsRepo.createProject(
          projectType: _projectType,
          communityLinks: _communityLinks,
          learningObjectives: objectives,
          projectName: name,
          problemStatement: problem,
          tags: [_selectedSubject!],
          difficulty: _selectedDifficulty,
          projectScale: _selectedScale,
          visibility: _selectedVisibility,
          shareFriends: _sharedAudience.friends,
          sharedCommunityIds: _sharedAudience.communityIds.toList(),
          projectImageUrl: _projectImageUrl,
        );

    if (!mounted) return;

    if (project == null) {
      setState(() => _isCreating = false);
      _snack(
        _projectsRepo.lastProjectSaveError ??
            'Failed to create project. Please try again.',
      );
      return;
    }

    _createdProject = project;

    if (!await _syncSetupMembers(project.id)) {
      if (mounted) {
        setState(() => _isCreating = false);
        _snack('Project saved. Some member changes failed; please retry.');
      }
      return;
    }

    if (!wasAlreadyCreated) {
      if (widget.challengeId != null) {
        await ChallengesRepo().joinChallenge(
          challengeId: widget.challengeId!,
          projectId: project.id,
        );
      }
    }

    if (!mounted) return;

    final dashboard = ProjectDashboard(
      projectsRepo: _projectsRepo,
      projectId: project.id,
      projectName: project.projectName,
      tags: project.tags,
      challengeId: widget.challengeId,
      learningObjectives: _objectiveRows
          .map(
            (row) => ProjectObjectiveSummary(
              action: row.objectiveType ?? '',
              subject: row.subjectDomain ?? '',
              description: row.descriptionController.text.trim(),
            ),
          )
          .toList(),
    );

    if (widget.challengeId != null || widget.initialCommunity != null) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => dashboard));
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dashboard),
        (route) => route.isFirst,
      );
    }
  }

  void _snack(String msg) {
    showTopSnackBar(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return CreationNavigationGuard(
      fingerprint: () => [
        _nameController.text,
        _problemController.text,
        _selectedSubject,
        _selectedDifficulty,
        _selectedScale,
        _selectedVisibility,
        _projectImageUrl,
        _projectType,
        _pendingMembers.map((p) => p.id).join(','),
        _communityLinks.toString(),
        ..._objectiveRows.map(
          (r) =>
              '${r.objectiveType}|${r.subjectDomain}|${r.descriptionController.text}',
        ),
      ].toString(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: CreationPageFrame(
          desktopMaxWidth: 720,
          child: PageScrollWithFooter(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CreationPageHeader(
                      onClose: () => Navigator.of(context).pop(false),
                      closeLabel: widget.existingProject == null
                          ? 'Close create project'
                          : 'Close project settings',
                      title: widget.existingProject == null
                          ? 'Create Project'
                          : 'Project Settings',
                    ),
                    CreationImagePicker(
                      label: 'Update project image',
                      iconOnlyTap: true,
                      imageUrl: _projectImageUrl,
                      imageBytes: _projectImagePreview,
                      isUploading: _isUploadingImage,
                      onTap: _showImageSourceSheet,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: JournalPageLayout.horizontalInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Project Name'),
                          const SizedBox(height: AppMetrics.labelGap),
                          _validatedField(
                            'name',
                            _ProjectSetupTextField(
                              showError:
                                  _showSetupValidation &&
                                  _setupErrors.containsKey('name'),
                              controller: _nameController,
                              height: 64,
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          _validatedField(
                            'type',
                            ProjectTypeSelector(
                              value: _projectType,
                              showError:
                                  _showSetupValidation && _projectType == null,
                              onChanged: (value) {
                                if (value == 'solo' &&
                                    _pendingMembers.any(
                                      (m) => m.id != _projectOwner?.id,
                                    )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Remove other members before changing to Solo.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _projectType = value);
                              },
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          if (widget.existingProject == null &&
                              _projectType == 'collaborative') ...[
                            if (_loadingMembers)
                              const LinearProgressIndicator()
                            else
                              _validatedField(
                                'members',
                                ProjectMembersSection(
                                  members: _pendingMembers,
                                  showError:
                                      _showSetupValidation &&
                                      _needsCollaborator,
                                  owner: _projectOwner,
                                  roles: _memberRoles,
                                  canManageRoles: _canManageRoles,
                                  onRoleChanged: (id, role) =>
                                      setState(() => _memberRoles[id] = role),
                                  onAddPeople: _openAddMemberDialog,
                                  onRemoveMember: (person) => setState(
                                    () => _pendingMembers.removeWhere(
                                      (member) => member.id == person.id,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppMetrics.fieldGap),
                          ],
                          if (widget.existingProject == null)
                            ProjectCommunitiesSection(
                              links: _communityLinks,
                              onAdd: _openCommunities,
                              onRemove: (id) => setState(
                                () => _communityLinks.removeWhere(
                                  (link) => link['id'] == id,
                                ),
                              ),
                              onCollaborator: (id) => setState(() {
                                for (final link in _communityLinks) {
                                  if (link['id'] == id) {
                                    link['role'] = 'collaborator';
                                  }
                                }
                              }),
                              onHome: (id) => setState(() {
                                for (final link in _communityLinks) {
                                  link['role'] = link['id'] == id
                                      ? 'home'
                                      : 'collaborator';
                                }
                              }),
                            ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const _SectionTitle('Problem Statement'),
                          const SizedBox(height: AppMetrics.helperGap),
                          const _SectionHint(
                            'What is the problem you are trying to solve?',
                          ),
                          const SizedBox(height: 12),
                          _validatedField(
                            'problem',
                            _ProjectSetupTextField(
                              showError:
                                  _showSetupValidation &&
                                  _setupErrors.containsKey('problem'),
                              controller: _problemController,
                              height: AppMetrics.longResponseHeight,
                              expands: true,
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const _SectionTitle('Subject'),
                          const SizedBox(height: AppMetrics.helperGap),
                          const _SectionHint(
                            'Choose the main area your project belongs to.',
                          ),
                          const SizedBox(height: 12),
                          _validatedField(
                            'subject',
                            Column(
                              children: [
                                for (final option in _subjectOptions) ...[
                                  _SubjectCard(
                                    option: option,
                                    showError:
                                        _showSetupValidation &&
                                        _selectedSubject == null,
                                    selected: _selectedSubject == option.value,
                                    onTap: () => _selectSubject(option.value),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const _SectionTitle('Difficulty'),
                          const SizedBox(height: AppMetrics.helperGap),
                          const _SectionHint('How difficult is your project?'),
                          const SizedBox(height: 12),
                          _validatedField(
                            'difficulty',
                            _ThreeCardSelector(
                              options: _difficultyOptions,
                              showError:
                                  _showSetupValidation &&
                                  _selectedDifficulty == null,
                              selectedValue: _selectedDifficulty,
                              lockedValue: widget.lockedDifficulty,
                              onSelected: (value) =>
                                  setState(() => _selectedDifficulty = value),
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const _SectionTitle('Scale'),
                          const SizedBox(height: AppMetrics.helperGap),
                          const _SectionHint('How large is the project?'),
                          const SizedBox(height: 12),
                          _validatedField(
                            'scale',
                            _ThreeCardSelector(
                              options: _scaleOptions,
                              showError:
                                  _showSetupValidation &&
                                  _selectedScale == null,
                              selectedValue: _selectedScale,
                              lockedValue: widget.lockedScale,
                              onSelected: (value) =>
                                  setState(() => _selectedScale = value),
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const _SectionTitle('Visibility'),
                          const SizedBox(height: AppMetrics.helperGap),
                          const _SectionHint(
                            'Choose who can see and interact with your project.',
                          ),
                          const SizedBox(height: 12),
                          _validatedField(
                            'visibility',
                            Column(
                              children: [
                                for (final option in _visibilityOptions) ...[
                                  _VisibilityCard(
                                    option: option,
                                    showError:
                                        _showSetupValidation &&
                                        _selectedVisibility == null,
                                    selected:
                                        _selectedVisibility == option.value,
                                    locked:
                                        widget.challengeId != null &&
                                        option.value != 'Friends',
                                    onTap:
                                        widget.challengeId != null &&
                                            option.value != 'Friends'
                                        ? null
                                        : () => _chooseVisibility(option.value),
                                  ),
                                  const SizedBox(height: AppMetrics.labelGap),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _validatedField(
                            'objectives',
                            _LearningObjectivesSection(
                              rows: _objectiveRows,
                              showValidation: _showObjectiveValidation,
                              onAdd: _addObjective,
                              onDelete: _removeObjective,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                          const SizedBox(height: AppMetrics.fieldGap),
                          const SizedBox(height: AppMetrics.labelGap),
                          SubmitButton(
                            label: widget.existingProject == null
                                ? 'Create'
                                : 'Save Changes',
                            isLoading: _isCreating,
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.primary,
                            onPressed: _handleCreate,
                          ),
                          if (widget.onDelete != null) ...[
                            const SizedBox(height: AppMetrics.labelGap),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isCreating
                                    ? null
                                    : () => widget.onDelete!(context),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete Project'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectSetupOption {
  final String label;
  final String value;
  final String asset;
  final String? description;
  final double? iconWidth;
  final double? iconHeight;

  const _ProjectSetupOption({
    required this.label,
    required this.value,
    required this.asset,
    this.description,
    this.iconWidth,
    this.iconHeight,
  });
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.fieldLabel);
}

class _SectionHint extends StatelessWidget {
  const _SectionHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: AppTypography.helper);
}

class _ProjectSetupTextField extends StatelessWidget {
  const _ProjectSetupTextField({
    required this.controller,
    required this.height,
    this.expands = false,
    this.showError = false,
  });

  final TextEditingController controller;
  final double height;
  final bool expands;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final line = TextPainter(
      text: const TextSpan(text: 'Ag', style: AppTypography.inputText),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final verticalPadding = ((height - line.height) / 2).clamp(0.0, height);
    line.dispose();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextField(
        controller: controller,
        expands: expands,
        maxLines: expands ? null : 1,
        minLines: expands ? null : 1,
        textAlignVertical: expands
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        style: AppTypography.inputText,
        decoration: InputDecoration(
          isDense: true,
          constraints: BoxConstraints.tightFor(height: height),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: expands ? 13 : verticalPadding,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: showError ? _projectSetupError : _projectSetupGreen,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: showError ? _projectSetupError : _projectSetupGreen,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: showError ? _projectSetupError : _projectSetupGreen,
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.option,
    required this.selected,
    required this.onTap,
    this.showError = false,
  });
  final _ProjectSetupOption option;
  final bool selected;
  final VoidCallback onTap;
  final bool showError;

  @override
  Widget build(BuildContext context) => CreationOptionCard(
    title: option.label,
    description: option.description ?? '',
    asset: option.asset,
    selected: selected,
    showError: showError,
    onTap: onTap,
  );
}

class _ThreeCardSelector extends StatelessWidget {
  const _ThreeCardSelector({
    required this.options,
    required this.selectedValue,
    required this.lockedValue,
    required this.onSelected,
    this.showError = false,
  });

  final List<_ProjectSetupOption> options;
  final String? selectedValue;
  final String? lockedValue;
  final ValueChanged<String> onSelected;

  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final option in options) ...[
          Expanded(
            child: _SmallChoiceCard(
              option: option,
              showError: showError,
              selected: selectedValue == option.value,
              locked: lockedValue != null && lockedValue != option.value,
              onTap: lockedValue != null
                  ? null
                  : () => onSelected(option.value),
            ),
          ),
          if (option != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SmallChoiceCard extends StatelessWidget {
  const _SmallChoiceCard({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.showError = false,
  });

  final _ProjectSetupOption option;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.35 : 1,
      child: _SelectableShell(
        selected: selected,
        showError: showError,
        height: 93,
        width: 99,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallChoiceIcon(option: option),
            const SizedBox(height: 10),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: _projectSetupText,
                fontSize: AppTypography.bodySize,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ProjectSettingKind { subject, difficulty, scale }

/// Uses the same saved-value icon mapping as project setup and settings.
class ProjectSettingIcon extends StatelessWidget {
  const ProjectSettingIcon({
    super.key,
    required this.kind,
    required this.value,
  });
  final ProjectSettingKind kind;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final options = switch (kind) {
      ProjectSettingKind.subject => _subjectOptions,
      ProjectSettingKind.difficulty => _difficultyOptions,
      ProjectSettingKind.scale => _scaleOptions,
    };
    for (final option in options) {
      if (option.value.toLowerCase() == value?.trim().toLowerCase()) {
        return _SmallChoiceIcon(option: option);
      }
    }
    return const Icon(Icons.horizontal_rule, color: Colors.grey, size: 28);
  }
}

class _SmallChoiceIcon extends StatelessWidget {
  const _SmallChoiceIcon({required this.option});

  final _ProjectSetupOption option;

  @override
  Widget build(BuildContext context) {
    if (option.value == 'Medium') {
      return const _ScaleMediumIcon();
    }
    if (option.value == 'Large') {
      return const _ScaleLargeIcon();
    }
    return SvgPicture.asset(
      option.asset,
      width: option.iconWidth,
      height: option.iconHeight,
      fit: BoxFit.contain,
    );
  }
}

class _ScaleMediumIcon extends StatelessWidget {
  const _ScaleMediumIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 35,
      height: 32,
      child: Stack(
        children: [
          _SvgPiece(
            'assets/project_setup/scale_medium_5.svg',
            left: 26,
            top: 0,
            width: 9,
            height: 9,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_1.svg',
            left: 4,
            top: 14,
            width: 27,
            height: 13,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_2.svg',
            left: 4,
            top: 20,
            width: 27,
            height: 1.2,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_3.svg',
            left: 13,
            top: 14,
            width: 1.2,
            height: 13,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_3.svg',
            left: 22,
            top: 14,
            width: 1.2,
            height: 13,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_4.svg',
            left: 18,
            top: 27,
            width: 1.2,
            height: 4,
          ),
          _SvgPiece(
            'assets/project_setup/scale_medium_6.svg',
            left: 0,
            top: 31,
            width: 35,
            height: 1.2,
          ),
        ],
      ),
    );
  }
}

class _ScaleLargeIcon extends StatelessWidget {
  const _ScaleLargeIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 19,
      height: 44,
      child: Stack(
        children: [
          _SvgPiece(
            'assets/project_setup/scale_large_3.svg',
            left: 9.6,
            top: 0,
            width: 1.2,
            height: 12.4,
          ),
          _SvgPiece(
            'assets/project_setup/scale_large_2.svg',
            left: 5,
            top: 7.7,
            width: 9.3,
            height: 9.3,
          ),
          _SvgPiece(
            'assets/project_setup/scale_large_4.svg',
            left: 0.3,
            top: 12.3,
            width: 9.3,
            height: 6.2,
          ),
          _SvgPiece(
            'assets/project_setup/scale_large_5.svg',
            left: 9.6,
            top: 12.3,
            width: 9.3,
            height: 6.2,
          ),
          _SvgPiece(
            'assets/project_setup/scale_large_1.svg',
            left: 9.6,
            top: 18.5,
            width: 1.2,
            height: 24.7,
          ),
          _SvgPiece(
            'assets/project_setup/scale_large_6.svg',
            left: 0,
            top: 43,
            width: 19,
            height: 1.2,
          ),
        ],
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.option,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.showError = false,
  });
  final _ProjectSetupOption option;
  final bool selected, locked;
  final VoidCallback? onTap;
  final bool showError;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: locked ? .35 : 1,
    child: CreationOptionCard(
      title: option.label,
      description: option.description ?? '',
      icon: _VisibilityIcon(option: option),
      selected: selected,
      showError: showError,
      onTap: onTap,
    ),
  );
}

class _VisibilityIcon extends StatelessWidget {
  const _VisibilityIcon({required this.option});

  final _ProjectSetupOption option;

  @override
  Widget build(BuildContext context) {
    if (option.value == 'Private' || option.value == 'Friends') {
      return SvgPicture.asset(
        option.value == 'Private'
            ? 'assets/project_setup/visibility_private.svg'
            : 'assets/project_setup/visibility_shared.svg',
        width: 40,
        height: 34,
      );
    }
    if (option.value == 'Public') {
      return SvgPicture.asset(
        'assets/project_setup/visibility_public.svg',
        width: 34,
        height: 34,
      );
    }
    if (option.value == 'Community Only') {
      return const SizedBox(
        width: 34,
        height: 26,
        child: Stack(
          children: [
            _SvgPiece(
              'assets/project_setup/visibility_community_1.svg',
              left: 4,
              top: 0,
              width: 13,
              height: 13,
            ),
            _SvgPiece(
              'assets/project_setup/visibility_community_2.svg',
              left: 0,
              top: 16,
              width: 22,
              height: 10,
            ),
            _SvgPiece(
              'assets/project_setup/visibility_community_3.svg',
              left: 24,
              top: 8,
              width: 10,
              height: 9,
            ),
            _SvgPiece(
              'assets/project_setup/visibility_community_4.svg',
              left: 26,
              top: 3,
              width: 6,
              height: 5,
            ),
          ],
        ),
      );
    }
    return SvgPicture.asset(
      option.asset,
      width: option.iconWidth,
      height: option.iconHeight,
      fit: BoxFit.contain,
    );
  }
}

class _SvgPiece extends StatelessWidget {
  const _SvgPiece(
    this.asset, {
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: SvgPicture.asset(asset, fit: BoxFit.fill),
    );
  }
}

class _SelectableShell extends StatelessWidget {
  const _SelectableShell({
    required this.child,
    required this.selected,
    required this.height,
    required this.onTap,
    this.showError = false,
    this.width,
  });

  final Widget child;
  final bool selected;
  final double height;
  final double? width;
  final VoidCallback? onTap;

  final bool showError;

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: selected
              ? _projectSetupGreen.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(
            color: showError ? _projectSetupError : _projectSetupGreen,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: child,
      ),
    );
  }
}

class _LearningObjectivesSection extends StatelessWidget {
  const _LearningObjectivesSection({
    required this.rows,
    required this.showValidation,
    required this.onAdd,
    required this.onDelete,
    required this.onChanged,
  });

  final List<_ObjectiveRowData> rows;
  final bool showValidation;
  final VoidCallback onAdd;
  final ValueChanged<int> onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Learning Objectives (${rows.length}/4)'),
        const SizedBox(height: 8),
        const Text(
          'Add at least one learning objective (up to four).',
          style: AppTypography.helper,
        ),
        if (showValidation &&
            (rows.isEmpty || rows.any((row) => !row.isComplete)))
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Add at least one complete learning objective.',
              style: AppTypography.requirement,
            ),
          ),
        const SizedBox(height: AppMetrics.labelGap),
        if (rows.isNotEmpty)
          _ObjectiveList(
            rows: rows,
            objectiveOptions: _objectiveActions,
            domainOptions: _subjectOptions
                .map((option) => option.value)
                .toList(),
            onDelete: onDelete,
            onChanged: onChanged,
            showValidation: showValidation,
          ),
        const SizedBox(height: AppMetrics.sectionGap),
        Center(
          child: SizedBox(
            width: 242,
            height: 33,
            child: OutlinedButton(
              onPressed: rows.length >= 4 ? null : onAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: _projectSetupGreen,
                disabledForegroundColor: _projectSetupGreen.withValues(
                  alpha: 0.45,
                ),
                side: BorderSide(
                  color: rows.length >= 4
                      ? _projectSetupGreen.withValues(alpha: 0.45)
                      : _projectSetupGreen,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Text(
                '+ Add Objective',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: _projectSetupGreen,
                  fontSize: AppTypography.buttonSize,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ObjectiveRowData {
  String? objectiveType;
  String? subjectDomain;
  final TextEditingController descriptionController;

  _ObjectiveRowData({
    required this.objectiveType,
    required this.subjectDomain,
    required String description,
  }) : descriptionController = TextEditingController(text: description);

  bool get isComplete {
    return _objectiveActions.contains(objectiveType) &&
        _subjectOptions.any((option) => option.value == subjectDomain) &&
        descriptionController.text.trim().isNotEmpty;
  }

  void dispose() {
    descriptionController.dispose();
  }
}

class _ObjectiveList extends StatelessWidget {
  const _ObjectiveList({
    required this.rows,
    required this.objectiveOptions,
    required this.domainOptions,
    required this.onDelete,
    required this.onChanged,
    required this.showValidation,
  });

  final List<_ObjectiveRowData> rows;
  final List<String> objectiveOptions;
  final List<String> domainOptions;
  final ValueChanged<int> onDelete;
  final VoidCallback onChanged;
  final bool showValidation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _projectSetupObjectiveBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _ObjectiveRow(
              index: index,
              row: rows[index],
              objectiveOptions: objectiveOptions,
              domainOptions: domainOptions,
              onDelete: () => onDelete(index),
              onChanged: onChanged,
              showValidation: showValidation,
            ),
            if (index != rows.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
          ],
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    required this.index,
    required this.row,
    required this.objectiveOptions,
    required this.domainOptions,
    required this.onDelete,
    required this.onChanged,
    required this.showValidation,
  });

  final int index;
  final _ObjectiveRowData row;
  final List<String> objectiveOptions;
  final List<String> domainOptions;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final bool showValidation;

  @override
  Widget build(BuildContext context) {
    Widget menu(bool domain) => SizedBox(
      height: AppMetrics.controlHeight,
      child: ProjectChipMenu(
        value: domain ? row.subjectDomain : row.objectiveType,
        hint: domain ? 'Subject' : 'Objective',
        options: domain ? domainOptions : objectiveOptions,
        showError:
            showValidation &&
            (domain ? row.subjectDomain : row.objectiveType) == null,
        onSelected: (value) {
          if (domain) {
            row.subjectDomain = value;
          } else {
            row.objectiveType = value;
          }
          onChanged();
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _projectSetupGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 320
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            menu(false),
                            const SizedBox(height: 12),
                            menu(true),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: menu(false)),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: menu(true)),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: row.descriptionController,
                        onChanged: (_) => onChanged(),
                        minLines: 3,
                        maxLines: null,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          color: _projectSetupText,
                          fontSize: AppTypography.bodySize,
                          height: 1.2,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color:
                                  showValidation &&
                                      row.descriptionController.text
                                          .trim()
                                          .isEmpty
                                  ? _projectSetupError
                                  : _projectSetupObjectiveBorder,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color:
                                  showValidation &&
                                      row.descriptionController.text
                                          .trim()
                                          .isEmpty
                                  ? _projectSetupError
                                  : _projectSetupObjectiveBorder,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Delete objective',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectChipMenu extends StatefulWidget {
  const ProjectChipMenu({
    super.key,
    this.fontSize = AppTypography.bodySize,
    this.fontWeight = FontWeight.w500,
    this.menuWidth,
    required this.value,
    required this.hint,
    required this.options,
    required this.showError,
    required this.onSelected,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double? menuWidth;
  final String? value;
  final String hint;
  final List<String> options;
  final bool showError;
  final ValueChanged<String> onSelected;

  @override
  State<ProjectChipMenu> createState() => ProjectChipMenuState();
}

class ProjectChipMenuState extends State<ProjectChipMenu> {
  final _chipKey = GlobalKey();

  double get _fontSize =>
      MediaQuery.sizeOf(context).width >= 1000 &&
          widget.fontSize < AppTypography.bodySize
      ? AppTypography.bodySize
      : widget.fontSize;

  Future<void> _openMenu() async {
    final chipContext = _chipKey.currentContext;
    if (chipContext == null) return;

    final chipBox = chipContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chipTopLeft = chipBox.localToGlobal(Offset.zero, ancestor: overlay);
    final chipRect = chipTopLeft & chipBox.size;

    final selected = await showMenu<String>(
      context: context,
      color: Colors.white,
      elevation: 2,
      constraints: BoxConstraints.tightFor(
        width: (widget.menuWidth ?? chipRect.width).clamp(
          180.0,
          overlay.size.width - 32,
        ),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(chipRect.left, chipRect.bottom + 4, chipRect.width, 0),
        Offset.zero & overlay.size,
      ),
      items: widget.options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              height: AppMetrics.controlHeight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                option,
                style: TextStyle(
                  color: _projectSetupText,
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );

    if (selected != null && selected != widget.value) {
      widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      key: _chipKey,
      behavior: HitTestBehavior.opaque,
      onTap: _openMenu,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: widget.showError
                ? _projectSetupError
                : _projectSetupObjectiveBorder,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.only(left: 8, right: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.value ?? widget.hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.value == null
                      ? const Color(0xFF555555)
                      : _projectSetupText,
                  fontSize: _fontSize,
                  height: 1,
                  fontWeight: widget.fontWeight,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SvgPicture.asset(
              'assets/learning_module/text_block_chevron.svg',
              width: 12,
              height: 7,
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectMembersSection extends StatelessWidget {
  const ProjectMembersSection({
    super.key,
    required this.members,
    this.showError = false,
    this.searchQuery = '',
    this.owner,
    this.showRoles = true,
    this.statuses = const {},
    required this.onAddPeople,
    required this.onRemoveMember,
    required this.roles,
    required this.canManageRoles,
    required this.onRoleChanged,
  });

  final List<UserProfile> members;
  final bool showError;
  final String searchQuery;
  List<UserProfile> get _visibleMembers {
    final query = searchQuery.trim().toLowerCase().replaceFirst(
      RegExp(r'^@'),
      '',
    );
    return [
          if (owner != null) owner!,
          ...members.where((person) => person.id != owner?.id),
        ]
        .where(
          (person) =>
              query.isEmpty ||
              person.resolvedDisplayName.toLowerCase().contains(query) ||
              (person.username ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  final UserProfile? owner;
  final bool showRoles;
  final Map<String, String> statuses;
  final Map<String, String> roles;
  final bool canManageRoles;
  final void Function(String, String) onRoleChanged;
  final VoidCallback onAddPeople;
  final ValueChanged<UserProfile> onRemoveMember;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          const Expanded(child: _SectionTitle('Members')),
          if (canManageRoles)
            TextButton.icon(
              onPressed: onAddPeople,
              icon: const Icon(Icons.add, color: _projectSetupGreen, size: 18),
              label: const Text(
                'Add People',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      if (showError)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Add at least one other member for a collaborative project.',
            style: AppTypography.requirement,
          ),
        ),
      const SizedBox(height: 10),
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: _visibleMembers.isEmpty
            ? SizedBox(
                width: double.infinity,
                height: 90,
                child: Center(
                  child: Text(
                    searchQuery.trim().isEmpty
                        ? 'No members added yet.'
                        : 'No matching members.',
                    style: TextStyle(
                      color: Color(0xFFA1A1A1),
                      fontSize: AppTypography.helperSize,
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final person in _visibleMembers) ...[
                    if (person.id != _visibleMembers.first.id)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFD0CECE),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage:
                                person.avatarUrl?.isNotEmpty == true
                                ? NetworkImage(person.avatarUrl!)
                                : null,
                            child: person.avatarUrl?.isNotEmpty == true
                                ? null
                                : const Icon(Icons.person_outline, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.resolvedDisplayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (person.username?.isNotEmpty == true)
                                  Text(
                                    person.username!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.helperSize,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (statuses[person.id] == 'pending')
                            const _PendingProjectInvite()
                          else if (showRoles && person.id == owner?.id)
                            const Text(
                              'Project Admin',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.helperSize,
                              ),
                            )
                          else if (showRoles)
                            ProjectRoleDropdown(
                              value: roles[person.id] ?? 'project_member',
                              options: const {
                                'project_member': 'Project Member',
                                'project_admin': 'Project Admin',
                              },
                              onChanged: canManageRoles
                                  ? (role) => onRoleChanged(person.id, role)
                                  : null,
                            ),
                          SizedBox(
                            width: 30,
                            child: person.id != owner?.id && canManageRoles
                                ? ItemActionMenu(
                                    extraActions: [
                                      ItemMenuAction(
                                        'Remove',
                                        () => onRemoveMember(person),
                                        color: const Color(0xFFFD1212),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ],
  );
}

class ProjectMemberPicker extends StatefulWidget {
  const ProjectMemberPicker({
    super.key,
    required this.existingMembers,
    this.loadFriends,
    this.searchPeople,
    this.communityIds = const [],
    this.loadCommunityMembers,
    this.confirmLabel = 'Add',
    this.excludedIds = const {},
  });
  final String confirmLabel;
  final Set<String> excludedIds;
  final Future<List<UserProfile>> Function()? loadFriends;
  final Future<List<UserProfile>> Function(String)? searchPeople;

  final List<String> communityIds;
  final Future<List<UserProfile>> Function()? loadCommunityMembers;
  final List<UserProfile> existingMembers;

  @override
  State<ProjectMemberPicker> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<ProjectMemberPicker> {
  final _searchController = TextEditingController();
  final _usersRepo = UsersRepo();
  Timer? _debounce;

  UserProfile? _ownerProfile;
  List<UserProfile> _members = [];
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.existingMembers);
    _loadOwner();
    _loadFriends();
    _loadCommunityMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfile> _friends = [];
  List<UserProfile> _communityPeople = [];
  bool _loadingCommunityPeople = false;
  bool _communityPeopleFailed = false;
  bool get _hasCommunitySource =>
      widget.communityIds.isNotEmpty || widget.loadCommunityMembers != null;

  Future<void> _loadCommunityMembers() async {
    if (!_hasCommunitySource) return;
    setState(() {
      _loadingCommunityPeople = true;
      _communityPeopleFailed = false;
    });
    try {
      final List<UserProfile> people;
      if (widget.loadCommunityMembers != null) {
        people = await widget.loadCommunityMembers!();
      } else {
        final communities = await Future.wait(
          widget.communityIds.toSet().map(
            (id) => CommunitiesRepo().getCommunityMembers(id),
          ),
        );
        people = [
          for (final members in communities)
            for (final member in members)
              if (member.status == 'accepted')
                UserProfile(
                  id: member.userId,
                  displayName: member.displayName,
                  username: member.username,
                  avatarUrl: member.avatarUrl,
                ),
        ];
      }
      if (!mounted) return;
      setState(() {
        _communityPeople = {
          for (final person in people) person.id: person,
        }.values.toList();
        _loadingCommunityPeople = false;
      });
      if (_searchController.text.trim().isNotEmpty) _onSearchChanged();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCommunityPeople = false;
          _communityPeopleFailed = true;
        });
      }
    }
  }

  List<UserProfile> _available(Iterable<UserProfile> people) => people
      .where(
        (person) =>
            person.id != _ownerProfile?.id &&
            !widget.excludedIds.contains(person.id) &&
            !_members.any((member) => member.id == person.id),
      )
      .toList();

  Widget _peopleSource(String title, List<UserProfile> people) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(title, style: AppTypography.fieldLabel),
      const SizedBox(height: 8),
      if (people.isEmpty)
        Text(
          'No more people to add from this list.',
          style: AppTypography.helper,
        )
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: PageScrollWithFooter(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [for (final person in people) _inviteeRow(person)],
            ),
          ),
        ),
    ],
  );

  Widget _inviteeRow(UserProfile person) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Theme(
            data: Theme.of(context).copyWith(
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              tooltip: 'Profile options',
              onSelected: (_) => openUserProfile(context, person.id),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('View profile')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: person.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(person.avatarUrl!)
                          : null,
                      child: person.avatarUrl?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.resolvedDisplayName,
                            style: AppTypography.body,
                          ),
                          if (person.username?.isNotEmpty == true)
                            Text(
                              '@${person.username!.replaceFirst(RegExp(r'^@'), '')}',
                              style: AppTypography.helper,
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
        IconButton(
          tooltip: 'Add ${person.resolvedDisplayName}',
          onPressed: () => _addMember(person),
          icon: const Icon(Icons.add, color: AppColors.primary),
        ),
      ],
    ),
  );

  Future<void> _loadFriends() async {
    final friends =
        await (widget.loadFriends?.call() ?? FriendsRepo().getFriends()) ?? [];
    if (!mounted) return;
    setState(() => _friends = friends);
  }

  Future<void> _loadOwner() async {
    if (widget.searchPeople != null) return;
    final profile = await _usersRepo.getCurrentUserProfile();
    if (mounted) setState(() => _ownerProfile = profile);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final q = _searchController.text.trim();
    setState(() {
      _searchResults = [];
      _isSearching = q.isNotEmpty;
    });
    if (q.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final results =
          await (widget.searchPeople?.call(q) ??
              _usersRepo.searchProjectInvitees(query: q)) ??
          [];
      final excluded = {
        ...widget.excludedIds,
        ..._members.map((m) => m.id),
        if (_ownerProfile != null) _ownerProfile!.id,
      };
      final query = q.toLowerCase();
      final matchingKnownPeople = [..._communityPeople, ..._friends].where(
        (person) =>
            person.resolvedDisplayName.toLowerCase().contains(query) ||
            (person.username ?? '').toLowerCase().contains(query),
      );
      final people = {
        for (final person in [...matchingKnownPeople, ...results])
          if (!excluded.contains(person.id)) person.id: person,
      };
      if (mounted && q == _searchController.text.trim()) {
        setState(() {
          _searchResults = people.values.toList()
            ..sort((a, b) {
              final aCommunity = _communityPeople.any(
                (person) => person.id == a.id,
              );
              final bCommunity = _communityPeople.any(
                (person) => person.id == b.id,
              );
              if (aCommunity != bCommunity) return aCommunity ? -1 : 1;
              final aFriend = _friends.any((friend) => friend.id == a.id);
              final bFriend = _friends.any((friend) => friend.id == b.id);
              return aFriend == bFriend
                  ? a.resolvedDisplayName.compareTo(b.resolvedDisplayName)
                  : (aFriend ? -1 : 1);
            });
          _isSearching = false;
        });
      }
    });
  }

  void _addMember(UserProfile user) {
    ModalDraftScope.changed(context);
    if (widget.excludedIds.contains(user.id) ||
        _members.any((member) => member.id == user.id))
      return;
    setState(() {
      _members.add(user);
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _removeMember(UserProfile user) {
    ModalDraftScope.changed(context);
    setState(() => _members.removeWhere((member) => member.id == user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              Expanded(
                child: PageScrollWithFooter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppTapTarget(
                              onTap: () => Navigator.pop(context),
                              child: SvgPicture.asset(
                                'assets/learning_module/x.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(
                                  AppColors.primary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Add Member',
                                textAlign: TextAlign.center,
                                style: AppTypography.pageTitle,
                              ),
                            ),
                            const SizedBox(width: 18),
                          ],
                        ),
                        const SizedBox(height: AppMetrics.fieldGap),
                        const Text(
                          'Search',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchController,
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
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (_searchResults.isNotEmpty)
                          Material(
                            color: const Color(0xFFF3F2F2),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 160),
                              margin: const EdgeInsets.only(top: 4),
                              child: PageScrollWithFooter(
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: _searchResults
                                      .map((user) => _inviteeRow(user))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        if (_searchController.text.trim().isEmpty) ...[
                          if (_hasCommunitySource)
                            if (_loadingCommunityPeople)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_communityPeopleFailed)
                              TextButton(
                                onPressed: _loadCommunityMembers,
                                child: const Text(
                                  'Retry loading community members',
                                ),
                              )
                            else
                              _peopleSource(
                                'Community members',
                                _available(_communityPeople),
                              ),
                          if (_friends.isNotEmpty || _hasCommunitySource)
                            _peopleSource(
                              'Friends',
                              _available(
                                _friends.where(
                                  (friend) => !_communityPeople.any(
                                    (person) => person.id == friend.id,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        if (_members.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Selected people',
                              style: AppTypography.fieldLabel,
                            ),
                          ),
                        if (_members.isNotEmpty)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 160),
                            child: PageScrollWithFooter(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _members.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 18),
                                itemBuilder: (context, index) {
                                  final member = _members[index];
                                  return _MemberRow(
                                    profile: member,
                                    label: 'Project Member',
                                    onRemove: () => _removeMember(member),
                                  );
                                },
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Search for people to add to this project.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        const SizedBox(height: AppMetrics.sectionGap),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Center(
                  child: SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _members),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        widget.confirmLabel,
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.buttonSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.profile, required this.label, this.onRemove});

  final UserProfile profile;
  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage:
              (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
              ? const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.primary,
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.resolvedDisplayName,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (profile.username != null)
                Text(
                  profile.username!,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.helperSize,
            color: label == 'Project Owner'
                ? AppColors.primary
                : Colors.grey.shade500,
            fontWeight: label == 'Project Owner'
                ? FontWeight.w400
                : FontWeight.w400,
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          AppTapTarget(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 18, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}

class ProjectTypeSelector extends StatelessWidget {
  const ProjectTypeSelector({
    super.key,
    required this.value,
    this.showError = false,
    required this.onChanged,
  });
  final String? value;
  final bool showError;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle('Project Type'),
      if (showError)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Choose a project type.',
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: Colors.red,
              fontSize: AppTypography.helperSize,
            ),
          ),
        ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (final type in ['solo', 'collaborative']) ...[
            if (type == 'collaborative') const SizedBox(width: 24),
            Expanded(
              child: Semantics(
                button: true,
                selected: value == type,
                child: AppTapTarget(
                  onTap: () => onChanged(type),
                  child: Container(
                    height: 105,
                    decoration: BoxDecoration(
                      color: value == type
                          ? const Color(0xFFD7EBDD)
                          : Colors.white,
                      border: Border.all(
                        color: showError ? Colors.red : _projectSetupGreen,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        type == 'solo'
                            ? const Icon(
                                Icons.person,
                                size: 36,
                                color: _projectSetupGreen,
                              )
                            : SvgPicture.asset(
                                'assets/project_setup/project_collaborative.svg',
                                width: 42,
                                height: 42,
                              ),
                        const SizedBox(height: 8),
                        Text(
                          type == 'solo' ? 'Solo' : 'Collaborative',
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.bodySize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// A pending invitation occupies the role position in both directories.
class _PendingProjectInvite extends StatelessWidget {
  const _PendingProjectInvite();
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.schedule_outlined, size: 16, color: AppColors.primary),
      SizedBox(width: 6),
      Text('Pending', style: AppTypography.helper),
    ],
  );
}

class ProjectCommunitiesSection extends StatelessWidget {
  const ProjectCommunitiesSection({
    super.key,
    required this.links,
    required this.onAdd,
    required this.onRemove,
    required this.onHome,
    this.onCollaborator,
    this.canManage = true,
    this.showOptional = true,
    this.searchQuery = '',
  });
  final String searchQuery;
  List<Map<String, dynamic>> get _visibleLinks => links
      .where(
        (link) =>
            searchQuery.trim().isEmpty ||
            (link['name'] ?? '').toString().toLowerCase().contains(
              searchQuery.trim().toLowerCase(),
            ),
      )
      .toList();
  final bool canManage;
  final bool showOptional;
  final List<Map<String, dynamic>> links;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onHome;
  final ValueChanged<String>? onCollaborator;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _SectionTitle('Communities'),
                if (showOptional)
                  OptionalFieldLabel(
                    ' (Optional)',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: Colors.grey,
                      fontSize: AppTypography.helperSize,
                    ),
                  ),
              ],
            ),
          ),
          if (canManage)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18, color: _projectSetupGreen),
              label: const Text(
                'Add Communities',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      if (canManage)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Link this project to the communities it belongs to or collaborates with. '
            'The Home Community is its main group; Collaborator Communities are other groups involved.',
            style: AppTypography.helper,
          ),
        ),
      const SizedBox(height: 12),
      Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMetrics.cornerRadius),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: _visibleLinks.isEmpty
            ? SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: Center(
                    child: Text(
                      searchQuery.trim().isEmpty
                          ? 'No communities added yet.'
                          : 'No matching communities.',
                      style: TextStyle(
                        color: Color(0xFFA1A1A1),
                        fontSize: AppTypography.helperSize,
                      ),
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  for (final link in _visibleLinks) ...[
                    if (link != _visibleLinks.first)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFD0CECE),
                      ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minVerticalPadding: 8,
                      horizontalTitleGap: 12,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            (link['imageUrl']?.toString().isNotEmpty ?? false)
                            ? NetworkImage(link['imageUrl'].toString())
                            : null,
                        child:
                            (link['imageUrl']?.toString().isNotEmpty ?? false)
                            ? null
                            : const Icon(Icons.groups_outlined, size: 18),
                      ),
                      title: Text(
                        link['name']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                        ),
                      ),
                      subtitle: link['status'] == 'pending'
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: _PendingProjectInvite(),
                            )
                          : ProjectRoleDropdown(
                              value: link['role'] == 'home'
                                  ? 'home'
                                  : 'collaborator',
                              options: const {
                                'home': 'Home Community',
                                'collaborator': 'Collaborator Community',
                              },
                              onChanged: !canManage
                                  ? null
                                  : (role) {
                                      if (role == 'home')
                                        onHome(link['id'].toString());
                                      else
                                        onCollaborator?.call(
                                          link['id'].toString(),
                                        );
                                    },
                            ),
                      trailing: SizedBox(
                        width: 30,
                        child: !canManage
                            ? null
                            : ItemActionMenu(
                                extraActions: [
                                  ItemMenuAction(
                                    link['status'] == 'pending'
                                        ? 'Cancel invitation'
                                        : 'Remove',
                                    () => onRemove(link['id'].toString()),
                                    color: const Color(0xFFFD1212),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ],
  );
}

class ProjectCommunityPicker extends StatefulWidget {
  const ProjectCommunityPicker({
    super.key,
    required this.initial,
    this.communities,
  });
  final List<Map<String, dynamic>> initial;
  final List<Community>? communities;
  @override
  State<ProjectCommunityPicker> createState() => _ProjectCommunityPickerState();
}

class _ProjectCommunityPickerState extends State<ProjectCommunityPicker> {
  List<Community> _communities = [];
  late final List<Map<String, dynamic>> _selected;
  String _query = '';
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _selected = widget.initial
        .map((link) => Map<String, dynamic>.from(link))
        .toList();
    _load();
  }

  Future<void> _load() async {
    final communities =
        widget.communities ?? await CommunitiesRepo().getAllCommunities();
    if (mounted) {
      setState(() {
        _communities = communities;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: SizedBox(
      width: 350,
      height: 440,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _projectSetupGreen),
                ),
                const Expanded(
                  child: Text(
                    'Add Communities',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: AppMetrics.labelGap),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                labelText: 'Search',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppMetrics.labelGap),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : PageScrollWithFooter(
                      child: ListView(
                        children: [
                          for (final community in _communities.where(
                            (item) => item.name.toLowerCase().contains(_query),
                          ))
                            CheckboxListTile(
                              secondary: CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryTint,
                                child: ClipOval(
                                  child:
                                      community.imageUrl?.trim().isNotEmpty ==
                                          true
                                      ? ProtectedImage.network(
                                          community.imageUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.groups_outlined,
                                                color: AppColors.primary,
                                              ),
                                        )
                                      : const Icon(
                                          Icons.groups_outlined,
                                          color: AppColors.primary,
                                        ),
                                ),
                              ),
                              value: _selected.any(
                                (link) => link['id'] == community.id,
                              ),
                              title: Text(
                                community.name,
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.bodySize,
                                ),
                              ),
                              activeColor: _projectSetupGreen,
                              onChanged: (selected) => setState(() {
                                ModalDraftScope.changed(context);
                                if (selected == true) {
                                  _selected.add({
                                    'id': community.id,
                                    'name': community.name,
                                    'imageUrl': community.imageUrl,
                                    'description': community.subjectFocus,
                                    'role': _selected.isEmpty
                                        ? 'home'
                                        : 'collaborator',
                                  });
                                } else {
                                  _selected.removeWhere(
                                    (link) => link['id'] == community.id,
                                  );
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _projectSetupGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, _selected),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProjectRoleDropdown extends StatelessWidget {
  const ProjectRoleDropdown({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
  });
  final String value;
  final Map<String, String> options;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.helperSize,
      color: AppColors.textPrimary,
    );
    final painter = TextPainter(
      text: TextSpan(text: options[value], style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: (painter.width + 26).clamp(0, constraints.maxWidth),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
            style: style,
            items: [
              for (final item in options.entries)
                DropdownMenuItem(
                  value: item.key,
                  child: Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged == null
                ? null
                : (role) {
                    if (role != null) onChanged!(role);
                  },
          ),
        ),
      ),
    );
  }
}
