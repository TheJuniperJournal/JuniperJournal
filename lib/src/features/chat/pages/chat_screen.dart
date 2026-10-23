import '../widgets/message_emoji_reactions.dart';
import '../widgets/message_gesture_surface.dart';
import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'package:juniper_journal/src/shared/widgets/flower_reaction_button.dart';
import '../widgets/group_chat_name_dialog.dart';
import '../../../shared/widgets/modal_actions.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/message.dart';
import 'package:juniper_journal/src/backend/db/repositories/chat_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/user_avatar.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherAvatarUrl;

  /// When true, uses per-message sender names and the community message RPC.
  final bool isGroup;
  final bool canRenameGroup;
  final ChatRepo? chatRepo;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherAvatarUrl,
    this.isGroup = false,
    this.canRenameGroup = false,
    this.chatRepo,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepo _chatRepo = widget.chatRepo ?? ChatRepo();
  late String _displayName = widget.otherUserName;
  late final Stream<List<Message>> _messages = widget.isGroup
      ? _chatRepo.streamCommunityMessages(widget.conversationId)
      : _chatRepo.streamMessages(widget.conversationId);
  final ConversationController _inputController = ConversationController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;
  bool _hasScrolledToBottom = false;

  String? get _currentUserId => AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _chatRepo.markAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      // Always scroll on first load; after that only scroll if already near bottom
      if (!_hasScrolledToBottom) {
        _scrollController.jumpTo(pos.maxScrollExtent);
        _hasScrolledToBottom = true;
        return;
      }
      if (pos.maxScrollExtent - pos.pixels < 100) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    final payload = _inputController.payload;
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    final success = await _chatRepo.sendMessage(widget.conversationId, payload);

    if (!mounted) return;
    if (success) _inputController.clear();
    if (!success) {
      _inputController.text = text;
      showTopSnackBar(context, 'Failed to send. Try again.', isError: true);
    }
    setState(() => _sending = false);
  }

  Future<void> _renameGroup() async {
    if (!widget.isGroup || !widget.canRenameGroup) return;
    final name = await showAppDialog<String>(
      context: context,
      builder: (_) => GroupChatNameDialog(
        initialName: _displayName,
        onSave: (name) => _chatRepo.renameGroupDm(
          conversationId: widget.conversationId,
          name: name,
        ),
      ),
    );
    if (mounted && name != null) setState(() => _displayName = name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(avatarUrl: widget.otherAvatarUrl, radius: 16),
            const SizedBox(width: 8),
            Flexible(
              child: AppTapTarget(
                onTap: widget.isGroup && widget.canRenameGroup
                    ? _renameGroup
                    : null,
                child: Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.headingFamily,
                    fontSize: AppTypography.pageTitleSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isGroup && widget.canRenameGroup)
            IconButton(
              tooltip: 'Rename group chat',
              onPressed: _renameGroup,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
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
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textSecondary,
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Say hello!',
                          style: TextStyle(
                            fontFamily: AppTypography.bodyFamily,
                            color: AppColors.textSecondary,
                            fontSize: AppTypography.helperSize,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                for (final msg in messages) {
                  _inputController.remember(
                    msg.senderId,
                    widget.isGroup || msg.senderId == _currentUserId
                        ? msg.resolvedSenderName
                        : widget.otherUserName,
                    msg.senderUsername,
                  );
                }
                _maybeScrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final msg = messages[index];
                    final isSent = msg.senderId == _currentUserId;
                    // Show the sender name above the first bubble in each consecutive group
                    final isFirstInGroup =
                        index == 0 ||
                        messages[index - 1].senderId != msg.senderId;
                    final showSenderName = !isSent && isFirstInGroup;

                    final senderName = widget.isGroup
                        ? msg.resolvedSenderName.split(' ').first
                        : widget.otherUserName.split(' ').first;
                    return _MessageBubble(
                      message: msg,
                      isSent: isSent,
                      showSenderName: showSenderName,
                      senderFirstName: senderName,
                      onReply: () => _inputController.replyTo(
                        msg.id,
                        widget.isGroup || isSent
                            ? msg.resolvedSenderName
                            : widget.otherUserName,
                        msg.content,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final bool showSenderName;
  final String senderFirstName;
  final VoidCallback onReply;

  const _MessageBubble({
    required this.message,
    required this.isSent,
    required this.showSenderName,
    required this.senderFirstName,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isSent
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showSenderName && !isSent)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderFirstName,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.helperSize,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isSent
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              MessageEmojiReactions(
                key: ValueKey('emojis-${message.id}'),
                targetId: message.id,
                builder: (context, openEmojis, emojiCounts) =>
                    FlowerReactionButton(
                      key: ValueKey(message.id),
                      target: FlowerTarget.message,
                      targetId: message.id,
                      builder: (context, reaction, busy, toggle) => Column(
                        crossAxisAlignment: isSent
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          MessageGestureSurface(
                            onReply: onReply,
                            onLike: toggle,
                            onReactions: openEmojis,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSent
                                    ? AppColors.primary
                                    : AppColors.surfaceInput,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isSent ? 18 : 4),
                                  bottomRight: Radius.circular(isSent ? 4 : 18),
                                ),
                              ),
                              child: ConversationBody(
                                message.content,
                                style: TextStyle(
                                  fontFamily: AppTypography.bodyFamily,
                                  fontSize: AppTypography.bodySize,
                                  color: isSent ? Colors.white : Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                          if ((reaction?.count ?? 0) > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 4,
                                left: 8,
                                right: 8,
                              ),
                              child: Semantics(
                                label: '${reaction!.count} likes',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_florist,
                                      size: 14,
                                      color: reaction.selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${reaction.count}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          emojiCounts,
                        ],
                      ),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final ConversationController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey != LogicalKeyboardKey.enter) {
                  return KeyEventResult.ignored;
                }
                if (HardwareKeyboard.instance.isShiftPressed) {
                  final sel = controller.selection;
                  final text = controller.text;
                  final newText = text.replaceRange(sel.start, sel.end, '\n');
                  controller.value = controller.value.copyWith(
                    text: newText,
                    selection: TextSelection.collapsed(offset: sel.start + 1),
                  );
                  return KeyEventResult.handled;
                }
                onSend();
                return KeyEventResult.handled;
              },
              child: ConversationComposer(
                controller: controller,
                child: TextField(
                  controller: controller,
                  focusNode: controller.focusNode,
                  enabled: !sending,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '',
                    hintStyle: const TextStyle(color: Colors.black38),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          AppTapTarget(
            onTap: sending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sending ? AppColors.borderLight : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
