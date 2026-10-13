import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
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
const _projectSetupSubtext = Color(0xB3000000);
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
    label: 'For You Only',
    value: 'Private',
    asset: '',
    iconWidth: 29.33333396911621,
    iconHeight: 29.33333396911621,
  ),
  _ProjectSetupOption(
    label: 'Friends',
    value: 'Friends',
    asset: 'assets/project_setup/visibility_friends_full.svg',
    iconWidth: 41,
    iconHeight: 37,
  ),
  _ProjectSetupOption(
    label: 'Everyone',
    value: 'Public',
    asset: '',
    iconWidth: 40,
    iconHeight: 22,
  ),
  _ProjectSetupOption(
    label: 'Community Members Only',
    value: 'Community Only',
    asset: '',
    iconWidth: 34,
    iconHeight: 26,
  ),
];

class CreateProjectScreen extends StatefulWidget {
  final String? challengeId;
  final String? lockedDifficulty;
  final String? lockedScale;

  const CreateProjectScreen({
    super.key,
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
  final _projectsRepo = ProjectsRepo();
  final _mediaService = MediaService();
  final List<_ObjectiveRowData> _objectiveRows = [];

  String? _selectedSubject;
  String? _selectedDifficulty;
  String? _selectedScale;
  String? _selectedVisibility;
  String? _projectImageUrl;
  Project? _createdProject;
  List<UserProfile> _pendingMembers = [];
  bool _isCreating = false;
  bool _isUploadingImage = false;
  bool _showObjectiveValidation = false;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = widget.lockedDifficulty;
    _selectedScale = widget.lockedScale;
    if (widget.challengeId != null) {
      _selectedVisibility = 'Community Only';
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
    setState(() => _isUploadingImage = true);
    final imageUrl = await _mediaService.pickAndUploadImage(
      source,
      folder: 'project-images',
    );
    if (!mounted) return;
    setState(() {
      if (imageUrl != null) _projectImageUrl = imageUrl;
      _isUploadingImage = false;
    });
  }

  Future<void> _showImageSourceSheet() async {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Project Image'),
        message: const Text('Choose image source'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickProjectImage(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickProjectImage(ImageSource.gallery);
            },
            child: const Text('Choose from Gallery'),
          ),
          if (_projectImageUrl != null && _projectImageUrl!.isNotEmpty)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _projectImageUrl = null);
              },
              child: const Text('Remove Image'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
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

  Future<void> _openAddMemberDialog() async {
    final result = await showDialog<List<UserProfile>>(
      context: context,
      builder: (_) =>
          _AddMemberDialog(existingMembers: List.from(_pendingMembers)),
    );
    if (result != null) {
      setState(() => _pendingMembers = result);
    }
  }

  void _handleSaveDraft() {
    _persistProjectAndOpenDashboard();
  }

  Future<void> _handleCreate() async {
    await _persistProjectAndOpenDashboard();
  }

  Future<void> _persistProjectAndOpenDashboard() async {
    if (_isCreating) return;
    final name = _nameController.text.trim();
    final problem = _problemController.text.trim();

    if (name.isEmpty) {
      _snack('Enter a project name');
      return;
    }
    if (problem.isEmpty) {
      _snack('Enter a problem statement');
      return;
    }
    if (_selectedSubject == null) {
      _snack('Select a subject');
      return;
    }
    if (_selectedDifficulty == null) {
      _snack('Select a difficulty level');
      return;
    }
    if (_selectedScale == null) {
      _snack('Select a project scale');
      return;
    }
    if (_selectedVisibility == null) {
      _snack('Select a visibility setting');
      return;
    }

    if (_objectiveRows.any((row) => !row.isComplete)) {
      setState(() => _showObjectiveValidation = true);
      _snack('Complete or remove unfinished learning objectives');
      return;
    }

    setState(() => _isCreating = true);

    final wasAlreadyCreated = _createdProject != null;
    final project =
        _createdProject ??
        await _projectsRepo.createProject(
          projectName: name,
          problemStatement: problem,
          tags: [_selectedSubject!],
          difficulty: _selectedDifficulty,
          projectScale: _selectedScale,
          visibility: _selectedVisibility,
          projectImageUrl: _projectImageUrl,
        );

    if (!mounted) return;

    if (project == null) {
      setState(() => _isCreating = false);
      _snack('Failed to create project. Please try again.');
      return;
    }

    _createdProject = project;

    if (!wasAlreadyCreated) {
      for (final member in _pendingMembers) {
        await _projectsRepo.inviteCollaborator(
          projectId: project.id,
          userId: member.id,
        );
      }

      if (widget.challengeId != null) {
        await ChallengesRepo().joinChallenge(
          challengeId: widget.challengeId!,
          projectId: project.id,
        );
      }
    }

    if (!mounted) return;

    final dashboard = ProjectDashboard(
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

    if (widget.challengeId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => dashboard),
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => dashboard),
        (route) => route.isFirst,
      );
    }
  }

  void _snack(String msg) {
    showTopSnackBar(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 393),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProjectSetupHeader(
                      onClose: () => Navigator.of(context).pop(),
                      onSave: _handleSaveDraft,
                    ),
                    _ProjectImagePicker(
                      imageUrl: _projectImageUrl,
                      isUploading: _isUploadingImage,
                      onTap: _showImageSourceSheet,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionTitle('Project Name'),
                          const SizedBox(height: 14),
                          _ProjectSetupTextField(
                            controller: _nameController,
                            height: 39,
                          ),
                          const SizedBox(height: 22),
                          const _SectionTitle('Problem Statement'),
                          const SizedBox(height: 15),
                          _ProjectSetupTextField(
                            controller: _problemController,
                            height: 102,
                            expands: true,
                          ),
                          const SizedBox(height: 14),
                          const _SectionTitle('Subject'),
                          const SizedBox(height: 5),
                          const _SectionHint(
                            'Choose the main area your project belongs to.',
                          ),
                          const SizedBox(height: 12),
                          for (final option in _subjectOptions) ...[
                            _SubjectCard(
                              option: option,
                              selected: _selectedSubject == option.value,
                              onTap: () => _selectSubject(option.value),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 4),
                          const _SectionTitle('Difficulty'),
                          const SizedBox(height: 5),
                          const _SectionHint('How difficult is your project?'),
                          const SizedBox(height: 12),
                          _ThreeCardSelector(
                            options: _difficultyOptions,
                            selectedValue: _selectedDifficulty,
                            lockedValue: widget.lockedDifficulty,
                            onSelected: (value) =>
                                setState(() => _selectedDifficulty = value),
                          ),
                          const SizedBox(height: 28),
                          const _SectionTitle('Scale'),
                          const SizedBox(height: 5),
                          const _SectionHint('How large is the project?'),
                          const SizedBox(height: 12),
                          _ThreeCardSelector(
                            options: _scaleOptions,
                            selectedValue: _selectedScale,
                            lockedValue: widget.lockedScale,
                            onSelected: (value) =>
                                setState(() => _selectedScale = value),
                          ),
                          const SizedBox(height: 28),
                          const _SectionTitle('Visibility'),
                          const SizedBox(height: 5),
                          const _SectionHint(
                            'Choose who can see and interact with your project.',
                          ),
                          const SizedBox(height: 12),
                          for (final option in _visibilityOptions) ...[
                            _VisibilityCard(
                              option: option,
                              selected: _selectedVisibility == option.value,
                              locked:
                                  widget.challengeId != null &&
                                  option.value != 'Community Only',
                              onTap: widget.challengeId != null
                                  ? null
                                  : () => setState(
                                      () => _selectedVisibility = option.value,
                                    ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          const SizedBox(height: 12),
                          _LearningObjectivesSection(
                            rows: _objectiveRows,
                            showValidation: _showObjectiveValidation,
                            onAdd: _addObjective,
                            onDelete: _removeObjective,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: 26),
                          _MembersSection(
                            members: _pendingMembers,
                            onAddPeople: _openAddMemberDialog,
                            onRemoveMember: (member) => setState(
                              () => _pendingMembers.removeWhere(
                                (pending) => pending.id == member.id,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
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

class _ProjectSetupHeader extends StatelessWidget {
  const _ProjectSetupHeader({required this.onClose, required this.onSave});

  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: 20,
            width: 18,
            height: 18,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SvgPicture.asset(
                'assets/learning_module/x.svg',
                colorFilter: const ColorFilter.mode(
                  _projectSetupGreen,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: Center(
              child: Text(
                'Create Project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1F2024),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 16,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSave,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _projectSetupGreen,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w700,
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

class _ProjectImagePicker extends StatelessWidget {
  const _ProjectImagePicker({
    required this.imageUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 131,
        width: double.infinity,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 39,
                height: 37,
                child: ClipOval(
                  child: hasImage
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _ProjectImageUploadIcon(),
                        )
                      : const _ProjectImageUploadIcon(),
                ),
              ),
              const SizedBox(height: 9),
              if (isUploading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Text(
                  'Tap Image to Update',
                  style: TextStyle(
                    color: Color(0xFFAFAFAF),
                    fontSize: 10,
                    height: 1,
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

class _ProjectImageUploadIcon extends StatelessWidget {
  const _ProjectImageUploadIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: SvgPicture.asset(
            'assets/project_setup/image_upload_circle.svg',
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          width: 19,
          height: 15,
          child: SvgPicture.asset(
            'assets/project_setup/image_upload_camera.svg',
            fit: BoxFit.fill,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionHint extends StatelessWidget {
  const _SectionHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _projectSetupSubtext,
        fontSize: 12,
        height: 1.15,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _ProjectSetupTextField extends StatelessWidget {
  const _ProjectSetupTextField({
    required this.controller,
    required this.height,
    this.expands = false,
  });

  final TextEditingController controller;
  final double height;
  final bool expands;

  @override
  Widget build(BuildContext context) {
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
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          isDense: true,
          constraints: BoxConstraints.tightFor(height: height),
          contentPadding: EdgeInsets.symmetric(
            horizontal: expands ? 17 : 9,
            vertical: expands ? 13 : 10,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _projectSetupGreen),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _projectSetupGreen, width: 1.2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: _projectSetupGreen),
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
  });

  final _ProjectSetupOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SelectableShell(
      selected: selected,
      height: 84,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Center(
              child: SvgPicture.asset(
                option.asset,
                width: 37,
                height: 37,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      height: 20 / 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    option.description ?? '',
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      height: 20 / 8,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeCardSelector extends StatelessWidget {
  const _ThreeCardSelector({
    required this.options,
    required this.selectedValue,
    required this.lockedValue,
    required this.onSelected,
  });

  final List<_ProjectSetupOption> options;
  final String? selectedValue;
  final String? lockedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final option in options)
          _SmallChoiceCard(
            option: option,
            selected: selectedValue == option.value,
            locked: lockedValue != null && lockedValue != option.value,
            onTap: lockedValue != null ? null : () => onSelected(option.value),
          ),
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
  });

  final _ProjectSetupOption option;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.35 : 1,
      child: _SelectableShell(
        selected: selected,
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
                color: _projectSetupText,
                fontSize: 14,
                height: 18 / 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
          _SvgPiece('assets/project_setup/scale_medium_5.svg',
              left: 26, top: 0, width: 9, height: 9),
          _SvgPiece('assets/project_setup/scale_medium_1.svg',
              left: 4, top: 14, width: 27, height: 13),
          _SvgPiece('assets/project_setup/scale_medium_2.svg',
              left: 4, top: 20, width: 27, height: 1.2),
          _SvgPiece('assets/project_setup/scale_medium_3.svg',
              left: 13, top: 14, width: 1.2, height: 13),
          _SvgPiece('assets/project_setup/scale_medium_3.svg',
              left: 22, top: 14, width: 1.2, height: 13),
          _SvgPiece('assets/project_setup/scale_medium_4.svg',
              left: 18, top: 27, width: 1.2, height: 4),
          _SvgPiece('assets/project_setup/scale_medium_6.svg',
              left: 0, top: 31, width: 35, height: 1.2),
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
          _SvgPiece('assets/project_setup/scale_large_3.svg',
              left: 9.6, top: 0, width: 1.2, height: 12.4),
          _SvgPiece('assets/project_setup/scale_large_2.svg',
              left: 5, top: 7.7, width: 9.3, height: 9.3),
          _SvgPiece('assets/project_setup/scale_large_4.svg',
              left: 0.3, top: 12.3, width: 9.3, height: 6.2),
          _SvgPiece('assets/project_setup/scale_large_5.svg',
              left: 9.6, top: 12.3, width: 9.3, height: 6.2),
          _SvgPiece('assets/project_setup/scale_large_1.svg',
              left: 9.6, top: 18.5, width: 1.2, height: 24.7),
          _SvgPiece('assets/project_setup/scale_large_6.svg',
              left: 0, top: 43, width: 19, height: 1.2),
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
  });

  final _ProjectSetupOption option;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.35 : 1,
      child: _SelectableShell(
        selected: selected,
        height: 65,
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 82,
              child: Center(
                child: _VisibilityIcon(option: option),
              ),
            ),
            Expanded(
              child: Text(
                option.label,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  height: 20 / 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityIcon extends StatelessWidget {
  const _VisibilityIcon({required this.option});

  final _ProjectSetupOption option;

  @override
  Widget build(BuildContext context) {
    if (option.value == 'Private') {
      return const SizedBox(
        width: 29.33333396911621,
        height: 29.33333396911621,
        child: Stack(
          children: [
            _SvgPiece('assets/project_setup/visibility_private_1.svg',
                left: 0, top: 0, width: 29.33333396911621, height: 29.33333396911621),
            _SvgPiece('assets/project_setup/visibility_private_2.svg',
                left: 0, top: 14.667, width: 29.33333396911621, height: 1.2),
            _SvgPiece('assets/project_setup/visibility_private_3.svg',
                left: 11.234, top: 0, width: 6.875, height: 29.33333396911621),
          ],
        ),
      );
    }
    if (option.value == 'Public') {
      return const SizedBox(
        width: 40,
        height: 22,
        child: Stack(
          children: [
            _SvgPiece('assets/project_setup/visibility_everyone_1.svg',
                left: 4, top: 0, width: 11, height: 12),
            _SvgPiece('assets/project_setup/visibility_everyone_2.svg',
                left: 0, top: 14, width: 19, height: 8),
            _SvgPiece('assets/project_setup/visibility_everyone_3.svg',
                left: 25, top: 0, width: 11, height: 12),
            _SvgPiece('assets/project_setup/visibility_everyone_4.svg',
                left: 21, top: 14, width: 19, height: 8),
          ],
        ),
      );
    }
    if (option.value == 'Community Only') {
      return const SizedBox(
        width: 34,
        height: 26,
        child: Stack(
          children: [
            _SvgPiece('assets/project_setup/visibility_community_1.svg',
                left: 4, top: 0, width: 13, height: 13),
            _SvgPiece('assets/project_setup/visibility_community_2.svg',
                left: 0, top: 16, width: 22, height: 10),
            _SvgPiece('assets/project_setup/visibility_community_3.svg',
                left: 24, top: 8, width: 10, height: 9),
            _SvgPiece('assets/project_setup/visibility_community_4.svg',
                left: 26, top: 3, width: 6, height: 5),
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
    this.width,
  });

  final Widget child;
  final bool selected;
  final double height;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: selected
              ? _projectSetupGreen.withValues(alpha: 0.08)
              : Colors.white,
          border: Border.all(color: _projectSetupGreen),
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
          'Add specific description of why this answer is correct.',
          style: TextStyle(
            color: _projectSetupSubtext,
            fontSize: 14,
            height: 1.15,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 18),
        if (rows.isNotEmpty)
          _ObjectiveList(
            rows: rows,
            objectiveOptions: _objectiveActions,
            domainOptions: _subjectOptions.map((option) => option.value).toList(),
            onDelete: onDelete,
            onChanged: onChanged,
            showValidation: showValidation,
          ),
        const SizedBox(height: 28),
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
                  color: _projectSetupGreen,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
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
    return objectiveType != null &&
        subjectDomain != null &&
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
    return SizedBox(
      height: 123,
      child: Stack(
        children: [
          Positioned(
            left: 13,
            top: 13,
            width: 19,
            height: 19,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _projectSetupGreen,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 52,
            top: 12,
            width: 69,
            height: 24,
            child: _AnchoredChipMenu(
              value: row.objectiveType,
              hint: 'Select',
              options: objectiveOptions,
              showError: showValidation && row.objectiveType == null,
              onSelected: (value) {
                row.objectiveType = value;
                onChanged();
              },
            ),
          ),
          Positioned(
            left: 130,
            top: 12,
            width: 177,
            height: 26,
            child: _AnchoredChipMenu(
              value: row.subjectDomain,
              hint: 'Select Domain',
              options: domainOptions,
              showError: showValidation && row.subjectDomain == null,
              onSelected: (value) {
                row.subjectDomain = value;
                onChanged();
              },
            ),
          ),
          Positioned(
            left: 52,
            top: 47,
            width: 254,
            height: 60,
            child: TextField(
              controller: row.descriptionController,
              onChanged: (_) => onChanged(),
              maxLines: 3,
              style: const TextStyle(
                color: _projectSetupText,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        showValidation &&
                            row.descriptionController.text.trim().isEmpty
                        ? _projectSetupError
                        : _projectSetupObjectiveBorder,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _projectSetupGreen),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          Positioned(
            right: 13,
            top: 63,
            width: 20,
            height: 22,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: SvgPicture.asset(
                'assets/learning_module/learning_objective_trash.svg',
                width: 20,
                height: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnchoredChipMenu extends StatefulWidget {
  const _AnchoredChipMenu({
    required this.value,
    required this.hint,
    required this.options,
    required this.showError,
    required this.onSelected,
  });

  final String? value;
  final String hint;
  final List<String> options;
  final bool showError;
  final ValueChanged<String> onSelected;

  @override
  State<_AnchoredChipMenu> createState() => _AnchoredChipMenuState();
}

class _AnchoredChipMenuState extends State<_AnchoredChipMenu> {
  final _chipKey = GlobalKey();

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(chipRect.left, chipRect.bottom + 4, chipRect.width, 0),
        Offset.zero & overlay.size,
      ),
      items: widget.options
          .map(
            (option) => PopupMenuItem<String>(
              value: option,
              height: 32,
              child: Text(
                option,
                style: const TextStyle(
                  color: _projectSetupText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
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
    return GestureDetector(
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
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SvgPicture.asset(
              'assets/learning_module/text_block_chevron.svg',
              width: 7,
              height: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({
    required this.members,
    required this.onAddPeople,
    required this.onRemoveMember,
  });

  final List<UserProfile> members;
  final VoidCallback onAddPeople;
  final ValueChanged<UserProfile> onRemoveMember;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 14),
          child: _SectionTitle('Members'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final member in members)
              _MemberChip(
                profile: member,
                onRemove: () => onRemoveMember(member),
              ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddPeople,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '+ Add People',
                  style: TextStyle(
                    color: Color(0xE6000000),
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.profile, required this.onRemove});

  final UserProfile profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 5, right: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            backgroundImage:
                (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                ? const Icon(
                    Icons.person_outline,
                    size: 12,
                    color: AppColors.primary,
                  )
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            profile.resolvedDisplayName,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Text(
                'x',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.existingMembers});

  final List<UserProfile> existingMembers;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOwner() async {
    final profile = await _usersRepo.getCurrentUserProfile();
    if (mounted) setState(() => _ownerProfile = profile);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _searchController.text.trim();
      if (q.isEmpty) {
        if (mounted) setState(() => _searchResults = []);
        return;
      }
      if (mounted) setState(() => _isSearching = true);
      final results = await _usersRepo.searchPublicUsers(query: q) ?? [];
      final excluded = {
        ..._members.map((m) => m.id),
        if (_ownerProfile != null) _ownerProfile!.id,
        if (AuthService.instance.currentUser != null)
          AuthService.instance.currentUser!.id,
      };
      if (mounted) {
        setState(() {
          _searchResults = results
              .where((u) => !excluded.contains(u.id))
              .toList();
          _isSearching = false;
        });
      }
    });
  }

  void _addMember(UserProfile user) {
    setState(() {
      _members.add(user);
      _searchResults.clear();
      _searchController.clear();
    });
  }

  void _removeMember(UserProfile user) {
    setState(() => _members.removeWhere((member) => member.id == user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Search',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add People',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.1),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: _searchResults
                        .map(
                          (user) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              backgroundImage:
                                  (user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty)
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child:
                                  (user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty)
                                  ? const Icon(
                                      Icons.person_outline,
                                      size: 16,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.resolvedDisplayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: user.username != null
                                ? Text(
                                    user.username!,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            onTap: () => _addMember(user),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 16),
              if (_ownerProfile != null) ...[
                _MemberRow(profile: _ownerProfile!, label: 'Project Owner'),
                const Divider(height: 18),
              ],
              if (_members.isNotEmpty)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _members.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return _MemberRow(
                        profile: member,
                        label: 'Project Member',
                        onRemove: () => _removeMember(member),
                      );
                    },
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
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
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.username != null)
                Text(
                  profile.username!,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: label == 'Project Owner'
                ? AppColors.primary
                : Colors.grey.shade500,
            fontWeight: label == 'Project Owner'
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 18, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}
