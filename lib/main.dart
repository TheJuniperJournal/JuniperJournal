import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'src/features/home_page/pages/password_recovery.dart';
import 'src/shared/widgets/desktop_page_scroll.dart';
import 'src/shared/widgets/browser_history_stub.dart'
    if (dart.library.html) 'src/shared/widgets/browser_history_web.dart';
import 'src/shared/widgets/page_url.dart';
import 'package:flutter/foundation.dart';
import 'src/shared/widgets/web_navigation_host.dart';
import 'src/shared/widgets/public_site_frame.dart';
import 'src/features/home_page/pages/public_explore.dart';
import 'src/shared/widgets/page_refresh_state.dart';
import 'src/backend/db/repositories/projects_repo.dart';
import 'src/features/project/services/project_activity.dart';
import 'src/shared/widgets/navigation_scroll_reset.dart';
import 'src/shared/widgets/desktop_modal_layer.dart';
import 'src/shared/widgets/persistent_desktop_shell.dart';
import 'src/shared/widgets/eco_reward_notice_host.dart';
import 'src/shared/widgets/restored_navigation.dart';
import 'src/shared/styling/app_theme.dart';
import 'src/shared/widgets/app_scroll_behavior.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:juniper_journal/src/features/project/pages/create_project.dart';
import 'package:juniper_journal/src/features/project/pages/project_dashboard.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:juniper_journal/src/backend/db/supabase_database.dart';
import 'package:juniper_journal/src/features/home_page/home_page.dart';
import 'package:juniper_journal/src/shared/styling/app_colors.dart';

// Preview restoration is opt-in; debug Chrome should exercise real authentication.
const _isLocalPreview = bool.fromEnvironment('LOCAL_PREVIEW');

String _launchLocation = "/";
bool _launchPasswordRecovery = false;

void main() {
  if (kIsWeb) {
    _launchPasswordRecovery = RegExp(
      r'(?:^|[&#?])type=recovery(?:&|$)',
    ).hasMatch(Uri.base.toString());
  }
  if (kIsWeb) _launchLocation = BrowserHistory().location;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AppBootstrap());
}

Future<Widget> _initializeApp() async {
  await SupabaseDatabase.instance.init();
  var recoverySession = false;
  try {
    final event =
        await SupabaseDatabase.instance.client.auth.onAuthStateChange.first;
    recoverySession = event.event == AuthChangeEvent.passwordRecovery;
  } catch (_) {
    // An expired callback must not reuse a previously signed-in session.
  }
  if (recoverySession) {
    return const MyApp(
      initialPage: PasswordRecoveryScreen(
        updatePassword: true,
        recoverySessionVerified: true,
      ),
    );
  }
  if (_launchPasswordRecovery) {
    return const MyApp(initialPage: PasswordRecoveryScreen());
  }
  var requested = kIsWeb ? PageUrl.decode(_launchLocation) : null;
  // Authentication is a fresh entry to Home; refreshes of actual destination
  // URLs still restore those destinations above the signed-in shell.
  if (SupabaseDatabase.instance.client.auth.currentSession != null &&
      const {'login', 'signup'}.contains(requested?['kind'])) {
    requested = <String, dynamic>{'kind': 'home', 'section': 0};
    _launchLocation = PageUrl.encode(requested);
  }
  if (requested != null) {
    try {
      final page = await PageRefreshState.restore(requested, ProjectsRepo());
      return MyApp(
        initialPage:
            page ??
            const Scaffold(
              body: Center(
                child: Text(
                  'This page is unavailable or you do not have access.',
                ),
              ),
            ),
      );
    } catch (_) {
      return const MyApp(
        initialPage: Scaffold(
          body: Center(
            child: Text('This page is unavailable or you do not have access.'),
          ),
        ),
      );
    }
  }

  if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
      '/explore') {
    return const MyApp(initialPage: PublicExploreScreen());
  }
  Widget initialPage = const _SessionGate();
  if (_isLocalPreview) {
    initialPage = const HomeShellScreen();
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('debug.projectId');
    if (id != null) {
      initialPage = ProjectDashboard(
        projectId: id,
        projectName: prefs.getString('debug.projectName') ?? 'Project',
        tags: prefs.getStringList('debug.projectTags') ?? const [],
        isOwner: prefs.getBool('debug.isOwner') ?? false,
        openSettingsOnLoad: prefs.getString('debug.page') == 'settings',
      );
    } else if (prefs.getString('debug.page') == 'create') {
      initialPage = const CreateProjectScreen();
    }
  }
  if (SupabaseDatabase.instance.client.auth.currentSession != null) {
    final remembered = await PageRefreshState.read();
    if (remembered != null) {
      try {
        final restored = await PageRefreshState.restore(
          remembered,
          ProjectsRepo(),
        );
        if (restored != null)
          return MyApp(
            initialPage: restored,
            restored: restored is! HomeShellScreen,
          );
      } catch (error) {
        debugPrint('Could not restore page: $error');
      }
    }
  }
  return MyApp(initialPage: initialPage);
}

class _SessionGate extends StatelessWidget {
  const _SessionGate({this.restoreJournal = true});
  final bool restoreJournal;
  @override
  Widget build(BuildContext context) {
    final auth = SupabaseDatabase.instance.client.auth;
    return StreamBuilder(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const PasswordRecoveryScreen(
            updatePassword: true,
            recoverySessionVerified: true,
          );
        }
        return auth.currentSession != null
            ? HomeShellScreen(restoreJournal: restoreJournal)
            : const PublicExploreScreen();
      },
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();
  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<Widget> _app = _initializeApp();
  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
    future: _app,
    builder: (context, snapshot) {
      if (snapshot.hasData) return snapshot.data!;
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: snapshot.hasError
                  ? [
                      const Text('Could not start Juniper Journal.'),
                      TextButton(
                        onPressed: () =>
                            setState(() => _app = _initializeApp()),
                        child: const Text('Retry'),
                      ),
                    ]
                  : const [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text('Loading Juniper Journal…'),
                    ],
            ),
          ),
        ),
      );
    },
  );
}

final _webNavigationHostKey = GlobalKey();

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialPage = const JuniperAuthScreen(),
    this.restored = false,
  });
  final bool restored;
  final Widget initialPage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Juniper Journal',
      navigatorKey: kIsWeb ? null : ecoRewardNavigatorKey,
      builder: (context, child) => DesktopPageScroll(
        child: ProjectActivityHost(
          child: EcoRewardNoticeHost(
            child: DesktopModalLayer(
              child: PersistentDesktopShell(
                child: PublicSiteFrame(
                  navigatorKey: ecoRewardNavigatorKey,
                  child: kIsWeb
                      ? WebNavigationHost(
                          key: _webNavigationHostKey,
                          initialLocation: _launchLocation,
                          navigatorKey: ecoRewardNavigatorKey,
                          initialPage: initialPage,
                          appParentPage: const _SessionGate(
                            restoreJournal: false,
                          ),
                          parentPage:
                              restored ||
                                  destinationNeedsAppParent(
                                    PageUrl.decode(_launchLocation)?['kind']
                                        as String?,
                                  )
                              ? const _SessionGate(restoreJournal: false)
                              : null,
                          observers: [
                            PageRefreshState.instance,
                            NavigationScrollResetObserver(),
                            desktopRouteObserver,
                          ],
                        )
                      : child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
      scrollBehavior: const AppScrollBehavior(),
      initialRoute: kIsWeb || restored || _isLocalPreview ? '/' : null,
      onGenerateInitialRoutes:
          (restored ||
              (_isLocalPreview &&
                  (initialPage is CreateProjectScreen ||
                      initialPage is ProjectDashboard)))
          ? (_) => restoredNavigationStack(
              home: const HomeShellScreen(restoreJournal: false),
              restored: initialPage,
            )
          : null,
      navigatorObservers: kIsWeb
          ? []
          : [
              PageRefreshState.instance,
              NavigationScrollResetObserver(),
              desktopRouteObserver,
              if (_isLocalPreview) _DebugPageObserver(),
            ],
      theme: buildAppTheme(),
      // Allows for pushNamed
      routes: {
        '/signup': (_) => const SignupScreen(),
        '/login': (_) => const LoginScreen(),
        '/explore': (_) => const PublicExploreScreen(),
      },
      home:
          (restored ||
              (_isLocalPreview &&
                  (initialPage is CreateProjectScreen ||
                      initialPage is ProjectDashboard)))
          ? null
          : initialPage,
    );
  }
}

class _DebugPageObserver extends NavigatorObserver {
  void _remember(Route<dynamic>? route) {
    if (route is! MaterialPageRoute || navigator == null) return;
    final page = route.builder(navigator!.context);
    if (page is! HomeShellScreen &&
        page is! ProjectDashboard &&
        page is! CreateProjectScreen) {
      return;
    }
    SharedPreferences.getInstance().then((prefs) async {
      if (page is ProjectDashboard) {
        await prefs.setString('debug.projectId', page.projectId);
        await prefs.setString('debug.projectName', page.projectName);
        await prefs.setStringList('debug.projectTags', page.tags);
        await prefs.setBool('debug.isOwner', page.isOwner);
        await prefs.setString(
          'debug.page',
          page.openSettingsOnLoad ? 'settings' : 'dashboard',
        );
      } else if (page is CreateProjectScreen) {
        if (page.existingProject != null) {
          await prefs.setString('debug.projectId', page.existingProject!.id);
          await prefs.setString('debug.page', 'settings');
        } else {
          await prefs.remove('debug.projectId');
          await prefs.setString('debug.page', 'create');
        }
      } else {
        await prefs.remove('debug.projectId');
        await prefs.setString('debug.page', 'home');
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remember(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remember(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _remember(newRoute);
}
