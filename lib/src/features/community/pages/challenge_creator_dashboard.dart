import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:juniper_journal/src/backend/db/models/challenge_participant.dart';
import 'package:juniper_journal/src/backend/db/models/design_challenge.dart';
import 'package:juniper_journal/src/backend/db/repositories/challenges_repo.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_funding_form.dart';
import 'package:juniper_journal/src/features/community/pages/challenge_settings_form.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ChallengeCreatorDashboard extends StatefulWidget {
  final String challengeId;

  const ChallengeCreatorDashboard({super.key, required this.challengeId});

  @override
  State<ChallengeCreatorDashboard> createState() =>
      _ChallengeCreatorDashboardState();
}

class _ChallengeCreatorDashboardState extends State<ChallengeCreatorDashboard>
    with SingleTickerProviderStateMixin {
  final _repo = ChallengesRepo();
  TabController? _tabCtrl;
  DesignChallenge? _challenge;
  List<ChallengeParticipant> _participants = [];
  bool _loading = true;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final challenge = await _repo.getChallengeById(widget.challengeId);
    final participants = await _repo.getParticipants(widget.challengeId);
    if (!mounted) return;
    setState(() {
      _challenge = challenge;
      _participants = participants;
      _loading = false;
    });
  }

  Future<void> _launch() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Launch Challenge?'),
        content: const Text(
          'This will make the challenge visible to all community members. You can still edit settings after launching.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Launch'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _launching = true);
    final ok = await _repo.launchChallenge(widget.challengeId);
    if (!mounted) return;
    setState(() => _launching = false);
    if (ok) {
      showTopSnackBar(context, 'Challenge launched!');
      _load();
    } else {
      showTopSnackBar(context, 'Failed to launch. Please try again.');
    }
  }

  Future<void> _unsubmitParticipant(ChallengeParticipant p) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Not Submitted?'),
        content: Text(
          '${p.resolvedName}\'s submission will be reset. They can resubmit before the deadline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _repo.unsubmitParticipant(p.id);
    if (!mounted) return;
    if (ok) {
      showTopSnackBar(context, 'Submission reset');
      _load();
    } else {
      showTopSnackBar(
        context,
        'Failed to reset. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _viewParticipantProject(ChallengeParticipant p) async {
    if (p.projectId == null) return;
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDashboard(
          projectId: p.projectId!,
          projectName: p.projectName ?? 'Project',
          tags: const [],
          isOwner: false,
          challengeId: widget.challengeId,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    if (_challenge == null) return;
    final updated = await pushAppRoute<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ChallengeSettingsForm(challenge: _challenge!),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Done',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'DESIGN DASHBOARD',
            style: TextStyle(
              fontFamily: AppTypography.headingFamily,
              color: Colors.white,
              fontSize: AppTypography.pageTitleSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textPrimary,
            ),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Launch / Status banner
                if (_challenge != null) _buildStatusBanner(),

                // Tabs
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabCtrl!,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 2,
                    labelStyle: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Submissions'),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl!,
                    children: [_buildOverviewTab(), _buildSubmissionsTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    final c = _challenge!;
    if (!c.isPublished) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'This challenge is a draft — only you can see it.',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: _launching ? null : _launch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: _launching
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Launch'),
              ),
            ),
          ],
        ),
      );
    }
    // Published — show active badge
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.isActive ? 'Challenge is live' : 'Challenge has ended',
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (c.dateRange.isNotEmpty)
            Text(
              c.dateRange,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _DashboardTile(
          icon: Icons.checklist_outlined,
          label: 'Requirements',
          subtitle: _requirementsSummary(),
          onTap: () async {
            if (_challenge == null) return;
            // Navigate to an edit view of requirements
            await pushAppRoute(
              context,
              MaterialPageRoute(
                builder: (_) => _EditRequirementsWrapper(
                  challenge: _challenge!,
                  repo: _repo,
                ),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 12),
        _DashboardTile(
          icon: Icons.attach_money_outlined,
          label: 'Funding & Materials',
          subtitle: _fundingSummary(),
          onTap: () async {
            if (_challenge == null) return;
            await pushAppRoute(
              context,
              MaterialPageRoute(
                builder: (_) => ChallengeFundingForm(challenge: _challenge!),
              ),
            );
            _load();
          },
        ),
      ],
    );
  }

  Widget _buildSubmissionsTab() {
    if (_participants.isEmpty) {
      return const Center(
        child: Text(
          'No participants yet.',
          style: TextStyle(
            fontFamily: AppTypography.bodyFamily,
            color: AppColors.textSecondary,
            fontSize: AppTypography.bodySize,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _participants.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        final p = _participants[i];
        final hasProject = p.projectId != null;
        return InkWell(
          onTap: hasProject ? () => _viewParticipantProject(p) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryTint,
                  backgroundImage: (p.avatarUrl?.isNotEmpty == true)
                      ? NetworkImage(p.avatarUrl!)
                      : null,
                  child: (p.avatarUrl?.isNotEmpty != true)
                      ? const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: AppColors.primary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Name + project name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.resolvedName,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        p.projectName?.isNotEmpty == true
                            ? p.projectName!
                            : 'No project linked',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          color: hasProject
                              ? AppColors.textSecondary
                              : AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status + date stacked
                if (p.hasSubmitted) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Submitted',
                        style: TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.bodySize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      if (p.submittedAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d').format(p.submittedAt!),
                          style: const TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            fontSize: AppTypography.helperSize,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 10),
                  AppTapTarget(
                    onTap: () => _unsubmitParticipant(p),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Pending',
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasProject)
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textSecondary,
                    )
                  else
                    const SizedBox(width: 18),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _requirementsSummary() {
    if (_challenge == null) return '';
    final parts = <String>[];
    if (_challenge!.requiredJournalEntries > 0) {
      parts.add('${_challenge!.requiredJournalEntries} journal entries');
    }
    if (_challenge!.measurementRequired) parts.add('measurement required');
    if (_challenge!.requiredMetrics.isNotEmpty) {
      parts.add('${_challenge!.requiredMetrics.length} metric(s)');
    }
    return parts.isEmpty ? 'No requirements set' : parts.join(' · ');
  }

  String _fundingSummary() {
    if (_challenge == null) return '';
    final max = _challenge!.budgetMax;
    final budget = max == null
        ? 'No budget restriction'
        : '\$${_challenge!.budgetMin}–\$$max budget';
    final mats = _challenge!.materials.length;
    return mats > 0 ? '$budget · $mats material(s)' : budget;
  }
}

// ── Edit Requirements Wrapper ─────────────────────────────────────────────────

class _EditRequirementsWrapper extends StatefulWidget {
  final DesignChallenge challenge;
  final ChallengesRepo repo;

  const _EditRequirementsWrapper({required this.challenge, required this.repo});

  @override
  State<_EditRequirementsWrapper> createState() =>
      _EditRequirementsWrapperState();
}

class _EditRequirementsWrapperState extends State<_EditRequirementsWrapper> {
  late int _journalEntries;
  late bool _measurementRequired;
  late Set<String> _selectedMetrics;
  late Set<String> _selectedPatterns;
  late int _minGroupMembers;
  final _linkCtrl = TextEditingController();
  bool _saving = false;

  static const _kMetrics = [
    'Energy',
    'Waste',
    'Water',
    'Biological Growth',
    'Educational Impact',
  ];
  static const _kPatterns = [
    'Behavior',
    'Regeneration',
    'Reduction',
    'Substitution',
  ];
  static const _kCommunityPatterns = ['Capacity Building'];

  bool get _isPatternChange => widget.challenge.type == 'pattern_change';
  bool get _isCommunityImpact => widget.challenge.type == 'community_impact';
  List<String> get _patternOptions =>
      _isCommunityImpact ? _kCommunityPatterns : _kPatterns;

  @override
  void initState() {
    super.initState();
    final c = widget.challenge;
    _journalEntries = c.requiredJournalEntries;
    _measurementRequired = c.measurementRequired;
    _selectedMetrics = Set.from(c.requiredMetrics);
    _selectedPatterns = Set.from(c.requiredPatterns);
    _minGroupMembers = c.minGroupMembers;
    _linkCtrl.text = c.externalLink ?? '';
  }

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.repo.updateRequirements(
      id: widget.challenge.id,
      requiredJournalEntries: _journalEntries,
      measurementRequired: _measurementRequired,
      requiredMetrics: _selectedMetrics.toList(),
      requiredPatterns: _selectedPatterns.toList(),
      minGroupMembers: _minGroupMembers,
      externalLink: _linkCtrl.text.trim().isEmpty
          ? null
          : _linkCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      showTopSnackBar(context, 'Failed to save. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            size: 28,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Requirements', style: AppTypography.pageTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rowField(
              'Required Journal Entries',
              _stepper(
                _journalEntries,
                0,
                99,
                (v) => setState(() => _journalEntries = v),
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),
            _rowField(
              'Measurement Required',
              Switch(
                value: _measurementRequired,
                onChanged: (v) => setState(() => _measurementRequired = v),
                activeColor: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppMetrics.fieldGap),
            if (_isCommunityImpact) ...[
              _rowField(
                'Minimum Group Members Required',
                _stepper(
                  _minGroupMembers,
                  1,
                  50,
                  (v) => setState(() => _minGroupMembers = v),
                ),
              ),
              const SizedBox(height: AppMetrics.fieldGap),
            ],
            _sectionLabel('Required Metrics (Multi-Select)'),
            const SizedBox(height: 10),
            _pillGrid(_kMetrics, _selectedMetrics),
            const SizedBox(height: AppMetrics.fieldGap),
            if (_isPatternChange || _isCommunityImpact) ...[
              _sectionLabel(
                _isPatternChange
                    ? 'Required Pattern (Select 1)'
                    : 'Required Patterns',
              ),
              const SizedBox(height: 10),
              _pillGrid(
                _patternOptions,
                _selectedPatterns,
                maxSelect: _isPatternChange ? 1 : null,
              ),
              const SizedBox(height: AppMetrics.fieldGap),
            ],
            Row(
              children: [
                _sectionLabel('Insert External Link'),
                const SizedBox(width: 8),
                const Icon(
                  Icons.link,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '',
                hintStyle: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.hintText,
                  fontSize: AppTypography.helperSize,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.journalSectionGap),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.buttonSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowField(String label, Widget trailing) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: AppTypography.bodyFamily,
            fontSize: AppTypography.bodySize,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      trailing,
    ],
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppTypography.bodyFamily,
      fontSize: AppTypography.bodySize,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
  );

  Widget _stepper(int value, int min, int max, void Function(int) onChanged) =>
      Row(
        children: [
          _stepBtn(Icons.remove, () => onChanged((value - 1).clamp(min, max))),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.bodySize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          _stepBtn(Icons.add, () => onChanged((value + 1).clamp(min, max))),
        ],
      );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => AppTapTarget(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary),
      ),
      child: Icon(icon, size: 16, color: AppColors.primary),
    ),
  );

  Widget _pillGrid(
    List<String> options,
    Set<String> selected, {
    int? maxSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = selected.contains(o);
        return AppTapTarget(
          onTap: () => setState(() {
            if (isSelected) {
              selected.remove(o);
            } else {
              if (maxSelect != null && selected.length >= maxSelect) {
                selected.clear();
              }
              selected.add(o);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
              ),
            ),
            child: Text(
              o.toUpperCase(),
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.helperSize,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _DashboardTile ────────────────────────────────────────────────────────────

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapTarget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
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
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.helperSize,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
