@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/journal_browser_storage.dart';

void main() {
  test(
    'large journal snapshots persist beyond preference storage size',
    () async {
      final key =
          'journal-storage-test-${DateTime.now().microsecondsSinceEpoch}';
      final large = List.filled(6 * 1024 * 1024, 'x').join();
      await JournalBrowserStorage.write(key, large);
      expect((await JournalBrowserStorage.read(key))?.length, large.length);
      await JournalBrowserStorage.write(key, 'test completed');
    },
  );
}
