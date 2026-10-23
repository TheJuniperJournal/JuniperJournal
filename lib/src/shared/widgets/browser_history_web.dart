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
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(path),
      replace: replace,
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
