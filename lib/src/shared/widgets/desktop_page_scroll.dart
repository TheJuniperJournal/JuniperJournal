import 'popup_route_observer.dart';
import 'package:flutter/services.dart';
import 'persistent_desktop_shell.dart' show desktopRouteObserver;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// One desktop scrollbar and scroll target, including wheel input on side panels.
class DesktopPageScroll extends StatefulWidget {
  const DesktopPageScroll({super.key, required this.child});
  final Widget child;
  @override
  State<DesktopPageScroll> createState() => DesktopPageScrollState();
}

class DesktopPageScrollState extends State<DesktopPageScroll> {
  final ScrollController _bar = ScrollController();
  final Set<ScrollController> _sides = {};
  ScrollPosition? _page;
  bool _queued = false;
  Route<dynamic>? _lastPageRoute;

  @override
  void initState() {
    super.initState();
    _lastPageRoute = desktopRouteObserver.current;
    desktopRouteObserver.changes.addListener(_routeChanged);
  }

  void _routeChanged() {
    if (identical(_lastPageRoute, desktopRouteObserver.current)) return;
    _lastPageRoute = desktopRouteObserver.current;
    _page?.removeListener(_follow);
    _page = null;
    for (final old in _bar.positions.toList()) {
      _bar.detach(old);
    }
    for (final side in _sides) {
      if (side.hasClients) side.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  bool _visible(BuildContext context) {
    final route = ModalRoute.of(context);
    // Popup menus have their own scrollables; they must never drive the page
    // scrollbar or the persistent profile column.
    if (route != null && route is! PageRoute) return false;
    var visible =
        route == null ||
        route.isCurrent ||
        identical(route, desktopRouteObserver.current);
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) visible = false;
      if (widget is DesktopSideScroll) visible = false;
      return visible;
    });
    return visible;
  }

  void _watch(BuildContext? context, int depth, Axis axis) {
    if (context == null ||
        depth != 0 ||
        axis != Axis.vertical ||
        !_visible(context))
      return;
    final position = Scrollable.maybeOf(context)?.position;
    if (position != null) _activate(position);
  }

  void _activate(ScrollPosition position) {
    if (identical(position, _page)) return;
    _page?.removeListener(_follow);
    for (final old in _bar.positions.toList()) {
      _bar.detach(old);
    }
    _page = position;
    _bar.attach(position);
    position.addListener(_follow);
    _follow();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _follow() {
    if (_queued || !mounted) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (!mounted || _page == null || !_page!.hasPixels) return;
      for (final controller in _sides) {
        if (!controller.hasClients || !controller.position.hasContentDimensions)
          continue;
        final sideExtent = controller.position.maxScrollExtent;
        final pageExtent = _page!.maxScrollExtent;
        // A shorter page must still reveal the entire profile sidebar.
        final scale = pageExtent > 0 && sideExtent > pageExtent
            ? sideExtent / pageExtent
            : 1.0;
        final next = (_page!.pixels * scale).clamp(0.0, sideExtent);
        if ((controller.offset - next).abs() > .5) controller.jumpTo(next);
      }
    });
  }

  ScrollableState? _findPage() {
    ScrollableState? best;
    void visit(Element element) {
      if (!_visible(element)) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.position.axis == Axis.vertical &&
            state.position.hasContentDimensions) {
          if (best == null ||
              state.position.maxScrollExtent > best!.position.maxScrollExtent)
            best = state;
          return;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return best;
  }

  void _wheel(PointerSignalEvent event) {
    if (PopupRouteObserver.hasOpenPopup ||
        event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs())
      return;
    final visiblePage = _findPage();
    ScrollPosition? target = visiblePage?.position;
    if (target == null || target.maxScrollExtent == 0) {
      for (final side in _sides) {
        if (side.hasClients &&
            side.position.hasContentDimensions &&
            (target == null ||
                side.position.maxScrollExtent > target.maxScrollExtent)) {
          target = side.position;
        }
      }
    }
    if (target != null) _activate(target);
    if (_page == null || !_page!.hasContentDimensions) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final page = _page;
      if (page == null || !page.hasContentDimensions) return;
      final next = (page.pixels + event.scrollDelta.dy).clamp(
        page.minScrollExtent,
        page.maxScrollExtent,
      );
      if (next != page.pixels) page.jumpTo(next);
    });
  }

  KeyEventResult _keyboardScroll(FocusNode node, KeyEvent event) {
    if (PopupRouteObserver.hasOpenPopup) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final focused = FocusManager.instance.primaryFocus?.context;
    var editing = false;
    focused?.visitAncestorElements((element) {
      if (element.widget is EditableText) editing = true;
      return !editing;
    });
    if (editing || (focused != null && ModalRoute.of(focused) is PopupRoute))
      return KeyEventResult.ignored;
    final page = _findPage()?.position;
    if (page == null || !page.hasContentDimensions)
      return KeyEventResult.ignored;
    final key = event.logicalKey;
    final double target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = page.pixels + 48;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = page.pixels - 48;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = page.pixels + page.viewportDimension * .85;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = page.pixels - page.viewportDimension * .85;
    } else if (key == LogicalKeyboardKey.home) {
      target = page.minScrollExtent;
    } else if (key == LogicalKeyboardKey.end) {
      target = page.maxScrollExtent;
    } else {
      return KeyEventResult.ignored;
    }
    _activate(page);
    page.jumpTo(target.clamp(page.minScrollExtent, page.maxScrollExtent));
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    desktopRouteObserver.changes.removeListener(_routeChanged);
    _page?.removeListener(_follow);
    for (final old in _bar.positions.toList()) {
      _bar.detach(old);
    }
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The window owns the scrollbar. Nested shells retain their layout without
    // creating another thumb beside a centered or constrained content column.
    if (context.dependOnInheritedWidgetOfExactType<DesktopScrollScope>() !=
        null) {
      return widget.child;
    }
    return DesktopScrollScope(
      owner: this,
      child: Focus(
        autofocus: true,
        onKeyEvent: _keyboardScroll,
        child: Listener(
          onPointerSignal: _wheel,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notice) {
                _watch(notice.context, notice.depth, notice.metrics.axis);
                return false;
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notice) {
                  _watch(notice.context, notice.depth, notice.metrics.axis);
                  return false;
                },
                child: RawScrollbar(
                  key: const ValueKey('desktop-page-scrollbar'),
                  controller: _bar,
                  thumbVisibility: _page != null,
                  interactive: true,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopScrollScope extends InheritedWidget {
  const DesktopScrollScope({
    super.key,
    required this.owner,
    required super.child,
  });
  final DesktopPageScrollState owner;
  @override
  bool updateShouldNotify(DesktopScrollScope oldWidget) =>
      owner != oldWidget.owner;
}

/// The side panel follows the page; it never owns a separate user scrollbar.
class DesktopSideScroll extends StatefulWidget {
  const DesktopSideScroll({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  State<DesktopSideScroll> createState() => _DesktopSideScrollState();
}

class _DesktopSideScrollState extends State<DesktopSideScroll> {
  final _controller = ScrollController();
  DesktopPageScrollState? _owner;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _owner?._sides.remove(_controller);
    _owner = context
        .dependOnInheritedWidgetOfExactType<DesktopScrollScope>()
        ?.owner;
    _owner?._sides.add(_controller);
  }

  @override
  void dispose() {
    _owner?._sides.remove(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: _controller,
    physics: _owner == null ? null : const NeverScrollableScrollPhysics(),
    padding: widget.padding,
    child: widget.child,
  );
}
