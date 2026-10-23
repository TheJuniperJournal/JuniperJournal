import 'package:flutter/widgets.dart';

/// The space available to a page between desktop navigation and profile.
class DesktopContentWidth extends InheritedWidget {
  const DesktopContentWidth({
    super.key,
    required this.width,
    required super.child,
  });
  final double width;
  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopContentWidth>()?.width;
  @override
  bool updateShouldNotify(DesktopContentWidth oldWidget) =>
      width != oldWidget.width;
}
