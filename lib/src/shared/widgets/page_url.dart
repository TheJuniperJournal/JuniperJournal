import 'dart:convert';

/// URLs contain destination identifiers only; content is loaded with current permissions.
abstract final class PageUrl {
  static String encode(Map<String, dynamic> page) {
    final kind = page['kind'];
    final project = page['project'];
    return switch (kind) {
      'explore' =>
        page['tab'] == 'communities' ? '/explore?tab=communities' : '/explore',
      'about' || 'support' || 'privacy' || 'safety' => '/$kind',
      'login' => '/login',
      'signup' => '/signup',
      'home' => Uri(
        path: '/home',
        queryParameters: {
          'section': '${page['section'] ?? 0}',
          for (final key in ['profileTab', 'exploreTab', 'subject'])
            if (page[key] != null) key: '${page[key]}',
        },
      ).toString(),
      'project' => Uri(
        path: '/projects/$project',
        queryParameters: {
          'tab': '${page['section'] ?? 0}',
          if (page['collaboration'] != null)
            'collaboration': '${page['collaboration']}',
          if (page['post'] != null) 'post': '${page['post']}',
          if (page['comment'] != null) 'comment': '${page['comment']}',
          if (page['event'] != null) 'event': '${page['event']}',
        },
      ).toString(),
      'phase' => '/projects/$project/phases/${page['phase']}',
      'journal-view' => '/projects/$project/entries/${page['entry']}',
      'community' =>
        '/communities/${page['community']}?tab=${page['tab'] ?? 'entries'}',
      'community-profile' =>
        '/communities/${page['community']}/profile${page['tab'] == 'members' ? '?tab=members' : ''}',
      'profile' => Uri(
        path: '/people/${page['user']}',
        queryParameters:
            {
              if (page['tab'] != null && page['tab'] != 0)
                'tab': '${page['tab']}',
              if (page['subject'] != null) 'subject': '${page['subject']}',
            }.isEmpty
            ? null
            : {
                if (page['tab'] != null && page['tab'] != 0)
                  'tab': '${page['tab']}',
                if (page['subject'] != null) 'subject': '${page['subject']}',
              },
      ).toString(),
      'chats' => '/messages',
      'chat' =>
        '/messages/${page['conversation']}${page['group'] == true ? '?group=true' : ''}',
      _ => Uri(
        path: '/page',
        queryParameters: {'destination': jsonEncode(page)},
      ).toString(),
    };
  }

  static Map<String, dynamic>? decode(String location) {
    try {
      final uri = Uri.parse(location);
      final p = uri.pathSegments;
      if (p.isEmpty) return null;
      if (p.first == 'explore')
        return {
          'kind': 'explore',
          if (uri.queryParameters['tab'] == 'communities') 'tab': 'communities',
        };
      if ([
        'login',
        'signup',
        'about',
        'support',
        'privacy',
        'safety',
      ].contains(p.first))
        return {'kind': p.first};
      if (p.first == 'home')
        return {
          'kind': 'home',
          'section': int.tryParse(uri.queryParameters['section'] ?? '') ?? 0,
          for (final key in ['profileTab', 'exploreTab', 'subject'])
            if (uri.queryParameters[key] != null) key: uri.queryParameters[key],
        };
      if (p.first == 'projects' && p.length >= 2) {
        if (p.length == 4 && p[2] == 'entries')
          return {'kind': 'journal-view', 'project': p[1], 'entry': p[3]};
        if (p.length == 4 && p[2] == 'phases')
          return {'kind': 'phase', 'project': p[1], 'phase': p[3]};
        if (p.length == 2)
          return {
            'kind': 'project',
            'project': p[1],
            'section': int.tryParse(uri.queryParameters['tab'] ?? '') ?? 0,
            for (final key in ['collaboration', 'post', 'comment', 'event'])
              if (uri.queryParameters[key] != null)
                key: uri.queryParameters[key],
          };
      }
      if (p.first == 'communities' && p.length >= 2)
        return {
          'kind': p.length == 3 && p[2] == 'profile'
              ? 'community-profile'
              : 'community',
          'community': p[1],
          if (p.length == 3 &&
              p[2] == 'profile' &&
              uri.queryParameters['tab'] == 'members')
            'tab': 'members',
          if (!(p.length == 3 && p[2] == 'profile'))
            'tab': int.tryParse(uri.queryParameters['tab'] ?? '') ?? 0,
        };
      if (p.first == 'people' && p.length == 2)
        return {
          'kind': 'profile',
          'user': p[1],
          if (uri.queryParameters['tab'] != null)
            'tab': int.tryParse(uri.queryParameters['tab']!) ?? 0,
          if (uri.queryParameters['subject'] != null)
            'subject': uri.queryParameters['subject'],
        };
      if (p.first == 'messages')
        return p.length == 1
            ? {'kind': 'chats'}
            : p.length == 2
            ? {
                'kind': 'chat',
                'conversation': p[1],
                if (uri.queryParameters['group'] == 'true') 'group': true,
              }
            : null;
      if (p.first == 'page')
        return Map<String, dynamic>.from(
          jsonDecode(uri.queryParameters['destination']!) as Map,
        );
    } catch (_) {}
    return null;
  }
}
