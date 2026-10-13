import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/collaboration_request.dart';
import 'package:juniper_journal/src/backend/db/models/friend_request.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/features/chat/chat.dart';
import 'package:juniper_journal/src/features/project/project.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/features/community/community.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/models/community_invite.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedIndex = 0;
  final _profileKey = GlobalKey<UserProfilePageState>();
  final ProjectsRepo _projectsRepo = ProjectsRepo();
  final FriendsRepo _friendsRepo = FriendsRepo();
  final ChatRepo _chatRepo = ChatRepo();
  final UsersRepo _usersRepo = UsersRepo();
  final CommunitiesRepo _communitiesRepo = CommunitiesRepo();
  String? _currentAvatarUrl;
  int _unreadCount = 0;
  int _pendingRequestCount = 0;
  List<Community> _communities = [];
  final Map<String, String> _ownerLabelByUserId = {};
  final Map<String, String?> _ownerAvatarByUserId = {};
  final Set<String> _likedProjectIds = {};
  final Set<String> _collaboratedProjectIds = {};
  final Map<String, List<UserProfile>> _collaboratorsByProjectId = {};
  Future<List<Project>?>? _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadFeedProjects();
    _loadUnreadCount();
    _loadPendingRequestCount();
    _loadCommunities();
  }

  Future<void> _loadCommunities() async {
    final communities = await _communitiesRepo.getUserCommunities();
    if (!mounted) return;
    setState(() => _communities = communities);
  }

  Future<void> _loadPendingRequestCount() async {
    final results = await Future.wait([
      _friendsRepo.getIncomingFriendRequests(),
      _projectsRepo.getPendingCollaborationRequests(),
      _communitiesRepo.getPendingInvites(),
    ]);
    if (!mounted) return;
    final friendCount = (results[0] as List?)?.length ?? 0;
    final collabCount = (results[1] as List).length;
    final communityCount = (results[2] as List).length;
    setState(
      () => _pendingRequestCount = friendCount + collabCount + communityCount,
    );
  }

  Future<void> _showNotifications() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(
        friendsRepo: _friendsRepo,
        projectsRepo: _projectsRepo,
        communitiesRepo: _communitiesRepo,
      ),
    );
    if (!mounted) return;
    _loadPendingRequestCount();
  }

  Future<void> _loadUnreadCount() async {
    final conversations = await _chatRepo.getConversations();
    if (!mounted) return;
    setState(() {
      _unreadCount =
          conversations?.fold<int>(0, (sum, c) => sum + c.unreadCount) ?? 0;
    });
  }

  Future<void> _refreshProjects() async {
    final nextFuture = _loadFeedProjects();
    setState(() {
      _projectsFuture = nextFuture;
    });
    await nextFuture;
    _loadCommunities();
  }

  Future<List<Project>?> _loadFeedProjects() async {
    final currentUserId = AuthService.instance.currentUser?.id;
    if (currentUserId == null) return [];

    final results = await Future.wait([
      _usersRepo.getCurrentUserProfile(),
      _friendsRepo.getFriends(),
    ]);
    final currentProfile = results[0] as dynamic;
    final friends = results[1] as List<dynamic>?;
    if (friends == null) return null;

    _ownerLabelByUserId
      ..clear()
      ..[currentUserId] = 'You';
    _ownerAvatarByUserId
      ..clear()
      ..[currentUserId] = currentProfile?.avatarUrl?.toString();
    if (mounted) {
      setState(() => _currentAvatarUrl = currentProfile?.avatarUrl?.toString());
    }
    final ownerIds = <String>{currentUserId};

    for (final friend in friends) {
      if (friend.id.isEmpty) continue;
      ownerIds.add(friend.id);
      final displayName = friend.displayName?.trim();
      final username = friend.username?.trim();
      _ownerLabelByUserId[friend.id] =
          (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (username != null && username.isNotEmpty ? '@$username' : 'Friend');
      final avatarUrl = friend.avatarUrl?.trim();
      _ownerAvatarByUserId[friend.id] =
          (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null;
    }

    final projectResults = await Future.wait([
      _projectsRepo.getProjectsForFeed(ownerIds: ownerIds.toList()),
      _projectsRepo.getCollaboratedProjects(),
    ]);

    final feedProjects = projectResults[0] as List<Project>?;
    final collaboratedProjects = projectResults[1] as List<Project>;

    if (feedProjects == null) return null;

    // Merge by project id (feed projects take priority for dedup)
    final projectMap = <String, Project>{for (final p in feedProjects) p.id: p};

    // Track collaborated project ids and ensure their owners are in the label map
    _collaboratedProjectIds.clear();
    final missingOwnerIds = <String>[];
    for (final p in collaboratedProjects) {
      _collaboratedProjectIds.add(p.id);
      if (!projectMap.containsKey(p.id)) {
        projectMap[p.id] = p;
        if (p.userId != null && !_ownerLabelByUserId.containsKey(p.userId)) {
          missingOwnerIds.add(p.userId!);
        }
      }
    }

    // Fetch profiles for project owners not yet in our label maps
    if (missingOwnerIds.isNotEmpty) {
      try {
        final profiles = await _usersRepo.getProfilesByIds(missingOwnerIds);
        for (final profile in profiles) {
          final displayName = profile.displayName?.trim();
          final username = profile.username?.trim();
          _ownerLabelByUserId[profile.id] =
              (displayName != null && displayName.isNotEmpty)
              ? displayName
              : (username != null && username.isNotEmpty
                    ? '@$username'
                    : 'User');
          final avatar = profile.avatarUrl?.trim();
          _ownerAvatarByUserId[profile.id] =
              (avatar != null && avatar.isNotEmpty) ? avatar : null;
        }
      } catch (_) {}
    }

    final mergedProjects = projectMap.values.toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    if (mergedProjects.isNotEmpty) {
      final collaboratorsMap = await _projectsRepo.getCollaboratorsForProjects(
        projectIds: mergedProjects.map((p) => p.id).toList(),
      );
      _collaboratorsByProjectId
        ..clear()
        ..addAll(collaboratorsMap);
    }

    if (mergedProjects.isNotEmpty) {
      final liked = await _projectsRepo.getLikedProjectIds(
        projectIds: mergedProjects.map((p) => p.id).toList(),
      );
      _likedProjectIds
        ..clear()
        ..addAll(liked);
    }
    return mergedProjects;
  }

  String _tabTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Journal';
      case 2:
        return 'Profile';
      default:
        return 'Home';
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JuniperAuthScreen()),
      (route) => false,
    );
  }

  Future<void> _openSearch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
    );
    if (!mounted) return;
    _refreshProjects();
  }

  // Shows create options as a popup above the FAB (does not cover the nav bar)
  Widget _buildNavBar(BuildContext ctx) {
    const barH = 56.0;
    const fabD = 72.0;
    const fabR = fabD / 2;
    const notchMargin = 8.0;
    final bottomPad = MediaQuery.of(ctx).padding.bottom;

    Widget navIcon(IconData icon, int index, {VoidCallback? onTapOverride}) =>
        _BottomNavIcon(
          icon: icon,
          isActive: _selectedIndex == index,
          onTap: onTapOverride ?? () => setState(() => _selectedIndex = index),
        );

    Widget profileIcon() => InkWell(
      onTap: () {
        setState(() => _selectedIndex = 2);
        _profileKey.currentState?.reload();
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _currentAvatarUrl != null
            ? CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(_currentAvatarUrl!),
              )
            : Icon(
                Icons.person,
                size: 28,
                color: _selectedIndex == 2
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
      ),
    );

    return SizedBox(
      height: barH + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Notched white bar ──────────────────────────────────────────
          Positioned.fill(
            child: PhysicalShape(
              clipper: _NavBarClipper(notchRadius: fabR + notchMargin),
              elevation: 8,
              color: AppColors.white,
              shadowColor: Colors.black,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [navIcon(Icons.home, 0)],
                      ),
                    ),
                    const SizedBox(width: fabD + notchMargin * 2),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [navIcon(Icons.article, 1), profileIcon()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── FAB ───────────────────────────────────────────────────────
          Positioned(
            top: -fabR,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                elevation: 6,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _showCreateOptions,
                  child: const SizedBox(
                    width: fabD,
                    height: fabD,
                    child: Icon(Icons.add, color: AppColors.white, size: 32),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateOptions() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: const Color.fromRGBO(60, 60, 60, 0.64),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final bottomPad = MediaQuery.of(context).padding.bottom + 168;
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            alignment: Alignment.bottomCenter,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                child: _CreateMenuDialog(
                  onClose: () => Navigator.pop(ctx),
                  onCommunityTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCommunityScreen(),
                      ),
                    );
                    if (!mounted) return;
                    _loadCommunities();
                  },
                  onJournalTap: () {
                    Navigator.pop(ctx);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const JournalAddToSheet(),
                    );
                  },
                  onProjectTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateProjectScreen(),
                      ),
                    );
                    if (!mounted) return;
                    _refreshProjects();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,

      // ---------- Bottom Navigation (custom notched bar) ----------
      bottomNavigationBar: _buildNavBar(context),

      // ---------- BODY ----------
      body: SafeArea(
        // On the profile tab the green bar extends into the status-bar area,
        // so we disable the top safe-area inset and add it manually below.
        top: _selectedIndex != 2,
        child: Column(
          children: [
            // ---------- FIXED TOP BAR ----------
            Container(
              color: _selectedIndex == 2 ? AppColors.primary : null,
              padding: EdgeInsets.fromLTRB(
                16.0,
                _selectedIndex == 2
                    ? MediaQuery.of(context).padding.top + 8
                    : 8,
                16.0,
                8,
              ),
              child: _selectedIndex == 2
                  ? Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                                if (!mounted) return;
                                _profileKey.currentState?.reload();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Settings',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _handleSignOut,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Logout',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: _openSearch,
                              icon: const Icon(Icons.search, size: 28),
                            ),
                          ),
                        ),
                        Text(
                          _tabTitle(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _showNotifications,
                                  icon: Badge(
                                    isLabelVisible: _pendingRequestCount > 0,
                                    label: Text(
                                      '$_pendingRequestCount',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ChatsListScreen(),
                                      ),
                                    );
                                    if (!mounted) return;
                                    _loadUnreadCount();
                                  },
                                  icon: Badge(
                                    isLabelVisible: _unreadCount > 0,
                                    label: Text(
                                      _unreadCount > 99
                                          ? '99+'
                                          : '$_unreadCount',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    child: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildProjectsSection(),
                  const JournalScreen(),
                  UserProfilePage(
                    key: _profileKey,
                    onProfileUpdated: _refreshProjects,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    final projectsFuture =
        _projectsFuture ?? (_projectsFuture = _loadFeedProjects());

    return FutureBuilder<List<Project>?>(
      future: projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return _ProjectsMessage(
            title: 'Unable to load projects',
            subtitle: 'Pull to refresh and try again.',
            onRefresh: _refreshProjects,
          );
        }

        final projects = snapshot.data!;
        if (projects.isEmpty) {
          return _ProjectsMessage(
            title: 'No projects yet',
            subtitle: 'Tap + to create your first project.',
            onRefresh: _refreshProjects,
          );
        }

        final currentUserId = AuthService.instance.currentUser?.id;
        return RefreshIndicator(
          onRefresh: _refreshProjects,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: projects.length + 1, // +1 for community carousel header
            separatorBuilder: (_, i) =>
                i == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CommunityCarousel(
                  communities: _communities,
                  onCommunityTap: (c) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityHomeScreen(community: c),
                    ),
                  ).then((_) => _loadCommunities()),
                  onCreateTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCommunityScreen(),
                      ),
                    );
                    if (!mounted) return;
                    _loadCommunities();
                  },
                );
              }
              final project = projects[index - 1];
              final projectId = project.id;
              final projectName = project.projectName.trim().isNotEmpty
                  ? project.projectName.trim()
                  : 'Untitled Project';
              final tags = project.tags;
              final imageUrl = project.imageUrl;
              final ownerId = project.userId;
              final isOwner =
                  (ownerId != null && ownerId == currentUserId) ||
                  _collaboratedProjectIds.contains(projectId);
              final ownerLabel = ownerId == null
                  ? null
                  : _ownerLabelByUserId[ownerId];
              final ownerAvatarUrl = ownerId == null
                  ? null
                  : _ownerAvatarByUserId[ownerId];

              return _ProjectCard(
                projectId: projectId,
                name: projectName,
                ownerLabel: ownerLabel,
                ownerAvatarUrl: ownerAvatarUrl,
                collaborators: _collaboratorsByProjectId[projectId] ?? [],
                tags: tags,
                imageUrl: imageUrl,
                description: project.problemStatement,
                initialLikes: project.likes,
                initialHasLiked: _likedProjectIds.contains(projectId),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDashboard(
                        projectId: projectId,
                        projectName: projectName,
                        tags: tags,
                        isOwner: isOwner,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  _refreshProjects();
                },
              );
            },
          ),
        );
      },
    );
  }
}

// Simple widget for bottom icons
class _NavBarClipper extends CustomClipper<Path> {
  final double notchRadius;
  const _NavBarClipper({required this.notchRadius});

  @override
  Path getClip(Size size) {
    return const CircularNotchedRectangle().getOuterPath(
      Offset.zero & size,
      Rect.fromCenter(
        center: Offset(size.width / 2, 0),
        width: notchRadius * 2,
        height: notchRadius * 2,
      ),
    );
  }

  @override
  bool shouldReclip(_NavBarClipper old) => old.notchRadius != notchRadius;
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Icon(
          icon,
          size: 28,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _CreateMenuDialog extends StatelessWidget {
  const _CreateMenuDialog({
    required this.onClose,
    required this.onCommunityTap,
    required this.onJournalTap,
    required this.onProjectTap,
  });

  static const _primary = Color(0xFF5DB075);
  static const _iconBackground = Color(0xFFD2E2DA);

  final VoidCallback onClose;
  final VoidCallback onCommunityTap;
  final VoidCallback onJournalTap;
  final VoidCallback onProjectTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      height: 312,
      child: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/create_menu/card_background.svg',
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 120,
            top: 10,
            child: Container(
              width: 22,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF707070),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 21,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                width: 29,
                height: 33,
                child: SvgPicture.asset(
                  'assets/create_menu/close.svg',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 99,
            top: 21,
            width: 64,
            height: 34,
            child: Text(
              'Create',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 28 / 16,
              ),
            ),
          ),
          Positioned(
            left: 44,
            top: 63.142578125,
            child: _CreateMenuOption(
              assetPath: 'assets/create_menu/community.svg',
              label: 'Community',
              labelGap: 11.89896011352539,
              labelWidth: 83,
              iconSize: const Size(30.86968421936035, 30.86968421936035),
              onTap: onCommunityTap,
            ),
          ),
          Positioned(
            left: 154,
            top: 63.142578125,
            child: _CreateMenuOption(
              assetPath: 'assets/create_menu/journal.svg',
              label: 'Journal',
              labelGap: 11.89896011352539,
              labelWidth: 61,
              iconSize: const Size(23.3835506439209, 24.24220848083496),
              onTap: onJournalTap,
            ),
          ),
          Positioned(
            left: 99,
            top: 183.982421875,
            child: _CreateMenuOption(
              assetPath: 'assets/create_menu/new_project.svg',
              label: 'New\nProject',
              labelGap: 8.05911636352539,
              labelWidth: 69,
              iconSize: const Size(23.3835506439209, 23.460201263427734),
              onTap: onProjectTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMenuOption extends StatelessWidget {
  const _CreateMenuOption({
    required this.label,
    required this.labelGap,
    required this.labelWidth,
    required this.onTap,
    this.assetPath,
    this.iconSize,
    this.iconBuilder,
  });

  final String label;
  final double labelGap;
  final double labelWidth;
  final VoidCallback onTap;
  final String? assetPath;
  final Size? iconSize;
  final Widget? iconBuilder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 53.78216552734375,
            height: 53.95846176147461,
            decoration: BoxDecoration(
              color: _CreateMenuDialog._iconBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child:
                  iconBuilder ??
                  SvgPicture.asset(
                    assetPath!,
                    width: iconSize!.width,
                    height: iconSize!.height,
                    fit: BoxFit.fill,
                  ),
            ),
          ),
          SizedBox(height: labelGap),
          SizedBox(
            width: labelWidth,
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1,
                color: _CreateMenuDialog._primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final String projectId;
  final String name;
  final String? ownerLabel;
  final String? ownerAvatarUrl;
  final List<UserProfile> collaborators;
  final List<String> tags;
  final String? imageUrl;
  final String? description;
  final int initialLikes;
  final bool initialHasLiked;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.projectId,
    required this.name,
    required this.ownerLabel,
    required this.ownerAvatarUrl,
    required this.collaborators,
    required this.tags,
    required this.imageUrl,
    required this.onTap,
    this.description,
    this.initialLikes = 0,
    this.initialHasLiked = false,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  final ProjectsRepo _projectsRepo = ProjectsRepo();
  late int _likes;
  bool _hasLiked = false;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.initialLikes;
    _hasLiked = widget.initialHasLiked;
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    _isLiking = true;

    final prevLikes = _likes;
    final prevHasLiked = _hasLiked;

    setState(() {
      _hasLiked = !_hasLiked;
      _likes = _hasLiked ? prevLikes + 1 : prevLikes - 1;
    });

    final ok = _hasLiked
        ? await _projectsRepo.likeProject(id: widget.projectId)
        : await _projectsRepo.unlikeProject(id: widget.projectId);

    if (!mounted) return;
    setState(() {
      _isLiking = false;
      if (!ok) {
        _hasLiked = prevHasLiked;
        _likes = prevLikes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image — full width, flush to card edges ──────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    (widget.imageUrl != null &&
                        widget.imageUrl!.trim().isNotEmpty)
                    ? Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultBanner(),
                      )
                    : _buildDefaultBanner(),
              ),
            ),
            // ── Card content ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            widget.ownerLabel != null &&
                                widget.ownerLabel!.trim().isNotEmpty
                            ? Row(
                                children: [
                                  _AvatarStack(
                                    ownerAvatarUrl: widget.ownerAvatarUrl,
                                    collaborators: widget.collaborators,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      () {
                                        final currentUserId = AuthService
                                            .instance
                                            .currentUser
                                            ?.id;
                                        final names = [
                                          widget.ownerLabel!,
                                          ...widget.collaborators.map(
                                            (c) => c.id == currentUserId
                                                ? 'You'
                                                : c.resolvedDisplayName,
                                          ),
                                        ];
                                        return 'by ${names.join(', ')}';
                                      }(),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      GestureDetector(
                        onTap: _handleLike,
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_florist,
                              size: 22,
                              color: _hasLiked
                                  ? AppColors.primaryDark
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_likes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _hasLiked
                                    ? AppColors.primaryDark
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => CommentsSheet(
                            projectId: widget.projectId,
                            projectName: widget.name,
                            description: widget.description,
                          ),
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 22,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.description != null &&
                      widget.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.description!.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (widget.tags.isEmpty)
                    const Text(
                      'No tags',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.tags
                          .map((tag) => tag.split('|').first.trim())
                          .toSet()
                          .map(
                            (domain) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                domain,
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryTint, Color(0xFFD2EAD8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.landscape_outlined,
          size: 30,
          color: AppColors.avatarIcon,
        ),
      ),
    );
  }
}

class _NotificationsSheet extends StatefulWidget {
  final FriendsRepo friendsRepo;
  final ProjectsRepo projectsRepo;
  final CommunitiesRepo communitiesRepo;

  const _NotificationsSheet({
    required this.friendsRepo,
    required this.projectsRepo,
    required this.communitiesRepo,
  });

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _isLoading = true;
  List<FriendRequest> _friendRequests = const [];
  List<CollaborationRequest> _collabRequests = const [];
  List<CommunityInvite> _communityInvites = const [];
  final Map<String, bool> _loadingByUserId = {};
  final Map<String, bool> _loadingByCollabId = {};
  final Map<String, bool> _loadingByCommunityId = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      widget.friendsRepo.getIncomingFriendRequests(),
      widget.projectsRepo.getPendingCollaborationRequests(),
      widget.communitiesRepo.getPendingInvites(),
    ]);
    if (!mounted) return;
    setState(() {
      _friendRequests = (results[0] as List<FriendRequest>?) ?? [];
      _collabRequests = results[1] as List<CollaborationRequest>;
      _communityInvites = results[2] as List<CommunityInvite>;
      _isLoading = false;
    });
  }

  Future<void> _acceptFriend(FriendRequest request) async {
    setState(() => _loadingByUserId[request.requesterId] = true);
    final ok = await widget.friendsRepo.acceptFriendRequest(
      requesterId: request.requesterId,
    );
    if (!mounted) return;
    setState(() => _loadingByUserId.remove(request.requesterId));
    if (!ok) {
      showTopSnackBar(context, 'Failed to accept request', isError: true);
      return;
    }
    _loadAll();
  }

  Future<void> _declineFriend(FriendRequest request) async {
    setState(() => _loadingByUserId[request.requesterId] = true);
    final ok = await widget.friendsRepo.declineFriendRequest(
      requesterId: request.requesterId,
    );
    if (!mounted) return;
    setState(() => _loadingByUserId.remove(request.requesterId));
    if (!ok) {
      showTopSnackBar(context, 'Failed to decline request', isError: true);
      return;
    }
    _loadAll();
  }

  Future<void> _respondCommunity(CommunityInvite invite, bool accept) async {
    setState(() => _loadingByCommunityId[invite.id] = true);
    final ok = await widget.communitiesRepo.respondToInvite(invite.id, accept);
    if (!mounted) return;
    setState(() => _loadingByCommunityId.remove(invite.id));
    if (!ok) {
      showTopSnackBar(
        context,
        accept ? 'Failed to accept invite' : 'Failed to decline invite',
        isError: true,
      );
      return;
    }
    _loadAll();
  }

  Future<void> _respondCollab(CollaborationRequest request, bool accept) async {
    setState(() => _loadingByCollabId[request.id] = true);
    final ok = await widget.projectsRepo.respondToCollaborationRequest(
      id: request.id,
      accept: accept,
    );
    if (!mounted) return;
    setState(() => _loadingByCollabId.remove(request.id));
    if (!ok) {
      showTopSnackBar(
        context,
        accept ? 'Failed to accept invite' : 'Failed to decline invite',
        isError: true,
      );
      return;
    }
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final hasAny =
        _friendRequests.isNotEmpty ||
        _collabRequests.isNotEmpty ||
        _communityInvites.isNotEmpty;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasAny
                    ? const Center(
                        child: Text(
                          'No pending notifications.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          if (_friendRequests.isNotEmpty) ...[
                            const _SectionHeader(title: 'Friend Requests'),
                            ..._friendRequests.map((request) {
                              final isActionLoading =
                                  _loadingByUserId[request.requesterId] == true;
                              final displayName =
                                  (request.displayName?.trim().isNotEmpty ==
                                      true)
                                  ? request.displayName!.trim()
                                  : (request.username?.trim().isNotEmpty == true
                                        ? '@${request.username!.trim()}'
                                        : 'User');
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryTint,
                                  backgroundImage:
                                      (request.avatarUrl != null &&
                                          request.avatarUrl!.isNotEmpty)
                                      ? NetworkImage(request.avatarUrl!)
                                      : null,
                                  child:
                                      (request.avatarUrl == null ||
                                          request.avatarUrl!.isEmpty)
                                      ? const Icon(
                                          Icons.person_outline,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: isActionLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () =>
                                                _declineFriend(request),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Decline'),
                                          ),
                                          const SizedBox(width: 6),
                                          FilledButton(
                                            onPressed: () =>
                                                _acceptFriend(request),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ],
                                      ),
                              );
                            }),
                          ],
                          if (_collabRequests.isNotEmpty) ...[
                            if (_friendRequests.isNotEmpty)
                              const SizedBox(height: 12),
                            const _SectionHeader(title: 'Project Invites'),
                            ..._collabRequests.map((request) {
                              final isActionLoading =
                                  _loadingByCollabId[request.id] == true;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryTint,
                                  backgroundImage:
                                      (request.inviterAvatarUrl != null &&
                                          request.inviterAvatarUrl!.isNotEmpty)
                                      ? NetworkImage(request.inviterAvatarUrl!)
                                      : null,
                                  child:
                                      (request.inviterAvatarUrl == null ||
                                          request.inviterAvatarUrl!.isEmpty)
                                      ? const Icon(
                                          Icons.person_outline,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  '${request.resolvedInviterName} invited you to collaborate',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  request.projectName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: isActionLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () =>
                                                _respondCollab(request, false),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Decline'),
                                          ),
                                          const SizedBox(width: 6),
                                          FilledButton(
                                            onPressed: () =>
                                                _respondCollab(request, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ],
                                      ),
                              );
                            }),
                          ],
                          if (_communityInvites.isNotEmpty) ...[
                            if (_friendRequests.isNotEmpty ||
                                _collabRequests.isNotEmpty)
                              const SizedBox(height: 12),
                            const _SectionHeader(title: 'Community Invites'),
                            ..._communityInvites.map((invite) {
                              final isLoading =
                                  _loadingByCommunityId[invite.id] == true;
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryTint,
                                  backgroundImage:
                                      (invite.communityImageUrl != null &&
                                          invite.communityImageUrl!.isNotEmpty)
                                      ? NetworkImage(invite.communityImageUrl!)
                                      : null,
                                  child:
                                      (invite.communityImageUrl == null ||
                                          invite.communityImageUrl!.isEmpty)
                                      ? const Icon(
                                          Icons.group_outlined,
                                          color: AppColors.primary,
                                        )
                                      : null,
                                ),
                                title: Text(
                                  '${invite.inviterLabel} invited you to join',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  invite.communityName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            onPressed: () => _respondCommunity(
                                              invite,
                                              false,
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                color: Colors.red,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Decline'),
                                          ),
                                          const SizedBox(width: 6),
                                          FilledButton(
                                            onPressed: () =>
                                                _respondCommunity(invite, true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                  ),
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ],
                                      ),
                              );
                            }),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final String? ownerAvatarUrl;
  final List<UserProfile> collaborators;

  const _AvatarStack({this.ownerAvatarUrl, required this.collaborators});

  static const double _diameter = 24.0;
  static const double _offset = 16.0;
  static const int _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    // Build flat list: owner first, then collaborators (avatar URLs)
    final allUrls = <String?>[
      ownerAvatarUrl,
      ...collaborators.map((c) => c.avatarUrl),
    ];

    final overflow = allUrls.length > _maxVisible
        ? allUrls.length - (_maxVisible - 1)
        : 0;
    final visible = overflow > 0
        ? allUrls.take(_maxVisible - 1).toList()
        : allUrls;
    final slotCount = visible.length + (overflow > 0 ? 1 : 0);
    final totalWidth = _diameter + (_offset * (slotCount - 1));

    return SizedBox(
      width: totalWidth,
      height: _diameter,
      child: Stack(
        children: [
          // Render in reverse so index 0 (owner) ends up on top
          for (int i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * _offset,
              child: _StackAvatar(url: visible[i], diameter: _diameter),
            ),
          if (overflow > 0)
            Positioned(
              left: visible.length * _offset,
              child: Container(
                width: _diameter,
                height: _diameter,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    '…',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
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

class _StackAvatar extends StatelessWidget {
  final String? url;
  final double diameter;

  const _StackAvatar({required this.url, required this.diameter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: ClipOval(
        child: (url != null && url!.trim().isNotEmpty)
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.borderLight,
    child: const Icon(Icons.person, size: 14, color: AppColors.textSecondary),
  );
}

class _ProjectsMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Future<void> Function() onRefresh;

  const _ProjectsMessage({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CommunityCarousel ────────────────────────────────────────────────────────

class _CommunityCarousel extends StatelessWidget {
  const _CommunityCarousel({
    required this.communities,
    required this.onCommunityTap,
    required this.onCreateTap,
  });

  final List<Community> communities;
  final void Function(Community) onCommunityTap;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return GestureDetector(
        onTap: onCreateTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add_outlined,
                color: AppColors.primary.withValues(alpha: 0.6),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Click here to join a community',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: communities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final c = communities[index];
          return GestureDetector(
            onTap: () => onCommunityTap(c),
            child: Container(
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
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
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: SizedBox(
                      width: 72,
                      height: double.infinity,
                      child: (c.imageUrl != null && c.imageUrl!.isNotEmpty)
                          ? Image.network(c.imageUrl!, fit: BoxFit.cover)
                          : Container(
                              color: c.bannerColor,
                              child: const Icon(
                                Icons.group,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
