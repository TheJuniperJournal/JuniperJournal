import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/protected_image.dart';

void main() {
  test('private references resolve stable paths, never persisted tokens', () {
    for (final mode in ['public', 'sign', 'authenticated']) {
      expect(
        journalAttachmentPath(
          'https://example.test/storage/v1/object/$mode/journal-attachments/project/image.png?token=expired',
        ),
        'project/image.png',
      );
    }
    expect(
      journalAttachmentPath(
        'https://example.test/storage/v1/object/public/images/avatar.png',
      ),
      isNull,
    );
    expect(
      journalAttachmentPath(
        'https://example.test/journal-attachments/project/image.png',
      ),
      isNull,
    );
  });
}
