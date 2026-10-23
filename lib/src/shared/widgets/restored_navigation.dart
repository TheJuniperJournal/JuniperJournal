import 'package:flutter/material.dart';

/// A restored detail page keeps its parent underneath it, just as normal
/// navigation does, so closing the page cannot empty the navigator.
List<Route<dynamic>> restoredNavigationStack({
  required Widget home,
  required Widget restored,
}) => [
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/'),
    builder: (_) => home,
  ),
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: '/restored'),
    builder: (_) => restored,
  ),
];
