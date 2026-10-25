import 'restored_navigation.dart';
import '../../features/site/pages/site_information_page.dart';
import '../../features/home_page/pages/landing.dart';
import '../../features/home_page/pages/public_community.dart';
import '../../features/home_page/pages/public_explore.dart';
import '../../features/home_page/pages/login.dart';
import '../../features/home_page/pages/signup.dart';
import '../../features/chat/pages/chat_screen.dart';
import '../../features/chat/pages/chats_list_screen.dart';
import '../../features/home_page/pages/public_user_profile.dart';
import '../../features/community/pages/community_home_screen.dart';
import '../../features/community/pages/community_profile_screen.dart';
import '../../features/community/pages/community_settings_screen.dart';
import '../../backend/db/repositories/communities_repo.dart';
import '../../features/project/pages/materials_cost.dart';
import '../../features/project/pages/impact_log.dart';
import '../../features/project/pages/project_settings.dart';
import '../../features/project/widgets/project_activity_feed.dart';
import '../../features/project/pages/journal_entry_editor.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../backend/db/repositories/projects_repo.dart';
import '../../features/home_page/pages/home.dart';
import '../../features/home_page/pages/settings.dart';
import '../../features/project/pages/project_dashboard.dart';
import '../../features/project/pages/project_development_flow.dart';
import '../../features/project/pages/create_project.dart';
import '../../features/project/pages/journal_entry_view.dart';
import 'journal_draft_session.dart';

/// Lightweight, account-scoped navigation state. Journal content lives separately.
class PageRefreshState extends NavigatorObserver {
  static final instance = PageRefreshState();
  static Map<String, dynamic>? currentDestination;
  static final destinationKind = ValueNotifier<String?>(null);
  static void _setCurrent(Map<String, dynamic> page) {
    currentDestination = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kind = currentDestination?['kind'] as String?;
      if (destinationKind.value != kind) destinationKind.value = kind;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void Function(Map<String, dynamic>)? onDestinationChanged;
  static final _pages = <Route<dynamic>, Map<String, dynamic>>{};
  static String? _last;
  static String get _key {
    String? user;
    try {
      user = ProjectsRepo().currentUserId;
    } catch (_) {}
    return 'last-page-v1-${user ?? 'local'}';
  }

  static Future<Map<String, dynamic>?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static void remember(BuildContext context, Map<String, dynamic> page) {
    final route = ModalRoute.of(context);
    if (route == null) return;
    _pages[route] = page;
    if (route.isCurrent) {
      _setCurrent(page);
      _save(page);
      onDestinationChanged?.call(page);
    }
  }

  static Future<void> _writes = Future.value();
  static void _save(Map<String, dynamic> page) {
    final encoded = jsonEncode(page), key = _key;
    if (_last == '$key:$encoded') return;
    _last = '$key:$encoded';
    _writes = _writes
        .then((_) async {
          await (await SharedPreferences.getInstance()).setString(key, encoded);
        })
        .catchError((Object _) {});
  }

  Map<String, dynamic>? describeRoute(Route<dynamic>? route) {
    if (route == null) return null;
    if (_pages.containsKey(route)) return _pages[route];
    if (navigator == null) return null;
    final Widget page;
    if (route is RestoredDetailRoute) {
      page = route.page;
    } else if (route is MaterialPageRoute) {
      page = route.builder(navigator!.context);
    } else {
      return null;
    }
    final data = switch (page) {
      PublicExploreScreen _ => {'kind': 'explore'},
      SiteInformationPage p => {'kind': p.page},
      PublicCommunityScreen p => {
        'kind': 'community',
        'community': p.community.id,
        'tab': 0,
      },
      LoginScreen _ => {'kind': 'login'},
      JuniperAuthScreen _ => {'kind': 'login'},
      SignupScreen _ => {'kind': 'signup'},
      HomeShellScreen p => {'kind': 'home', 'section': p.initialSection},
      ProjectDashboard p => {
        'kind': 'project',
        'project': p.projectId,
        'section': p.initialSection.index,
      },
      DiscoveryDashboardPage p => {
        'kind': 'phase',
        'project': p.projectId,
        'phase': 'discover',
      },
      IdeatingDashboardPage p => {
        'kind': 'phase',
        'project': p.projectId,
        'phase': 'ideating',
      },
      PrototypingDashboardPage p => {
        'kind': 'phase',
        'project': p.projectId,
        'phase': 'prototyping',
      },
      ImplementationDashboardPage p => {
        'kind': 'phase',
        'project': p.projectId,
        'phase': 'implementation',
      },
      CreateProjectScreen p => {
        'kind': p.existingProject == null ? 'create' : 'project-settings',
        'project': p.existingProject?.id,
      },
      SettingsScreen _ => {'kind': 'settings'},
      ChatsListScreen _ => {'kind': 'chats'},
      ChatScreen p => {
        'kind': 'chat',
        'conversation': p.conversationId,
        'name': p.otherUserName,
        'avatar': p.otherAvatarUrl,
        'group': p.isGroup,
      },
      PublicUserProfilePage p => {'kind': 'profile', 'user': p.userId},
      CommunityHomeScreen p => {
        'kind': 'community',
        'community': p.community.id,
        'tab': p.initialTab,
      },
      CommunityProfileScreen p => {
        'kind': 'community-profile',
        'community': p.community.id,
      },
      CommunitySettingsScreen p => {
        'kind': 'community-settings',
        'community': p.community.id,
      },
      MaterialsCostPage p => {'kind': 'materials', 'project': p.projectId},
      ImpactLogScreen p => {'kind': 'impact', 'project': p.projectId},
      ProjectSettingsScreen p => {
        'kind': 'legacy-project-settings',
        'project': p.projectId,
      },
      ProjectActivityHistory p => {'kind': 'activity', 'project': p.projectId},
      JournalEntryView p => {
        'kind': 'journal-view',
        'project': p.project.id,
        'entry': p.entry.id,
      },
      JournalEntryEditorScreen p => {
        'kind': 'journal',
        'project': p.projectId,
        'phase': p.initialProgress,
        'freeNotes': p.freeNotes,
        'entry': p.entryId,
      },
      _ => null,
    };
    if (data != null) _pages[route] = data;
    return data;
  }

  void _record(Route<dynamic>? route) {
    final data = describeRoute(route);
    if (data != null) {
      _setCurrent(data);
      _save(data);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _record(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      _pages.remove(route);
      _record(previousRoute);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _pages.remove(oldRoute);
    _record(newRoute);
  }

  static Future<Widget?> restore(
    Map<String, dynamic>? page,
    ProjectsRepo repo,
  ) async {
    if (page == null) return null;
    final kind = page['kind'];
    if (sitePageTitles.containsKey(kind))
      return SiteInformationPage(page: kind as String);
    if (kind == 'explore') return const PublicExploreScreen();
    if (kind == 'login') return const LoginScreen();
    if (kind == 'signup') return const SignupScreen();
    if (kind == 'home')
      return HomeShellScreen(
        initialSection: (page['section'] as int? ?? 0).clamp(0, 3),
        restoreJournal: false,
      );
    if (kind == 'create') return const CreateProjectScreen();
    if (kind == 'settings') return const SettingsScreen();
    if (kind == 'chats') return const ChatsListScreen();
    if (kind == 'chat')
      return ChatScreen(
        conversationId: page['conversation'] as String,
        otherUserName: page['name'] as String? ?? 'Messages',
        otherAvatarUrl: page['avatar'] as String?,
        isGroup: page['group'] == true,
      );
    if (kind == 'profile')
      return PublicUserProfilePage(userId: page['user'] as String);
    if ((kind as String).startsWith('community')) {
      final community = await CommunitiesRepo().getCommunityById(
        page['community'] as String,
      );
      if (community == null) return null;
      if (kind == 'community-settings')
        return CommunitySettingsScreen(community: community);
      if (kind == 'community-profile')
        return CommunityProfileScreen(community: community);
      return CommunityHomeScreen(
        community: community,
        initialTab: page['tab'] as int? ?? 0,
      );
    }
    final id = page['project'] as String?;
    if (id == null) return null;
    final project = await repo.getProjectById(id);
    if (project == null) return null;
    final owner = await repo.canManageProject(id);
    if (kind == 'materials')
      return MaterialsCostPage(
        projectId: id,
        projectName: project.projectName,
        tags: project.tags,
        isOwner: owner,
        projectsRepo: repo,
      );
    if (kind == 'impact')
      return ImpactLogScreen(
        projectId: id,
        projectName: project.projectName,
        isOwner: owner,
      );
    if (kind == 'legacy-project-settings')
      return ProjectSettingsScreen(projectId: id, projectsRepo: repo);
    if (kind == 'activity')
      return ProjectActivityHistory(
        projectId: id,
        repo: repo,
        fallback: const [],
      );
    if (kind == 'project-settings')
      return CreateProjectScreen(existingProject: project);
    if (kind == 'phase')
      return switch (page['phase']) {
        'discover' => DiscoveryDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        'ideating' => IdeatingDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        'prototyping' => PrototypingDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
        _ => ImplementationDashboardPage(
          projectId: id,
          projectsRepo: repo,
          isOwner: owner,
        ),
      };
    if (kind == 'journal' || kind == 'journal-view') {
      var entry = kind == 'journal'
          ? await JournalDraftSession.interruptedEntry(repo)
          : null;
      if (entry?.projectId != id ||
          (page['entry'] != null && entry?.id != page['entry']))
        entry = null;
      if (entry == null && page['entry'] != null) {
        final entries = await repo.getJournalEntries(projectId: id);
        for (final item in entries ?? []) {
          if (item.id == page['entry']) entry = item;
        }
      }
      if (entry != null && entry.projectId == id)
        return kind == 'journal-view'
            ? JournalEntryView(
                entry: entry,
                project: project,
                projectsRepo: repo,
              )
            : editableJournalEntryPage(entry, project, repo);
      // Empty editors have no saved content and may be inspected without creating a draft.
      if (kind == 'journal' && page['freeNotes'] == true)
        return JournalEntryEditorScreen(
          projectId: id,
          projectName: project.projectName,
          tags: project.tags,
          entryId: '',
          initialTitle: '',
          initialContent: const [],
          initialProgress: page['phase'] as String?,
          freeNotes: true,
          projectsRepo: repo,
        );
      if (kind == 'journal')
        return switch (page['phase']) {
          'discover' => DiscoveryObservationEntryPage(
            projectId: id,
            projectsRepo: repo,
          ),
          'ideating' => IdeatingEntryPage(projectId: id, projectsRepo: repo),
          'implementation' => ImplementationEntryPage(
            projectId: id,
            projectsRepo: repo,
          ),
          _ => restoreEmptyPrototypingPage(
            id,
            repo,
            page['prototypeType'] as String?,
          ),
        };
    }
    if (kind == 'journal-view') return null;
    return ProjectDashboard(
      projectId: id,
      projectName: project.projectName,
      tags: project.tags,
      projectsRepo: repo,
      isOwner: owner,
      initialSection: ProjectDashboardSection
          .values[(page['section'] as int? ?? 0).clamp(0, 3)],
    );
  }
}

/// Completed entries reopen from the beginning; drafts resume their furthest visit.
int restoredJournalStage(
  List<dynamic> content,
  int length, {
  bool completed = false,
}) {
  if (completed || length <= 1) return 0;
  var furthest = 0;
  for (final row in content.whereType<Map>()) {
    if (row['stage'] != '_navigation') continue;
    final indices = [
      if (row['currentStage'] is int) row['currentStage'] as int,
      if (row['visitedStages'] is List)
        ...(row['visitedStages'] as List).whereType<int>(),
    ];
    for (final index in indices) {
      final bounded = index.clamp(0, length - 1);
      if (bounded > furthest) furthest = bounded;
    }
  }
  return furthest;
}
