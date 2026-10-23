import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/project.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/features/home_page/services/home_journal_feed.dart';

void main() {
  test(
    'Home retains older entries from the same project and excludes drafts',
    () {
      const project = Project(id: 'p', projectName: 'Project', tags: []);
      JournalEntry entry(int i, {bool complete = true}) => JournalEntry(
        id: '$i',
        projectId: 'p',
        title: 'Entry $i',
        updatedAt: DateTime(2026, 10, 23, 0, i),
        content: [
          {'stage': 'free_notes', 'submitted': complete},
          {'type': 'body', 'text': 'Notes for entry $i'},
        ],
      );
      final feed = homeJournalFeed(
        [project],
        [
          [for (var i = 0; i < 12; i++) entry(i), entry(13, complete: false)],
        ],
      );
      expect(feed.length, 12);
      expect(feed.map((row) => row.$2.id), [
        for (var i = 11; i >= 0; i--) '$i',
      ]);
      expect(feed.every((row) => row.$1.id == row.$2.projectId), isTrue);
    },
  );
}
