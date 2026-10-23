import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tap controls share pointer and keyboard feedback without changing layout.
/// Gesture callbacks and hit testing remain handled by Flutter's detector.
class AppTapTarget extends GestureDetector {
  AppTapTarget({
    super.key,
    super.child,
    super.onTapDown,
    super.onTapUp,
    super.onTap,
    super.onTapMove,
    super.onTapCancel,
    super.onSecondaryTap,
    super.onSecondaryTapDown,
    super.onSecondaryTapUp,
    super.onSecondaryTapCancel,
    super.onTertiaryTapDown,
    super.onTertiaryTapUp,
    super.onTertiaryTapCancel,
    super.onDoubleTapDown,
    super.onDoubleTap,
    super.onDoubleTapCancel,
    super.onLongPressDown,
    super.onLongPressCancel,
    super.onLongPress,
    super.onLongPressStart,
    super.onLongPressMoveUpdate,
    super.onLongPressUp,
    super.onLongPressEnd,
    super.onSecondaryLongPressDown,
    super.onSecondaryLongPressCancel,
    super.onSecondaryLongPress,
    super.onSecondaryLongPressStart,
    super.onSecondaryLongPressMoveUpdate,
    super.onSecondaryLongPressUp,
    super.onSecondaryLongPressEnd,
    super.onTertiaryLongPressDown,
    super.onTertiaryLongPressCancel,
    super.onTertiaryLongPress,
    super.onTertiaryLongPressStart,
    super.onTertiaryLongPressMoveUpdate,
    super.onTertiaryLongPressUp,
    super.onTertiaryLongPressEnd,
    super.onVerticalDragDown,
    super.onVerticalDragStart,
    super.onVerticalDragUpdate,
    super.onVerticalDragEnd,
    super.onVerticalDragCancel,
    super.onHorizontalDragDown,
    super.onHorizontalDragStart,
    super.onHorizontalDragUpdate,
    super.onHorizontalDragEnd,
    super.onHorizontalDragCancel,
    super.onForcePressStart,
    super.onForcePressPeak,
    super.onForcePressUpdate,
    super.onForcePressEnd,
    super.onPanDown,
    super.onPanStart,
    super.onPanUpdate,
    super.onPanEnd,
    super.onPanCancel,
    super.onScaleStart,
    super.onScaleUpdate,
    super.onScaleEnd,
    super.behavior,
    super.excludeFromSemantics,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
    super.supportedDevices,
  });

  @override
  Widget build(BuildContext context) {
    final content = super.build(context);
    if (onTap == null || excludeFromSemantics) return content;
    return _TapFeedback(onActivate: onTap!, child: content);
  }
}

class _TapFeedback extends StatefulWidget {
  const _TapFeedback({required this.onActivate, required this.child});
  final VoidCallback onActivate;
  final Widget child;
  @override
  State<_TapFeedback> createState() => _TapFeedbackState();
}

class _TapFeedbackState extends State<_TapFeedback> {
  bool _hovered = false;
  bool _focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    mouseCursor: SystemMouseCursors.click,
    onShowFocusHighlight: (value) => setState(() => _focused = value),
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onActivate();
          return null;
        },
      ),
    },
    child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: _hovered
                      ? Theme.of(context).hoverColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: _focused
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
