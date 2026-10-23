import '../../../shared/widgets/journal_preview_image.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import '../../site/pages/site_information_page.dart';
import '../../../shared/widgets/journal_entry_menu.dart';
import '../../../shared/widgets/item_action_menu.dart';
import '../../project/utils/journal_completion.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import '../../../shared/widgets/journal_draft_session.dart';
import '../../../shared/widgets/navigation_scroll_reset.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'public_user_profile.dart';
import '../../../shared/widgets/explained_project_tag.dart';
import '../../community/utils/community_visit_history.dart';
import '../../../shared/widgets/journal_publication.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import '../../../shared/widgets/adaptive_app_shell.dart';
import 'project_notification_destination.dart';
import '../../../shared/widgets/create_menu_dialog.dart';
import '../../../shared/widgets/app_refresh_indicator.dart';
import '../../project/pages/project_development_flow.dart'
    show normalizePhase;
import '../../../shared/widgets/journal_project_link.dart';
import '../../project/pages/journal_entry_view.dart';
import '../../../backend/db/models/journal_entry.dart';
import 'dart:async';

import '../../../shared/widgets/app_tab_transition.dart';
import 'explore_page.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
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
  const HomeShellScreen({
    super.key,
    this.initialSection = 0,
    this.restoreJournal = true,
    this.informationPage,
  });
  final int initialSection;
  final bool restoreJournal;
  final String? informationPage;

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  Timer? _notificationRefresh;
  late int _selectedIndex = widget.initialSection;
  int _feedRevision = 0;
  final _exploreKey = GlobalKey<ProjectBrowsePageState>();
  final _libraryKey = GlobalKey<ProjectBrowsePageState>();
  final Set<int> _visitedSections = {0};
  final _profileKey = GlobalKey<UserProfilePageState>();
  final _desktopProfileKey = GlobalKey<UserProfilePageState>();
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
  final Map<String, List<UserProfile>> _collaboratorsByProjectId = {};
  final Map<String, JournalEntry> _feedEntryByProject = {};
  Future<List<Project>?>? _projectsFuture;
  int _visibleFeedItems = 10;

  @override
  void initState() {
    super.initState();
    _visitedSections.add(widget.initialSection);
    JournalPublication.onPublished = _journalPublished;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.restoreJournal) _restoreInterruptedJournal();
    });
    _projectsFuture = _loadFeedProjects();
    _loadUnreadCount();
    _loadPendingRequestCount();
    _loadCommunities();
    _notificationRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadPendingRequestCount();
      if (_selectedIndex == 0 && ModalRoute.of(context)?.isCurrent == true) {
        _refreshFeedSilently();
      }
    });
  }

  Future<void> _restoreInterruptedJournal() async {
    try {
      final entry = await JournalDraftSession.interruptedEntry(_projectsRepo);
      if (entry == null || !mounted) return;
      final project = await _projectsRepo.getProjectById(entry.projectId);
      if (project == null ||
          !mounted ||
          ModalRoute.of(context)?.isCurrent != true)
        return;
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) =>
              editableJournalEntryPage(entry, project, _projectsRepo),
        ),
      );
      if (mounted) _refreshProjects();
    } catch (error) {
      debugPrint('Could not reopen interrupted journal: $error');
    }
  }

  void _journalPublished() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    setState(() {
      _selectedIndex = 0;
      _feedRevision++;
    });
    _refreshProjects();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTopSnackBar(context, 'Journal entry submitted.');
    });
    Navigator.of(
      context,
    ).popUntil((candidate) => candidate == route || candidate.isFirst);
  }

  @override
  void dispose() {
    if (JournalPublication.onPublished == _journalPublished)
      JournalPublication.onPublished = null;
    _notificationRefresh?.cancel();
    super.dispose();
  }

  Future<void> _loadCommunities() async {
    final communities = await _communitiesRepo.getUserCommunities();
    if (!mounted) return;
    final ranked = await CommunityVisitHistory.rank(communities);
    if (!mounted) return;
    setState(() => _communities = ranked);
  }

  Future<void> _loadPendingRequestCount() async {
    final results = await Future.wait([
      _friendsRepo.getIncomingFriendRequests(),
      _projectsRepo.getPendingCollaborationRequests(),
      _communitiesRepo.getPendingInvites(),
      _projectsRepo.getProjectNotifications(),
    ]);
    if (!mounted) return;
    final friendCount = (results[0] as List?)?.length ?? 0;
    final collabCount = (results[1] as List).length;
    final communityCount = (results[2] as List).length;
    setState(
      () => _pendingRequestCount =
          friendCount +
          collabCount +
          communityCount +
          (results[3] as List<Map<String, dynamic>>)
              .where((n) => n['read_at'] == null)
              .length,
    );
  }

  Future<void> _showNotifications() async {
    await showAppModalBottomSheet(
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

  bool _refreshingFeed = false;
  Future<void> _refreshFeedSilently() async {
    if (_refreshingFeed) return;
    _refreshingFeed = true;
    try {
      final projects = await _loadFeedProjects();
      if (mounted && projects != null) {
        setState(() => _projectsFuture = Future.value(projects));
      }
    } finally {
      _refreshingFeed = false;
    }
  }

  Future<void> _refreshProjects() async {
    final nextFuture = _loadFeedProjects();
    setState(() {
      _projectsFuture = nextFuture;
    });
    await nextFuture;
    _desktopProfileKey.currentState?.reload();
    _exploreKey.currentState?.reload();
    _libraryKey.currentState?.reload();
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

    final feedProjects = await _projectsRepo.getProjectsForFeed(
      ownerIds: ownerIds.toList(),
    );
    if (feedProjects == null) return null;
    final projectMap = {
      for (final project in feedProjects) project.id: project,
    };
    final missingOwnerIds = feedProjects
        .map((p) => p.userId)
        .whereType<String>()
        .where((id) => !_ownerLabelByUserId.containsKey(id))
        .toSet()
        .toList();

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

    final mergedProjects = await _projectsRepo
        .projectsWithCompletedJournalEntries(projectMap.values.toList());

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
    final entries = await Future.wait(
      mergedProjects.map((p) => _projectsRepo.getPublishedJournalEntries(p.id)),
    );
    _feedEntryByProject.clear();
    for (var i = 0; i < mergedProjects.length; i++) {
      final latest = completedJournalFeedEntries(entries[i]);
      if (latest.isNotEmpty) {
        _feedEntryByProject[mergedProjects[i].id] = latest.first;
      }
    }
    final visible = mergedProjects
        .where((p) => _feedEntryByProject.containsKey(p.id))
        .toList();
    DateTime activity(Project project) {
      final entry = _feedEntryByProject[project.id]!;
      return entry.updatedAt ?? entry.createdAt ?? DateTime(1970);
    }

    visible.sort((a, b) => activity(b).compareTo(activity(a)));
    return visible;
  }

  String _tabTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Journal Library';
      case 3:
        return 'Explore';
      case 2:
        return 'Profile';
      default:
        return 'Home';
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    DesktopShellScope.of(context)?.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const JuniperAuthScreen()),
      (route) => false,
    );
  }

  Future<void> _openMessages() async {
    await pushAppRoute(
      context,
      MaterialPageRoute(builder: (_) => const ChatsListScreen()),
    );
    if (mounted) _loadUnreadCount();
  }

  Future<void> _openSearch() async {
    await pushAppRoute(
      context,
      MaterialPageRoute(builder: (_) => const HomeSearchScreen()),
    );
    if (!mounted) return;
    _refreshProjects();
  }

  // Shows create options as a popup above the FAB (does not cover the nav bar)
  void _selectSection(int index) {
    if (widget.informationPage != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              HomeShellScreen(initialSection: index, restoreJournal: false),
        ),
        (_) => false,
      );
      return;
    }
    resetPageScroll(context);
    setState(() {
      _selectedIndex = index;
      _visitedSections.add(index);
    });
    _desktopProfileKey.currentState?.reload();
    if (index == 3) _exploreKey.currentState?.reload();
    if (index == 1) _libraryKey.currentState?.reload();
    if (index == 2) _profileKey.currentState?.reload();
  }

  Widget _buildNavBar(BuildContext ctx) {
    const barH = 56.0;
    const fabD = 72.0;
    const fabR = fabD / 2;
    const notchMargin = 8.0;
    final bottomPad = MediaQuery.of(ctx).padding.bottom;

    Widget navIcon(IconData icon, int index, {VoidCallback? onTapOverride}) =>
        _BottomNavIcon(
          icon: icon,
          iconSize: index == 3 ? 34 : 28,
          isActive: _selectedIndex == index,
          onTap:
              onTapOverride ??
              () {
                _selectSection(index);
              },
        );

    Widget profileIcon() => InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = 2;
          _visitedSections.add(2);
        });
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
      // Keep the entire create button inside the Stack's hit-test bounds.
      height: fabR + barH + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Notched white bar ──────────────────────────────────────────
          Positioned.fill(
            top: fabR,
            child: CustomPaint(
              foregroundPainter: _NavBarBorderPainter(
                notchRadius: fabR + notchMargin,
              ),
              child: PhysicalShape(
                clipper: _NavBarClipper(notchRadius: fabR + notchMargin),
                elevation: 0,
                color: AppColors.white,
                shadowColor: Colors.black,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            navIcon(Icons.home, 0),
                            navIcon(Icons.landscape_outlined, 3),
                          ],
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
          ),
          // ── FAB ───────────────────────────────────────────────────────
          Positioned(
            top: 0,
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
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: const Color.fromRGBO(60, 60, 60, 0.64),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            alignment: Alignment.center,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CreateMenuDialog(
                  onClose: () => Navigator.pop(ctx),
                  onCommunityTap: () async {
                    Navigator.pop(ctx);
                    final result = await pushAppRoute(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCommunityScreen(),
                      ),
                    );
                    if (!mounted) return;
                    _loadCommunities();
                    if (result == false) _showCreateOptions();
                  },
                  onJournalTap: () async {
                    Navigator.pop(ctx);
                    final result = await showAppModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const JournalAddToSheet(),
                    );
                    if (mounted && result == false) _showCreateOptions();
                  },
                  onProjectTap: () async {
                    Navigator.pop(ctx);
                    final result = await pushAppRoute(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateProjectScreen(),
                      ),
                    );
                    if (!mounted) return;
                    _refreshProjects();
                    if (result == false) _showCreateOptions();
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
    PageRefreshState.remember(context, {
      'kind': widget.informationPage ?? 'home',
      if (widget.informationPage == null) 'section': _selectedIndex,
    });
    return AdaptiveAppShell(
      selectedIndex: widget.informationPage == null ? _selectedIndex : -1,
      onSelect: (index) async {
        final navigator = Navigator.of(context);
        if (!await JournalDraftGuard.leaveCurrent(navigator) || !mounted)
          return;
        if (widget.informationPage != null) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  HomeShellScreen(initialSection: index, restoreJournal: false),
            ),
            (_) => false,
          );
          return;
        }
        while (navigator.canPop()) {
          final route = desktopRouteObserver.current;
          final popped = await navigator.maybePop();
          if (!popped || !mounted) return;
          // maybePop honors each editor's PopScope and autosave hooks.
          await WidgetsBinding.instance.endOfFrame;
          if (desktopRouteObserver.current == route) return;
        }
        if (mounted) _selectSection(index);
      },
      onCreate: _showCreateOptions,
      mobileNavigation: _buildNavBar(context),
      desktopSidebar: UserProfilePage(
        key: _desktopProfileKey,
        compact: true,
        onProfileUpdated: _refreshProjects,
        onSettings: () => pushAppRoute(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
        onLogout: _handleSignOut,
        onNotifications: _showNotifications,
        onMessages: _openMessages,
        notificationCount: _pendingRequestCount,
        unreadMessageCount: _unreadCount,
      ),

      // ---------- BODY ----------
      body: widget.informationPage != null
          ? SiteInformationPage(page: widget.informationPage!, embedded: true)
          : SafeArea(
              bottom: false,
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
                                      await pushAppRoute(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SettingsScreen(),
                                        ),
                                      );
                                      if (!mounted) return;
                                      _profileKey.currentState?.reload();
                                      await _refreshProjects();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Settings',
                                      style: TextStyle(
                                        fontFamily: AppTypography.bodyFamily,
                                        fontSize: AppTypography.buttonSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Text(
                                'Profile',
                                style: TextStyle(
                                  fontFamily: AppTypography.headingFamily,
                                  fontSize: AppTypography.sectionTitleSize,
                                  fontWeight: FontWeight.w600,
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
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(
                                        fontFamily: AppTypography.bodyFamily,
                                        fontSize: AppTypography.buttonSize,
                                        fontWeight: FontWeight.w500,
                                      ),
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
                                    tooltip: _selectedIndex == 1
                                        ? 'Back to Home'
                                        : 'Search',
                                    onPressed: _selectedIndex == 1
                                        ? () =>
                                              setState(() => _selectedIndex = 0)
                                        : _openSearch,
                                    icon: Icon(
                                      _selectedIndex == 1
                                          ? Icons.chevron_left
                                          : Icons.search,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                _tabTitle(),
                                style: const TextStyle(
                                  fontFamily: AppTypography.headingFamily,
                                  fontSize: AppTypography.pageTitleSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (MediaQuery.sizeOf(context).width <
                                          AdaptiveAppShell
                                              .desktopBreakpoint) ...[
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: _showNotifications,
                                          icon: Badge(
                                            isLabelVisible:
                                                _pendingRequestCount > 0,
                                            label: Text(
                                              '$_pendingRequestCount',
                                              style: const TextStyle(
                                                fontFamily:
                                                    AppTypography.bodyFamily,
                                                fontSize:
                                                    AppTypography.captionSize,
                                              ),
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
                                            await pushAppRoute(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ChatsListScreen(),
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
                                              style: const TextStyle(
                                                fontFamily:
                                                    AppTypography.bodyFamily,
                                                fontSize:
                                                    AppTypography.captionSize,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 26,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  Expanded(
                    child: AppTabStack(
                      index: _selectedIndex,
                      children: [
                        _buildProjectsSection(),
                        _visitedSections.contains(1)
                            ? JournalScreen(browseKey: _libraryKey)
                            : const SizedBox.shrink(),
                        _visitedSections.contains(2)
                            ? UserProfilePage(
                                key: _profileKey,
                                onProfileUpdated: _refreshProjects,
                              )
                            : const SizedBox.shrink(),
                        _visitedSections.contains(3)
                            ? ProjectBrowsePage(key: _exploreKey)
                            : const SizedBox.shrink(),
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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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

        final visibleCount = projects.length < _visibleFeedItems
            ? projects.length
            : _visibleFeedItems;
        final hasMore = visibleCount < projects.length;
        return AppRefreshIndicator(
          onRefresh: _refreshProjects,
          child: ListView.separated(
            key: ValueKey('home-feed-$_feedRevision'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              116 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: visibleCount + 1 + (hasMore ? 1 : 0),
            separatorBuilder: (_, i) =>
                i == 0 ? const SizedBox.shrink() : const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == visibleCount + 1 && hasMore) {
                return Center(
                  child: OutlinedButton(
                    key: const ValueKey('home-feed-load-more'),
                    onPressed: () => setState(() => _visibleFeedItems += 10),
                    child: const Text('Load more'),
                  ),
                );
              }
              if (index == 0) {
                return _CommunityCarousel(
                  communities: _communities,
                  onCommunityTap: (c) => pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityHomeScreen(community: c),
                    ),
                  ).then((_) => _loadCommunities()),
                  onCreateTap: () async {
                    await pushAppRoute(
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
              final feedEntry = _feedEntryByProject[projectId]!;
              final imageUrl = journalFeedPreviewImage(
                feedEntry.content,
                projectCover: project.imageUrl,
              );
              final ownerId = project.userId;

              final ownerLabel = ownerId == null
                  ? null
                  : _ownerLabelByUserId[ownerId];
              final ownerAvatarUrl = ownerId == null
                  ? null
                  : _ownerAvatarByUserId[ownerId];

              final viewer = AuthService.instance.currentUser?.id;
              final projectParticipant =
                  viewer != null &&
                  (project.userId == viewer ||
                      (_collaboratorsByProjectId[projectId]?.any(
                            (p) => p.id == viewer,
                          ) ??
                          false));
              return _ProjectCard(
                projectId: projectId,
                onEdit:
                    projectParticipant &&
                        (feedEntry.authorId ==
                                AuthService.instance.currentUser?.id ||
                            project.userId ==
                                AuthService.instance.currentUser?.id ||
                            (feedEntry.participantIds.contains(
                                  AuthService.instance.currentUser?.id,
                                ) &&
                                (_collaboratorsByProjectId[projectId]?.any(
                                      (p) =>
                                          p.id ==
                                          AuthService.instance.currentUser?.id,
                                    ) ??
                                    false)))
                    ? () async {
                        await pushAppRoute(
                          context,
                          MaterialPageRoute(
                            builder: (_) => editableJournalEntryPage(
                              feedEntry,
                              project,
                              _projectsRepo,
                            ),
                          ),
                        );
                        if (mounted) await _refreshProjects();
                      }
                    : null,
                onDelete:
                    projectParticipant &&
                        (feedEntry.authorId ==
                                AuthService.instance.currentUser?.id ||
                            project.userId ==
                                AuthService.instance.currentUser?.id)
                    ? () async {
                        if (await confirmDeleteJournalEntry(
                              context,
                              _projectsRepo,
                              feedEntry,
                            ) &&
                            mounted)
                          await _refreshProjects();
                      }
                    : null,
                name: _feedEntryByProject[projectId]!.title,
                phase: _feedEntryByProject[projectId]!.progress,
                projectName: projectName,
                onProjectTap: () =>
                    openJournalProject(context, project, _projectsRepo),
                ownerId: ownerId,
                ownerLabel: ownerLabel,
                ownerAvatarUrl: ownerAvatarUrl,
                collaborators: _collaboratorsByProjectId[projectId] ?? [],
                tags: tags,
                imageUrl: imageUrl,
                description: project.problemStatement,
                initialLikes: project.likes,
                initialHasLiked: _likedProjectIds.contains(projectId),
                onTap: () async {
                  await pushAppRoute(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JournalEntryView(
                        entry: _feedEntryByProject[projectId]!,
                        project: project,
                        projectsRepo: _projectsRepo,
                      ),
                    ),
                  );
                  if (mounted) await _refreshProjects();
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

class _NavBarBorderPainter extends CustomPainter {
  const _NavBarBorderPainter({required this.notchRadius});
  final double notchRadius;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _NavBarClipper(notchRadius: notchRadius).getClip(size),
      Paint()
        ..color = const Color(0xFFD1DBD5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  @override
  bool shouldRepaint(_NavBarBorderPainter oldDelegate) =>
      oldDelegate.notchRadius != notchRadius;
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavIcon({
    required this.icon,
    this.iconSize = 28,
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
          size: iconSize,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final String projectId;
  final String name;
  final String? phase;
  final String projectName;
  final VoidCallback onProjectTap;
  final VoidCallback? onEdit, onDelete;
  final String? ownerId;
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
    required this.phase,
    required this.projectName,
    required this.onProjectTap,
    this.onEdit,
    this.onDelete,
    this.ownerId,
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
            if (widget.imageUrl?.trim().isNotEmpty == true)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SizedBox(
                    width: constraints.maxWidth,
                    height: (constraints.maxWidth * 9 / 16).clamp(0.0, 260.0),
                    child:
                        (widget.imageUrl != null &&
                            widget.imageUrl!.trim().isNotEmpty)
                        ? JournalPreviewImage(
                            widget.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : _buildDefaultBanner(),
                  ),
                ),
              ),
            // ── Card content ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: widget.imageUrl?.trim().isNotEmpty == true ? 16 : 38,
              ),
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
                                    ownerId: widget.ownerId,
                                    ownerAvatarUrl: widget.ownerAvatarUrl,
                                    collaborators: widget.collaborators,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text('by '),
                                        if (widget.ownerId != null)
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: () => openUserProfile(
                                              context,
                                              widget.ownerId!,
                                            ),
                                            child: Text(widget.ownerLabel!),
                                          ),
                                        for (final person
                                            in widget.collaborators)
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            onPressed: () => openUserProfile(
                                              context,
                                              person.id,
                                            ),
                                            child: Text(
                                              person.id ==
                                                      AuthService
                                                          .instance
                                                          .currentUser
                                                          ?.id
                                                  ? 'You'
                                                  : person.resolvedDisplayName,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (widget.onEdit != null || widget.onDelete != null)
                        ItemActionMenu(
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      AppTapTarget(
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
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.bodySize,
                                fontWeight: FontWeight.w500,
                                color: _hasLiked
                                    ? AppColors.primaryDark
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      AppTapTarget(
                        onTap: () => showAppModalBottomSheet(
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
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _entryPhaseTag(),
                              for (final subject
                                  in widget.tags
                                      .map((tag) => tag.split('|').first.trim())
                                      .where((subject) => subject.isNotEmpty)
                                      .toSet())
                                ExplainedProjectTag(
                                  label: subject,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: .45,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      subject,
                                      style: AppTypography.helper.copyWith(
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      JournalProjectLink(
                        projectName: widget.projectName,
                        onTap: widget.onProjectTap,
                        topPadding: 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryPhaseTag() {
    final (label, icon) = switch (normalizePhase(widget.phase)) {
      'discover' => ('Discovery', Icons.search_outlined),
      'ideating' => ('Ideation', Icons.lightbulb_outline),
      'prototyping' => ('Prototyping', Icons.build_outlined),
      'implementation' => ('Implementation', Icons.rocket_launch_outlined),
      _ => ('Journal', Icons.menu_book_outlined),
    };
    return ExplainedProjectTag(
      label: label,
      isPhase: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: AppTypography.helper.copyWith(color: Colors.white),
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
  Timer? _notificationRefresh;
  bool _isLoading = true;
  List<Map<String, dynamic>> _projectNotifications = [];
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
    _notificationRefresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadAll(showLoading: false),
    );
  }

  @override
  void dispose() {
    _notificationRefresh?.cancel();
    super.dispose();
  }

  Future<void> _loadAll({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final results = await Future.wait([
      widget.friendsRepo.getIncomingFriendRequests(),
      widget.projectsRepo.getPendingCollaborationRequests(),
      widget.communitiesRepo.getPendingInvites(),
      widget.projectsRepo.getProjectNotifications(),
    ]);
    if (!mounted) return;
    setState(() {
      _friendRequests = (results[0] as List<FriendRequest>?) ?? [];
      _collabRequests = results[1] as List<CollaborationRequest>;
      _communityInvites = results[2] as List<CommunityInvite>;
      _projectNotifications = results[3] as List<Map<String, dynamic>>;
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
        _projectNotifications.isNotEmpty ||
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontFamily: AppTypography.headingFamily,
                            fontSize: AppTypography.sectionTitleSize,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const ValueKey('close-notifications'),
                          tooltip: 'Close notifications',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
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
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          if (_projectNotifications.isNotEmpty) ...[
                            const _SectionHeader(title: 'Project Updates'),
                            for (final notification in _projectNotifications)
                              ListTile(
                                leading: Icon(
                                  Icons.folder_shared_outlined,
                                  color: notification['read_at'] == null
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                title: Text(
                                  notification['message']?.toString() ??
                                      'Project update',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => runActionOnce(
                                  this,
                                  'open-notification',
                                  () async {
                                    try {
                                      final destination =
                                          await projectNotificationDestination(
                                            notification,
                                            widget.projectsRepo,
                                          );
                                      if (!context.mounted) return;
                                      await widget.projectsRepo
                                          .markProjectNotificationRead(
                                            notification['id'].toString(),
                                          );
                                      if (!context.mounted) return;
                                      final navigator = Navigator.of(context);
                                      navigator.pop();
                                      await pushAppRoute(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => destination,
                                        ),
                                      );
                                    } on StateError catch (error) {
                                      if (context.mounted)
                                        showTopSnackBar(
                                          context,
                                          error.message,
                                          isError: true,
                                        );
                                    } catch (_) {
                                      if (context.mounted)
                                        showTopSnackBar(
                                          context,
                                          'Could not open this notification. Please try again.',
                                          isError: true,
                                        );
                                    }
                                    if (mounted) _loadAll(showLoading: false);
                                  },
                                ),
                              ),
                          ],
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
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.helperSize,
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
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.helperSize,
                                  ),
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
          fontFamily: AppTypography.bodyFamily,
          fontSize: AppTypography.helperSize,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final String? ownerAvatarUrl;
  final List<UserProfile> collaborators;

  const _AvatarStack({
    this.ownerId,
    this.ownerAvatarUrl,
    required this.collaborators,
  });
  final String? ownerId;

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
              child: Semantics(
                button: true,
                label: 'View contributor profile',
                child: AppTapTarget(
                  onTap: () {
                    final id = i == 0 ? ownerId : collaborators[i - 1].id;
                    if (id != null) openUserProfile(context, id);
                  },
                  child: _StackAvatar(url: visible[i], diameter: _diameter),
                ),
              ),
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
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.captionSize,
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
    return AppRefreshIndicator(
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
                      fontFamily: AppTypography.headingFamily,
                      fontSize: AppTypography.sectionTitleSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
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

  Future<void> _showAll(BuildContext context) async {
    final selected = await showAppModalBottomSheet<Community>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(sheetContext).height * .65,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your communities',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close communities',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: communities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final community = communities[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: community.bannerColor,
                        backgroundImage: community.imageUrl?.isNotEmpty == true
                            ? NetworkImage(community.imageUrl!)
                            : null,
                        child: community.imageUrl?.isNotEmpty == true
                            ? null
                            : const Icon(Icons.groups, color: Colors.white),
                      ),
                      title: Text(community.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(sheetContext, community),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && context.mounted) onCommunityTap(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (communities.isEmpty) {
      return AppTapTarget(
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
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Your communities', style: AppTypography.fieldLabel),
            ),
            TextButton(
              onPressed: () => _showAll(context),
              child: const Text('View all communities'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (
                  var index = 0;
                  index < communities.take(3).length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final c = communities[index];
                      return Expanded(
                        child: _CommunityHoverCard(
                          onTap: () => onCommunityTap(c),
                          child: Container(
                            width: double.infinity,
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
                                    width: 48,
                                    height: double.infinity,
                                    child:
                                        (c.imageUrl != null &&
                                            c.imageUrl!.isNotEmpty)
                                        ? Image.network(
                                            c.imageUrl!,
                                            fit: BoxFit.cover,
                                          )
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
                                      fontFamily: AppTypography.bodyFamily,
                                      fontSize: AppTypography.bodySize,
                                      fontWeight: FontWeight.w500,
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
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Paint above artwork so feedback covers the complete community card.
class _CommunityHoverCard extends StatefulWidget {
  const _CommunityHoverCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_CommunityHoverCard> createState() => _CommunityHoverCardState();
}

class _CommunityHoverCardState extends State<_CommunityHoverCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AppTapTarget(
      onTap: widget.onTap,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: _hovered
                      ? const Color(0x10000000)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
