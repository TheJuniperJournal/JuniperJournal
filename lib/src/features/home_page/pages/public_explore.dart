import '../../../shared/widgets/page_refresh_state.dart';
import 'package:flutter/material.dart';
import '../../../backend/db/repositories/projects_repo.dart';
import '../../../backend/db/repositories/communities_repo.dart';
import '../../../shared/widgets/persistent_desktop_shell.dart';
import 'explore_page.dart';
import 'login.dart';
import 'signup.dart';

/// Public front door: discovery does not require a personal workspace.
class PublicExploreScreen extends StatefulWidget {
  const PublicExploreScreen({
    super.key,
    this.projectsRepo,
    this.communitiesRepo,
    this.initialCommunities = false,
  });
  final bool initialCommunities;
  final ProjectsRepo? projectsRepo;
  final CommunitiesRepo? communitiesRepo;
  @override
  State<PublicExploreScreen> createState() => _PublicExploreScreenState();
}

class _PublicExploreScreenState extends State<PublicExploreScreen> {
  Route<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route == route) return;
    _route = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route != null) {
        PageRefreshState.remember(context, {
          'kind': 'explore',
          if (widget.initialCommunities) 'tab': 'communities',
        });
        DesktopShellScope.of(context)?.clear();
        desktopRouteObserver.registerStandalone(route, true);
      }
    });
  }

  @override
  void dispose() {
    final route = _route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route != null) desktopRouteObserver.registerStandalone(route, false);
    });
    super.dispose();
  }

  void _authenticate({bool signup = false}) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => signup ? const SignupScreen() : const LoginScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            children: [
              Expanded(
                child: ProjectBrowsePage(
                  publicLanding: true,
                  initialCommunities: widget.initialCommunities,
                  onCommunitiesChanged: (value) => PageRefreshState.remember(
                    context,
                    {'kind': 'explore', if (value) 'tab': 'communities'},
                  ),
                  projectsRepo: widget.projectsRepo,
                  communitiesRepo: widget.communitiesRepo,
                  onSignIn: _authenticate,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
