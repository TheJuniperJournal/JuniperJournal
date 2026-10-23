import 'journal_navigation.dart';
import 'journal_draft_session.dart';
import 'package:flutter/material.dart';

/// Published entries refresh the existing authenticated Home without touching drafts.
abstract final class JournalPublication {
  static VoidCallback? onPublished;
  static Future<void> returnHome(BuildContext context) async {
    // Let the saved/published state reach exit guards before popping routes.
    await JournalDraftGuard.allowPublished(context);
    if (!context.mounted) return;
    final handler = onPublished;
    if (handler != null) {
      handler();
    } else {
      exitJournalRoute(context, result: true);
    }
  }
}
