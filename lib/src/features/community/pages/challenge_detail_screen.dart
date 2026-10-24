import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/challenge_participant.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/models/impact_entry.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_creator_dashboard.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final DesignChallenge challenge;

  const ChallengeDetailScreen({super.key, required this.challenge});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final _repo = ChallengesRepo();
  final _projectsRepo = ProjectsRepo();
  late DesignChallenge _challenge;
  ChallengeParticipant? _myParticipation;
  bool _loading = true;

  // Progress tracking
  List<ImpactEntry> _impactEntries = [];
  List<JournalEntry> _journalEntries = [];
  int _memberCount = 1;

  bool get _isCreator =>
      _challenge.creatorId == AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final participation = await _repo.getMyParticipation(_challenge.id);
    final refreshed = await _repo.getChallengeById(_challenge.id);

    List<ImpactEntry> impactEntries = [];
    List<JournalEntry> journalEntries = [];
    int memberCount = 1;

    final projectId = participation?.projectId;
    if (projectId != null) {
      final results = await Future.wait([
        _projectsRepo.getImpactEntries(projectId: projectId),
        _projectsRepo.getJournalEntries(projectId: projectId),
        _projectsRepo.getProjectCollaborators(projectId: projectId),
      ]);
      impactEntries = List<ImpactEntry>.from(results[0] as List);
      journalEntries = List<JournalEntry>.from(results[1] as List);
      memberCount = 1 + (results[2] as List).length;
    }

    if (!mounted) return;
    setState(() {
      if (refreshed != null) _challenge = refreshed;
      _myParticipation = participation;
      _impactEntries = impactEntries;
      _journalEntries = journalEntries;
      _memberCount = memberCount;
      _loading = false;
    });
  }

  Future<void> _joinChallenge() async {
    final result = await pushAppRoute<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(
          challengeId: _challenge.id,
          lockedDifficulty: _challenge.difficulty,
          lockedScale: _challenge.scale,
        ),
      ),
    );
    // result is the projectId after creation
    if (result != null && mounted) {
      _load();
    }
  }

  Future<void> _viewProject() async {
    final p = _myParticipation;
    if (p?.projectId == null) return;
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDashboard(
          projectId: p!.projectId!,
          projectName: p.projectName ?? 'Project',
          tags: const [],
          isOwner: true,
          challengeId: _challenge.id,
        ),
      ),
    );
    _load();
  }

  Future<void> _openCreatorDashboard() async {
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeCreatorDashboard(challengeId: _challenge.id),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PageScrollWithFooter(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHero()),
                  SliverToBoxAdapter(child: _buildTasksSection()),
                ],
              ),
            ),
    );
  }

  Widget _buildHero() {
    final hasJoined = _myParticipation != null;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Navigation row
          Row(
            children: [
              AppTapTarget(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.chevron_left,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (_isCreator)
                AppTapTarget(
                  onTap: _openCreatorDashboard,
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: Colors.white,
                      fontSize: AppTypography.buttonSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppMetrics.fieldGap),

          // Challenge name
          Text(
            _challenge.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.headingFamily,
              fontSize: AppTypography.displaySize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Date range
          if (_challenge.dateRange.isNotEmpty)
            Text(
              _challenge.dateRange,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 16),

          // Participant avatar stack
          if (_challenge.participantAvatars.isNotEmpty ||
              _challenge.participantCount > 0)
            _buildAvatarStack(),
          const SizedBox(height: 16),

          // Prompt
          if (_challenge.prompt?.isNotEmpty == true)
            Text(
              _challenge.prompt!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: Colors.white,
                height: 1.5,
              ),
            ),

          // Submission deadline for joined members
          if (hasJoined && _challenge.endsAt != null && !_isCreator) ...[
            const SizedBox(height: 12),
            Text(
              'Submission Deadline: ${_deadlineText()}',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: AppMetrics.fieldGap),

          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isCreator
                  ? _openCreatorDashboard
                  : hasJoined
                  ? _viewProject
                  : _challenge.isPast
                  ? null
                  : _joinChallenge,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.buttonSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(
                _isCreator
                    ? 'View Submissions'
                    : hasJoined
                    ? 'View Project'
                    : _challenge.isPast
                    ? 'Challenge Ended'
                    : 'Join the Challenge',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    final avatars = _challenge.participantAvatars.take(5).toList();
    final extra = _challenge.participantCount - avatars.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 36,
          width: (avatars.length * 26 + 10).toDouble(),
          child: Stack(
            children: avatars.asMap().entries.map((e) {
              return Positioned(
                left: e.key * 26.0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: e.value.isNotEmpty
                      ? NetworkImage(e.value)
                      : null,
                  child: e.value.isEmpty
                      ? const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: AppColors.primary,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$extra',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: Colors.white,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTasksSection() {
    final tasks = _buildTaskList();
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tasks',
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              fontSize: AppTypography.sectionTitleSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...tasks.map(_buildTaskCard),
        ],
      ),
    );
  }

  List<_TaskItem> _buildTaskList() {
    final c = _challenge;
    final tasks = <_TaskItem>[];
    final hasProject = _myParticipation?.projectId != null;

    for (final metric in c.requiredMetrics) {
      final count = hasProject
          ? _impactEntries
                .where((e) => e.metric.toLowerCase() == metric.toLowerCase())
                .length
          : 0;
      tasks.add(
        _TaskItem(
          icon: _metricIcon(metric),
          title: 'Metric: $metric',
          subtitle: '$count/1 $metric Impact Entries',
          done: count >= 1,
        ),
      );
    }

    for (final pattern in c.requiredPatterns) {
      final count = hasProject
          ? _impactEntries
                .where(
                  (e) => e.patternType.toLowerCase() == pattern.toLowerCase(),
                )
                .length
          : 0;
      tasks.add(
        _TaskItem(
          icon: Icons.change_circle_outlined,
          title: 'Pattern: $pattern',
          subtitle: '$count/1 $pattern Impact Entries',
          done: count >= 1,
        ),
      );
    }

    if (c.type == 'community_impact' && c.minGroupMembers > 1) {
      final count = hasProject ? _memberCount : 0;
      tasks.add(
        _TaskItem(
          icon: Icons.group_add_outlined,
          title: 'Group Project Members',
          subtitle: '$count/${c.minGroupMembers} Members',
          done: count >= c.minGroupMembers,
        ),
      );
    }

    if (c.requiredJournalEntries > 0) {
      final count = hasProject ? _journalEntries.length : 0;
      tasks.add(
        _TaskItem(
          icon: Icons.menu_book_outlined,
          title: 'Complete ${c.requiredJournalEntries} Journal Entries',
          subtitle: '$count/${c.requiredJournalEntries} Journal Entries',
          done: count >= c.requiredJournalEntries,
        ),
      );
    }

    if (c.budgetMax != null) {
      tasks.add(
        _TaskItem(
          icon: Icons.attach_money_outlined,
          title: 'Funding Requirements: \$${c.budgetMin}–\$${c.budgetMax}',
          subtitle: '0/1 Material Cost',
          done: false,
        ),
      );
    }

    if (c.measurementRequired) {
      final count = hasProject
          ? _impactEntries.where((e) => e.measurement != null).length
          : 0;
      tasks.add(
        _TaskItem(
          icon: Icons.straighten_outlined,
          title: 'Measurement',
          subtitle: '$count/1 Impact Entries with Measurement',
          done: count >= 1,
        ),
      );
    }

    return tasks;
  }

  Widget _buildTaskCard(_TaskItem task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: task.done
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.done
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
        boxShadow: task.done
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: task.done
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: task.done ? AppColors.primary : AppColors.borderLight,
              ),
            ),
            child: Icon(
              task.done ? Icons.check : task.icon,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.subtitle,
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.helperSize,
                    color: task.done
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _metricIcon(String metric) {
    switch (metric.toLowerCase()) {
      case 'energy':
        return Icons.bolt_outlined;
      case 'waste':
        return Icons.delete_outline;
      case 'water':
        return Icons.water_drop_outlined;
      case 'biological growth':
        return Icons.eco_outlined;
      case 'educational impact':
        return Icons.school_outlined;
      default:
        return Icons.bar_chart_outlined;
    }
  }

  String _deadlineText() {
    final e = _challenge.endsAt;
    if (e == null) return '';
    final date = '${e.month}/${e.day}/${e.year.toString().substring(2)}';
    if (_challenge.allDay) return date;
    final h = e.hour % 12 == 0 ? 12 : e.hour % 12;
    final m = e.minute.toString().padLeft(2, '0');
    final ampm = e.hour < 12 ? 'AM' : 'PM';
    return '$date $h:$m $ampm';
  }
}

class _TaskItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

  const _TaskItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.done = false,
  });
}
