import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../backend/db/models/user_profile.dart';
import '../../backend/db/repositories/users_repo.dart';
import '../styling/app_colors.dart';

/// Versioned rich content stored in the existing text column. Plain messages stay plain.
class ConversationContent {
  const ConversationContent(this.text, {this.reply, this.mentions = const []});
  final String text;
  final Map<String, String>? reply;
  final List<Map<String, String>> mentions;
  static ConversationContent parse(String value) {
    if (!value.startsWith('{"juniper_message":1,'))
      return ConversationContent(value);
    try {
      final data = jsonDecode(value) as Map<String, dynamic>;
      return ConversationContent(
        data['text'] as String,
        reply: data['reply'] == null
            ? null
            : Map<String, String>.from(data['reply']),
        mentions: (data['mentions'] as List? ?? [])
            .map((m) => Map<String, String>.from(m))
            .toList(),
      );
    } catch (_) {
      return ConversationContent(value);
    }
  }

  String encode() => reply == null && mentions.isEmpty
      ? text
      : jsonEncode({
          'juniper_message': 1,
          'text': text,
          if (reply != null) 'reply': reply,
          'mentions': mentions,
        });
}

class ConversationController extends TextEditingController {
  final focusNode = FocusNode();
  final Map<String, UserProfile> participants = {};
  void remember(String id, String name, [String? username]) {
    participants[id] = UserProfile(
      id: id,
      displayName: name,
      username: username,
    );
  }

  Map<String, String>? reply;
  final List<Map<String, String>> mentions = [];
  void replyTo(String id, String author, String content) {
    reply = {
      'id': id,
      'author': author,
      'text': ConversationContent.parse(content).text.substring(
        0,
        ConversationContent.parse(content).text.length.clamp(0, 160),
      ),
    };
    notifyListeners();
    focusNode.requestFocus();
  }

  void cancelReply() {
    reply = null;
    notifyListeners();
  }

  String get payload => ConversationContent(
    text.trim(),
    reply: reply,
    mentions: mentions.where((m) => text.contains(m['token']!)).toList(),
  ).encode();
  @override
  void clear() {
    reply = null;
    mentions.clear();
    super.clear();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}

class ConversationComposer extends StatefulWidget {
  const ConversationComposer({
    super.key,
    required this.controller,
    required this.child,
    this.searchUsers,
    this.showReplyPreview = true,
  });
  final ConversationController controller;
  final bool showReplyPreview;
  final Widget child;
  final Future<List<UserProfile>> Function(String)? searchUsers;
  @override
  State<ConversationComposer> createState() => _ConversationComposerState();
}

class _ConversationComposerState extends State<ConversationComposer> {
  Timer? _timer;
  String? _query;
  int _request = 0;
  List<UserProfile> _users = [];
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    final c = widget.controller;
    final end = c.selection.isValid
        ? c.selection.baseOffset.clamp(0, c.text.length)
        : c.text.length;
    final query = RegExp(
      r'(?:^|\s)@([\w.-]*)$',
    ).firstMatch(c.text.substring(0, end))?.group(1);
    if (query != _query) {
      _query = query;
      _users = [];
      _timer?.cancel();
      final request = ++_request;
      if (query != null && query.isNotEmpty)
        _timer = Timer(const Duration(milliseconds: 250), () async {
          final local = widget.controller.participants.values.where(
            (u) =>
                u.resolvedDisplayName.toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                (u.username ?? '').toLowerCase().contains(query.toLowerCase()),
          );
          final users = widget.searchUsers != null
              ? await widget.searchUsers!(query)
              : await UsersRepo().searchPublicUsers(query: query);
          if (mounted && request == _request)
            setState(
              () => _users = {
                for (final u in local) u.id: u,
                for (final u in users ?? <UserProfile>[]) u.id: u,
              }.values.take(5).toList(),
            );
        });
    }
    setState(() {});
  }

  void _mention(UserProfile user) {
    final c = widget.controller;
    final end = c.selection.isValid ? c.selection.baseOffset : c.text.length;
    final start = c.text.lastIndexOf('@', end - 1);
    if (start < 0) return;
    final token =
        '@${user.username?.isNotEmpty == true ? user.username!.replaceFirst(RegExp(r'^@'), '') : user.resolvedDisplayName}';
    c.mentions.add({'id': user.id, 'token': token});
    final updated = c.text.replaceRange(start, end, '$token ');
    c.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + token.length + 1),
    );
    c.focusNode.requestFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showReplyPreview && widget.controller.reply != null)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to ${widget.controller.reply!['author']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      widget.controller.reply!['text']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cancel reply',
                onPressed: widget.controller.cancelReply,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      if (_users.isNotEmpty)
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final user in _users)
                  ListTile(
                    dense: true,
                    title: Text(user.resolvedDisplayName),
                    subtitle: user.username == null
                        ? null
                        : Text('@${user.username}'),
                    onTap: () => _mention(user),
                  ),
              ],
            ),
          ),
        ),
      if (_query != null && _query!.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Type a name after @ to mention someone.'),
        ),
      widget.child,
    ],
  );
}

class ConversationBody extends StatelessWidget {
  const ConversationBody(
    this.content, {
    super.key,
    this.style,
    this.showReply = true,
  });
  final String content;
  final TextStyle? style;
  final bool showReply;
  @override
  Widget build(BuildContext context) {
    final data = ConversationContent.parse(content);
    final tokens =
        data.mentions
            .map((m) => m['token']!)
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.length.compareTo(a.length));
    final spans = <TextSpan>[];
    if (tokens.isEmpty) {
      spans.add(TextSpan(text: data.text));
    } else {
      final regex = RegExp(tokens.map(RegExp.escape).join('|'));
      var offset = 0;
      for (final match in regex.allMatches(data.text)) {
        spans.add(TextSpan(text: data.text.substring(offset, match.start)));
        spans.add(
          TextSpan(
            text: match.group(0),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
        );
        offset = match.end;
      }
      spans.add(TextSpan(text: data.text.substring(offset)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showReply && data.reply != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 3),
              ),
              color: Colors.black.withValues(alpha: .05),
            ),
            child: Text(
              '${data.reply!['author']}\n${data.reply!['text']}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(fontSize: 12),
            ),
          ),
        Text.rich(TextSpan(children: spans), style: style),
      ],
    );
  }
}
