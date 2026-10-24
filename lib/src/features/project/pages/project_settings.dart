import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/project_photo_dialog.dart';
import 'dart:typed_data';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import '../../../shared/widgets/confirm_project_deletion.dart';
import '../../../shared/widgets/content_aligned_back_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/collaborators_sheet.dart';
import 'package:juniper_journal/src/services/media_service.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/widgets.dart';

// Domain → Focus options
const _focusByDomain = <String, List<String>>{
  'Environment & Sustainability': [
    'Ecosystems & Biodiversity',
    'Climate & Weather Patterns',
    'Human Impact on Natural Systems',
    'Natural Resources & Conservation',
    'Pollution and Waste Management',
  ],
  'Engineering & Design': [
    'Defining and Delimiting Engineering Problems',
    'Designing Solutions and Prototyping',
    'Materials and Their Properties',
    'Iteration and Improvement Processes',
    'Sustainable Innovation and Practices',
  ],
  'Energy & Systems': [
    'Energy Sources and Forms',
    'Energy Transfer and Transformation',
    'Renewable and Nonrenewable Resources',
    'Efficiency and Conservation of Energy',
    'Energy Flow in Natural and Engineered Systems',
  ],
  'Community & Built Environment': [
    'Sustainable Communities and Urban Planning',
    'Green Building and Infrastructure',
    'Transportation and Mobility Systems',
    'Public Space Design and Equity',
    'Interaction Between Human and Natural Environments',
  ],
};

typedef _SubjectTag = ({String domain, String focus});

class ProjectSettingsScreen extends StatefulWidget {
  final String projectId;
  final ProjectsRepo? projectsRepo;
  final MediaService? mediaService;

  const ProjectSettingsScreen({
    super.key,
    required this.projectId,
    this.projectsRepo,
    this.mediaService,
  });

  @override
  State<ProjectSettingsScreen> createState() => _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends State<ProjectSettingsScreen> {
  late final ProjectsRepo _projectsRepo;
  late final MediaService _mediaService;
  final _formKey = GlobalKey<FormState>();

  final _projectNameController = TextEditingController();
  final _problemStatementController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _projectImageUrl;
  Uint8List? _projectImagePreview;
  bool _uploadingImage = false;
  String? _ownerUserId;

  // Subject tags
  String? _activeDomain;
  String? _activeFocus;
  final List<_SubjectTag> _subjectTags = [];

  String? _selectedDifficulty;
  String? _selectedScale;
  String? _selectedVisibility;

  @override
  void initState() {
    super.initState();
    _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
    _mediaService = widget.mediaService ?? MediaService();
    _loadProject();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _problemStatementController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final project = await _projectsRepo.getProjectById(widget.projectId);
    if (!mounted) return;

    if (project == null) {
      setState(() => _isLoading = false);
      showTopSnackBar(
        context,
        'Failed to load project settings',
        isError: true,
      );
      return;
    }

    _projectNameController.text = project.projectName;
    _problemStatementController.text = project.problemStatement ?? '';
    _projectImageUrl = project.imageUrl;
    _ownerUserId = project.userId;

    // Parse stored "Domain|Focus" tag strings
    final tags = project.tags
        .map((s) {
          final parts = s.split('|');
          if (parts.length == 2) {
            return (domain: parts[0].trim(), focus: parts[1].trim());
          }
          return null;
        })
        .whereType<_SubjectTag>()
        .toList();

    setState(() {
      _subjectTags
        ..clear()
        ..addAll(tags);
      _selectedDifficulty = project.difficulty;
      _selectedScale = project.projectScale;
      _selectedVisibility = project.visibility;
      _isLoading = false;
    });
  }

  Future<void> _pickProjectImage(ImageSource source) async {
    if (_uploadingImage) return;
    _uploadingImage = true;
    final previousPreview = _projectImagePreview;
    final imageUrl = await _mediaService.pickAndUploadImage(
      source,
      folder: 'project-images',
      onSelected: (bytes) {
        if (mounted) setState(() => _projectImagePreview = bytes);
      },
    );
    if (!mounted) return;
    setState(() {
      _uploadingImage = false;
      if (imageUrl != null)
        _projectImageUrl = imageUrl;
      else
        _projectImagePreview = previousPreview;
    });
  }

  Future<void> _showImageSourceSheet() async {
    if (MediaService.usesDesktopImageUpload) {
      await _pickProjectImage(ImageSource.gallery);
      return;
    }
    final source = await showProjectPhotoDialog(context);
    if (source != null && mounted) await _pickProjectImage(source);
  }

  void _addSubjectTag() {
    if (_activeDomain == null || _activeFocus == null) return;
    final domain = _activeDomain!;
    final focus = _activeFocus!;
    if (_subjectTags.any((t) => t.domain == domain && t.focus == focus)) {
      setState(() {
        _activeDomain = null;
        _activeFocus = null;
      });
      return;
    }
    setState(() {
      _subjectTags.add((domain: domain, focus: focus));
      _activeDomain = null;
      _activeFocus = null;
    });
  }

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final tags = _subjectTags.map((t) => '${t.domain}|${t.focus}').toList();

    final success = await _projectsRepo.updateProjectMetadata(
      id: widget.projectId,
      projectName: _projectNameController.text.trim(),
      problemStatement: _problemStatementController.text.trim(),
      tags: tags,
      projectImageUrl: _projectImageUrl,
      difficulty: _selectedDifficulty,
      projectScale: _selectedScale,
      visibility: _selectedVisibility,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      showTopSnackBar(
        context,
        'Failed to update project settings',
        isError: true,
      );
      return;
    }

    Navigator.of(context).pop({
      'project_name': _projectNameController.text.trim(),
      'tags': tags,
      'project_image_url': _projectImageUrl,
    });
  }

  Future<void> _deleteProject() async {
    final confirmed = await confirmProjectDeletion(context);
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    // Remove challenge participation before deleting the project
    await ChallengesRepo().leaveChallenge(projectId: widget.projectId);
    final success = await _projectsRepo.deleteProject(id: widget.projectId);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      showTopSnackBar(context, 'Failed to delete project', isError: true);
      return;
    }

    Navigator.of(context).pop({'deleted': true});
  }

  @override
  Widget build(BuildContext context) {
    final canAddTag = _activeDomain != null && _activeFocus != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: ContentAlignedBackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: const Text('Project Settings', style: AppTypography.pageTitle),
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.6),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project image
                      Center(
                        child: AppTapTarget(
                          onTap: _showImageSourceSheet,
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.accent,
                            backgroundImage: _projectImagePreview != null
                                ? MemoryImage(_projectImagePreview!)
                                : (_projectImageUrl != null &&
                                      _projectImageUrl!.isNotEmpty)
                                ? NetworkImage(_projectImageUrl!)
                                : null,
                            child:
                                (_projectImagePreview == null &&
                                    (_projectImageUrl == null ||
                                        _projectImageUrl!.isEmpty))
                                ? const Icon(Icons.camera_alt, size: 28)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Tap image to update',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Project Name
                      _fieldLabel('Project Name'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _projectNameController,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Project name is required'
                            : null,
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Problem Statement
                      _fieldLabel('Problem Statement'),
                      const SizedBox(height: 10),
                      TextFormField(
                        minLines: 5,
                        controller: _problemStatementController,
                        maxLines: null,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 14,
                          ),
                          hintText: '',
                          hintStyle: const TextStyle(color: AppColors.hintText),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.borderLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Subject Domain & Focus
                      _fieldLabel('Subject Domain & Focus'),
                      const SizedBox(height: 10),
                      if (_subjectTags.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjectTags
                              .map(
                                (t) => _SubjectTagChip(
                                  domain: t.domain,
                                  focus: t.focus,
                                  onRemove: () =>
                                      setState(() => _subjectTags.remove(t)),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Domain',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            PillSelector(
                              value: _activeDomain,
                              placeholder: 'Select',
                              items: _focusByDomain.keys.toList(),
                              onChanged: (v) => setState(() {
                                _activeDomain = v;
                                _activeFocus = null;
                              }),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Focus',
                              style: TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.helperSize,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            PillSelector(
                              value: _activeFocus,
                              placeholder: _activeDomain == null
                                  ? 'Pick domain first'
                                  : 'Select',
                              items: _activeDomain != null
                                  ? _focusByDomain[_activeDomain]!
                                  : [],
                              onChanged: (v) =>
                                  setState(() => _activeFocus = v),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: canAddTag ? _addSubjectTag : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor: Colors.grey.shade200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: canAddTag
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                                label: Text(
                                  'Add Combination',
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.buttonSize,
                                    fontWeight: FontWeight.w500,
                                    color: canAddTag
                                        ? Colors.white
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Difficulty
                      _fieldLabel('Difficulty'),
                      const SizedBox(height: 10),
                      PillSelector(
                        value: _selectedDifficulty,
                        placeholder: 'Select Difficulty',
                        items: const ['Easy', 'Moderate', 'Hard'],
                        onChanged: (v) =>
                            setState(() => _selectedDifficulty = v),
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Project Scale
                      _fieldLabel('Project Scale'),
                      const SizedBox(height: 10),
                      PillSelector(
                        value: _selectedScale,
                        placeholder: 'Select Scale',
                        items: const ['Small', 'Medium', 'Large'],
                        onChanged: (v) => setState(() => _selectedScale = v),
                      ),
                      const SizedBox(height: AppMetrics.fieldGap),

                      // Visibility
                      _fieldLabel('Visibility'),
                      const SizedBox(height: 10),
                      if (_selectedVisibility == 'Community Only')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Community Only',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        PillSelector(
                          value: _selectedVisibility,
                          placeholder: 'Select Visibility',
                          items: const ['Private', 'Friends Only', 'Public'],
                          onChanged: (v) =>
                              setState(() => _selectedVisibility = v),
                        ),
                      const SizedBox(height: AppMetrics.sectionGap),

                      // Collaborators
                      _fieldLabel('Collaborators'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => showAppModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CollaboratorsSheet(
                              projectId: widget.projectId,
                              projectName: _projectNameController.text,
                              isOwner:
                                  _ownerUserId != null &&
                                  _ownerUserId ==
                                      AuthService.instance.currentUser?.id,
                              ownerUserId: _ownerUserId,
                            ),
                          ),
                          icon: const Icon(Icons.group_outlined),
                          label: const Text('Manage Collaborators'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppMetrics.sectionGap),

                      SubmitButton(
                        label: 'Save Settings',
                        isLoading: _isSaving,
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        onPressed: _saveSettings,
                      ),
                      const SizedBox(height: AppMetrics.labelGap),
                      OutlinedButton.icon(
                        onPressed: _isSaving ? null : _deleteProject,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Project'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );
}

// ── _SubjectTagChip ──────────────────────────────────────────────────────────

class _SubjectTagChip extends StatelessWidget {
  const _SubjectTagChip({
    required this.domain,
    required this.focus,
    required this.onRemove,
  });

  final String domain;
  final String focus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '$domain • $focus',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          AppTapTarget(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
