import 'package:flutter_test/flutter_test.dart';
import 'package:juniper_journal/src/shared/widgets/evidence_media_source.dart';

void main() {
  test(
    'saved media refreshes storage URLs instead of reusing stale links',
    () async {
      expect(
        await resolveEvidenceMediaUrl(
          {
            'public_url': 'https://old.example/image',
            'storage_path': 'saved/photo.png',
          },
          bucket: 'images',
          signer: (path, bucket) async {
            expect(path, 'saved/photo.png');
            expect(bucket, 'images');
            return 'https://fresh.example/image';
          },
        ),
        'https://fresh.example/image',
      );
    },
  );
  test('legacy URL names work even when newer fields are blank', () async {
    expect(
      await resolveEvidenceMediaUrl({
        'public_url': '',
        'publicUrl': 'https://example.com/photo.png',
      }, bucket: 'images'),
      'https://example.com/photo.png',
    );
  });
  test('storage failure retains a usable direct image URL', () async {
    expect(
      await resolveEvidenceMediaUrl(
        {
          'public_url': 'https://example.com/photo.png',
          'storagePath': 'saved/photo.png',
        },
        bucket: 'images',
        signer: (_, __) async => throw StateError('unavailable'),
      ),
      'https://example.com/photo.png',
    );
  });
  test('missing media is distinct from a failed media lookup', () async {
    expect(await resolveEvidenceMediaUrl({}, bucket: 'images'), isEmpty);
    expect(
      resolveEvidenceMediaUrl(
        {'storage_path': 'photo.png'},
        bucket: 'images',
        signer: (_, __) async => throw StateError('unavailable'),
      ),
      throwsStateError,
    );
  });
}
