import 'package:flutter/material.dart';

/// Start a newly selected page at the top without discarding its data or forms.
/// Horizontal carousels and date/time wheels retain their selection.
void resetPageScroll(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final root = ModalRoute.of(context)?.subtreeContext ?? context;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is IgnorePointer && widget.ignoring) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.widget.controller is! FixedExtentScrollController) {
          final position = state.position;
          if (position.axis == Axis.vertical && position.hasContentDimensions) {
            final top = position.axisDirection == AxisDirection.up
                ? position.maxScrollExtent
                : position.minScrollExtent;
            if (position.pixels != top) position.jumpTo(top);
          }
        }
      }
      element.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
  });
}

class NavigationScrollResetObserver extends NavigatorObserver {
  void _reset(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = route.subtreeContext;
      if (context != null && context.mounted) resetPageScroll(context);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _reset(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _reset(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _reset(newRoute);
  }
}
