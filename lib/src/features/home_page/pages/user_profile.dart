import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'home.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:flutter/cupertino.dart';
import 'public_user_profile.dart';
import '../../../shared/widgets/desktop_page_scroll.dart';
import '../../../shared/widgets/eco_reward_notice_host.dart'
    show ecoRewardNavigatorKey;
import '../../../shared/widgets/app_tab_transition.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'explore_page.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/features/home_page/pages/search.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    this.onProfileUpdated,
    this.onSubjectSelected,
    this.compact = false,
    this.onSettings,
    this.onLogout,
    this.onNotifications,
    this.onMessages,
    this.notificationCount = 0,
    this.unreadMessageCount = 0,
  });

  final Future<void> Function()? onProfileUpdated;
  final ValueChanged<String>? onSubjectSelected;
  final bool compact;
  final VoidCallback? onSettings, onLogout, onNotifications, onMessages;
  final int notificationCount, unreadMessageCount;

  @override
  State<UserProfilePage> createState() => UserProfilePageState();
}

class UserProfilePageState extends State<UserProfilePage> {
  BuildContext get _navigationContext => widget.compact
      ? (ecoRewardNavigatorKey.currentState?.overlay?.context ?? context)
      : context;
  final _authService = AuthService.instance;
  final _friendsRepo = FriendsRepo();
  final _projectsRepo = ProjectsRepo();
  final _usersRepo = UsersRepo();

  String? _avatarUrl;
  String _displayName = 'User';
  String _email = '';
  bool _isUploading = false;
  List<UserProfile> _friends = const [];
  Map<String, double> _friendPoints = {};
  double _totalPoints = 0;
  Map<String, double> _subjectPoints = {};
  String _friendQuery = '';
  bool _showFriends = false;
  bool _editingFriends = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadFriends();
    _loadAchievements();
  }

  /// Called by the parent shell whenever the Profile tab becomes active.
  void reload() {
    _loadUser();
    _loadFriends();
    _loadAchievements();
  }

  Future<void> _loadUser() async {
    final profile = await _usersRepo.getCurrentUserProfile();
    final email = _authService.currentUser?.email ?? '';
    if (!mounted) return;
    setState(() {
      _displayName = profile?.displayName?.trim().isNotEmpty == true
          ? profile!.displayName!
          : profile?.username?.trim().isNotEmpty == true
          ? '@${profile!.username}'
          : email.split('@').first;
      _email = email;
      _avatarUrl = profile?.avatarUrl;
    });
  }

  Future<void> _loadFriends() async {
    final friends = await _friendsRepo.getFriends();
    if (!mounted) return;
    setState(() => _friends = friends ?? const []);

    if (_friends.isEmpty) return;
    final points = await Future.wait(
      _friends.map((f) => _projectsRepo.getTotalEcoPointsForUser(f.id)),
    );
    if (!mounted) return;
    setState(() {
      _friendPoints = {
        for (var i = 0; i < _friends.length; i++) _friends[i].id: points[i],
      };
    });
  }

  Future<void> _deleteFriend(UserProfile friend) async {
    final confirmed = await showAppDialog<bool>(
      context: _navigationContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove friend?'),
        content: Text(
          '${friend.resolvedDisplayName} will be removed from your friends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await _friendsRepo.removeFriend(friendId: friend.id);
    if (!mounted) return;
    if (!ok) {
      showTopSnackBar(context, 'Failed to remove friend', isError: true);
      return;
    }
    _loadFriends();
  }

  Future<void> _loadAchievements() async {
    final points = await _projectsRepo.getTotalEcoPoints();
    final subjects = await _projectsRepo.getCurrentUserSubjectEcoPoints();
    if (!mounted) return;
    setState(() {
      _totalPoints = points;
      _subjectPoints = subjects;
    });
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Widget _buildAvatar() {
    return Semantics(
      button: true,
      label: 'View your profile',
      child: AppTapTarget(
        onTap: () {
          final id = _authService.currentUser?.id;
          if (id != null) openUserProfile(_navigationContext, id);
        },
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: widget.compact ? 80 : 112,
              height: widget.compact ? 80 : 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 4),
              ),
              child: ClipOval(
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.avatarBackground,
                  backgroundImage:
                      (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? NetworkImage(_avatarUrl!)
                      : null,
                  child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.avatarIcon,
                        )
                      : null,
                ),
              ),
            ),
            if (_isUploading)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Stats card ────────────────────────────────────────────────────────────

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _buildStatItem('ECOPOINTS', _totalPoints.toStringAsFixed(0)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/project_setup/card_eco_leaf.svg',
            width: 26,
            height: 26,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              color: Colors.white70,
              fontSize: AppTypography.captionSize,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppTypography.headingFamily,
              color: Colors.white,
              fontSize: AppTypography.sectionTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildFriendsContent() {
    final matching = _friends
        .where(
          (friend) => ('${friend.resolvedDisplayName} ${friend.username ?? ''}')
              .toLowerCase()
              .contains(_friendQuery.trim().toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_friends.length} Friends',
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip: _editingFriends
                        ? 'Done editing'
                        : 'Manage friends',
                    onPressed: () =>
                        setState(() => _editingFriends = !_editingFriends),
                    icon: Icon(
                      _editingFriends ? Icons.check : Icons.edit_outlined,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.add, size: 22),
                    tooltip: 'Add friend',
                    onPressed: () async {
                      await pushAppRoute(
                        _navigationContext,
                        MaterialPageRoute(
                          builder: (_) => const HomeSearchScreen(
                            initialScope: SearchScope.friends,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _loadFriends();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: TextField(
            onChanged: (value) => setState(() => _friendQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search friends',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        if (matching.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Center(
              child: Text(
                _friends.isEmpty
                    ? 'No friends yet.\nSearch for people to connect with!'
                    : 'No friends match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  color: AppColors.textSecondary,
                  fontSize: AppTypography.helperSize,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: MediaQuery.sizeOf(context).height.clamp(400.0, 800.0) * .42,
            child: PageScrollWithFooter(
              child: ListView.builder(
                primary: false,
                itemCount: matching.length,
                itemBuilder: (context, index) {
                  final friend = matching[index];
                  final avatarUrl = friend.avatarUrl;
                  return Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
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
                        AppTapTarget(
                          onTap: () =>
                              openUserProfile(_navigationContext, friend.id),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.avatarBackground,
                            backgroundImage:
                                (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    color: AppColors.avatarIcon,
                                    size: 22,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => pushAppRoute(
                              _navigationContext,
                              MaterialPageRoute(
                                builder: (_) => PublicUserProfilePage(
                                  userId: friend.id,
                                  profile: friend,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend.resolvedDisplayName,
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${(_friendPoints[friend.id] ?? 0).toStringAsFixed(0)} EcoPoints',
                                  style: TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.bodySize,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_editingFriends)
                          IconButton.outlined(
                            tooltip: 'Remove friend',
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => _deleteFriend(friend),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileTabs() => CupertinoSlidingSegmentedControl<bool>(
    groupValue: _showFriends,
    children: const {
      false: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('Progress'),
      ),
      true: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text('Friends'),
      ),
    },
    onValueChanged: (value) {
      if (value != null) setState(() => _showFriends = value);
    },
  );

  Widget _buildProgressContent() {
    const subjects = [
      ('Environment & Sustainability', 'environment', Color(0xFF12B85A)),
      ('Engineering & Design', 'engineering', Color(0xFF009ECB)),
      ('Energy & Systems', 'energy', Color(0xFFE0B900)),
      ('Community & Built Environment', 'community', Color(0xFFE85870)),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 28),
      child: Column(
        children: [
          for (final subject in subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Material(
                color: Colors.white,
                elevation: 2,
                shadowColor: const Color(0x18000000),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: widget.compact
                      ? null
                      : () {
                          if (widget.onSubjectSelected != null) {
                            widget.onSubjectSelected!(subject.$1);
                          } else {
                            pushAppRoute(
                              _navigationContext,
                              MaterialPageRoute(
                                builder: (_) => HomeShellScreen(
                                  initialSection: 1,
                                  initialLibrarySubject: subject.$1,
                                  restoreJournal: false,
                                ),
                              ),
                            );
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: subject.$3,
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            'assets/project_setup/subject_${subject.$2}.svg',
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
                              Text(subject.$1, style: AppTypography.fieldLabel),
                              const SizedBox(height: 6),
                              Text(
                                '${(_subjectPoints[subject.$1] ?? 0).toStringAsFixed(0)} EcoPoints',
                                style: AppTypography.helper,
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _totalPoints == 0
                                    ? 0
                                    : ((_subjectPoints[subject.$1] ?? 0) /
                                              _totalPoints)
                                          .clamp(0, 1),
                                color: subject.$3,
                                backgroundColor: const Color(0xFFF2F5F3),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                        if (!widget.compact)
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text(
              'EcoPoints by subject',
              style: AppTypography.helper,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return AnimatedBuilder(
        animation: desktopRouteObserver.changes,
        builder: (context, _) => DesktopSideScroll(
          key: const ValueKey('desktop-profile-progress'),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE2E8E3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Notifications',
                          onPressed: widget.onNotifications,
                          icon: Badge(
                            isLabelVisible: widget.notificationCount > 0,
                            label: Text('${widget.notificationCount}'),
                            child: const Icon(Icons.notifications_outlined),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          onPressed: widget.onLogout,
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                    _buildAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      _displayName,
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle,
                    ),
                    TextButton(
                      onPressed: () {
                        final id = _authService.currentUser?.id;
                        if (id != null) openUserProfile(_navigationContext, id);
                      },
                      child: const Text('View profile'),
                    ),
                    if (!desktopRouteObserver.showingProfile) ...[
                      const SizedBox(height: 16),
                      _buildStatsCard(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onMessages,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  widget.unreadMessageCount > 0
                      ? 'Messages (${widget.unreadMessageCount})'
                      : 'Messages',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              if (!desktopRouteObserver.showingProfile) ...[
                const SizedBox(height: 24),
                _buildProfileTabs(),
                const SizedBox(height: 20),
                AppContentTransition(
                  index: _showFriends,
                  child: _showFriends
                      ? _buildFriendsContent()
                      : _buildProgressContent(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Layout uses a Stack so the white card can overlap the green header,
    // and the avatar can straddle their boundary.
    //
    // Green bar: 0–100px
    // White card: starts at 80px (overlaps green by 20px), rounded top
    // Avatar centre: at 100px → Positioned top: 44 (44 + 56 = 100)
    // Content padding-top: 88px (card-top 80 → avatar bottom 156 → delta 76 + 12 gap)
    return Stack(
      fit: StackFit.expand,
      children: [
        // Green top section
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(color: AppColors.primary),
        ),

        // White rounded card (main scrollable content)
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: PageScrollWithFooter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 88), // clears avatar
                    Center(
                      child: Text(
                        _displayName,
                        style: const TextStyle(
                          fontFamily: AppTypography.headingFamily,
                          fontSize: AppTypography.sectionTitleSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _email.isNotEmpty ? _email : 'Member',
                        style: const TextStyle(
                          fontFamily: AppTypography.bodyFamily,
                          fontSize: AppTypography.helperSize,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppMetrics.fieldGap),
                    _buildStatsCard(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildProfileTabs(),
                    ),
                    const SizedBox(height: 20),
                    AppContentTransition(
                      index: _showFriends,
                      child: _showFriends
                          ? _buildFriendsContent()
                          : _buildProgressContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Avatar straddling the green/white boundary
        Positioned(
          top: 44,
          left: 0,
          right: 0,
          child: Center(child: _buildAvatar()),
        ),
      ],
    );
  }
}
