import '../../home_page/pages/login.dart';
import '../../home_page/pages/signup.dart';
import '../../../shared/widgets/account_required_prompt.dart';
import '../../home_page/pages/explore_page.dart';
import '../../../shared/widgets/page_refresh_state.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import '../utils/community_visit_history.dart';
import 'community_project_invitations.dart';
import '../../../shared/widgets/app_tab_transition.dart';
import '../../../shared/styling/app_motion.dart';
import 'community_profile_screen.dart';
import '../widgets/community_entries_feed.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/community.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/features/chat/pages/chat_screen.dart';
import 'package:juniper_journal/src/features/community/pages/community_settings_screen.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

// ── CommunityHomeScreen ───────────────────────────────────────────────────────

class CommunityHomeScreen extends StatefulWidget {
  final Community community;
  final int initialTab;

  const CommunityHomeScreen({
    super.key,
    required this.community,
    this.initialTab = 0,
  });

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;
  int _tabIndex = 0;
  void _syncTab() {
    if (mounted && _tabIndex != _tabCtrl!.index)
      setState(() => _tabIndex = _tabCtrl!.index);
  }

  final _projectsRepo = ProjectsRepo();
  final _chatRepo = ChatRepo();
  int _chatUnread = 0;
  bool _communityMember = false;
  final _projectBrowserKey = GlobalKey<ProjectBrowsePageState>();

  late Community _community;
  final _entriesKey = GlobalKey<CommunityEntriesFeedState>();

  @override
  void initState() {
    super.initState();
    CommunityVisitHistory.record(widget.community.id);
    _tabIndex = widget.initialTab.clamp(0, 1);
    _tabCtrl = TabController(
      length: 2,
      initialIndex: _tabIndex,
      vsync: this,
      animationDuration: AppMotion.tabDuration,
    )..addListener(_syncTab);
    _community = widget.community;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (AuthService.instance.currentUser != null) _load();
        _loadCommunityWorkspace();
      }
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    // Reinitialize after hot reload if the mixin wasn't active before.
    _tabCtrl ??= TabController(
      length: 2,
      initialIndex: _tabIndex,
      vsync: this,
      animationDuration: AppMotion.tabDuration,
    )..addListener(_syncTab);
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadCommunityWorkspace() async {
    final user = AuthService.instance.currentUser?.id;
    if (user == null) return;
    final member =
        user == _community.createdBy ||
        await CommunitiesRepo().isAcceptedCommunityMember(_community.id);
    if (!mounted) return;
    setState(() => _communityMember = member);
    if (_communityMember) await _loadChatUnread();
  }

  Future<void> _loadChatUnread() async {
    if (!_communityMember || AuthService.instance.currentUser == null) return;
    final convId = _community.conversationId;
    if (convId == null) return;
    final count = await _chatRepo.getUnreadCount(convId);
    if (mounted) setState(() => _chatUnread = count);
  }

  Future<void> _load() async {
    await _projectBrowserKey.currentState?.reload();
    await _entriesKey.currentState?.reload();
  }

  Future<void> _openSettings() async {
    final result = await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => CommunitySettingsScreen(community: _community),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.of(context).pop();
    } else if (result is Community) {
      setState(() => _community = result);
    }
  }

  Future<void> _openChat() async {
    if (!_communityMember) return;
    final convId = _community.conversationId;
    if (convId == null) {
      showTopSnackBar(context, 'Chat not available yet');
      return;
    }
    await pushAppRoute(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          otherUserName: _community.name,
          otherAvatarUrl: _community.imageUrl,
          isGroup: true,
        ),
      ),
    );
    if (mounted) _loadChatUnread();
  }

  @override
  Widget build(BuildContext context) {
    PageRefreshState.remember(context, {
      'kind': 'community',
      'community': widget.community.id,
      'tab': _tabIndex,
    });
    final bannerColor = _community.bannerColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 204,
            pinned: true,
            backgroundColor: bannerColor,
            leading: IconButton(
              icon: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_communityMember)
                IconButton(
                  icon: Badge(
                    isLabelVisible: _chatUnread > 0,
                    label: Text(
                      _chatUnread > 99 ? '99+' : '$_chatUnread',
                      style: const TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.captionSize,
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  onPressed: _openChat,
                ),
              if (AuthService.instance.currentUser != null)
                CommunityProjectInvitationsButton(
                  communityId: _community.id,
                  compact: true,
                ),
              if (_community.createdBy == AuthService.instance.currentUser?.id)
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _openSettings,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: ColoredBox(
                color: bannerColor,
                child: Stack(
                  children: [
                    Positioned(
                      top: 48,
                      left: 24,
                      right: 24,
                      child: Column(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Community profile',
                            child: InkWell(
                              onTap: _openProfile,
                              customBorder: const CircleBorder(),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.white.withValues(
                                  alpha: .2,
                                ),
                                backgroundImage:
                                    _community.imageUrl?.isNotEmpty == true
                                    ? NetworkImage(_community.imageUrl!)
                                    : null,
                                child: _community.imageUrl?.isNotEmpty == true
                                    ? null
                                    : const Icon(
                                        Icons.groups_outlined,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _community.name,
                            textAlign: TextAlign.center,
                            style: AppTypography.fieldLabel.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl!,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Entries'),
                Tab(text: 'Projects'),
              ],
            ),
          ),
        ],
        body: AppTabStack(
          index: _tabIndex,
          sizing: StackFit.expand,
          onIndexChanged: (index) => _tabCtrl!.animateTo(index),
          children: [
            CommunityEntriesFeed(
              key: _entriesKey,
              communityId: _community.id,
              projectsRepo: _projectsRepo,
            ),
            ProjectBrowsePage(
              key: _projectBrowserKey,
              communityId: _community.id,
              projectsRepo: _projectsRepo,
              publicLanding: AuthService.instance.currentUser == null,
              onSignIn: () => showAccountRequiredPrompt(context),
            ),
          ],
        ),
      ),
    );
  }

  void _authenticate({bool signup = false}) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => signup ? const SignupScreen() : const LoginScreen(),
    ),
  );

  // ── Projects tab ────────────────────────────────────────────────────────────

  Future<void> _openProfile() async {
    final result = await pushAppRoute<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityProfileScreen(community: _community),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context);
      return;
    }
    final updated = await CommunitiesRepo().getCommunityById(_community.id);
    if (mounted && updated != null) setState(() => _community = updated);
    await _load();
  }
}
