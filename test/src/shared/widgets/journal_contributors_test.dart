import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';

void main() {
  test(
    'contributors are selected people, deduplicated, excluding the poster',
    () {
      const entry = JournalEntry(
        id: 'entry',
        title: 'Title',
        projectId: 'project',
        authorId: 'author',
        content: [
          {
            'stage': 'observations',
            'involved': [
              {'id': 'author', 'name': 'Poster'},
              {'id': 'amelia', 'name': 'Amelia'},
            ],
          },
          {
            'stage': 'learning',
            'involved': [
              {'id': 'amelia', 'name': 'Amelia'},
              {'id': 'ricky', 'name': 'Ricky'},
            ],
          },
          {
            'projectMembers': [
              {'id': 'not-involved'},
            ],
          },
        ],
      );
      expect(entry.contributorCount, 2);
      expect(
        const JournalEntry(
          id: 'empty',
          title: '',
          projectId: '',
          content: [],
        ).contributorCount,
        0,
      );
    },
  );
}
