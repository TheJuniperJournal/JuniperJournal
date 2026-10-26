import 'popup_route_observer.dart';
import 'app_navigation.dart';
import 'package:flutter/material.dart';
import 'eco_reward_notice_host.dart' show ecoRewardNavigatorKey;

final desktopModalNavigatorKey = GlobalKey<NavigatorState>();

/// Popup routes cover the window; ordinary app routes keep their desktop frame.
class DesktopModalLayer extends StatefulWidget {
  const DesktopModalLayer({super.key, required this.child});
  final Widget child;
  @override
  State<DesktopModalLayer> createState() => _DesktopModalLayerState();
}

class _DesktopModalLayerState extends State<DesktopModalLayer> {
  bool _desktopEnabled = false;
  final _popups = PopupRouteObserver();

  @override
  void dispose() {
    _popups.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _desktopEnabled =
        _desktopEnabled || MediaQuery.sizeOf(context).width >= 1000;
    if (!_desktopEnabled) return widget.child;
    return Navigator(
      key: desktopModalNavigatorKey,
      reportsRouteUpdateToEngine: false,
      observers: [_popups],
      onGenerateRoute: (_) => PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => widget.child,
        transitionDuration: Duration.zero,
      ),
    );
  }
}

/// Leaving a popup for an editor restores the main page navigator first.
Future<T?> pushAppPage<T>(BuildContext context, Route<T> route) {
  final current = Navigator.of(context);
  final overlay = desktopModalNavigatorKey.currentState;
  final pages = ecoRewardNavigatorKey.currentState;
  if (current == overlay && pages != null) {
    overlay!.popUntil((route) => route.isFirst);
    return pushAppRoute<T>(
      pages.overlay!.context,
      route,
      targetNavigator: pages,
    );
  }
  return pushAppRoute<T>(context, route, targetNavigator: current);
}
