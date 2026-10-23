import 'package:flutter/material.dart';
import 'adaptive_app_shell.dart';

/// Keeps app chrome outside the route navigator so only the center changes.
class PersistentDesktopShell extends StatefulWidget {
  const PersistentDesktopShell({super.key, required this.child});
  final Widget child;
  @override
  State<PersistentDesktopShell> createState() => PersistentDesktopShellState();
}

class PersistentDesktopShellState extends State<PersistentDesktopShell> {
  AdaptiveAppShell? _configuration;
  int _projectWorkspaces = 0;
  void updateProjectWorkspaces(int delta) {
    if (mounted) setState(() => _projectWorkspaces += delta);
  }

  void configure(AdaptiveAppShell configuration) {
    if (mounted) setState(() => _configuration = configuration);
  }

  void clear() {
    if (mounted) setState(() => _configuration = null);
  }

  @override
  void initState() {
    super.initState();
    desktopRouteObserver.changes.addListener(_routeChanged);
  }

  void _routeChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    desktopRouteObserver.changes.removeListener(_routeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = desktopRouteObserver.showingStandalone
        ? null
        : _configuration;
    return DesktopShellScope(
      controller: this,
      child: config == null
          ? widget.child
          : AdaptiveAppShell(
              hostFrame: true,
              showCreate: _projectWorkspaces == 0,
              body: widget.child,
              mobileNavigation: const SizedBox.shrink(),
              selectedIndex: config.selectedIndex,
              onSelect: config.onSelect,
              onCreate: config.onCreate,
              desktopSidebar: config.desktopSidebar,
            ),
    );
  }
}

/// Keeps project-specific actions in the project while its nested pages are open.
class ProjectWorkspaceChrome extends StatefulWidget {
  const ProjectWorkspaceChrome({super.key, required this.child});
  final Widget child;
  @override
  State<ProjectWorkspaceChrome> createState() => _ProjectWorkspaceChromeState();
}

class _ProjectWorkspaceChromeState extends State<ProjectWorkspaceChrome> {
  PersistentDesktopShellState? _host;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = DesktopShellScope.of(context);
    if (_host == host) return;
    final previous = _host;
    _host = host;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      previous?.updateProjectWorkspaces(-1);
      if (mounted) host?.updateProjectWorkspaces(1);
    });
  }

  @override
  void dispose() {
    final host = _host;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      host?.updateProjectWorkspaces(-1);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DesktopShellScope extends InheritedWidget {
  const DesktopShellScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final PersistentDesktopShellState controller;
  static PersistentDesktopShellState? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DesktopShellScope>()
      ?.controller;
  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) => false;
}

final desktopRouteObserver = DesktopRouteObserver();

class DesktopRouteObserver extends NavigatorObserver {
  final changes = ChangeNotifier();
  Route<dynamic>? current;
  final standaloneRoutes = <Route<dynamic>>{};
  bool get showingStandalone => standaloneRoutes.contains(current);

  void registerStandalone(Route<dynamic> route, bool present) {
    if (present) {
      standaloneRoutes.add(route);
    } else {
      standaloneRoutes.remove(route);
    }
    changes.notifyListeners();
  }

  final profileRoutes = <Route<dynamic>>{};
  bool get showingProfile => profileRoutes.contains(current);

  void registerProfile(Route<dynamic> route, bool present) {
    if (present) {
      profileRoutes.add(route);
    } else {
      profileRoutes.remove(route);
    }
    changes.notifyListeners();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    current = route;
    changes.notifyListeners();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    current = previousRoute is PageRoute ? previousRoute : null;
    changes.notifyListeners();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (current == route) current = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (current == oldRoute) current = newRoute;
  }
}
