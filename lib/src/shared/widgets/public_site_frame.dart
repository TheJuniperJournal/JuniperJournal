import 'page_refresh_state.dart';
import 'desktop_page_scroll.dart';
import 'package:flutter/material.dart';
import '../../backend/db/supabase_database.dart';

/// Shared website navigation outside the page navigator, including detail pages.
class PublicSiteFrame extends StatelessWidget {
  const PublicSiteFrame({
    super.key,
    required this.navigatorKey,
    required this.child,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = SupabaseDatabase.instance.client.auth;
    return ValueListenableBuilder<String?>(
      valueListenable: PageRefreshState.destinationKind,
      builder: (context, kind, _) => StreamBuilder(
        stream: auth.onAuthStateChange,
        builder: (context, snapshot) {
          final publicPage = const [
            'explore',
            'about',
            'support',
            'privacy',
            'safety',
          ].contains(kind);
          final hideHeader =
              kind == 'login' ||
              kind == 'signup' ||
              (auth.currentSession != null &&
                  (!publicPage || kind != 'explore'));
          void navigate(String name) {
            if (PageRefreshState.currentDestination?['kind'] ==
                name.substring(1))
              return;
            navigatorKey.currentState?.pushNamed(name);
          }

          void explore() {
            if (PageRefreshState.currentDestination?['kind'] == 'explore')
              return;
            navigatorKey.currentState?.pushNamedAndRemoveUntil(
              '/explore',
              (_) => false,
            );
          }

          return Column(
            children: [
              Offstage(
                offstage: hideHeader,
                child: Material(
                  color: Colors.white,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 700;
                              return Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: explore,
                                        style: TextButton.styleFrom(
                                          alignment: Alignment.centerLeft,
                                        ),
                                        child: Text(
                                          'Juniper Journal',
                                          style: TextStyle(
                                            fontSize: compact ? 18 : 24,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF24543C),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (!compact)
                                    TextButton(
                                      onPressed: explore,
                                      child: const Text('Explore'),
                                    ),
                                  if (!compact) ...[
                                    TextButton(
                                      onPressed: () => navigate('/about'),
                                      child: const Text('About'),
                                    ),
                                    TextButton(
                                      onPressed: () => navigate('/support'),
                                      child: const Text('Support'),
                                    ),
                                  ] else
                                    PopupMenuButton<String>(
                                      tooltip: 'Site navigation',
                                      onSelected: navigate,
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: '/explore',
                                          child: Text('Explore'),
                                        ),
                                        PopupMenuItem(
                                          value: '/about',
                                          child: Text('About'),
                                        ),
                                        PopupMenuItem(
                                          value: '/support',
                                          child: Text('Support'),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () => navigate('/login'),
                                    child: const Text('Log In'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Offstage(
                offstage: hideHeader,
                child: const Divider(height: 1, color: Color(0xFFE8EDE8)),
              ),
              Expanded(
                child: DesktopPageScroll(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: hideHeader ? double.infinity : 1160,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
