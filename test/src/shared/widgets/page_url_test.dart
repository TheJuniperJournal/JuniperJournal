import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/page_url.dart';

void main() {
  test('shareable destinations round trip without content or session data', () {
    for (final page in <Map<String, dynamic>>[
      {'kind': 'project', 'project': 'p', 'section': 2},
      {
        'kind': 'project',
        'project': 'p',
        'section': 2,
        'collaboration': 'members',
        'post': 'post-id',
        'comment': 'comment-id',
      },
      {'kind': 'project', 'project': 'p', 'section': 3, 'event': 'event-id'},
      {'kind': 'home', 'section': 3, 'exploreTab': 'communities'},
      {'kind': 'home', 'section': 2, 'profileTab': 'friends'},
      {'kind': 'home', 'section': 1, 'subject': 'Energy & Systems'},
      {
        'kind': 'profile',
        'user': 'u',
        'tab': 2,
        'subject': 'Engineering & Design',
      },
      {'kind': 'community-profile', 'community': 'c', 'tab': 'members'},
      {'kind': 'people-search', 'scope': 'friends'},
      {
        'kind': 'subject-projects',
        'subject': 'Energy & Systems',
        'public': true,
      },
      {
        'kind': 'journal',
        'project': 'p',
        'entry': 'e',
        'phase': 'discover',
        'step': 'analyze',
      },
      {'kind': 'chats'},
      {'kind': 'chat', 'conversation': 'c', 'group': true},
      {'kind': 'create-community'},
      {'kind': 'community-invitations', 'community': 'c'},
      {'kind': 'challenge-dashboard', 'challenge': 'c', 'tab': 1},
      {'kind': 'impact-entry', 'project': 'p', 'impact': 'i', 'readOnly': true},
      {'kind': 'journal-view', 'project': 'p', 'entry': 'e'},
      {'kind': 'phase', 'project': 'p', 'phase': 'discover'},
      {'kind': 'community', 'community': 'c', 'tab': 1},
      {'kind': 'community-profile', 'community': 'c'},
      {'kind': 'profile', 'user': 'u'},
      {'kind': 'login'},
      {'kind': 'signup'},
      {'kind': 'explore'},
      {'kind': 'explore', 'tab': 'communities'},
      {'kind': 'about'},
      {'kind': 'support'},
      {'kind': 'privacy'},
      {'kind': 'safety'},
    ]) {
      expect(PageUrl.decode(PageUrl.encode(page)), page);
    }
  });
  test('malformed and unknown routes are rejected', () {
    expect(PageUrl.decode('/projects'), isNull);
    expect(PageUrl.decode('/page?destination=invalid'), isNull);
    expect(PageUrl.decode('/unknown'), isNull);
  });
}
