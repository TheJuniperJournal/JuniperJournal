import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single and double clicks share Flutter's gesture arena, so a like does not reply.
class MessageGestureSurface extends StatefulWidget {
  const MessageGestureSurface({
    super.key,
    required this.child,
    required this.onReply,
    required this.onLike,
  });
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onLike;
  @override
  State<MessageGestureSurface> createState() => _MessageGestureSurfaceState();
}

class _MessageGestureSurfaceState extends State<MessageGestureSurface> {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    customSemanticsActions: {
      CustomSemanticsAction(label: 'Reply to message'): widget.onReply,
      CustomSemanticsAction(label: 'Like or unlike message'): widget.onLike,
    },
    child: FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.keyL): _LikeMessageIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onReply();
            return null;
          },
        ),
        _LikeMessageIntent: CallbackAction<_LikeMessageIntent>(
          onInvoke: (_) {
            widget.onLike();
            return null;
          },
        ),
      },
      child: Tooltip(
        message: 'Click to reply · Double-click to like',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onReply,
          onDoubleTap: widget.onLike,
          child: widget.child,
        ),
      ),
    ),
  );
}

class _LikeMessageIntent extends Intent {
  const _LikeMessageIntent();
}
