import '../../site/pages/site_information_page.dart';
import '../../../shared/widgets/explore_project_card.dart';
import '../../../shared/widgets/account_required_prompt.dart';
import 'public_community.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../services/project_recommendations.dart';
import 'package:flutter/cupertino.dart';
import '../../../backend/db/models/community.dart';
import '../../../backend/db/repositories/communities_repo.dart';
import '../../community/pages/community_home_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/gestures.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../../shared/widgets/confirm_project_deletion.dart';
import 'package:flutter/material.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/project.dart';
import '../../../backend/db/models/user_profile.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../shared/styling/app_colors.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/project_filter_sheet.dart';
import '../../../shared/widgets/top_snack_bar.dart';
import '../../project/pages/project_dashboard.dart';

String browsePhase(String value) => switch (value.trim().toLowerCase()) {
  'discovering' || 'discover' || 'discovery' => 'discover',
  'ideating' || 'ideation' => 'ideating',
  'prototyping' || 'prototype' || 'testing & iterating' => 'prototyping',
  'implemented' || 'implementation' => 'implementation',
  _ => value.toLowerCase(),
};
bool projectMatchesBrowse(
  Project project, {
  String query = '',
  String? projectPhase,
  Set<String> subjects = const {},
  Set<String> phases = const {},
  Set<String> scales = const {},
  Set<String> difficulties = const {},
  Set<String> projectTypes = const {},
}) {
  if (!matchesProjectType(project.projectType, projectTypes)) return false;
  final text =
      '${project.projectName} ${project.problemStatement ?? ''} ${project.tags.join(' ')}'
          .toLowerCase();
  if (query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .any((word) => !text.contains(word)))
    return false;
  final domains = {
    if (project.subjectDomain != null) project.subjectDomain!,
    ...project.tags.map((tag) => tag.split('|').first.trim()),
  };
  if (subjects.isNotEmpty && !subjects.any(domains.contains)) return false;
  final values = {
    if (projectPhase != null || project.progress != null)
      browsePhase(projectPhase ?? project.progress!),
    if (projectPhase == null && project.progress == null)
      ...project.journalProgressValues.map(browsePhase),
  };
  if (phases.isNotEmpty && !phases.map(browsePhase).any(values.contains))
    return false;
  if (scales.isNotEmpty && !scales.contains(project.projectScale)) return false;
  if (difficulties.isNotEmpty && !difficulties.contains(project.difficulty))
    return false;
  return true;
}

/// Shared search and cards keep Explore and the personal library consistent.
class ProjectBrowsePage extends StatefulWidget {
  const ProjectBrowsePage({
    super.key,
    this.library = false,
    this.publicLanding = false,
    this.onSignIn,
    this.projectsRepo,
    this.initialSubject,
    this.communitiesRepo,
    this.communityId,
  });
  final String? communityId;
  final CommunitiesRepo? communitiesRepo;
  final bool library;
  final bool publicLanding;
  final VoidCallback? onSignIn;
  final String? initialSubject;
  final ProjectsRepo? projectsRepo;
  @override
  State<ProjectBrowsePage> createState() => ProjectBrowsePageState();
}

class ProjectBrowsePageState extends State<ProjectBrowsePage> {
  late final _repo = widget.projectsRepo ?? ProjectsRepo();
  final _search = TextEditingController();
  final _filters = <String, Set<String>>{
    'Project Type': {},
    'Subject': {},
    'Scale': {},
    'Difficulty': {},
    'Metrics': {},
    'Impact': {},
    'Pattern': {},
  };
  List<Project> _projects = [];
  List<Project> _recommendationHistory = [];
  Map<String, List<UserProfile>> _people = {};
  Set<String> _bookmarks = {};
  Map<String, int> _counts = {};
  Map<String, Map<String, Set<String>>> _impactValues = {};
  final Set<String> _saving = {};
  bool _communitiesMode = false;
  Future<List<Community>>? _communities;
  bool _onlyBookmarks = false;
  bool _loading = true;
  bool _error = false;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    try {
      final projects = widget.communityId != null
          ? await _repo.getLinkedCommunityProjects(widget.communityId!)
          : widget.library
          ? {
              for (final p in [
                ...await _repo.getLibraryProjects(),
                ...await _repo.getBookmarkedProjects(),
              ])
                p.id: p,
            }.values.toList()
          : await _repo.projectsWithCompletedJournalEntries(
              await _repo.getExploreProjects(),
            );
      final history = widget.library || widget.publicLanding
          ? <Project>[]
          : await _loadRecommendationHistory();
      final ids = projects.map((p) => p.id).toList();
      final impactValues = await _repo.getProjectImpactFilterValues(ids);
      final counts = await _repo.getJournalEntryCounts(
        ids,
        completedOnly: !widget.library,
      );
      final bookmarks = widget.publicLanding || ids.isEmpty
          ? <String>{}
          : await _repo.getBookmarkedProjectIds(projectIds: ids);
      final people = widget.publicLanding || ids.isEmpty
          ? <String, List<UserProfile>>{}
          : await _repo.getCollaboratorsForProjects(projectIds: ids);
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _recommendationHistory = history;
        _counts = counts;
        _impactValues = impactValues;
        _bookmarks = bookmarks;
        _people = people;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = true;
        });
    }
  }

  Future<List<Project>> _loadRecommendationHistory() async {
    try {
      return [
        ...await _repo.getLibraryProjects(),
        ...await _repo.getBookmarkedProjects(),
      ];
    } catch (_) {
      // Discovery still works if optional personalization signals are unavailable.
      return [];
    }
  }

  String? _phaseForProject(Project project) {
    if (project.progress?.isNotEmpty == true) return project.progress;
    final phases = (_impactValues[project.id]?['Phase'] ?? {})
        .map(browsePhase)
        .toSet();
    for (final phase in [
      'implementation',
      'prototyping',
      'ideating',
      'discover',
    ]) {
      if (phases.contains(phase)) return phase;
    }
    return null;
  }

  List<Project> get _filtered => _projects
      .where(
        (p) =>
            (!_onlyBookmarks || _bookmarks.contains(p.id)) &&
            (widget.initialSubject == null ||
                projectMatchesBrowse(p, subjects: {widget.initialSubject!})) &&
            projectMatchesBrowse(
              p,
              query: _search.text,
              projectPhase: _phaseForProject(p),
              subjects: _filters['Subject']!,
              scales: _filters['Scale']!,
              difficulties: _filters['Difficulty']!,
              projectTypes: _filters['Project Type']!,
            ) &&
            ['Metrics', 'Impact', 'Pattern'].every(
              (group) =>
                  _filters[group]!.isEmpty ||
                  _filters[group]!.any(
                    (_impactValues[p.id]?[group] ?? {}).contains,
                  ),
            ),
      )
      .toList();
  bool get _searching =>
      _search.text.trim().isNotEmpty ||
      _onlyBookmarks ||
      _filters.values.any((f) => f.isNotEmpty);
  void _filter(String title) {
    final options = switch (title) {
      'Project Type' => kProjectTypeOptions,
      'Subject' => kSubjectOptions,
      'Scale' => kScaleOptions,
      'Difficulty' => kDifficultyOptions,
      'Metrics' => kMetricOptions,
      'Impact' => kImpactOptions,
      _ => kPatternOptions,
    };
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProjectFilterSheet(
        title: title,
        options: options,
        initialSelected: _filters[title]!,
        onApply: (values) => setState(() => _filters[title] = values),
      ),
    );
  }

  Future<void> _bookmark(Project project) async {
    if (_repo.currentUserId == null) {
      await showAccountRequiredPrompt(context);
      return;
    }
    if (_saving.contains(project.id)) return;
    setState(() => _saving.add(project.id));
    final saved = _bookmarks.contains(project.id);
    final ok = saved
        ? await _repo.unbookmarkProject(id: project.id)
        : await _repo.bookmarkProject(id: project.id);
    if (!mounted) return;
    setState(() {
      _saving.remove(project.id);
      if (ok) {
        saved ? _bookmarks.remove(project.id) : _bookmarks.add(project.id);
      }
    });
    if (!ok) {
      showTopSnackBar(context, 'Could not update bookmark', isError: true);
    } else if (!widget.library) {
      final history = await _loadRecommendationHistory();
      if (mounted) setState(() => _recommendationHistory = history);
    }
  }

  bool _owns(Project project) =>
      !widget.publicLanding &&
      project.userId != null &&
      project.userId == _repo.currentUserId;

  final Set<String> _deleting = {};
  Future<void> _delete(Project project) async {
    if (!_owns(project) || !_deleting.add(project.id)) return;
    try {
      if (!await confirmProjectDeletion(context) || !mounted) return;
      final deleted = await _repo.deleteProject(id: project.id);
      if (!mounted) return;
      if (deleted) {
        setState(() {
          _projects.removeWhere((p) => p.id == project.id);
          _bookmarks.remove(project.id);
          _counts.remove(project.id);
          _people.remove(project.id);
        });
        showTopSnackBar(context, 'Project deleted');
      } else {
        showTopSnackBar(context, 'Failed to delete project', isError: true);
      }
    } finally {
      _deleting.remove(project.id);
    }
  }

  Future<void> _open(Project project) async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDashboard(
          projectId: project.id,
          projectName: project.projectName,
          tags: project.tags,
          isOwner:
              !widget.publicLanding &&
              project.userId != null &&
              project.userId == AuthService.instance.currentUser?.id,
          projectsRepo: _repo,
        ),
      ),
    );
    if (mounted) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    if (widget.initialSubject != null) return _subjectCollection(filtered);
    if (!widget.library && widget.initialSubject == null)
      return _exploreBody(filtered);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search for projects',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              if (widget.library) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Bookmarked projects',
                  onPressed: () =>
                      setState(() => _onlyBookmarks = !_onlyBookmarks),
                  icon: Icon(
                    _onlyBookmarks ? Icons.bookmark : Icons.bookmark_border,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _filterRow(),
        ),
        if (_filters.values.any((f) => f.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final group in _filters.entries)
                  for (final value in group.value)
                    InputChip(
                      label: Text(value),
                      onDeleted: () =>
                          setState(() => group.value.remove(value)),
                    ),
                TextButton(
                  onPressed: () => setState(() {
                    for (final f in _filters.values) {
                      f.clear();
                    }
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : AppRefreshIndicator(
                  onRefresh: reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                    children: [
                      if (_error)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Could not load projects. Pull down to retry.',
                          ),
                        )
                      else if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              Text(
                                _searching
                                    ? 'No matching projects'
                                    : 'No projects yet',
                                style: AppTypography.sectionTitle,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searching
                                    ? 'Try another search or adjust your filters.'
                                    : 'Projects will appear here as new work is shared.',
                                style: AppTypography.helper,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else if (widget.library ||
                          widget.initialSubject != null ||
                          _searching) ...[
                        if (_searching)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${filtered.length} projects',
                              style: AppTypography.helper,
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final desktop =
                                MediaQuery.sizeOf(context).width >= 1000;
                            final cardWidth = desktop
                                ? constraints.maxWidth.clamp(0.0, 280.0)
                                : constraints.maxWidth;
                            return Wrap(
                              spacing: 16,
                              alignment: desktop
                                  ? WrapAlignment.center
                                  : WrapAlignment.start,
                              children: [
                                for (final project in filtered)
                                  SizedBox(
                                    width: cardWidth,
                                    child: _card(project),
                                  ),
                              ],
                            );
                          },
                        ),
                      ] else ...[
                        for (final project in filtered) _card(project),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _subjectCollection(List<Project> projects) => AppRefreshIndicator(
    onRefresh: reload,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error)
          TextButton(
            onPressed: reload,
            child: const Text('Could not load projects. Try again.'),
          )
        else if (projects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Text(
              'No public projects in this subject yet.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Text('${projects.length} projects', style: AppTypography.helper),
          const SizedBox(height: 16),
          _projectGrid(projects),
        ],
      ],
    ),
  );

  Widget _exploreBody(List<Project> filtered) => AppRefreshIndicator(
    onRefresh: () async {
      if (_communitiesMode) {
        final future = (widget.communitiesRepo ?? CommunitiesRepo())
            .getAllCommunities();
        setState(() => _communities = future);
        await future;
      } else {
        await reload();
      }
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      children: [
        if (widget.publicLanding && widget.communityId == null) ...[
          const SizedBox(height: 24),
          const Text(
            'Innovate Ideas. Projects built together.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF24543C),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Discover sustainability projects, follow the process, and find communities learning together.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF667269),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!widget.publicLanding && widget.communityId == null)
          const Text(
            'Find projects and communities.',
            textAlign: TextAlign.center,
            style: AppTypography.helper,
          ),
        const SizedBox(height: 24),
        if (widget.communityId == null)
          Center(
            child: CupertinoSlidingSegmentedControl<bool>(
              groupValue: _communitiesMode,
              children: const {
                false: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Projects'),
                ),
                true: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text('Communities'),
                ),
              },
              onValueChanged: (value) {
                if (value == null) return;
                setState(() {
                  _communitiesMode = value;
                  if (value)
                    _communities ??=
                        (widget.communitiesRepo ?? CommunitiesRepo())
                            .getAllCommunities();
                });
              },
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _communitiesMode
                ? 'Search communities'
                : 'Search projects',
            prefixIcon: const Icon(Icons.search, size: 28),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                child: const Text('Search'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_communitiesMode) ...[
          const SizedBox(height: 24),
          _communityResults(),
        ] else ...[
          const SizedBox(height: 12),
          _filterRow(),
          if (_searching) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final group in _filters.entries)
                  for (final value in group.value)
                    InputChip(
                      label: Text(value),
                      onDeleted: () =>
                          setState(() => group.value.remove(value)),
                    ),
                TextButton(
                  onPressed: () => setState(() {
                    _search.clear();
                    for (final values in _filters.values) {
                      values.clear();
                    }
                  }),
                  child: const Text('Clear search and filters'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          if (!_searching && widget.communityId == null) ...[
            const Text('Explore by subject', style: AppTypography.sectionTitle),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 4
                    : constraints.maxWidth >= 400
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final subject in const [
                      (
                        'Environment & Sustainability',
                        'environment',
                        Color(0xFF12B85A),
                      ),
                      (
                        'Engineering & Design',
                        'engineering',
                        Color(0xFF009ECB),
                      ),
                      ('Energy & Systems', 'energy', Color(0xFFE0B900)),
                      (
                        'Community & Built Environment',
                        'community',
                        Color(0xFFE85870),
                      ),
                    ])
                      SizedBox(
                        width: width,
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openSubject(subject.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 24,
                              ),
                              child: Column(
                                children: [
                                  SvgPicture.asset(
                                    'assets/project_setup/subject_${subject.$2}.svg',
                                    width: 36,
                                    height: 36,
                                    colorFilter: ColorFilter.mode(
                                      subject.$3,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 48,
                                    child: Center(
                                      child: Text(
                                        subject.$1,
                                        textAlign: TextAlign.center,
                                        style: AppTypography.fieldLabel,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'View projects',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          Text(
            _searching
                ? '${filtered.length} projects'
                : widget.communityId != null
                ? 'Community projects'
                : 'Recent public projects',
            style: AppTypography.sectionTitle,
          ),
          const SizedBox(height: 8),
          if (!_searching)
            const Text(
              'Latest activity from the community.',
              style: AppTypography.helper,
            ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error)
            TextButton(
              onPressed: reload,
              child: const Text('Could not load projects. Try again.'),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                _searching
                    ? 'No matching projects. Try another search or adjust your filters.'
                    : 'Public projects will appear here as new work is shared.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            _projectGrid(
              _searching || widget.publicLanding || widget.communityId != null
                  ? filtered
                  : filtered.take(4).toList(),
            ),
            if (!_searching &&
                !widget.publicLanding &&
                widget.communityId == null) ...[
              const SizedBox(height: 28),
              const Text(
                'Recommended projects',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 8),
              Text(
                _recommendationHistory.isEmpty
                    ? 'Recent public projects to help you discover your interests.'
                    : 'Based on the subjects and topics in your projects and bookmarks.',
                style: AppTypography.helper,
              ),
              const SizedBox(height: 16),
              _recommendedGrid(filtered),
            ],
          ],
        ],
        if (widget.publicLanding && widget.communityId == null)
          const SiteFooter(),
      ],
    ),
  );

  Widget _recommendedGrid(List<Project> candidates) {
    final recommendations = recommendProjects(
      candidates: candidates,
      history: _recommendationHistory,
      userId: _repo.currentUserId,
    );
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }
    return _projectGrid(recommendations.take(4).toList());
  }

  Widget _projectGrid(List<Project> projects) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560
          ? ((constraints.maxWidth + 16) / 296).floor().clamp(2, 6)
          : 1;
      final width = ((constraints.maxWidth - (columns - 1) * 16) / columns)
          .clamp(0.0, 320.0);
      return Wrap(
        spacing: 16,
        children: [
          for (final project in projects)
            SizedBox(width: width, child: _card(project)),
        ],
      );
    },
  );

  void _openSubject(String subject) {
    pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(subject, style: AppTypography.pageTitle),
            centerTitle: true,
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
          ),
          body: ProjectBrowsePage(
            initialSubject: subject,
            publicLanding: widget.publicLanding,
            onSignIn: widget.onSignIn,
            projectsRepo: _repo,
          ),
        ),
      ),
    );
  }

  Widget _filterRow() => widget.publicLanding
      ? Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [for (final title in _filters.keys) _filterChip(title)],
        )
      : LayoutBuilder(
          builder: (context, constraints) => ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final title in _filters.keys) ...[
                      _filterChip(title),
                      if (title != _filters.keys.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );

  Widget _filterChip(String title) => ActionChip(
    shape: const StadiumBorder(),
    backgroundColor: AppColors.primary,
    labelStyle: AppTypography.button.copyWith(color: Colors.white),
    label: Text(
      '$title${_filters[title]!.isEmpty ? '' : ' (${_filters[title]!.length})'}',
    ),
    onPressed: () => _filter(title),
  );

  Widget _communityResults() => FutureBuilder<List<Community>>(
    future: _communities,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return TextButton(
          onPressed: () => setState(() {
            _communities = (widget.communitiesRepo ?? CommunitiesRepo())
                .getAllCommunities();
          }),
          child: const Text('Could not load communities. Try again.'),
        );
      final query = _search.text.trim().toLowerCase();
      final communities = (snapshot.data ?? [])
          .where(
            (community) =>
                community.visibility.toLowerCase() == 'public' &&
                '${community.name} ${community.subjectFocus ?? ''}'
                    .toLowerCase()
                    .contains(query),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Public communities', style: AppTypography.sectionTitle),
          const SizedBox(height: 16),
          if (communities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No matching communities.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final community in communities)
            Card(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: community.bannerColor,
                  backgroundImage: community.imageUrl?.isNotEmpty == true
                      ? NetworkImage(community.imageUrl!)
                      : null,
                  child: community.imageUrl?.isNotEmpty == true
                      ? null
                      : const Icon(Icons.groups_outlined, color: Colors.white),
                ),
                title: Text(community.name),
                subtitle: community.subjectFocus?.isNotEmpty == true
                    ? Text(community.subjectFocus!)
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => pushAppRoute(
                  context,
                  MaterialPageRoute(
                    builder: (_) => widget.publicLanding
                        ? PublicCommunityScreen(community: community)
                        : CommunityHomeScreen(community: community),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _card(Project project) => ExploreProjectCard(
    project: project,
    onOpen: () => _open(project),
    onBookmark: () => _bookmark(project),
    onDelete: _owns(project) ? () => _delete(project) : null,
    people: _people[project.id] ?? const [],
    bookmarked: _bookmarks.contains(project.id),
    saving: _saving.contains(project.id),
    entryCount: _counts[project.id],
  );
}
