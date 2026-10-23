import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

void main() {
  test('text-only entries do not reserve a feed image', () {
    expect(
      journalContentImageUrls([
        {'stage': 'learning', 'reflection': 'Learned something'},
      ]),
      isEmpty,
    );
  });
  test('feed photos come from attached entry images', () {
    expect(
      journalContentImageUrls([
        {'type': 'image', 'url': 'https://example.com/photo.png'},
        {
          'type': 'Images',
          'data': {
            'images': [
              {'public_url': 'https://example.com/evidence.png'},
            ],
          },
        },
        {'type': 'image', 'url': 'https://example.com/photo.png'},
        {'type': 'image', 'url': ''},
      ]),
      ['https://example.com/photo.png', 'https://example.com/evidence.png'],
    );
  });
}
