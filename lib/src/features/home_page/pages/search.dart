import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/users_repo.dart';
import 'public_user_profile.dart';
import 'package:juniper_journal/src/shared/styling/theme.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

enum SearchScope { friends, users }

class HomeSearchScreen extends StatefulWidget {
  const HomeSearchScreen({
    super.key,
    this.initialScope = SearchScope.users,
    this.usersRepo,
    this.friendsRepo,
  });
  final UsersRepo? usersRepo;
  final FriendsRepo? friendsRepo;
  final SearchScope initialScope;

  @override
  State<HomeSearchScreen> createState() => _HomeSearchScreenState();
}

class _HomeSearchScreenState extends State<HomeSearchScreen> {
  late final _usersRepo = widget.usersRepo ?? UsersRepo();
  late final _friendsRepo = widget.friendsRepo ?? FriendsRepo();
  final _queryController = TextEditingController();
  Timer? _friendsSearchDebounce;

  late SearchScope _scope = widget.initialScope;
  bool _isFriendsLoading = false;
  final Map<String, bool> _actionLoadingByUserId = {};
  String? _friendsErrorMessage;
  List<UserProfile> _friends = const [];
  Map<String, String> _friendStatuses = const {};

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFriends();
    });
  }

  @override
  void dispose() {
    _friendsSearchDebounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (!mounted) return;
    setState(() {});
    _friendsSearchDebounce?.cancel();
    _friendsSearchDebounce = Timer(
      const Duration(milliseconds: 250),
      _searchFriends,
    );
  }

  Future<void> _searchFriends() async {
    final query = _queryController.text.trim();
    final scope = _scope;
    if (query.isEmpty && scope == SearchScope.users) {
      setState(() {
        _friends = const [];
        _isFriendsLoading = false;
        _friendsErrorMessage = null;
      });
      return;
    }

    setState(() {
      _isFriendsLoading = true;
      _friendsErrorMessage = null;
    });

    final users = scope == SearchScope.friends
        ? (await _friendsRepo.getFriends())
              ?.where(
                (user) => '${user.resolvedDisplayName} ${user.username ?? ''}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
              )
              .toList()
        : await _usersRepo.searchPublicUsers(query: query);
    if (!mounted || scope != _scope || query != _queryController.text.trim())
      return;

    if (users == null) {
      setState(() {
        _friends = const [];
        _friendStatuses = const {};
        _isFriendsLoading = false;
        _friendsErrorMessage = 'Search unavailable. Please try again.';
      });
      return;
    }

    final ids = users.map((u) => u.id).where((id) => id.isNotEmpty).toList();
    final statuses = await _friendsRepo.getRelationshipStatuses(ids);
    if (!mounted || scope != _scope || query != _queryController.text.trim())
      return;

    setState(() {
      _friends = users;
      _friendStatuses = statuses;
      _isFriendsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: AppColors.border,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search', style: AppTypography.pageTitle),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _queryController,
                decoration: InputDecoration(
                  hintText: _scope == SearchScope.friends
                      ? 'Search your friends'
                      : 'Search users by name or username',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoSlidingSegmentedControl<SearchScope>(
                groupValue: _scope,
                children: const {
                  SearchScope.users: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Users'),
                  ),
                  SearchScope.friends: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Friends'),
                  ),
                },
                onValueChanged: (value) {
                  if (value == null) return;
                  setState(() => _scope = value);
                  _searchFriends();
                },
              ),
            ),
            const SizedBox(height: AppMetrics.labelGap),
            Expanded(child: _buildFriendsResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsResults() {
    final query = _queryController.text.trim();
    if (query.isEmpty && _scope == SearchScope.users) {
      return const Center(
        child: Text(
          'Search for users by name or username.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    if (_isFriendsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_friendsErrorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _friendsErrorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Text(
          'No users found for "$query".',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemBuilder: (context, index) {
        final user = _friends[index];
        final displayName = user.displayName ?? user.username ?? 'Unknown User';
        final username = user.username;
        final avatarUrl = user.avatarUrl;
        final status = _friendStatuses[user.id] ?? 'none';

        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryTint,
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person_outline, color: AppColors.primary)
                : null,
          ),
          onTap: () => openUserProfile(context, user.id),
          title: Text(
            displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: (username != null && username.isNotEmpty)
              ? Text('@$username')
              : const Text('Public profile'),
          trailing: _buildFriendActionButton(userId: user.id, status: status),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: _friends.length,
    );
  }

  Widget _buildFriendActionButton({
    required String userId,
    required String status,
  }) {
    if (_actionLoadingByUserId[userId] == true) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (status == 'friends') {
      return const Chip(
        label: Text('Friends'),
        visualDensity: VisualDensity.compact,
      );
    }

    if (status == 'pending_outgoing') {
      return const OutlinedButton(onPressed: null, child: Text('Pending'));
    }

    if (status == 'pending_incoming') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () => _declineRequest(userId),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Decline'),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => _acceptRequest(userId),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Accept'),
          ),
        ],
      );
    }

    return FilledButton(
      onPressed: () => _sendRequest(userId),
      child: const Text('Add'),
    );
  }

  Future<void> _sendRequest(String userId) async {
    if (userId.isEmpty) return;
    setState(() => _actionLoadingByUserId[userId] = true);
    final ok = await _friendsRepo.sendFriendRequest(addresseeId: userId);
    if (!mounted) return;

    setState(() => _actionLoadingByUserId.remove(userId));
    if (!ok) {
      showTopSnackBar(context, 'Failed to send friend request', isError: true);
      return;
    }
    _searchFriends();
  }

  Future<void> _acceptRequest(String requesterId) async {
    if (requesterId.isEmpty) return;
    setState(() => _actionLoadingByUserId[requesterId] = true);
    final ok = await _friendsRepo.acceptFriendRequest(requesterId: requesterId);
    if (!mounted) return;

    setState(() => _actionLoadingByUserId.remove(requesterId));
    if (!ok) {
      showTopSnackBar(context, 'Failed to accept request', isError: true);
      return;
    }
    _searchFriends();
  }

  Future<void> _declineRequest(String requesterId) async {
    if (requesterId.isEmpty) return;
    setState(() => _actionLoadingByUserId[requesterId] = true);
    final ok = await _friendsRepo.declineFriendRequest(
      requesterId: requesterId,
    );
    if (!mounted) return;

    setState(() => _actionLoadingByUserId.remove(requesterId));
    if (!ok) {
      showTopSnackBar(context, 'Failed to decline request', isError: true);
      return;
    }
    _searchFriends();
  }
}
