import '../../features/project/services/project_activity.dart';
import 'journal_draft_session.dart';
import '../../features/chat/pages/chat_screen.dart';
import '../../features/community/pages/challenge_detail_screen.dart';
import '../../features/project/pages/journal_entry_editor.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/home_page/pages/public_user_profile.dart';
import '../../features/project/pages/project_dashboard.dart';
import '../../features/project/pages/journal_entry_view.dart';
import '../../features/community/pages/community_home_screen.dart';
import '../../features/community/pages/community_profile_screen.dart';
import '../../features/community/pages/community_settings_screen.dart';

final _openPages = Expando<List<_OpenPage>>();

class _OpenPage {
  _OpenPage(this.key, this.route, this.result);
  final String key;
  final Route<dynamic> route;
  final Future<dynamic> result;
}

String _destination(Widget page, RouteSettings settings) {
  final identity = switch (page) {
    PublicUserProfilePage p => p.userId,
    ProjectDashboard p => p.projectId,
    JournalEntryView p => p.entry.id,
    JournalEntryEditorScreen p => p.entryId,
    ChatScreen p => p.conversationId,
    ChallengeDetailScreen p => p.challenge.id,
    CommunityHomeScreen p => p.community.id,
    CommunityProfileScreen p => p.community.id,
    CommunitySettingsScreen p => p.community.id,
    _ => settings.name ?? page.key?.toString() ?? '',
  };
  // Anonymous collection routes use their visible title as an identity.
  final title = page is Scaffold && page.appBar is AppBar
      ? (page.appBar as AppBar).title
      : null;
  return '${page.runtimeType}:$identity:${title is Text ? title.data : ''}';
}

/// Reuse an open destination rather than stacking it on repeated taps.
Future<T?> pushAppRoute<T extends Object?>(
  BuildContext context,
  Route<T> route, {
  NavigatorState? targetNavigator,
}) async {
  final navigator = targetNavigator ?? Navigator.of(context);
  if (route is MaterialPageRoute<T> &&
      JournalDraftGuard.isExternalNavigation(context, navigator)) {
    if (!await JournalDraftGuard.leaveCurrent(navigator) || !context.mounted)
      return null;
  }
  if (route is! MaterialPageRoute<T>) return navigator.push(route);
  final page = route.builder(context);
  final key = _destination(page, route.settings);
  final entries = _openPages[navigator] ??= [];
  for (final entry in entries) {
    if (entry.key == key && entry.route.isActive) {
      if (!entry.route.isCurrent) unawaited(_reveal(navigator, entry.route));
      return entry.result.then((value) => value as T?);
    }
  }
  final completer = Completer<T?>();
  final entry = _OpenPage(key, route, completer.future);
  entries.add(entry);
  ProjectActivity.inheritRoute(route, context);
  navigator
      .push(route)
      .then(
        (value) {
          ProjectActivity.forgetRoute(route);
          entries.remove(entry);
          completer.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          ProjectActivity.forgetRoute(route);
          entries.remove(entry);
          completer.completeError(error, stack);
        },
      );
  return completer.future;
}

Future<void> _reveal(NavigatorState navigator, Route<dynamic> target) async {
  while (navigator.mounted && target.isActive && !target.isCurrent) {
    if (!await navigator.maybePop()) return;
    await WidgetsBinding.instance.endOfFrame;
  }
}
