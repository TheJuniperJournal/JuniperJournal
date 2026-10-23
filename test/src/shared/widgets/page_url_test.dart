import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/page_url.dart';

void main() {
  test('shareable destinations round trip without content or session data', () {
    for (final page in <Map<String, dynamic>>[
      {'kind': 'project', 'project': 'p', 'section': 2},
      {'kind': 'journal-view', 'project': 'p', 'entry': 'e'},
      {'kind': 'phase', 'project': 'p', 'phase': 'discover'},
      {'kind': 'community', 'community': 'c', 'tab': 1},
      {'kind': 'community-profile', 'community': 'c'},
      {'kind': 'profile', 'user': 'u'},
      {'kind': 'login'},
      {'kind': 'signup'},
      {'kind': 'explore'},
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
