import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/backend/db/models/journal_entry.dart';
import 'package:juniper_journal/src/backend/db/repositories/projects_repo.dart';
import 'package:juniper_journal/src/shared/widgets/journal_entry_title.dart';

class _Repo extends ProjectsRepo {
  @override
  Future<List<JournalEntry>?> getJournalEntries({
    required String projectId,
  }) async => const [
    JournalEntry(
      id: 'a',
      projectId: 'p',
      title: 'Custom title',
      progress: 'ideating',
      content: [],
    ),
    JournalEntry(
      id: 'b',
      projectId: 'p',
      title: 'Different phase',
      progress: 'discover',
      content: [],
    ),
  ];
}

void main() {
  test('custom titles are kept in full; empty titles use phase numbering', () {
    expect(
      journalEntryTitle('  A longer descriptive title  ', 2, 'ideating'),
      'A longer descriptive title',
    );
    expect(journalEntryTitle('', 2, 'ideating'), 'Entry 2: Ideation');
    expect(journalEntryTitle(' ', 3, 'prototyping'), 'Entry 3: Prototyping');
  });
  test(
    'numbering is scoped to phase and preserves existing entry numbers',
    () async {
      expect(await journalEntryNumber(_Repo(), 'p', 'Ideation', null), 2);
      expect(await journalEntryNumber(_Repo(), 'p', 'Implementation', null), 1);
      expect(
        await journalEntryNumber(
          _Repo(),
          'p',
          'Ideation',
          const JournalEntry(
            id: 'c',
            projectId: 'p',
            title: 'Entry 7: Ideation',
            content: [],
          ),
        ),
        7,
      );
    },
  );
}
