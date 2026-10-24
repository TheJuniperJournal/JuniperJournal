import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/project_photo_dialog.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import 'impact_log.dart';
import '../widgets/project_activity_feed.dart';
import '../../../backend/db/models/project_activity_event.dart';
import '../services/project_activity.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/desktop_content_width.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import '../../../shared/widgets/app_scroll_behavior.dart';
import '../utils/project_impact_totals.dart';
import '../../../backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/shared/widgets/journal_section_header.dart';
import 'journal_entry_view.dart';
import '../../../backend/db/repositories/project_bulletin_repo.dart';
import '../../../shared/widgets/modal_actions.dart';
import '../../../services/media_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/widgets/app_tab_transition.dart';
import '../utils/journal_completion.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import '../../../shared/widgets/progress_tracker.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/project.dart';
import '../../../shared/widgets/confirm_project_deletion.dart';
import 'project_collaboration_tab.dart';
import 'journal_entry_editor.dart';
import '../../home_page/pages/home.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'create_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/materials_cost.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/project_timeline_tab.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ProjectDashboard extends StatefulWidget {
  final bool openSettingsOnLoad;
  final ProjectDashboardSection initialSection;
  final JournalEntry? initialJournalEntry;
  final String? initialPostId, initialCommentId, initialEventId;
  final CollaborationSection initialCollaborationSection;
  final ProjectBulletinRepo? bulletinRepo;
  final bool openMaterialsOnLoad;
  final String projectId;
  final String projectName;
  final List<String> tags;
  final bool isOwner;
  final String? challengeId;
  final ProjectsRepo? projectsRepo;
  final List<ProjectObjectiveSummary> learningObjectives;

  const ProjectDashboard({
    super.key,
    this.openSettingsOnLoad = false,
    this.initialSection = ProjectDashboardSection.overview,
    this.initialJournalEntry,
    this.initialPostId,
    this.initialCommentId,
    this.initialEventId,
    this.initialCollaborationSection = CollaborationSection.bulletin,
    this.bulletinRepo,
    this.openMaterialsOnLoad = false,
    required this.projectId,
    required this.projectName,
    required this.tags,
    this.isOwner = true,
    this.challengeId,
    this.projectsRepo,
    this.learningObjectives = const [],
    Object? challengesRepo,
    Object? mediaService,
  });

  @override
  State<ProjectDashboard> createState() => _ProjectDashboardState();
}

class ProjectObjectiveSummary {
  const ProjectObjectiveSummary({
    required this.action,
    required this.subject,
    required this.description,
  });

  final String action;
  final String subject;
  final String description;
}

enum ProjectDashboardSection { overview, development, collaboration, timeline }

class _ProjectDashboardState extends State<ProjectDashboard> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF1C1C1C);
  double get _canvasWidth =>
      (DesktopContentWidth.of(context) == null &&
                  MediaQuery.sizeOf(context).width >= 1000
              ? AppMetrics.publicContentWidth
              : JournalPageLayout.widthFor(context, mobileWidth: 402))
          .clamp(0.0, AppMetrics.publicContentWidth);
  double get _sectionInset => (_canvasWidth - _sectionWidth) / 2;
  double get _sectionWidth =>
      (_canvasWidth - 44).clamp(0.0, AppMetrics.publicContentWidth - 44);

  late final ProjectsRepo _projectsRepo;
  late String _projectName;
  late List<String> _tags;
  late List<ProjectObjectiveSummary> _learningObjectives;
  String? _imageUrl;
  bool _canEditCover = false;
  bool _participant = false;
  String _description = '';
  bool _uploadingCover = false;
  String? _difficulty;
  String? _projectScale;
  List<ImpactEntry> _impacts = const [];
  ProjectImpactTotals get _impactTotals => ProjectImpactTotals(_impacts);
  double get _impactTotal => _impactTotals.ecoPoints;
  double _categoryPoints(String metric) => _impactTotals.pointsFor(metric);
  double _materialsTotal = 0;
  int _materialsCount = 0;
  DevelopmentSummary _developmentSummary = DevelopmentSummary.empty();
  bool _isLoading = true;
  bool _loadFailed = false;
  int _settingsRevision = 0;
  int _collaborationRevision = 0;
  String? _activityEventId, _activityPostId;
  CollaborationSection? _activityCollaborationSection;
  int _activityNavigationRevision = 0;
  bool _openingSettings = false;
  bool _projectDeleted = false;
  ProjectDashboardSection _selectedTab = ProjectDashboardSection.overview;
  final Set<ProjectDashboardSection> _visitedTabs = {
    ProjectDashboardSection.overview,
  };

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialSection;
    _visitedTabs.add(widget.initialSection);
    _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
    _projectName = widget.projectName;
    _tags = List<String>.from(widget.tags);
    _learningObjectives = List.of(widget.learningObjectives);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadProject();
      if (mounted && widget.openSettingsOnLoad) await _openSettings();
      if (!mounted || _loadFailed) return;
      if (widget.initialJournalEntry != null) {
        final project = await _projectsRepo.getProjectById(widget.projectId);
        if (!mounted || project == null) return;
        await pushAppRoute(
          context,
          MaterialPageRoute(
            builder: (_) => JournalEntryView(
              entry: widget.initialJournalEntry!,
              project: project,
              projectsRepo: _projectsRepo,
            ),
          ),
        );
        if (mounted) await _loadProject();
      } else if (_participant && widget.openMaterialsOnLoad) {
        await pushAppRoute(
          context,
          MaterialPageRoute(
            builder: (_) => MaterialsCostPage(
              projectId: widget.projectId,
              projectName: _projectName,
              tags: _tags,
              projectsRepo: _projectsRepo,
              isOwner: _canEditCover,
              readOnly: !_canEditCover,
            ),
          ),
        );
        if (mounted) await _loadProject();
      }
    });
  }

  Future<void> _loadProject() async {
    try {
      final results = await Future.wait([
        _projectsRepo.getProjectById(widget.projectId),
        _projectsRepo.getMaterialsCost(widget.projectId),
        _projectsRepo.getJournalEntries(projectId: widget.projectId),
        _projectsRepo.getImpactEntries(projectId: widget.projectId),
      ]);
      final project = results[0] as Project?;
      if (project == null) throw StateError('Project unavailable');
      final participant = await _projectsRepo.canViewInternalProjectLogs(
        widget.projectId,
      );
      var canEditCover =
          participant && project.userId == _projectsRepo.currentUserId;
      if (!canEditCover) {
        try {
          canEditCover = await _projectsRepo.canManageProject(widget.projectId);
        } catch (_) {}
      }
      final materials = results[1] as List<Map<String, dynamic>>?;
      final entries = results[2] as List<JournalEntry>?;
      if (!mounted) return;

      setState(() {
        _projectName = project.projectName.isNotEmpty
            ? project.projectName
            : _projectName;
        _tags = List<String>.from(project.tags);
        _learningObjectives = project.learningObjectives
            .map(
              (item) => ProjectObjectiveSummary(
                action: item['action']?.toString() ?? '',
                subject: item['subject']?.toString() ?? '',
                description: item['description']?.toString() ?? '',
              ),
            )
            .toList();
        _imageUrl = project.imageUrl;
        _description = project.problemStatement?.trim() ?? '';
        _canEditCover = canEditCover;
        _difficulty = project.difficulty;
        _projectScale = project.projectScale;

        _participant = participant;
        if (!participant && _selectedTab == ProjectDashboardSection.timeline) {
          _selectedTab = ProjectDashboardSection.overview;
          _visitedTabs.remove(ProjectDashboardSection.timeline);
          _visitedTabs.add(ProjectDashboardSection.overview);
        }
        _impacts = (results[3] as List<ImpactEntry>?) ?? const [];
        _updateMaterialsSummary(materials ?? const []);
        _developmentSummary = DevelopmentSummary.fromEntries(
          entries ?? const [],
        );
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('Project dashboard load: $e');
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadFailed = true;
        });
    }
  }

  Future<void> _reloadDevelopmentSummary() async {
    final impacts = await _projectsRepo.getImpactEntries(
      projectId: widget.projectId,
    );
    final entries = await _projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
      _impacts = impacts ?? _impacts;
      _developmentSummary = DevelopmentSummary.fromEntries(entries ?? const []);
    });
  }

  void _updateMaterialsSummary(List<Map<String, dynamic>> materials) {
    _materialsCount = materials.length;
    _materialsTotal = materials.fold(0, (total, item) {
      return total + ((item['cost'] as num?)?.toDouble() ?? 0);
    });
  }

  String get _subject {
    if (_tags.isEmpty) return 'Not selected';
    return _tags.first.split('|').first.trim();
  }

  // Keep a full section gap after wrapped or enlarged project names.
  double get _overviewContentOffset {
    final title = TextPainter(
      text: TextSpan(
        text: _projectName,
        style: const TextStyle(
          fontFamily: AppTypography.headingFamily,
          fontSize: AppTypography.displaySize,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _sectionWidth);
    final offset = (title.height + 24 - 60).clamp(0.0, double.infinity);
    title.dispose();
    if (_description.isEmpty) return offset;
    final description = TextPainter(
      text: TextSpan(
        text: _description,
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _sectionWidth.clamp(0.0, 720.0));
    final extra = description.height + 18;
    description.dispose();
    return offset + extra;
  }

  @override
  Widget build(BuildContext context) => ProjectActivityScope(
    projectId: widget.projectId,
    repo: _projectsRepo,
    child: ProjectWorkspaceChrome(
      child: AppTabStack(
        index: _selectedTab.index,
        duration: const Duration(milliseconds: 280),
        sizing: StackFit.expand,
        children: [
          for (final tab in ProjectDashboardSection.values)
            _visitedTabs.contains(tab)
                ? _buildTab(tab)
                : const SizedBox.shrink(),
        ],
      ),
    ),
  );

  Widget _buildTab(ProjectDashboardSection tab) {
    PageRefreshState.remember(context, {
      'kind': 'project',
      'project': widget.projectId,
      'section': _selectedTab.index,
    });
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _canvasWidth),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load this project.'),
                        TextButton(
                          onPressed: _loadProject,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : tab == ProjectDashboardSection.collaboration
                ? _buildCollaborationCanvas(context)
                : SingleChildScrollView(
                    primary: false,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: _canvasWidth,
                        child: switch (tab) {
                          ProjectDashboardSection.collaboration =>
                            const SizedBox.shrink(),
                          ProjectDashboardSection.timeline => SizedBox(
                            width: _canvasWidth,
                            height: 852,
                            child: Stack(
                              children: [
                                _buildHeader(context),
                                _buildTabs(),
                                ProjectTimelineTab(
                                  key: ValueKey(
                                    'timeline-$_settingsRevision-$_activityNavigationRevision',
                                  ),
                                  initialEventId:
                                      _activityEventId ?? widget.initialEventId,
                                  projectId: widget.projectId,
                                  isOwner: _canEditCover,
                                  projectsRepo: _projectsRepo,
                                ),
                              ],
                            ),
                          ),
                          ProjectDashboardSection.development => SizedBox(
                            width: _canvasWidth,
                            height: 760,
                            child: Stack(
                              children: [
                                _buildHeader(context),
                                _buildTabs(),
                                ProjectDevelopmentTab(
                                  projectId: widget.projectId,
                                  isOwner: _canEditCover,
                                  summary: _developmentSummary,
                                  onChanged: _reloadDevelopmentSummary,
                                  projectsRepo: _projectsRepo,
                                ),
                              ],
                            ),
                          ),
                          ProjectDashboardSection.overview => SizedBox(
                            width: _canvasWidth,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 987 + _overviewContentOffset,
                                  child: Stack(
                                    children: [
                                      _buildHeader(context),
                                      _buildTabs(),
                                      _buildHero(),
                                      Transform.translate(
                                        offset: Offset(
                                          0,
                                          _overviewContentOffset,
                                        ),
                                        child: _buildDevelopmentProgress(),
                                      ),
                                      Transform.translate(
                                        offset: Offset(
                                          0,
                                          _overviewContentOffset,
                                        ),
                                        child: _buildProjectBasics(),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildImpactSummary(),
                                const SizedBox(height: 40),
                                _buildLearningObjectives(),
                                const SizedBox(height: 16),
                                if (_participant) const SizedBox(height: 16),
                                if (_participant)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _sectionInset,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 48,
                                      ),
                                      child: _buildRecentActivity(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollaborationCanvas(BuildContext context) {
    final platform = ScrollConfiguration.of(context).getPlatform(context);
    final gutter = DesktopContentWidth.of(context) != null
        ? 0.0
        : switch (platform) {
            TargetPlatform.macOS ||
            TargetPlatform.windows ||
            TargetPlatform.linux => AppScrollbar.gutterWidth,
            _ => 0.0,
          };
    // Match the viewport and canvas scale used by the other dashboard tabs.
    return Padding(
      padding: EdgeInsetsDirectional.only(end: gutter),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / _canvasWidth).clamp(0.0, 1.0);
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: _canvasWidth,
              height: constraints.maxHeight / scale,
              child: Column(
                children: [
                  SizedBox(
                    height: 124,
                    child: Stack(
                      children: [_buildHeader(context), _buildTabs()],
                    ),
                  ),
                  Expanded(
                    child: ProjectCollaborationTab(
                      readOnly: !_participant,
                      refreshToken: _collaborationRevision,
                      initialSection:
                          _activityCollaborationSection ??
                          widget.initialCollaborationSection,
                      initialPostId: _activityPostId ?? widget.initialPostId,
                      initialCommentId: widget.initialCommentId,
                      bulletinRepo: widget.bulletinRepo,
                      key: ValueKey(
                        'collaboration-$_settingsRevision-$_activityNavigationRevision',
                      ),
                      projectId: widget.projectId,
                      projectsRepo: _projectsRepo,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 21,
          top: 19,
          width: 47,
          height: 40,
          key: const ValueKey('project-dashboard-done'),
          child: AppTapTarget(
            behavior: HitTestBehavior.opaque,
            onTap: _exitProject,
            child: const Align(
              alignment: Alignment.center,
              child: Text(
                'Done',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.primary,
                  fontSize: AppTypography.buttonSize,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: (_canvasWidth - 215) / 2,
          top: 19,
          width: 215,
          height: 40,
          key: const ValueKey('project-dashboard-label'),
          child: const _ProjectNameTag(),
        ),
        if (_canEditCover)
          Positioned(
            right: 22.5,
            top: 15,
            width: 48,
            height: 48,
            key: const ValueKey('project-dashboard-settings'),
            child: AppTapTarget(
              behavior: HitTestBehavior.opaque,
              onTap: _openingSettings ? null : _openSettings,
              child: Center(
                child: _openingSettings
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SvgPicture.asset(
                        'assets/learning_module/dashboard_settings.svg',
                        width: 35,
                        height: 35,
                      ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _exitProject() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'debug.projectId',
      'debug.projectName',
      'debug.projectTags',
      'debug.isOwner',
      'debug.page',
    ]) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShellScreen()),
      );
    }
  }

  Future<void> _openSettings() async {
    if (_openingSettings || !_canEditCover) return;
    setState(() => _openingSettings = true);
    try {
      final project = await _projectsRepo.getProjectById(widget.projectId);
      if (!mounted) return;
      if (project == null) {
        showTopSnackBar(
          context,
          'Could not load project settings. Please try again.',
          isError: true,
        );
        return;
      }
      final isOwner =
          _canEditCover ||
          (project.userId != null &&
              project.userId == _projectsRepo.currentUserId);
      if (!isOwner && !await _projectsRepo.canManageProject(widget.projectId)) {
        if (!mounted) return;
        showTopSnackBar(
          context,
          _projectsRepo.lastProjectAccessError ??
              'Only the project owner or a project admin can change settings.',
          isError: true,
        );
        return;
      }
      if (!mounted) return;
      final changed = await pushAppRoute<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CreateProjectScreen(
            existingProject: project,
            projectsRepo: _projectsRepo,
            challengeId: widget.challengeId,
            initialObjectives: _learningObjectives,
            onDelete: (settingsContext) =>
                _deleteProject(confirmationContext: settingsContext),
          ),
        ),
      );
      if (!mounted) return;
      if (_projectDeleted) {
        Navigator.of(context).pop(true);
        return;
      }
      if (changed == true) setState(() => _settingsRevision++);
      await _loadProject();
    } catch (e) {
      debugPrint('Open project settings: $e');
      if (mounted)
        showTopSnackBar(
          context,
          'Could not open project settings. Please try again.',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _openingSettings = false);
    }
  }

  Future<void> _deleteProject({BuildContext? confirmationContext}) async {
    final confirmed = await confirmProjectDeletion(
      confirmationContext ?? context,
    );
    if (!confirmed || !mounted) return;
    final ok = await _projectsRepo.deleteProject(id: widget.projectId);
    if (!mounted) return;
    if (ok) {
      _projectDeleted = true;
      showTopSnackBar(context, 'Project deleted');
      Navigator.of(context).pop(true);
    } else {
      showTopSnackBar(context, 'Failed to delete project', isError: true);
    }
  }

  Widget _buildTabs() {
    final selected = _selectedTab;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 121,
          width: _canvasWidth,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
        ),
        Positioned(
          left: 0,
          top: 95,
          width: _canvasWidth,
          height: 29,
          child: Row(
            children: [
              for (final tab in ProjectDashboardSection.values.where(
                (tab) =>
                    _participant || tab != ProjectDashboardSection.timeline,
              ))
                Expanded(
                  child: AppTapTarget(
                    highlightInsets: const EdgeInsets.fromLTRB(24, 0, 24, 11),
                    highlightBorderRadius: BorderRadius.circular(16),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        if (tab == ProjectDashboardSection.collaboration &&
                            _selectedTab != tab)
                          _collaborationRevision++;
                        _selectedTab = tab;
                        _visitedTabs.add(tab);
                      });
                      if (tab == ProjectDashboardSection.overview)
                        _loadProject();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: _TabLabel(switch (tab) {
                              ProjectDashboardSection.overview => 'Overview',
                              ProjectDashboardSection.development =>
                                'Development',
                              ProjectDashboardSection.collaboration =>
                                'Collaboration',
                              ProjectDashboardSection.timeline => 'Timeline',
                            }, active: selected == tab),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          key: ValueKey('dashboard-tab-indicator-${tab.name}'),
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          height: 3,
                          decoration: BoxDecoration(
                            color: selected == tab
                                ? _green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editCover(ImageSource source) async {
    if (_uploadingCover || (_imageUrl?.trim().isNotEmpty ?? false)) return;
    if (!await _projectsRepo.canManageProject(widget.projectId)) return;
    if (!mounted) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await MediaService().pickAndUploadImage(
        source,
        folder: 'project-images',
      );
      if (url == null) return;
      final saved = await _projectsRepo.updateProjectImage(
        id: widget.projectId,
        projectImageUrl: url,
      );
      if (mounted) {
        if (saved)
          setState(() => _imageUrl = url);
        else
          showTopSnackBar(
            context,
            'Could not save the cover image. Please retry.',
            isError: true,
          );
      }
    } catch (_) {
      if (mounted)
        showTopSnackBar(
          context,
          'Could not update the cover image. Please retry.',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _openCover() async {
    if (_uploadingCover) return;
    final url = _imageUrl;
    if (url != null && url.isNotEmpty) {
      await showAppDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close image',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: ProtectedImage.network(
                      url,
                      key: const ValueKey('expanded-project-cover'),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Image could not be loaded.'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (!_canEditCover) return;
    if (MediaService.usesDesktopImageUpload) {
      await _editCover(ImageSource.gallery);
      return;
    }
    final source = await showProjectPhotoDialog(context);
    if (source != null && mounted) await _editCover(source);
  }

  Widget _buildHero() {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    return Stack(
      children: [
        Positioned(
          left: MediaQuery.sizeOf(context).width >= 1000
              ? _sectionInset
              : (_canvasWidth - 283) / 2,
          top: 140,
          width: MediaQuery.sizeOf(context).width >= 1000 ? _sectionWidth : 283,
          height: 255,
          child: Semantics(
            button: hasImage || _canEditCover,
            label: hasImage ? 'View project cover' : 'Add project cover',
            child: AppTapTarget(
              onTap: hasImage || _canEditCover ? _openCover : null,
              child: ClipRRect(
                key: const ValueKey('project-cover'),
                borderRadius: BorderRadius.circular(11),
                child: _uploadingCover
                    ? const Center(child: CircularProgressIndicator())
                    : hasImage
                    ? ProtectedImage.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _HeroPlaceholder(),
                      )
                    : _HeroPlaceholder(
                        onAddPhoto: _canEditCover ? _openCover : null,
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          left: _sectionInset,
          top: 438,
          width: _sectionWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _projectName,
                style: const TextStyle(
                  fontFamily: AppTypography.headingFamily,
                  color: _text,
                  fontSize: AppTypography.displaySize,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_description.isNotEmpty) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      _description,
                      style: const TextStyle(fontSize: 15, height: 1.5),
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

  Future<void> _openDevelopmentPhase(int index) async {
    final page = switch (index) {
      0 => DiscoveryDashboardPage(
        projectId: widget.projectId,
        isOwner: _canEditCover,
        projectsRepo: _projectsRepo,
      ),
      1 => IdeatingDashboardPage(
        projectId: widget.projectId,
        isOwner: _canEditCover,
        projectsRepo: _projectsRepo,
      ),
      2 => PrototypingDashboardPage(
        projectId: widget.projectId,
        isOwner: _canEditCover,
        projectsRepo: _projectsRepo,
      ),
      _ => ImplementationDashboardPage(
        projectId: widget.projectId,
        isOwner: _canEditCover,
        projectsRepo: _projectsRepo,
      ),
    };
    await pushAppRoute(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _reloadDevelopmentSummary();
  }

  Widget _buildDevelopmentProgress() {
    final furthestPhase = _developmentSummary.furthestPhase;
    return Stack(
      children: [
        Positioned(
          left: _sectionInset,
          top: 498,
          child: _SectionTitle('Development Progress'),
        ),
        Positioned(
          left: _sectionInset - 8,
          top: 553,
          width: _sectionWidth,
          height: 82,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _canvasWidth - 12,
              child: ProgressTracker(
                key: const ValueKey('project-development-tracker'),
                onSelected: _openDevelopmentPhase,
                showCurrentIndicator: false,
                labels: const [
                  'Discover',
                  'Ideating',
                  'Prototyping',
                  'Implementation',
                ],
                currentIndex: furthestPhase > 0 ? furthestPhase - 1 : null,
                reachedIndices: {for (var i = 0; i < furthestPhase; i++) i},
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectBasics() {
    return Stack(
      children: [
        Positioned(
          left: _sectionInset,
          top: 648,
          child: _SectionTitle('Project Basics'),
        ),
        Positioned(
          left: _sectionInset,
          top: 675,
          width: _sectionWidth,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
        ),
        Positioned(
          left: _sectionInset,
          top: 684,
          width: _sectionWidth,
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BasicColumn(
                  heading: 'Subject',
                  icon: ProjectSettingIcon(
                    kind: ProjectSettingKind.subject,
                    value: _subject,
                  ),
                  value: _subject,
                ),
              ),
              const VerticalDivider(
                width: 16,
                thickness: 1,
                color: Color(0xFFEAEAEA),
              ),
              Expanded(
                child: _BasicColumn(
                  heading: 'Difficulty',
                  icon: ProjectSettingIcon(
                    kind: ProjectSettingKind.difficulty,
                    value: _difficulty,
                  ),
                  value: _difficulty?.trim().isNotEmpty == true
                      ? _difficulty!
                      : 'Not set',
                ),
              ),
              const VerticalDivider(
                width: 16,
                thickness: 1,
                color: Color(0xFFEAEAEA),
              ),
              Expanded(
                child: _BasicColumn(
                  heading: 'Scale',
                  icon: ProjectSettingIcon(
                    kind: ProjectSettingKind.scale,
                    value: _projectScale,
                  ),
                  value: _projectScale?.trim().isNotEmpty == true
                      ? _projectScale!
                      : 'Not set',
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: _sectionInset,
          top: 807,
          width: _sectionWidth,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
        ),
        Positioned(
          left: _sectionInset,
          top: 831,
          width: _sectionWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCard(
                icon: const _JournalCardIcon(),
                title: 'Journal Entries',
                value: '${_developmentSummary.totalEntries}',
                caption: 'Across all phases',
              ),
              _StatCard(
                icon: const _MoneyCardIcon(),
                title: 'Materials & Cost',
                value: _formatDashboardCurrency(_materialsTotal),
                caption:
                    '$_materialsCount ${_materialsCount == 1 ? 'item' : 'items'}',
                showChevron: true,
                onTap: () async {
                  final changed = await pushAppRoute<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MaterialsCostPage(
                        projectId: widget.projectId,
                        projectName: _projectName,
                        tags: _tags,
                        isOwner: _canEditCover,
                        readOnly: !_canEditCover,
                      ),
                    ),
                  );
                  if (changed == true) {
                    final materials = await _projectsRepo.getMaterialsCost(
                      widget.projectId,
                    );
                    if (!mounted) return;
                    setState(
                      () => _updateMaterialsSummary(materials ?? const []),
                    );
                  }
                },
              ),
              ListenableBuilder(
                listenable: ProjectActivity.meter(
                  widget.projectId,
                  _projectsRepo,
                ),
                builder: (context, _) {
                  final time = ProjectActivity.meter(
                    widget.projectId,
                    _projectsRepo,
                  );
                  return _StatCard(
                    icon: _TimeCardIcon(),
                    title: 'Time Spent',
                    value: time.available
                        ? formatProjectTime(time.displaySeconds)
                        : '—',
                    caption: time.available
                        ? (time.participant
                              ? 'Your active time'
                              : 'Total participant time')
                        : 'Time tracking unavailable',
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactSummary() => Container(
    key: const ValueKey('project-impact-preview'),
    width: _sectionWidth,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E0E0)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Impact Summary'),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E2E2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ecological Impact', style: AppTypography.helper),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _impactTotal.toStringAsFixed(2),
                    style: AppTypography.pageTitle.copyWith(
                      fontSize: AppTypography.displaySize,
                      color: _green,
                    ),
                  ),
                  const Text('EcoPoints', style: AppTypography.body),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'From ${_impacts.length} recorded impact entries',
                style: AppTypography.helper,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Impact Category Breakdown', style: AppTypography.helper),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 5 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 20) / columns;
            return Wrap(
              spacing: 20,
              runSpacing: 28,
              children: [
                for (final item in <(String, Widget)>[
                  ('Energy', _EnergyImpactIcon()),
                  ('Waste', _WasteImpactIcon()),
                  ('Water', _WaterImpactIcon()),
                  ('Biological Growth', _BioImpactIcon()),
                  ('Education', _EducationImpactIcon()),
                ])
                  SizedBox(
                    width: width,
                    child: _ImpactLabel(
                      label: item.$1,
                      points: _categoryPoints(item.$1),
                      measurements: _impactTotals.measurementsFor(item.$1),
                      icon: item.$2,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    ),
  );

  Widget _buildLearningObjectives() {
    final objectives = _learningObjectives;
    return Container(
      width: _sectionWidth,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Learning Objectives'),
          const SizedBox(height: 16),
          if (objectives.isEmpty)
            const Text(
              'No learning objectives selected.',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                color: AppColors.textSecondary,
              ),
            )
          else
            for (var index = 0; index < objectives.length; index++) ...[
              if (index > 0) const SizedBox(height: 16),
              _ObjectivePreview(
                number: index + 1,
                objective: objectives[index],
              ),
            ],
        ],
      ),
    );
  }

  Future<void> _openRecentEntry(JournalEntry entry) async {
    if (await openFreeNotesIfNeeded(context, entry, _projectsRepo)) {
      if (mounted) await _loadProject();
      return;
    }

    final page = switch (normalizePhase(entry.progress)) {
      'discover'
          when !journalEntryIsComplete(entry) &&
              (_canEditCover ||
                  (entry.authorId != null &&
                      entry.authorId ==
                          AuthService.instance.currentUser?.id)) =>
        DiscoveryObservationEntryPage(
          projectId: widget.projectId,
          projectsRepo: _projectsRepo,
          returnToPhaseDashboard: true,
          entry: entry,
        ),
      'discover' => DiscoveryEntryPreviewPage(entry: entry),
      'ideating' => IdeatingEntryPreviewPage(entry: entry),
      'prototyping'
          when entry.content.whereType<Map>().any(
            (row) => row['entryType'] != null,
          ) =>
        PrototypingJournalEntryPage(
          projectId: widget.projectId,
          projectsRepo: _projectsRepo,
          entry: entry,
          readOnly:
              journalEntryIsComplete(entry) ||
              (!_canEditCover &&
                  entry.authorId != AuthService.instance.currentUser?.id),
        ),
      'prototyping' => PrototypingDashboardPage(
        projectId: widget.projectId,
        isOwner: _canEditCover,
        projectsRepo: _projectsRepo,
      ),
      'implementation' => ImplementationPreviewPage(
        entry: entry,
        projectId: widget.projectId,
        projectsRepo: _projectsRepo,
      ),
      _ => JournalEntryEditorScreen(
        projectId: widget.projectId,
        projectName: _projectName,
        tags: _tags,
        entryId: entry.id,
        initialTitle: entry.title,
        initialContent: entry.content,
        initialProgress: entry.progress,
        readOnly: true,
      ),
    };
    await pushAppRoute(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadProject();
  }

  Future<void> _openActivity(ProjectActivityEvent activity) async {
    if (activity.kind.startsWith('impact_')) {
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => ImpactLogScreen(
            projectId: widget.projectId,
            projectName: _projectName,
            isOwner: _canEditCover,
          ),
        ),
      );
      if (mounted) await _loadProject();
      return;
    }
    if (activity.journalEntryId != null) {
      final entries = await _projectsRepo.getJournalEntries(
        projectId: widget.projectId,
      );
      if (!mounted) return;
      final matches = (entries ?? <JournalEntry>[]).where(
        (e) => e.id == activity.journalEntryId,
      );
      if (matches.isNotEmpty) {
        await _openRecentEntry(matches.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This entry is no longer available.')),
        );
      }
      return;
    }
    if (activity.kind.startsWith('materials') ||
        activity.kind == 'budget_updated') {
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => MaterialsCostPage(
            projectId: widget.projectId,
            projectName: _projectName,
            tags: _tags,
            isOwner: _canEditCover,
          ),
        ),
      );
      if (mounted) await _loadProject();
      return;
    }
    final section =
        activity.kind == 'journal_deleted' ||
            activity.kind == 'journal_draft_deleted'
        ? ProjectDashboardSection.development
        : activity.kind.startsWith('timeline')
        ? ProjectDashboardSection.timeline
        : activity.kind.startsWith('member') ||
              activity.kind.startsWith('forum')
        ? ProjectDashboardSection.collaboration
        : ProjectDashboardSection.overview;
    setState(() {
      _activityNavigationRevision++;
      _activityEventId =
          activity.kind.startsWith('timeline') &&
              activity.kind != 'timeline_removed'
          ? activity.sourceId
          : null;
      _activityCollaborationSection = activity.kind.startsWith('member')
          ? CollaborationSection.members
          : CollaborationSection.bulletin;
      _activityPostId =
          activity.kind.startsWith('forum') &&
              activity.kind != 'forum_post_deleted'
          ? activity.sourceId
          : null;
      _selectedTab = section;
      _visitedTabs.add(section);
    });
  }

  Widget _buildRecentActivity() => ProjectActivityFeed(
    projectId: widget.projectId,
    repo: _projectsRepo,
    entries: _developmentSummary.entries,
    onOpen: _openActivity,
  );
}

class _ProjectNameTag extends StatelessWidget {
  const _ProjectNameTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _ProjectDashboardState._green,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Text(
        'PROJECT DASHBOARD',
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.bodyFamily,
          color: Colors.white,
          fontSize: AppTypography.bodySize,
          height: 1,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.text, {this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: active ? _ProjectDashboardState._green : Colors.grey,
        fontSize: AppTypography.helperSize,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder({this.onAddPhoto});
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.avatarBackground,
      alignment: Alignment.center,
      child: onAddPhoto == null
          ? const Icon(
              Icons.landscape_outlined,
              size: 42,
              color: AppColors.avatarIcon,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.landscape_outlined,
                  size: 42,
                  color: AppColors.avatarIcon,
                ),
                const SizedBox(height: 10),
                const Text('Tap to add a photo', style: AppTypography.helper),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'You can change this photo later in Project Settings.',
                    textAlign: TextAlign.center,
                    style: AppTypography.helper,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.sectionTitle);
  }
}

class _BasicColumn extends StatelessWidget {
  const _BasicColumn({
    required this.heading,
    required this.icon,
    required this.value,
  });
  final String heading;
  final Widget icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetaHeading(heading),
        const SizedBox(height: 10),
        SizedBox(
          height: 43,
          child: Center(
            child: SizedBox(
              width: 49,
              height: 43,
              child: FittedBox(fit: BoxFit.scaleDown, child: icon),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _MetaValue(value),
      ],
    );
  }
}

class _MetaHeading extends StatelessWidget {
  const _MetaHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFA5A5A5),
        fontSize: AppTypography.helperSize,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _MetaValue extends StatelessWidget {
  const _MetaValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: AppTypography.bodyFamily,
        color: _ProjectDashboardState._text,
        fontSize: AppTypography.bodySize,
        height: 1.4,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    this.showChevron = false,
    this.onTap,
  });

  final Widget icon;
  final String title;
  final String value;
  final String caption;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width:
          (((JournalPageLayout.widthFor(context, mobileWidth: 402) - 44).clamp(
                        0.0,
                        620.0,
                      ) -
                      32) /
                  3)
              .clamp(0.0, 148.0),
      height: 122,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDED7D7)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121C1C1C),
            blurRadius: 40,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(width: 32, height: 32, child: icon),
          const SizedBox(height: 11),
          Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: AppColors.textSecondary,
              fontSize: AppTypography.helperSize,
              height: 1,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: _ProjectDashboardState._green,
                    fontSize: AppTypography.bodySize,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 13,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  caption,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    color: AppColors.textSecondary,
                    fontSize: AppTypography.helperSize,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.16,
                  ),
                ),
                if (showChevron)
                  Positioned(
                    right: 6,
                    child: Icon(
                      Icons.chevron_right,
                      color: Color(0xFF838383),
                      size: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return AppTapTarget(onTap: onTap, child: card);
  }
}

class _ImpactLabel extends StatelessWidget {
  const _ImpactLabel({
    required this.label,
    required this.icon,
    required this.points,
    this.measurements = const [],
  });
  final double points;
  final List<String> measurements;

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          SizedBox(width: 31, height: 31, child: icon),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                color: AppColors.textSecondary,
                fontSize: AppTypography.helperSize,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            points.toStringAsFixed(points == points.roundToDouble() ? 0 : 2),
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _ProjectDashboardState._green,
              fontSize: AppTypography.bodySize,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Text(
            'EcoPoints',
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _ProjectDashboardState._green,
              fontSize: AppTypography.captionSize,
              height: 1.4,
            ),
          ),
          if (measurements.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                measurements.join(' · '),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.helper,
              ),
            ),
        ],
      ),
    );
  }
}

class _JournalCardIcon extends StatelessWidget {
  const _JournalCardIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _JournalIconPainter());
  }
}

class _MoneyCardIcon extends StatelessWidget {
  const _MoneyCardIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _ProjectDashboardState._green, width: 1.3),
      ),
      child: const Center(
        child: Text(
          '\$',
          style: TextStyle(
            fontFamily: AppTypography.headingFamily,
            color: _ProjectDashboardState._green,
            fontSize: AppTypography.sectionTitleSize,
            height: 1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _TimeCardIcon extends StatelessWidget {
  const _TimeCardIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TimeIconPainter());
  }
}

class _EnergyImpactIcon extends StatelessWidget {
  const _EnergyImpactIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/impact_energy.svg',
      fit: BoxFit.contain,
    );
  }
}

class _WasteImpactIcon extends StatelessWidget {
  const _WasteImpactIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/impact_waste.svg',
      fit: BoxFit.contain,
    );
  }
}

class _WaterImpactIcon extends StatelessWidget {
  const _WaterImpactIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/impact_water.svg',
      fit: BoxFit.contain,
    );
  }
}

class _BioImpactIcon extends StatelessWidget {
  const _BioImpactIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/impact_bio.svg',
      fit: BoxFit.contain,
    );
  }
}

class _EducationImpactIcon extends StatelessWidget {
  const _EducationImpactIcon();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/project_setup/impact_education.svg',
      fit: BoxFit.contain,
    );
  }
}

abstract class _LineIconPainter extends CustomPainter {
  _LineIconPainter(this.color);

  final Color color;

  Paint get stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JournalIconPainter extends _LineIconPainter {
  _JournalIconPainter() : super(_ProjectDashboardState._green);

  @override
  void paint(Canvas canvas, Size size) {
    final outline = stroke;
    final rect = Rect.fromLTWH(
      size.width * .21,
      size.height * .13,
      size.width * .58,
      size.height * .74,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide * .10)),
      outline,
    );
    final bookmark = Path()
      ..moveTo(rect.left + rect.width * .19, rect.top)
      ..lineTo(rect.left + rect.width * .19, rect.top + rect.height * .35)
      ..lineTo(rect.left + rect.width * .285, rect.top + rect.height * .29)
      ..lineTo(rect.left + rect.width * .38, rect.top + rect.height * .35)
      ..lineTo(rect.left + rect.width * .38, rect.top);
    canvas.drawPath(bookmark, stroke..strokeWidth = 1);
  }
}

class _TimeIconPainter extends _LineIconPainter {
  _TimeIconPainter() : super(_ProjectDashboardState._green);

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    final c = size.center(Offset.zero);
    canvas.drawCircle(c, size.shortestSide * .43, s);
    canvas.drawLine(c, Offset(c.dx, size.height * .27), s);
    canvas.drawLine(c, Offset(size.width * .65, size.height * .62), s);
  }
}

String _formatDashboardCurrency(double value) =>
    '\$${value.toStringAsFixed(2)}';

class _ObjectivePreview extends StatelessWidget {
  const _ObjectivePreview({required this.number, required this.objective});
  final int number;
  final ProjectObjectiveSummary objective;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ProjectDashboardState._green,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: Colors.white,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            objective.description,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: _ProjectDashboardState._text,
              fontSize: AppTypography.bodySize,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
