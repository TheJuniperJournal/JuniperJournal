import 'package:juniper_journal/src/shared/widgets/page_scroll_with_footer.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/app_navigation.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import '../widgets/group_chat_name_dialog.dart';
import '../../../shared/widgets/top_snack_bar.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/conversation_preview.dart';
import 'package:juniper_journal/src/backend/db/models/user_profile.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/backend/db/repositories/friends_repo.dart';
import 'package:juniper_journal/src/features/chat/pages/chat_screen.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/user_avatar.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key, this.chatRepo, this.friendsRepo});
  final ChatRepo? chatRepo;
  final FriendsRepo? friendsRepo;

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  late final ChatRepo _chatRepo = widget.chatRepo ?? ChatRepo();
  late final FriendsRepo _friendsRepo = widget.friendsRepo ?? FriendsRepo();
  final TextEditingController _searchController = TextEditingController();

  List<ConversationPreview> _conversations = [];
  List<ConversationPreview> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    final data = await _chatRepo.getConversations();
    if (!mounted) return;
    setState(() {
      _conversations = data ?? [];
      _filtered = _applySearch(_conversations);
      _loading = false;
    });
  }

  void _onSearchChanged() {
    setState(() => _filtered = _applySearch(_conversations));
  }

  List<ConversationPreview> _applySearch(List<ConversationPreview> list) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return list;
    return list
        .where((c) => c.resolvedDisplayName.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _openNewChat() async {
    final selected = await pushAppRoute<List<UserProfile>>(
      context,
      MaterialPageRoute(
        builder: (_) => _NewMessageScreen(friendsRepo: _friendsRepo),
      ),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    if (selected.length == 1) {
      final conversationId = await _chatRepo.getOrCreateDm(selected.first.id);
      if (!mounted) return;
      if (conversationId == null) {
        showTopSnackBar(
          context,
          'Could not create chat. Please try again.',
          isError: true,
        );
        return;
      }
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: selected.first.resolvedDisplayName,
            otherAvatarUrl: selected.first.avatarUrl,
            chatRepo: _chatRepo,
          ),
        ),
      );
    } else {
      final suggested = selected
          .map((f) => f.resolvedDisplayName.split(' ').first)
          .join(', ');
      final name = await showAppDialog<String>(
        context: context,
        builder: (_) => GroupChatNameDialog(
          initialName: suggested.length > 80
              ? suggested.substring(0, 80)
              : suggested,
          title: 'Name group chat',
          confirmLabel: 'Create group',
        ),
      );
      if (name == null || !mounted) return;
      final conversationId = await _chatRepo.createGroupDm(
        name: name,
        memberIds: selected.map((f) => f.id).toList(),
      );
      if (!mounted) return;
      if (conversationId == null) {
        showTopSnackBar(
          context,
          'Could not create chat. Please try again.',
          isError: true,
        );
        return;
      }
      await pushAppRoute(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserName: name,
            isGroup: true,
            canRenameGroup: true,
            chatRepo: _chatRepo,
          ),
        ),
      );
    }

    if (!mounted) return;
    _loadConversations();
  }

  Future<bool> _confirmAndDelete(String conversationId) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Conversation'),
        content: const Text(
          'This will hide the conversation for you. Others will still see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    return _chatRepo.deleteConversation(conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Chats', style: AppTypography.pageTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.textPrimary),
            onPressed: _openNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(Icons.search, color: Colors.black38),
                filled: true,
                fillColor: AppColors.surfaceInput,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_filtered.isEmpty) return _buildEmptyState();
    return _buildConversationList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            _conversations.isEmpty ? 'No conversations yet' : 'No results',
            style: const TextStyle(
              fontFamily: AppTypography.bodyFamily,
              fontSize: AppTypography.helperSize,
              color: AppColors.textSecondary,
            ),
          ),
          if (_conversations.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tap + to start a chat',
              style: TextStyle(
                fontFamily: AppTypography.bodyFamily,
                fontSize: AppTypography.bodySize,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: PageScrollWithFooter(
        child: ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, index) {
            final c = _filtered[index];
            return Dismissible(
              key: Key(c.conversationId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              confirmDismiss: (_) => _confirmAndDelete(c.conversationId),
              onDismissed: (_) {
                setState(() {
                  _conversations.removeWhere(
                    (x) => x.conversationId == c.conversationId,
                  );
                  _filtered.removeWhere(
                    (x) => x.conversationId == c.conversationId,
                  );
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ConversationTile(
                    conversation: c,
                    onTap: () async {
                      await pushAppRoute(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: c.conversationId,
                            otherUserName: c.resolvedDisplayName,
                            otherAvatarUrl: c.isGroup ? null : c.otherAvatarUrl,
                            isGroup: c.isGroup,
                            canRenameGroup: c.isGroup,
                            chatRepo: _chatRepo,
                          ),
                        ),
                      );
                      if (!mounted) return;
                      _loadConversations();
                    },
                  ),
                  if (index < _filtered.length - 1)
                    const Divider(height: 1, indent: 76, endIndent: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── _ConversationTile ──────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationPreview conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final hasUnread = c.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar — group shows a people icon, DM shows user avatar
            if (c.isGroup)
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(
                  Icons.group,
                  color: AppColors.primary,
                  size: 24,
                ),
              )
            else
              UserAvatar(avatarUrl: c.otherAvatarUrl, radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.resolvedDisplayName,
                    style: TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.bodySize,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (c.lastMessage != null && c.lastMessage!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      ConversationContent.parse(c.lastMessage!).text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        fontSize: AppTypography.bodySize,
                        color: hasUnread ? Colors.black87 : Colors.black54,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                child: Center(
                  child: Text(
                    c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      color: Colors.white,
                      fontSize: AppTypography.helperSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── _NewMessageScreen ─────────────────────────────────────────────────────────

class _NewMessageScreen extends StatefulWidget {
  const _NewMessageScreen({required this.friendsRepo});
  final FriendsRepo friendsRepo;

  @override
  State<_NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<_NewMessageScreen> {
  late final FriendsRepo _friendsRepo = widget.friendsRepo;
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _allFriends = [];
  List<UserProfile> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await _friendsRepo.getFriends();
    if (!mounted) return;
    setState(() {
      _allFriends = friends ?? [];
      _filtered = _allFriends;
      _loading = false;
    });
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allFriends
          : _allFriends
                .where(
                  (f) =>
                      f.resolvedDisplayName.toLowerCase().contains(q) ||
                      (f.username?.toLowerCase().contains(q) ?? false),
                )
                .toList();
    });
  }

  List<UserProfile> get _selectedFriends =>
      _allFriends.where((f) => _selectedIds.contains(f.id)).toList();

  void _confirm() {
    final selected = _selectedFriends;
    if (selected.isEmpty) return;
    Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedFriends;
    final hasSelection = selected.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Message', style: AppTypography.pageTitle),
        centerTitle: true,
        actions: [
          if (hasSelection)
            TextButton(
              onPressed: _confirm,
              child: Text(
                selected.length == 1 ? 'Message' : 'Create',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: '',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(Icons.search, color: Colors.black38),
                filled: true,
                fillColor: AppColors.surfaceInput,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Selected chips row
          if (hasSelection) ...[
            SizedBox(
              height: 72,
              child: PageScrollWithFooter(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: selected
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                children: [
                                  UserAvatar(
                                    avatarUrl: f.avatarUrl,
                                    radius: 22,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: AppTapTarget(
                                      onTap: () => setState(
                                        () => _selectedIds.remove(f.id),
                                      ),
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                f.resolvedDisplayName.split(' ').first,
                                style: const TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.helperSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const Divider(height: 1),
          ],

          // Suggestions label
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                _searchController.text.isEmpty ? 'Suggested' : 'Results',
                style: TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4,
                ),
              ),
            ),

          // Friend list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      _allFriends.isEmpty ? 'No friends yet' : 'No results',
                      style: const TextStyle(color: Colors.black45),
                    ),
                  )
                : PageScrollWithFooter(
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (_, index) {
                        final friend = _filtered[index];
                        final isSelected = _selectedIds.contains(friend.id);
                        return ListTile(
                          leading: UserAvatar(
                            avatarUrl: friend.avatarUrl,
                            radius: 22,
                          ),
                          title: Text(
                            friend.resolvedDisplayName,
                            style: const TextStyle(
                              fontFamily: AppTypography.bodyFamily,
                              fontSize: AppTypography.bodySize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: friend.username != null
                              ? Text(
                                  '@${friend.username!}',
                                  style: const TextStyle(
                                    fontFamily: AppTypography.bodyFamily,
                                    fontSize: AppTypography.helperSize,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: Colors.grey.shade300,
                                ),
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedIds.remove(friend.id);
                            } else {
                              _selectedIds.add(friend.id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
