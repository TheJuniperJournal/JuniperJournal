import 'package:flutter/material.dart';
import '../../../backend/db/models/message.dart';
import '../../../shared/widgets/conversation_composer.dart';
import '../../../shared/styling/app_colors.dart';

class MessageThread {
  const MessageThread(this.parent, this.replies);
  final Message parent;
  final List<Message> replies;
}

/// Resolve reply chains only within the messages visible in this conversation.
/// Missing parents and malformed cycles stay visible as standalone messages.
List<MessageThread> groupMessageThreads(List<Message> messages) {
  final byId = {for (final message in messages) message.id: message};
  String rootOf(Message message) {
    var current = message;
    final visited = <String>{message.id};
    while (true) {
      final parentId = ConversationContent.parse(current.content).reply?['id'];
      final parent = byId[parentId];
      if (parent == null || parent.conversationId != message.conversationId)
        return current.id;
      if (!visited.add(parent.id)) return message.id;
      current = parent;
    }
  }

  final groups = <String, List<Message>>{};
  for (final message in messages) {
    (groups[rootOf(message)] ??= []).add(message);
  }
  return [
    for (final message in messages)
      if (groups.containsKey(message.id))
        MessageThread(
          message,
          groups[message.id]!.where((m) => m.id != message.id).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        ),
  ];
}

class InlineMessageThread extends StatefulWidget {
  const InlineMessageThread({
    super.key,
    required this.parent,
    required this.replies,
  });
  final Widget parent;
  final List<Widget> replies;
  @override
  State<InlineMessageThread> createState() => _InlineMessageThreadState();
}

class _InlineMessageThreadState extends State<InlineMessageThread> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      widget.parent,
      if (widget.replies.isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              '${widget.replies.length} ${widget.replies.length == 1 ? 'reply' : 'replies'}${_expanded ? ' · Hide' : ' · View'}',
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(left: 12, bottom: 16),
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.borderLight, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.replies,
            ),
          ),
      ],
    ],
  );
}
