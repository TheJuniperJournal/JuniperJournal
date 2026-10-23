import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'package:juniper_journal/src/shared/widgets/flower_reaction_button.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:juniper_journal/src/shared/widgets/modal_actions.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/auth/auth_service.dart';
import 'package:juniper_journal/src/backend/db/models/comment.dart';
import 'package:juniper_journal/src/backend/db/repositories/comments_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

String _timeAgo(DateTime? dt) {
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
}

class CommentsSheet extends StatefulWidget {
  final String projectId;
  final String projectName;
  final String? description;

  const CommentsSheet({
    super.key,
    required this.projectId,
    required this.projectName,
    this.description,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _repo = CommentsRepo();
  final _textController = ConversationController();
  final _scrollController = ScrollController();

  List<Comment>? _comments;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isSending = false;

  String? get _currentUserId => AuthService.instance.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    final result = await _repo.getComments(projectId: widget.projectId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result == null) {
        _hasError = true;
      } else {
        _comments = result;
        for (final c in result) {
          _textController.remember(
            c.userId,
            c.resolvedAuthorName,
            c.authorUsername,
          );
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final comment = await _repo.postComment(
      projectId: widget.projectId,
      content: _textController.payload,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (comment != null) {
      _textController.clear();
      setState(() => _comments = [...?_comments, comment]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _repo.deleteComment(commentId: comment.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _comments?.removeWhere((c) => c.id == comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sticky header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.projectName,
                            style: const TextStyle(
                              fontFamily: AppTypography.headingFamily,
                              fontSize: AppTypography.sectionTitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.description != null &&
                              widget.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.description!.trim(),
                              style: const TextStyle(
                                fontFamily: AppTypography.bodyFamily,
                                fontSize: AppTypography.helperSize,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close comments',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 12),
              // Comment list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _hasError
                    ? GestureDetector(
                        onTap: _load,
                        child: const Center(
                          child: Text(
                            "Couldn't load comments. Tap to retry.",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _comments!.isEmpty
                    ? const Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        itemCount: _comments!.length,
                        itemBuilder: (_, i) {
                          final comment = _comments![i];
                          return _CommentTile(
                            comment: comment,
                            onReply: () => _textController.replyTo(
                              comment.id,
                              comment.resolvedAuthorName,
                              comment.content,
                            ),
                            isOwn: comment.userId == _currentUserId,
                            onDelete: () => _deleteComment(comment),
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              // Input bar
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConversationComposer(
                          controller: _textController,
                          child: TextField(
                            buildCounter:
                                (
                                  _, {
                                  required currentLength,
                                  required isFocused,
                                  maxLength,
                                }) => null,
                            controller: _textController,
                            focusNode: _textController.focusNode,
                            enabled: !_isSending,
                            maxLength: 500,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: '',
                              counterText: '',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(999),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : GestureDetector(
                              onTap: _send,
                              child: const Icon(
                                Icons.send_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isOwn;
  final VoidCallback onDelete;
  final VoidCallback onReply;

  const _CommentTile({
    required this.comment,
    required this.isOwn,
    required this.onDelete,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: isOwn ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryTint,
              backgroundImage:
                  (comment.authorAvatarUrl != null &&
                      comment.authorAvatarUrl!.isNotEmpty)
                  ? NetworkImage(comment.authorAvatarUrl!)
                  : null,
              child:
                  (comment.authorAvatarUrl == null ||
                      comment.authorAvatarUrl!.isEmpty)
                  ? const Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                      size: 18,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.resolvedAuthorName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ConversationBody(comment.content),
                  TextButton(onPressed: onReply, child: const Text('Reply')),
                  const SizedBox(height: 3),
                  Text(
                    _timeAgo(comment.createdAt),
                    style: const TextStyle(
                      fontFamily: AppTypography.bodyFamily,
                      fontSize: AppTypography.helperSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            FlowerReactionButton(
              target: FlowerTarget.projectComment,
              targetId: comment.id,
            ),
          ],
        ),
      ),
    );
  }
}
