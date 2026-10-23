import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/features/project/pages/project_development_flow.dart';

void main() {
  test('feed previews support old URL aliases and storage-only images', () {
    final sources = journalContentImageUrls([
      {
        'type': 'Images',
        'data': {
          'images': [
            {'url': 'https://example.com/legacy.jpg'},
            {'storage_path': 'owner/photo.jpg'},
            {'has_placeholder_image': true},
          ],
        },
      },
      {
        'contentType': 'image/png',
        'publicUrl': 'https://example.com/context.png',
      },
    ]);
    expect(sources.length, 3);
    expect(sources.first, 'https://example.com/legacy.jpg');
    expect(sources[1], contains('owner/photo.jpg'));
    expect(sources.last, 'https://example.com/context.png');
  });
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
