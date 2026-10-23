import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Native mobile pull-to-refresh; desktop and web use ordinary scrolling.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      return child;
    }
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}
