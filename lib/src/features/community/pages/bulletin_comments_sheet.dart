import 'package:juniper_journal/src/shared/widgets/app_tap_target.dart';
import 'package:juniper_journal/src/shared/widgets/conversation_composer.dart';
import 'package:juniper_journal/src/shared/widgets/flower_reaction_button.dart';
import 'package:juniper_journal/src/shared/styling/app_metrics.dart';
import 'package:juniper_journal/src/shared/styling/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:juniper_journal/src/backend/db/models/bulletin_comment.dart';
import 'package:juniper_journal/src/backend/db/repositories/communities_repo.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';
import 'package:juniper_journal/src/shared/widgets/top_snack_bar.dart';

class BulletinCommentsSheet extends StatefulWidget {
  final String postId;
  final String postTitle;
  final int initialCommentCount;
  final void Function(int newCount)? onCountChanged;

  const BulletinCommentsSheet({
    super.key,
    required this.postId,
    required this.postTitle,
    this.initialCommentCount = 0,
    this.onCountChanged,
  });

  @override
  State<BulletinCommentsSheet> createState() => _BulletinCommentsSheetState();
}

class _BulletinCommentsSheetState extends State<BulletinCommentsSheet> {
  final _repo = CommunitiesRepo();
  final _bodyCtrl = ConversationController();
  final _scrollCtrl = ScrollController();
  List<BulletinComment> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final comments = await _repo.getBulletinComments(widget.postId);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      for (final c in comments) {
        _bodyCtrl.remember(c.userId, c.authorLabel, c.authorUsername);
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _posting = true);
    final comment = await _repo.addBulletinComment(
      postId: widget.postId,
      body: _bodyCtrl.payload,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (comment == null) {
      showTopSnackBar(context, 'Failed to post comment');
      return;
    }
    _bodyCtrl.clear();
    setState(() => _comments.add(comment));
    widget.onCountChanged?.call(_comments.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontFamily: AppTypography.bodyFamily,
                    fontSize: AppTypography.bodySize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close comments',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Comments list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: _loading
                ? const Center(
                    heightFactor: 3,
                    child: CircularProgressIndicator(),
                  )
                : _comments.isEmpty
                ? const Center(
                    heightFactor: 3,
                    child: Text(
                      'No comments yet. Be the first!',
                      style: TextStyle(
                        fontFamily: AppTypography.bodyFamily,
                        color: AppColors.textSecondary,
                        fontSize: AppTypography.bodySize,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollCtrl,
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _comments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppMetrics.labelGap),
                    itemBuilder: (_, i) => _CommentTile(
                      comment: _comments[i],
                      onReply: () => _bodyCtrl.replyTo(
                        _comments[i].id,
                        _comments[i].authorLabel,
                        _comments[i].body,
                      ),
                    ),
                  ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Input row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConversationComposer(
                    controller: _bodyCtrl,
                    child: TextField(
                      controller: _bodyCtrl,
                      focusNode: _bodyCtrl.focusNode,
                      enabled: !_posting,
                      minLines: 5,
                      maxLines: null,
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
                          vertical: 10,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AppTapTarget(
                  onTap: _posting ? null : _submit,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _posting
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CommentTile ──────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final BulletinComment comment;

  final VoidCallback onReply;
  const _CommentTile({required this.comment, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          backgroundImage: (comment.authorAvatarUrl?.trim().isNotEmpty == true)
              ? NetworkImage(comment.authorAvatarUrl!)
              : null,
          child: (comment.authorAvatarUrl?.trim().isNotEmpty != true)
              ? const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.primary,
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorLabel,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              ConversationBody(
                comment.body,
                style: const TextStyle(
                  fontFamily: AppTypography.bodyFamily,
                  fontSize: AppTypography.bodySize,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              TextButton(onPressed: onReply, child: const Text('Reply')),
            ],
          ),
        ),
        FlowerReactionButton(
          target: FlowerTarget.communityComment,
          targetId: comment.id,
        ),
      ],
    );
  }
}
