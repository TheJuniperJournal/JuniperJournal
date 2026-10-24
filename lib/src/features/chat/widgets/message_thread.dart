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
    this.isSent = false,
  });
  final bool isSent;
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
      if (widget.replies.isNotEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 6),
          child: Row(
            children: [
              Icon(
                Icons.subdirectory_arrow_right_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              SizedBox(width: 6),
              Text(
                'Original message',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      widget.parent,
      if (widget.replies.isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.replies.length} ${widget.replies.length == 1 ? 'Reply' : 'Replies'}',
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          CustomPaint(
            painter: const _ReplyConnectorPainter(),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 40,
                right: 0,
                top: 4,
                bottom: 22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.replies,
              ),
            ),
          ),
      ],
    ],
  );
}

class _ReplyConnectorPainter extends CustomPainter {
  const _ReplyConnectorPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final bottom = size.height - 6;
    final bend = bottom < 24 ? bottom : 24.0;
    final path = Path()
      ..moveTo(13, 0)
      ..lineTo(13, bottom - bend)
      ..quadraticBezierTo(13, bottom, 13 + bend, bottom)
      ..lineTo(40, bottom);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ReplyConnectorPainter oldDelegate) => false;
}
