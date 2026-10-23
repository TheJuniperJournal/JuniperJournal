import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const tabDuration = Duration(milliseconds: 180);
  static const pageDuration = Duration(milliseconds: 240);
  static const curve = Curves.easeInOut;
}

/// A consistent, small forward/back movement instead of platform-specific zooms.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();
  @override
  Duration get transitionDuration => AppMotion.pageDuration;
  @override
  Duration get reverseTransitionDuration => AppMotion.pageDuration;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = animation.drive(CurveTween(curve: AppMotion.curve));
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: eased.drive(
          Tween(begin: const Offset(.035, 0), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}
