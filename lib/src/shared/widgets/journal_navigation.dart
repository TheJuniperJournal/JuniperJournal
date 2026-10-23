import 'package:flutter/material.dart';
import '../../features/home_page/pages/home.dart';

/// Deep links can make an editor the only route. Never pop the last page.
void exitJournalRoute(
  BuildContext context, {
  Object? result,
  Widget? fallback,
}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop(result);
  } else {
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            fallback ?? const HomeShellScreen(restoreJournal: false),
      ),
      result: result,
    );
  }
}
