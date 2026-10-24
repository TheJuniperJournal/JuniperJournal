import 'package:flutter/material.dart';
import '../../features/site/pages/site_information_page.dart';
import 'desktop_page_scroll.dart';

/// The footer is a final sliver in the page's own scrollable, never fixed chrome.
class PageScrollWithFooter extends StatelessWidget {
  const PageScrollWithFooter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<SiteFooterScope>() == null ||
        context.dependOnInheritedWidgetOfExactType<_FooterScrollScope>() !=
            null ||
        ModalRoute.of(context) is PopupRoute)
      return child;
    var nested = false;
    context.visitAncestorElements((element) {
      if (element.widget is Scrollable || element.widget is DesktopSideScroll)
        nested = true;
      return !nested;
    });
    if (nested) return child;
    final scroll = child;
    if (scroll is! ScrollView && scroll is! SingleChildScrollView) return child;
    final axis = scroll is ScrollView
        ? scroll.scrollDirection
        : (scroll as SingleChildScrollView).scrollDirection;
    if (axis != Axis.vertical) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final footer = SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SiteFooter(
              key: const ValueKey('page-end-footer'),
              compact: true,
              onNavigate: (page) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SiteInformationPage(page: page),
                ),
              ),
            ),
          ),
        );
        final Widget result;
        if (scroll is ListView) {
          result = CustomScrollView(
            controller: scroll.controller,
            primary: scroll.primary,
            physics: scroll.physics,
            reverse: scroll.reverse,
            keyboardDismissBehavior: scroll.keyboardDismissBehavior,
            slivers: [
              SliverPadding(
                padding: scroll.padding ?? EdgeInsets.zero,
                sliver: SliverList(delegate: scroll.childrenDelegate),
              ),
              footer,
            ],
          );
        } else if (scroll is SingleChildScrollView) {
          result = CustomScrollView(
            controller: scroll.controller,
            primary: scroll.primary,
            physics: scroll.physics,
            reverse: scroll.reverse,
            keyboardDismissBehavior: scroll.keyboardDismissBehavior,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: scroll.padding ?? EdgeInsets.zero,
                  child: scroll.child,
                ),
              ),
              footer,
            ],
          );
        } else if (scroll is CustomScrollView) {
          result = CustomScrollView(
            controller: scroll.controller,
            primary: scroll.primary,
            physics: scroll.physics,
            reverse: scroll.reverse,
            center: scroll.center,
            anchor: scroll.anchor,
            keyboardDismissBehavior: scroll.keyboardDismissBehavior,
            slivers: [...scroll.slivers, footer],
          );
        } else {
          return child;
        }
        return _FooterScrollScope(child: result);
      },
    );
  }
}

class _FooterScrollScope extends InheritedWidget {
  const _FooterScrollScope({required super.child});
  @override
  bool updateShouldNotify(_FooterScrollScope oldWidget) => false;
}
