import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/project/pages/materials_cost.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';
import 'package:juniper_journal/src/features/project/pages/project_timeline_tab.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ProjectDashboard extends StatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> tags;
  final bool isOwner;
  final String? challengeId;
  final ProjectsRepo? projectsRepo;
  final List<ProjectObjectiveSummary> learningObjectives;

  const ProjectDashboard({
    super.key,
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

enum _DashboardTab { overview, development, timeline }

class _ProjectDashboardState extends State<ProjectDashboard> {
  static const _green = Color(0xFF5DB075);
  static const _text = Color(0xFF1C1C1C);
  static const _canvasWidth = 402.0;

  late final ProjectsRepo _projectsRepo;
  late String _projectName;
  late List<String> _tags;
  String? _imageUrl;
  String? _difficulty;
  String? _projectScale;
  double _materialsTotal = 0;
  int _materialsCount = 0;
  DevelopmentSummary _developmentSummary = DevelopmentSummary.empty();
  bool _isLoading = true;
  _DashboardTab _selectedTab = _DashboardTab.overview;

  @override
  void initState() {
    super.initState();
    _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
    _projectName = widget.projectName;
    _tags = List<String>.from(widget.tags);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProject();
    });
  }

  Future<void> _loadProject() async {
    final project = await _projectsRepo.getProjectById(widget.projectId);
    final materials = await _projectsRepo.getMaterialsCost(widget.projectId);
    final entries = await _projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;

    setState(() {
      if (project != null) {
        _projectName = project.projectName.isNotEmpty
            ? project.projectName
            : _projectName;
        _tags = project.tags.isNotEmpty ? project.tags : _tags;
        _imageUrl = project.imageUrl;
        _difficulty = project.difficulty;
        _projectScale = project.projectScale;
      }
      _updateMaterialsSummary(materials ?? const []);
      _developmentSummary = DevelopmentSummary.fromEntries(entries ?? const []);
      _isLoading = false;
    });
  }

  Future<void> _reloadDevelopmentSummary() async {
    final entries = await _projectsRepo.getJournalEntries(
      projectId: widget.projectId,
    );
    if (!mounted) return;
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _canvasWidth),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: switch (_selectedTab) {
                      _DashboardTab.timeline => SizedBox(
                        width: _canvasWidth,
                        height: 852,
                        child: Stack(
                          children: [
                            _buildHeader(context),
                            _buildTabs(),
                            ProjectTimelineTab(
                              projectId: widget.projectId,
                              isOwner: widget.isOwner,
                              projectsRepo: _projectsRepo,
                            ),
                          ],
                        ),
                      ),
                      _DashboardTab.development => SizedBox(
                        width: _canvasWidth,
                        height: 760,
                        child: Stack(
                          children: [
                            _buildHeader(context),
                            _buildTabs(),
                            ProjectDevelopmentTab(
                              projectId: widget.projectId,
                              isOwner: widget.isOwner,
                              summary: _developmentSummary,
                              onChanged: _reloadDevelopmentSummary,
                              projectsRepo: _projectsRepo,
                            ),
                          ],
                        ),
                      ),
                      _DashboardTab.overview => SizedBox(
                        width: _canvasWidth,
                        height: 1716,
                        child: Stack(
                          children: [
                            _buildHeader(context),
                            _buildTabs(),
                            _buildHero(),
                            _buildDevelopmentProgress(),
                            _buildProjectBasics(),
                            _buildImpactSummary(),
                            _buildLearningObjectives(),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
                    },
                  ),
          ),
        ),
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
          height: 22,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Done',
                style: TextStyle(
                  color: _green,
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 89,
          top: 19,
          width: 215,
          height: 40,
          child: const _ProjectNameTag(),
        ),
        Positioned(
          right: 29,
          top: 19,
          width: 35,
          height: 35,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openSettings,
            child: SvgPicture.asset(
              'assets/learning_module/dashboard_settings.svg',
              width: 35,
              height: 35,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSettings() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (widget.isOwner)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFD64545),
                ),
                title: const Text(
                  'Delete Project',
                  style: TextStyle(
                    color: Color(0xFFD64545),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop('delete'),
              )
            else
              const ListTile(
                title: Text('No settings available.'),
                enabled: false,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'delete') await _deleteProject();
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Project?'),
        content: const Text(
          'This permanently deletes the project and all of its journal '
          'entries, impacts and materials. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFD64545)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _projectsRepo.deleteProject(id: widget.projectId);
    if (!mounted) return;
    if (ok) {
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
        const Positioned(
          left: 0,
          top: 121,
          width: 402,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
        ),
        Positioned(
          left: switch (selected) {
            _DashboardTab.overview => 22,
            _DashboardTab.development => 151,
            _DashboardTab.timeline => 298,
          },
          top: 121,
          width: selected == _DashboardTab.development ? 103 : 75,
          child: const Divider(height: 1, thickness: 1, color: _green),
        ),
        Positioned(
          left: 26,
          top: 95,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedTab = _DashboardTab.overview),
            child: _TabLabel(
              'Overview',
              active: selected == _DashboardTab.overview,
            ),
          ),
        ),
        Positioned(
          left: 158,
          top: 95,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                setState(() => _selectedTab = _DashboardTab.development),
            child: _TabLabel(
              'Development',
              active: selected == _DashboardTab.development,
            ),
          ),
        ),
        Positioned(
          left: 306,
          top: 95,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _selectedTab = _DashboardTab.timeline),
            child: _TabLabel(
              'Timeline',
              active: selected == _DashboardTab.timeline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    return Stack(
      children: [
        Positioned(
          left: 52,
          top: 140,
          width: 283,
          height: 255,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: hasImage
                ? Image.network(
                    _imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _HeroPlaceholder(),
                  )
                : const _HeroPlaceholder(),
          ),
        ),
        Positioned(
          left: 26,
          top: 438,
          width: 349,
          child: Text(
            _projectName,
            style: const TextStyle(
              color: _text,
              fontSize: 24,
              height: 29 / 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevelopmentProgress() {
    final furthestPhase = _developmentSummary.furthestPhase;
    return Stack(
      children: [
        const Positioned(
          left: 22,
          top: 498,
          child: _SectionTitle('Development Progress'),
        ),
        const Positioned(
          left: 64,
          top: 553,
          width: 256,
          child: _ProgressTrack(),
        ),
        Positioned(
          left: 1,
          top: 553,
          child: _ProgressBubble(
            number: '1',
            label: 'Discover',
            active: furthestPhase >= 1,
          ),
        ),
        Positioned(
          left: 98,
          top: 553,
          child: _ProgressBubble(
            number: '2',
            label: 'Ideating',
            active: furthestPhase >= 2,
          ),
        ),
        Positioned(
          left: 194,
          top: 554,
          child: _ProgressBubble(
            number: '3',
            label: 'Prototyping',
            active: furthestPhase >= 3,
          ),
        ),
        Positioned(
          left: 291,
          top: 554,
          child: _ProgressBubble(
            number: '4',
            label: 'Implementation',
            active: furthestPhase >= 4,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectBasics() {
    return Stack(
      children: [
        const Positioned(
          left: 22,
          top: 648,
          child: _SectionTitle('Project Basics'),
        ),
        const Positioned(
          left: 25,
          top: 675,
          width: 357,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
        ),
        const Positioned(left: 45, top: 684, child: _MetaHeading('Subject')),
        Positioned(
          left: 58,
          top: 711,
          child: SvgPicture.asset(
            'assets/project_setup/subject_environment.svg',
            width: 43,
            height: 43,
          ),
        ),
        Positioned(left: 34, top: 762, width: 90, child: _MetaValue(_subject)),
        const Positioned(
          left: 170,
          top: 684,
          child: _MetaHeading('Difficulty'),
        ),
        Positioned(
          left: 181,
          top: 721,
          child: SvgPicture.asset(
            'assets/project_setup/difficulty_moderate.svg',
            width: 49,
            height: 25,
          ),
        ),
        Positioned(
          left: 170,
          top: 762,
          width: 72,
          child: _MetaValue(_difficulty ?? 'Not set'),
        ),
        const Positioned(left: 317, top: 684, child: _MetaHeading('Scale')),
        Positioned(
          left: 317,
          top: 714,
          child: SvgPicture.asset(
            'assets/project_setup/scale_small.svg',
            width: 43,
            height: 43,
          ),
        ),
        Positioned(
          left: 310,
          top: 762,
          width: 58,
          child: _MetaValue(_projectScale ?? 'Not set'),
        ),
        const Positioned(
          left: 25,
          top: 807,
          width: 357,
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE1E1E1)),
        ),
        Positioned(
          left: 10,
          top: 831,
          child: _StatCard(
            icon: const _JournalCardIcon(),
            title: 'Journal Entries',
            value: '${_developmentSummary.totalEntries}',
            caption: 'Across all phases',
          ),
        ),
        Positioned(
          left: 141,
          top: 831,
          child: _StatCard(
            icon: const _MoneyCardIcon(),
            title: 'Materials & Cost',
            value: _formatDashboardCurrency(_materialsTotal),
            caption:
                '$_materialsCount ${_materialsCount == 1 ? 'item' : 'items'}',
            showChevron: true,
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => MaterialsCostPage(
                    projectId: widget.projectId,
                    projectName: _projectName,
                    tags: _tags,
                    isOwner: widget.isOwner,
                  ),
                ),
              );
              if (changed == true) {
                final materials = await _projectsRepo.getMaterialsCost(
                  widget.projectId,
                );
                if (!mounted) return;
                setState(() => _updateMaterialsSummary(materials ?? const []));
              }
            },
          ),
        ),
        const Positioned(
          left: 272,
          top: 831,
          child: _StatCard(
            icon: _TimeCardIcon(),
            title: 'Time Spent',
            value: '12.4 hrs',
            caption: 'Across all phases',
          ),
        ),
      ],
    );
  }

  Widget _buildImpactSummary() {
    return Stack(
      children: [
        Positioned(
          left: 22,
          top: 987,
          width: 347,
          height: 340,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const Positioned(
          left: 50,
          top: 999,
          child: _SectionTitle('Impact Summary'),
        ),
        Positioned(
          left: 50,
          top: 1029,
          width: 295,
          height: 115,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E2E2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ecological Impact',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      height: 18 / 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '0.00',
                        style: TextStyle(
                          color: _green,
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'EcoPoints',
                          style: TextStyle(
                            color: _green,
                            fontSize: 20,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  Text(
                    'From 0 implementation entries',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 39,
          top: 1160,
          child: Text(
            'Impact Category Breakdown',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
              height: 18 / 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Positioned(
          left: 37,
          top: 1194,
          child: _ImpactLabel(label: 'Energy', icon: _EnergyImpactIcon()),
        ),
        const Positioned(
          left: 103,
          top: 1194,
          child: _ImpactLabel(label: 'Waste', icon: _WasteImpactIcon()),
        ),
        const Positioned(
          left: 166,
          top: 1194,
          child: _ImpactLabel(label: 'Water', icon: _WaterImpactIcon()),
        ),
        const Positioned(
          left: 226,
          top: 1194,
          child: _ImpactLabel(label: 'BioGrowth', icon: _BioImpactIcon()),
        ),
        const Positioned(
          left: 295,
          top: 1194,
          child: _ImpactLabel(
            label: 'Educational',
            icon: _EducationImpactIcon(),
          ),
        ),
      ],
    );
  }

  Widget _buildLearningObjectives() {
    final objectives = widget.learningObjectives;
    return Stack(
      children: [
        Positioned(
          left: 22,
          top: 1360,
          width: 347,
          height: 143,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const Positioned(
          left: 47,
          top: 1371,
          child: _SectionTitle('Learning Objectives'),
        ),
        if (objectives.isEmpty)
          const Positioned(
            left: 45,
            top: 1408,
            width: 300,
            child: Text(
              'No learning objectives selected.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          )
        else
          for (var index = 0; index < objectives.take(2).length; index++)
            _ObjectivePreview(
              top: index == 0 ? 1400 : 1447,
              number: index + 1,
              objective: objectives[index],
            ),
      ],
    );
  }

  JournalEntry? _mostRecentEntry() {
    final entries = _developmentSummary.entries;
    if (entries.isEmpty) return null;
    final sorted = [...entries]
      ..sort((a, b) {
        final da =
            a.updatedAt ??
            a.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db =
            b.updatedAt ??
            b.createdAt ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
    return sorted.first;
  }

  String _phaseLabelOf(JournalEntry entry) {
    final key = normalizePhase(entry.progress);
    final index = phaseKeys.indexOf(key);
    return index >= 0 ? phaseLabels[index] : 'Entry';
  }

  Widget _buildRecentActivity() {
    final entry = _mostRecentEntry();
    return Stack(
      children: [
        const Positioned(
          left: 22,
          top: 1536,
          child: _SectionTitle('Recent Activity'),
        ),
        Positioned(
          left: 22,
          top: 1568,
          width: _canvasWidth - 44,
          child: entry == null
              ? const Text(
                  'No activity yet.',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                )
              : Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title.isEmpty
                                  ? 'Untitled entry'
                                  : entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              () {
                                final date = entry.updatedAt ?? entry.createdAt;
                                return date == null
                                    ? ''
                                    : DateFormat(
                                        'MMMM d, yyyy',
                                      ).format(date.toLocal());
                              }(),
                              style: const TextStyle(
                                color: Color(0xFFA1A1A1),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _phaseLabelOf(entry).toUpperCase(),
                          style: const TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
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
          color: Colors.white,
          fontSize: 16,
          height: 1,
          fontWeight: FontWeight.w700,
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
      style: TextStyle(
        color: active ? _ProjectDashboardState._text : Colors.black,
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.avatarBackground,
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_outlined,
        size: 42,
        color: AppColors.avatarIcon,
      ),
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
        color: _ProjectDashboardState._text,
        fontSize: 14,
        height: 17 / 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ProgressBubble extends StatelessWidget {
  const _ProgressBubble({
    required this.number,
    required this.label,
    this.active = false,
  });

  final String number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 45,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 29,
            top: 0,
            width: 34,
            height: 34,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _ProjectDashboardState._green : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: _ProjectDashboardState._green),
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: active ? Colors.white : _ProjectDashboardState._text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 38,
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: CustomPaint(painter: _ProgressTrackPainter(), size: Size.infinite),
    );
  }
}

class _ProgressTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ProjectDashboardState._green
      ..strokeWidth = 1;
    final y = size.height / 2;
    canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetaHeading extends StatelessWidget {
  const _MetaHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ProjectDashboardState._text,
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w700,
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
        color: _ProjectDashboardState._text,
        fontSize: 13,
        height: 18 / 13,
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
      width: 111,
      height: 122,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
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
          SizedBox(width: 34, height: 34, child: icon),
          const SizedBox(height: 13),
          Text(
            title,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF838383),
              fontSize: 10,
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
              Text(
                value,
                style: const TextStyle(
                  color: _ProjectDashboardState._green,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.28,
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 13),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF838383),
                  size: 13,
                ),
              ],
            ],
          ),
          const SizedBox(height: 9),
          Text(
            caption,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF838383),
              fontSize: 8,
              height: 1,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.16,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _ImpactLabel extends StatelessWidget {
  const _ImpactLabel({required this.label, required this.icon});

  final String label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          SizedBox(width: 31, height: 31, child: icon),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 10),
          ),
          const SizedBox(height: 14),
          const Text(
            '20',
            style: TextStyle(
              color: _ProjectDashboardState._green,
              fontSize: 15,
              height: 18 / 15,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Text(
            'EcoPoints',
            maxLines: 1,
            style: TextStyle(
              color: _ProjectDashboardState._green,
              fontSize: 10,
              height: 18 / 10,
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
    return CustomPaint(painter: _MoneyIconPainter());
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
    return CustomPaint(painter: _EnergyIconPainter());
  }
}

class _WasteImpactIcon extends StatelessWidget {
  const _WasteImpactIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WasteIconPainter());
  }
}

class _WaterImpactIcon extends StatelessWidget {
  const _WaterImpactIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _WaterIconPainter());
  }
}

class _BioImpactIcon extends StatelessWidget {
  const _BioImpactIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BioIconPainter());
  }
}

class _EducationImpactIcon extends StatelessWidget {
  const _EducationImpactIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _EducationIconPainter());
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
    final s = stroke;
    final rect = Rect.fromLTWH(
      size.width * .31,
      size.height * .13,
      size.width * .38,
      size.height * .74,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .42, size.height * .18),
      Offset(size.width * .42, size.height * .36),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .18),
      Offset(size.width * .5, size.height * .36),
      s,
    );
  }
}

class _MoneyIconPainter extends _LineIconPainter {
  _MoneyIconPainter() : super(_ProjectDashboardState._green);

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * .43, s);
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, size.height * .28),
      Offset(centerX, size.height * .72),
      s,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, size.height * .4),
        width: size.width * .23,
        height: size.height * .22,
      ),
      1.4,
      3.2,
      false,
      s,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX, size.height * .6),
        width: size.width * .23,
        height: size.height * .22,
      ),
      -1.8,
      3.2,
      false,
      s,
    );
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

class _EnergyIconPainter extends _LineIconPainter {
  _EnergyIconPainter() : super(const Color(0xFFFFC329));

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .55, size.height * .05)
      ..lineTo(size.width * .18, size.height * .55)
      ..lineTo(size.width * .47, size.height * .55)
      ..lineTo(size.width * .36, size.height * .95)
      ..lineTo(size.width * .82, size.height * .39)
      ..lineTo(size.width * .52, size.height * .39)
      ..close();
    canvas.drawPath(path, stroke);
  }
}

class _WasteIconPainter extends _LineIconPainter {
  _WasteIconPainter() : super(_ProjectDashboardState._green);

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    canvas.drawLine(
      Offset(size.width * .25, size.height * .25),
      Offset(size.width * .75, size.height * .25),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .42, size.height * .12),
      Offset(size.width * .58, size.height * .12),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .12),
      Offset(size.width * .5, size.height * .25),
      s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .32,
          size.height * .3,
          size.width * .36,
          size.height * .58,
        ),
        const Radius.circular(2),
      ),
      s,
    );
  }
}

class _WaterIconPainter extends _LineIconPainter {
  _WaterIconPainter() : super(const Color(0xFF0F6AD9));

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .09)
      ..cubicTo(
        size.width * .25,
        size.height * .39,
        size.width * .22,
        size.height * .55,
        size.width * .22,
        size.height * .66,
      )
      ..cubicTo(
        size.width * .22,
        size.height * .84,
        size.width * .35,
        size.height * .94,
        size.width * .5,
        size.height * .94,
      )
      ..cubicTo(
        size.width * .65,
        size.height * .94,
        size.width * .78,
        size.height * .84,
        size.width * .78,
        size.height * .66,
      )
      ..cubicTo(
        size.width * .78,
        size.height * .55,
        size.width * .75,
        size.height * .39,
        size.width * .5,
        size.height * .09,
      );
    canvas.drawPath(path, stroke);
  }
}

class _BioIconPainter extends _LineIconPainter {
  _BioIconPainter() : super(_ProjectDashboardState._green);

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    canvas.drawLine(
      Offset(size.width * .5, size.height * .88),
      Offset(size.width * .5, size.height * .36),
      s,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * .17,
        size.height * .08,
        size.width * .33,
        size.height * .28,
      ),
      0,
      3.2,
      false,
      s,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * .5,
        size.height * .08,
        size.width * .33,
        size.height * .28,
      ),
      3.1,
      3.2,
      false,
      s,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * .22, size.height * .88)
        ..lineTo(size.width * .78, size.height * .88)
        ..lineTo(size.width * .68, size.height * .55)
        ..lineTo(size.width * .32, size.height * .55)
        ..close(),
      s,
    );
  }
}

class _EducationIconPainter extends _LineIconPainter {
  _EducationIconPainter() : super(const Color(0xFFAD45E6));

  @override
  void paint(Canvas canvas, Size size) {
    final s = stroke;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * .16,
        size.height * .18,
        size.width * .68,
        size.height * .64,
      ),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .28, size.height * .91),
      Offset(size.width * .72, size.height * .91),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .82),
      Offset(size.width * .5, size.height * .91),
      s,
    );
    canvas.drawLine(
      Offset(size.width * .6, size.height * .32),
      Offset(size.width * .41, size.height * .58),
      s,
    );
    canvas.drawCircle(
      Offset(size.width * .4, size.height * .61),
      size.width * .06,
      s,
    );
    canvas.drawCircle(
      Offset(size.width * .63, size.height * .29),
      size.width * .05,
      s,
    );
  }
}

String _formatDashboardCurrency(double value) =>
    '\$${value.toStringAsFixed(2)}';

class _ObjectivePreview extends StatelessWidget {
  const _ObjectivePreview({
    required this.top,
    required this.number,
    required this.objective,
  });

  final double top;
  final int number;
  final ProjectObjectiveSummary objective;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: top,
      width: _ProjectDashboardState._canvasWidth,
      height: 38,
      child: Stack(
        children: [
          Positioned(
            left: 45,
            top: 5,
            width: 19,
            height: 19,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ProjectDashboardState._green,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            left: 78,
            top: 0,
            width: 291,
            child: Text(
              objective.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ProjectDashboardState._text,
                fontSize: 12,
                height: 17 / 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
