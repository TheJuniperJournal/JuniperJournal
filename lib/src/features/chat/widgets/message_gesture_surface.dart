import 'package:flutter/semantics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single and double clicks share Flutter's gesture arena, so a like does not reply.
class MessageGestureSurface extends StatefulWidget {
  const MessageGestureSurface({
    super.key,
    required this.child,
    required this.onReply,
    required this.onLike,
    required this.onReactions,
  });
  final Widget child;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onReactions;
  @override
  State<MessageGestureSurface> createState() => _MessageGestureSurfaceState();
}

class _MessageGestureSurfaceState extends State<MessageGestureSurface> {
  bool _restoreMenu = false;
  void _enter() {
    if (kIsWeb && !_restoreMenu) {
      _restoreMenu = true;
      BrowserContextMenu.disableContextMenu();
    }
  }

  void _exit() {
    if (_restoreMenu) {
      _restoreMenu = false;
      BrowserContextMenu.enableContextMenu();
    }
  }

  @override
  void dispose() {
    _exit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    customSemanticsActions: {
      CustomSemanticsAction(label: 'Reply to message'): widget.onReply,
      CustomSemanticsAction(label: 'Like or unlike message'): widget.onLike,
      CustomSemanticsAction(label: 'Choose emoji reaction'): widget.onReactions,
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
      child: MouseRegion(
        onEnter: (_) => _enter(),
        onExit: (_) => _exit(),
        child: Tooltip(
          message:
              'Click to reply · Double-click to like · Right-click for emojis',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onReply,
            onDoubleTap: widget.onLike,
            onSecondaryTap: widget.onReactions,
            onLongPress: widget.onReactions,
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class _LikeMessageIntent extends Intent {
  const _LikeMessageIntent();
}
