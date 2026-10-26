import 'package:flutter/material.dart';

/// Popup scrolling belongs to the popup, never to the page behind its anchor.
/// Each Navigator has its own observer; the desktop window shares the lock.
class PopupRouteObserver extends NavigatorObserver {
  static final _open = <Route<dynamic>>{};
  final _owned = <Route<dynamic>>{};
  static bool get hasOpenPopup => _open.isNotEmpty;

  void _add(Route<dynamic>? route) {
    if (route is! PopupRoute) return;
    _owned.add(route);
    _open.add(route);
  }

  void _remove(Route<dynamic>? route) {
    _owned.remove(route);
    _open.remove(route);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remove(oldRoute);
    _add(newRoute);
  }

  void dispose() {
    _open.removeAll(_owned);
    _owned.clear();
  }
}
