import '../../features/site/pages/site_information_page.dart';
import 'eco_reward_notice_host.dart' show ecoRewardNavigatorKey;
import 'page_refresh_state.dart';
import 'app_navigation.dart';
import 'desktop_content_width.dart';
import 'desktop_page_scroll.dart';
import 'persistent_desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styling/app_colors.dart';
import '../styling/app_typography.dart';

/// One set of screens, with navigation adapted to the available window width.
class AdaptiveAppShell extends StatefulWidget {
  const AdaptiveAppShell({
    super.key,
    required this.body,
    required this.mobileNavigation,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCreate,
    this.desktopSidebar,
    this.hostFrame = false,
    this.showCreate = true,
  });
  static const desktopBreakpoint = 1000.0;
  final Widget body, mobileNavigation;
  final Widget? desktopSidebar;
  final bool hostFrame;
  final bool showCreate;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  @override
  State<AdaptiveAppShell> createState() => _AdaptiveAppShellState();
}

class _AdaptiveAppShellState extends State<AdaptiveAppShell> {
  final _bodyKey = GlobalKey();
  Widget get mobileNavigation => widget.mobileNavigation;
  int get selectedIndex => widget.selectedIndex;
  ValueChanged<int> get onSelect => widget.onSelect;
  VoidCallback get onCreate => widget.onCreate;
  static const _sections = [0, 3, 1, 2];

  void _openInformation(String page) {
    if (PageRefreshState.currentDestination?['kind'] == page) return;
    final nav = ecoRewardNavigatorKey.currentState ?? Navigator.of(context);
    pushAppRoute(
      nav.overlay!.context,
      MaterialPageRoute(
        settings: RouteSettings(name: '/$page'),
        builder: (_) => SiteInformationPage(page: page),
      ),
      targetNavigator: nav,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final host = DesktopShellScope.of(context);
      final desktop =
          (host != null && !widget.hostFrame
              ? MediaQuery.sizeOf(context).width
              : constraints.maxWidth) >=
          AdaptiveAppShell.desktopBreakpoint;
      if (!widget.hostFrame && host != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) host.configure(widget);
        });
      }
      final body = KeyedSubtree(key: _bodyKey, child: widget.body);
      if (!widget.hostFrame && host != null && desktop) return body;
      if (widget.hostFrame && !desktop) return body;
      final content = desktop
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    key: const ValueKey('desktop-three-columns'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 280,
                        child: SafeArea(
                          child: NavigationRail(
                            key: const ValueKey('desktop-navigation'),
                            extended: true,
                            minExtendedWidth: 224,
                            backgroundColor: AppColors.white,
                            selectedIndex:
                                selectedIndex == 2 || selectedIndex < 0
                                ? null
                                : [0, 3, 1].indexOf(selectedIndex),
                            onDestinationSelected: (index) =>
                                onSelect(_sections[index]),
                            leading: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                24,
                                12,
                                24,
                              ),
                              child: Column(
                                children: [
                                  TextButton(
                                    onPressed: () => _openInformation('about'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.textPrimary,
                                    ),
                                    child: const Text(
                                      'Juniper Journal',
                                      style: AppTypography.sectionTitle,
                                    ),
                                  ),
                                  if (widget.showCreate)
                                    const SizedBox(height: 24),
                                  if (widget.showCreate)
                                    SizedBox(
                                      width: 188,
                                      height: 44,
                                      child: FilledButton.icon(
                                        onPressed: onCreate,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Create'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home),
                                label: Text('Home'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.landscape_outlined),
                                selectedIcon: Icon(Icons.landscape),
                                label: Text('Explore'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.article_outlined),
                                selectedIcon: Icon(Icons.article),
                                label: Text('Journal Library'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, pageConstraints) =>
                              DesktopContentWidth(
                                width: pageConstraints.maxWidth,
                                child: Semantics(container: true, child: body),
                              ),
                        ),
                      ),
                      if (widget.desktopSidebar != null) ...[
                        const SizedBox(width: 24),
                        SizedBox(width: 280, child: widget.desktopSidebar),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : body;
      return CallbackShortcuts(
        bindings: {
          for (var i = 0; i < _sections.length; i++)
            SingleActivator(
              [
                LogicalKeyboardKey.digit1,
                LogicalKeyboardKey.digit2,
                LogicalKeyboardKey.digit3,
                LogicalKeyboardKey.digit4,
              ][i],
              alt: true,
            ): () =>
                onSelect(_sections[i]),
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          extendBody: !desktop,
          bottomNavigationBar: desktop ? null : mobileNavigation,
          body: desktop ? DesktopPageScroll(child: content) : content,
        ),
      );
    },
  );
}
