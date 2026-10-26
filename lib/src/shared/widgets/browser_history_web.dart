import 'package:flutter/services.dart';
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

class BrowserHistory {
  StreamSubscription<html.PopStateEvent>? _subscription;
  String get location =>
      html.window.location.hash.replaceFirst(RegExp(r'^#'), '').isEmpty
      ? '/'
      : html.window.location.hash.substring(1);
  Future<void> listen(void Function(String) onChange) async {
    await SystemNavigator.selectMultiEntryHistory();
    _subscription = html.window.onPopState.listen((_) => onChange(location));
  }

  void write(String path, {bool replace = false}) {
    if (location == path) return;
    // This host owns hash navigation; do not let Flutter's platform route
    // reporting retain the initial login route while the nested Navigator moves.
    final url =
        '${html.window.location.pathname}${html.window.location.search}#$path';
    if (replace) {
      html.window.history.replaceState(null, '', url);
    } else {
      html.window.history.pushState(null, '', url);
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
