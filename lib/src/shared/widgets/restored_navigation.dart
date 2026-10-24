import 'package:flutter/material.dart';

/// A restored detail page keeps its parent underneath it, just as normal
/// navigation does, so closing the page cannot empty the navigator.
List<Route<dynamic>> restoredNavigationStack({
  required Widget home,
  required Widget restored,
}) => [
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => home,
  ),
  restoredDetailRoute(restored),
];

/// Build the parent on a cold start so it can configure the persistent shell.
/// Detail screens provide their own opaque Scaffold inside the route.
Route<void> restoredDetailRoute(Widget page, {RouteSettings? settings}) =>
    RestoredDetailRoute(page, settings: settings);

class RestoredDetailRoute extends PageRouteBuilder<void> {
  RestoredDetailRoute(this.page, {RouteSettings? settings})
    : super(
        settings: settings ?? const RouteSettings(name: '/restored'),
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      );
  final Widget page;
}

/// Every application detail/form needs the shared parent; public destinations do not.
bool destinationNeedsAppParent(String? kind) =>
    kind != null &&
    !const {
      'home',
      'explore',
      'login',
      'signup',
      'about',
      'support',
      'privacy',
      'safety',
      'password-recovery',
    }.contains(kind);
