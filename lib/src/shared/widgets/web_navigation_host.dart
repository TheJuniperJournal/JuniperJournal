import 'restored_navigation.dart';
import '../../features/site/pages/site_information_page.dart';
import 'package:flutter/material.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../../features/home_page/pages/public_explore.dart';
import '../../features/home_page/pages/login.dart';
import '../../features/home_page/pages/signup.dart';
import 'browser_history_stub.dart'
    if (dart.library.html) 'browser_history_web.dart';
import 'page_refresh_state.dart';
import 'page_url.dart';
import 'journal_draft_session.dart';
import 'popup_route_observer.dart';

/// Owns browser history separately from Navigator's temporary popup routes.
class WebNavigationHost extends StatefulWidget {
  const WebNavigationHost({
    super.key,
    this.initialLocation = "/",
    required this.navigatorKey,
    required this.initialPage,
    required this.observers,
    this.parentPage,
    this.appParentPage,
    this.history,
  });
  final String initialLocation;
  final BrowserHistory? history;
  final Widget? parentPage;

  /// Stable signed-in shell for later browser-history navigation, even when
  /// this host originally bootstrapped at the login screen.
  final Widget? appParentPage;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget initialPage;
  final List<NavigatorObserver> observers;
  @override
  State<WebNavigationHost> createState() => _WebNavigationHostState();
}

class _WebNavigationHostState extends State<WebNavigationHost> {
  late final _history = widget.history ?? BrowserHistory();
  late final _observer = _PageObserver(this);
  final _popups = PopupRouteObserver();
  bool _opening = false;
  bool _pendingDestination = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _opening = true;
    PageRefreshState.onDestinationChanged = _remember;
    final initial = widget.initialLocation;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _history.listen(_openLocation);
      if (!mounted) return;
      // Bootstrap already resolved initialPage from this URL. Reopening it here
      // replaces the first visible page and starts its data requests twice.
      _opening = false;
      if (PageUrl.decode(initial) != null) {
        _history.write(initial, replace: true);
      } else {
        _changed(_observer.top, replace: true);
      }
    });
  }

  void _remember(Map<String, dynamic> data) {
    final path = PageUrl.encode(data);
    // remember() only reports the current route. A wrapper can reveal a new
    // destination without a Navigator push (for example public/auth shells).
    // Keep that destination in the URL even when its path differs.
    if (_opening) return;
    if (_pendingDestination) {
      _pendingDestination = false;
      _history.write(path);
    } else {
      _history.write(path, replace: true);
    }
  }

  Future<void> _openLocation(String location) async {
    final request = ++_request;
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;
    _opening = true;
    if (!await JournalDraftGuard.leaveCurrent(nav)) {
      _opening = false;
      return;
    }
    Widget? page;
    try {
      final data = PageUrl.decode(location);
      page = data == null
          ? const PublicExploreScreen()
          : await PageRefreshState.restore(data, ProjectsRepo());
    } catch (_) {}
    if (!mounted || request != _request) return;
    page ??= const Scaffold(
      body: Center(
        child: Text('This page is unavailable or you do not have access.'),
      ),
    );
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            widget.appParentPage ?? widget.parentPage ?? widget.initialPage,
      ),
      (_) => false,
    );
    for (final parent in projectNavigationParents(page)) {
      nav.push(restoredDetailRoute(parent));
    }
    nav.push(
      restoredDetailRoute(
        page,
        settings: RouteSettings(arguments: PageUrl.decode(location)),
      ),
    );
    _history.write(location, replace: true);
    _opening = false;
  }

  void _changed(Route<dynamic>? route, {bool replace = false}) {
    if (_opening || route is! PageRoute) return;
    final data = PageRefreshState.instance.describeRoute(route);
    _pendingDestination = data == null;
    if (data != null) _history.write(PageUrl.encode(data), replace: replace);
  }

  Route<dynamic> _route(RouteSettings settings) => MaterialPageRoute(
    settings: settings,
    builder: (_) => switch (settings.name) {
      '/login' => const LoginScreen(),
      '/signup' => const SignupScreen(),
      '/explore' => const PublicExploreScreen(),
      '/about' ||
      '/support' ||
      '/privacy' ||
      '/safety' => SiteInformationPage(page: settings.name!.substring(1)),
      _ => widget.initialPage,
    },
  );
  @override
  Widget build(BuildContext context) => Navigator(
    key: widget.navigatorKey,
    reportsRouteUpdateToEngine: false,
    observers: [...widget.observers, _observer, _popups],
    onGenerateRoute: _route,
    onGenerateInitialRoutes: (_, __) => [
      if (widget.parentPage != null)
        MaterialPageRoute<void>(builder: (_) => widget.parentPage!),
      if (widget.parentPage != null)
        for (final parent in projectNavigationParents(widget.initialPage))
          restoredDetailRoute(parent),
      if (widget.parentPage != null)
        restoredDetailRoute(
          widget.initialPage,
          settings: RouteSettings(
            name: '/',
            arguments: PageUrl.decode(widget.initialLocation),
          ),
        )
      else
        MaterialPageRoute(
          builder: (_) => widget.initialPage,
          settings: RouteSettings(
            name: '/',
            arguments: PageUrl.decode(widget.initialLocation),
          ),
        ),
    ],
  );
  @override
  void dispose() {
    PageRefreshState.onDestinationChanged = null;
    _history.dispose();
    _popups.dispose();
    super.dispose();
  }
}

class _PageObserver extends NavigatorObserver {
  _PageObserver(this.host);
  final _WebNavigationHostState host;
  Route<dynamic>? top;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
    host._changed(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    top = newRoute;
    host._changed(newRoute, replace: true);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute;
    if (route is PageRoute) host._changed(previousRoute);
  }
}
