import '../../../shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/protected_image.dart';
import '../../../shared/styling/app_metrics.dart';
import '../../../backend/db/models/project.dart';
import '../../../shared/widgets/profile_ecopoints_card.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../../../shared/widgets/app_tab_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../backend/auth/auth_service.dart';
import '../../../backend/db/models/community.dart';
import '../../../backend/db/models/community_member.dart';
import '../../../backend/db/models/user_profile.dart';
import '../../../backend/db/repositories/communities_repo.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../shared/styling/app_colors.dart';
import '../../../shared/styling/app_typography.dart';
import '../../../shared/widgets/modal_actions.dart';
import '../../../shared/widgets/top_snack_bar.dart';
import '../../home_page/pages/public_user_profile.dart';
import '../../project/pages/project_dashboard.dart';
import '../community_journal_data.dart';
import 'community_settings_screen.dart';

const _domains = [
  ('Environment & Sustainability', 'environment', Color(0xFF12B85A)),
  ('Engineering & Design', 'engineering', Color(0xFF009ECB)),
  ('Energy & Systems', 'energy', Color(0xFFE0B900)),
  ('Community & Built Environment', 'community', Color(0xFFE85870)),
];

class CommunityProfileScreen extends StatefulWidget {
  const CommunityProfileScreen({
    super.key,
    required this.community,
    this.communitiesRepo,
    this.projectsRepo,
    this.currentUserId,
    this.initialMembers = false,
  });
  final bool initialMembers;
  final Community community;
  final CommunitiesRepo? communitiesRepo;
  final ProjectsRepo? projectsRepo;
  final String? currentUserId;
  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> {
  late final _repo = widget.communitiesRepo ?? CommunitiesRepo();
  late final _projectsRepo = widget.projectsRepo ?? ProjectsRepo();
  late Community _community = widget.community;
  late final String? _userId = _currentUserId();
  String? _currentUserId() {
    if (widget.currentUserId != null) return widget.currentUserId;
    try {
      return AuthService.instance.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  List<CommunityMember> _members = [];
  List<CommunityJournalRecord> _records = [];
  bool _restricted = true;
  Map<String, dynamic>? _publicSummary;
  List<Project> _publicProjects = [];
  bool _loading = true;
  bool _loadError = false;
  bool _editing = false;
  late bool _membersTab = widget.initialMembers;
  final Set<String> _removing = {};
  bool get _isOwner => _userId != null && _userId == _community.createdBy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final member =
          _isOwner ||
          (_userId != null &&
              await _repo.isAcceptedCommunityMember(_community.id));
      if (!member) {
        final summary = await _repo.getPublicCommunityProfile(_community.id);
        if (!mounted) return;
        setState(() {
          _restricted = true;
          _publicSummary = summary;
          _members = (summary['admins'] as List? ?? [])
              .whereType<Map>()
              .map(
                (row) => CommunityMember.fromMap({
                  'id': row['id'],
                  'user_id': row['id'],
                  'role': row['role'],
                  'status': 'accepted',
                  'profiles': row,
                }),
              )
              .toList();
          _publicProjects = (summary['projects'] as List? ?? [])
              .whereType<Map>()
              .map((row) => Project.fromMap(Map<String, dynamic>.from(row)))
              .toList();
          _records = [];
          _loading = false;
          _loadError = false;
        });
        return;
      }
      final results = await Future.wait<Object>([
        _repo.getCommunityMembers(_community.id),
        loadCommunityJournal(_projectsRepo, _community.id),
      ]);
      if (!mounted) return;
      setState(() {
        _restricted = false;
        _members = (results[0] as List<CommunityMember>)
            .where((m) => _isOwner || m.status == 'accepted')
            .toList();
        _records = results[1] as List<CommunityJournalRecord>;
        _loading = false;
        _loadError = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _loadError = true;
        });
    }
  }

  Future<void> _invite() async {
    if (!_isOwner) return;
    final profile = await showAppDialog<UserProfile>(
      context: context,
      builder: (_) => CommunityMemberSearchDialog(
        excludeIds: _members.map((m) => m.userId).toSet(),
      ),
    );
    if (profile == null || !mounted) return;
    final ok = await _repo.inviteMember(
      communityId: _community.id,
      userId: profile.id,
    );
    if (!mounted) return;
    showTopSnackBar(
      context,
      ok ? 'Invitation sent' : 'Could not send invitation',
      isError: !ok,
    );
    if (ok) await _load();
  }

  Future<void> _remove(CommunityMember member) async {
    if (!_isOwner || member.role == 'owner' || member.userId == _userId) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          member.status == 'pending' ? 'Cancel invitation?' : 'Remove member?',
        ),
        content: Text(
          member.status == 'pending'
              ? 'Cancel the invitation for ${member.resolvedName}?'
              : 'Remove ${member.resolvedName} from this community?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(member.memberId));
    final ok = await _repo.removeMember(member.memberId);
    if (!mounted) return;
    setState(() => _removing.remove(member.memberId));
    if (ok) {
      await _load();
    } else {
      showTopSnackBar(context, 'Could not remove member', isError: true);
    }
  }

  Future<void> _settings() async {
    final result = await pushAppRoute<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsScreen(community: _community),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context, result);
      return;
    }
    final updated = await _repo.getCommunityById(_community.id);
    if (!mounted) return;
    if (updated != null) setState(() => _community = updated);
    await _load();
  }

  Widget _avatar(String? url, {double radius = 24, bool community = false}) =>
      CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryTint,
        child: ClipOval(
          child: url?.isNotEmpty == true
              ? ProtectedImage.network(
                  url!,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    community ? Icons.groups_outlined : Icons.person_outline,
                    color: AppColors.primary,
                    size: radius,
                  ),
                )
              : Icon(
                  community ? Icons.groups_outlined : Icons.person_outline,
                  color: AppColors.primary,
                  size: radius,
                ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    PageRefreshState.remember(context, {
      'kind': 'community-profile',
      'community': widget.community.id,
      'tab': _membersTab ? 'members' : 'projects',
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _community.bannerColor,
        foregroundColor: Colors.white,
        title: Text(
          'Profile',
          style: AppTypography.pageTitle.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: ColoredBox(color: _community.bannerColor),
          ),
          RefreshIndicator(
            onRefresh: _load,
            child: PageScrollWithFooter(
              child: ListView(
                padding: const EdgeInsets.only(
                  bottom: AppMetrics.pageBottomPadding,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 28),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 48),
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height - 160,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 68, 24, 40),
                        child: Column(
                          children: [
                            Text(
                              _community.name,
                              style: AppTypography.pageTitle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            if (!_loading && !_loadError)
                              ProfileEcoPointsCard(
                                points: _restricted
                                    ? (_publicSummary?['eco_points'] as num? ??
                                              0)
                                          .toDouble()
                                    : _records.fold<double>(
                                        0,
                                        (sum, record) => sum + record.ecoPoints,
                                      ),
                              ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Progress'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Members'),
                                  ),
                                ],
                                selected: {_membersTab},
                                showSelectedIcon: false,
                                onSelectionChanged: (value) =>
                                    setState(() => _membersTab = value.first),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              )
                            else if (_loadError)
                              TextButton(
                                onPressed: _load,
                                child: const Text(
                                  'Could not load community activity. Tap to retry.',
                                ),
                              )
                            else
                              AppContentTransition(
                                index: _membersTab,
                                child: Column(
                                  children: _membersTab
                                      ? _memberWidgets()
                                      : [..._progressWidgets()],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: _avatar(
                          _community.imageUrl,
                          radius: 52,
                          community: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _memberWidgets() => [
    Row(
      children: [
        Expanded(
          child: Text(
            '${_restricted ? (_publicSummary?['member_count'] ?? 0) : _members.where((m) => m.status == 'accepted').length} Members',
            style: AppTypography.fieldLabel,
          ),
        ),
        if (_isOwner) ...[
          IconButton.outlined(
            tooltip: 'Add people',
            onPressed: _invite,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: _editing ? 'Done editing' : 'Manage members',
            onPressed: () => setState(() => _editing = !_editing),
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
          ),
        ],
      ],
    ),
    const SizedBox(height: 16),
    if (_members.isEmpty)
      const Padding(
        padding: EdgeInsets.all(32),
        child: Text('No members yet.'),
      ),
    if (_restricted) ...[
      const Text('Community admins', style: AppTypography.fieldLabel),
      const SizedBox(height: 8),
      const Text(
        'The member list is visible only to community members.',
        style: AppTypography.helper,
      ),
      const SizedBox(height: 16),
    ],
    for (final member in _members)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDADADA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: _avatar(member.avatarUrl, radius: 22),
              title: Text(member.resolvedName, style: AppTypography.fieldLabel),
              subtitle: member.status == 'pending'
                  ? const Text(
                      'Invitation pending',
                      style: AppTypography.helper,
                    )
                  : member.role == 'owner'
                  ? Text(
                      _restricted ? 'Community admin' : 'Community owner',
                      style: AppTypography.helper,
                    )
                  : null,
              onTap: () => pushAppRoute(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicUserProfilePage(userId: member.userId),
                ),
              ),
              trailing:
                  _isOwner &&
                      _editing &&
                      member.role != 'owner' &&
                      member.userId != _userId
                  ? _removing.contains(member.memberId)
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton.outlined(
                            tooltip: member.status == 'pending'
                                ? 'Cancel invitation'
                                : 'Remove member',
                            onPressed: () => _remove(member),
                            icon: const Icon(Icons.delete_outline),
                          )
                  : null,
            ),
          ),
        ),
      ),
    if (_isOwner)
      TextButton(onPressed: _settings, child: const Text('Community settings')),
  ];

  List<Widget> _progressWidgets() {
    final total = _restricted
        ? (_publicSummary?['eco_points'] as num? ?? 0).toDouble()
        : _records.fold<double>(0, (sum, r) => sum + r.ecoPoints);
    final entryCount = _restricted
        ? (_publicSummary?['completed_entries'] ?? 0)
        : _records.length;
    return [
      Text(
        '$entryCount completed journal entries · ${_points(total)} EcoPoints',
        style: AppTypography.helper,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      for (final domain in _domains)
        Builder(
          builder: (context) {
            final records = _records
                .where(
                  (r) =>
                      r.project.subjectDomain == domain.$1 ||
                      r.project.tags.contains(domain.$1),
                )
                .toList();
            final stats = (_publicSummary?['progress'] as List? ?? [])
                .whereType<Map>()
                .where((row) => row['subject'] == domain.$1)
                .firstOrNull;
            final points = _restricted
                ? (stats?['eco_points'] as num? ?? 0).toDouble()
                : records.fold<double>(0, (sum, r) => sum + r.ecoPoints);
            final count = _restricted
                ? (stats?['entries'] ?? 0)
                : records.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 2,
                shadowColor: const Color(0x18000000),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showDomain(domain.$1, records),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: domain.$3,
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/project_setup/subject_${domain.$2}.svg',
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(domain.$1, style: AppTypography.fieldLabel),
                              const SizedBox(height: 6),
                              Text(
                                '${_points(points)} EcoPoints · $count entries',
                                style: AppTypography.helper,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: total == 0
                                    ? 0
                                    : (points / total).clamp(0, 1),
                                color: domain.$3,
                                backgroundColor: const Color(0xFFF2F5F3),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      const Text(
        'Bars show each subject’s share of recorded EcoPoints from completed community entries.',
        style: AppTypography.helper,
        textAlign: TextAlign.center,
      ),
    ];
  }

  String _points(double points) => points == points.roundToDouble()
      ? points.toStringAsFixed(0)
      : points.toStringAsFixed(1);
  void _showDomain(String title, List<CommunityJournalRecord> records) {
    final projects = _restricted
        ? {
            for (final project in _publicProjects)
              if (project.subjectDomain == title ||
                  project.tags.contains(title))
                project.id: project,
          }
        : {for (final record in records) record.project.id: record.project};
    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .7,
          ),
          child: PageScrollWithFooter(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTypography.sectionTitle),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (records.isEmpty)
                  const Text(
                    'Completed entries in this subject will appear as the community documents its work.',
                    style: AppTypography.helper,
                  ),
                for (final project in projects.values)
                  ListTile(
                    title: Text(project.projectName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      pushAppRoute(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDashboard(
                            projectId: project.id,
                            projectName: project.projectName,
                            tags: project.tags,
                            isOwner: project.userId == _userId,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
