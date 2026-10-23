import 'package:flutter/material.dart';
import '../styling/app_motion.dart';

/// Crossfades retained tabs while preserving their forms and scroll positions.
class AppTabStack extends StatefulWidget {
  const AppTabStack({
    super.key,
    required this.index,
    required this.children,
    this.sizing = StackFit.loose,
    this.onIndexChanged,
    this.duration = AppMotion.tabDuration,
  });
  final Duration duration;
  final int index;
  final List<Widget> children;
  final StackFit sizing;
  final ValueChanged<int>? onIndexChanged;
  @override
  State<AppTabStack> createState() => _AppTabStackState();
}

class _AppTabStackState extends State<AppTabStack>
    with SingleTickerProviderStateMixin {
  late final _controller =
      AnimationController(vsync: this, duration: widget.duration, value: 1)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted)
            setState(() => _previous = null);
        });
  int? _previous;
  @override
  void didUpdateWidget(covariant AppTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previous = oldWidget.index;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final stack = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduced ? 1.0 : AppMotion.curve.transform(_controller.value);
        return Stack(
          fit: widget.sizing,
          children: [
            for (var index = 0; index < widget.children.length; index++)
              Offstage(
                key: ValueKey(index),
                offstage:
                    index != widget.index && (reduced || index != _previous),
                child: TickerMode(
                  enabled: index == widget.index,
                  child: ExcludeSemantics(
                    excluding: index != widget.index,
                    child: IgnorePointer(
                      ignoring: index != widget.index,
                      child: Opacity(
                        opacity: index == widget.index
                            ? t
                            : index == _previous
                            ? 1 - t
                            : 0,
                        child: ExcludeFocus(
                          excluding: index != widget.index,
                          child: widget.children[index],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
    if (widget.onIndexChanged == null) return stack;
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 300) return;
        final next = (widget.index + (velocity < 0 ? 1 : -1)).clamp(
          0,
          widget.children.length - 1,
        );
        if (next != widget.index) widget.onIndexChanged!(next);
      },
      child: stack,
    );
  }
}

/// For small sections whose data is held by the surrounding page.
class AppContentTransition extends StatefulWidget {
  const AppContentTransition({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppMotion.tabDuration,
  });
  final Duration duration;
  final Object index;
  final Widget child;
  @override
  State<AppContentTransition> createState() => _AppContentTransitionState();
}

class _AppContentTransitionState extends State<AppContentTransition> {
  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final index = widget.index;
    final duration = widget.duration;
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedSwitcher(
        duration: duration,
        reverseDuration: duration,
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            for (final old in previous)
              if (constraints.hasBoundedHeight)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: IgnorePointer(child: ExcludeFocus(child: old)),
                  ),
                )
              else
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ExcludeSemantics(
                    child: IgnorePointer(child: ExcludeFocus(child: old)),
                  ),
                ),
            if (current != null) current,
          ],
        ),
        child: KeyedSubtree(key: ValueKey(index), child: child),
      ),
    );
  }
}
