import 'dart:convert';

/// URLs contain destination identifiers only; content is loaded with current permissions.
abstract final class PageUrl {
  static String encode(Map<String, dynamic> page) {
    final kind = page['kind'];
    final project = page['project'];
    return switch (kind) {
      'explore' => '/explore',
      'about' || 'support' || 'privacy' || 'safety' => '/$kind',
      'login' => '/login',
      'signup' => '/signup',
      'home' => '/home?section=${page['section'] ?? 0}',
      'project' => '/projects/$project?tab=${page['section'] ?? 0}',
      'phase' => '/projects/$project/phases/${page['phase']}',
      'journal-view' => '/projects/$project/entries/${page['entry']}',
      'community' =>
        '/communities/${page['community']}?tab=${page['tab'] ?? 'entries'}',
      'community-profile' => '/communities/${page['community']}/profile',
      'profile' => '/people/${page['user']}',
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
      if ([
        'explore',
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
          };
      }
      if (p.first == 'communities' && p.length >= 2)
        return {
          'kind': p.length == 3 && p[2] == 'profile'
              ? 'community-profile'
              : 'community',
          'community': p[1],
          if (!(p.length == 3 && p[2] == 'profile'))
            'tab': int.tryParse(uri.queryParameters['tab'] ?? '') ?? 0,
        };
      if (p.first == 'people' && p.length == 2)
        return {'kind': 'profile', 'user': p[1]};
      if (p.first == 'page')
        return Map<String, dynamic>.from(
          jsonDecode(uri.queryParameters['destination']!) as Map,
        );
    } catch (_) {}
    return null;
  }
}
