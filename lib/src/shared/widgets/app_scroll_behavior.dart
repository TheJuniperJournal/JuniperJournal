import 'package:flutter/material.dart';

/// Keeps desktop scroll thumbs in a dedicated lane outside the content viewport.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) return child;
    // Menus already size their surface to the menu items. A scrollbar gutter
    // inside that surface would leave a blank strip and offset the labels.
    final route = ModalRoute.of(context);
    if (route is PopupRoute &&
        route is! DialogRoute &&
        route is! ModalBottomSheetRoute) {
      return child;
    }

    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return AppScrollbar(
          controller: details.controller,
          thumbVisibility:
              route is DialogRoute || route is ModalBottomSheetRoute
              ? true
              : null,
          child: child,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return child;
    }
  }
}

class AppScrollbar extends StatelessWidget {
  static const gutterWidth = 16.0;
  const AppScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility,
  });
  final Widget child;
  final ScrollController? controller;
  final bool? thumbVisibility;

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    thumbVisibility: thumbVisibility,
    thickness: 6,
    radius: const Radius.circular(3),
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: gutterWidth),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: child,
      ),
    ),
  );
}
