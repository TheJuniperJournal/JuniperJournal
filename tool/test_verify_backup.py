import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from verify_backup import verify


class VerifyBackupTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'storage').mkdir()
        self.file = self.root / 'storage' / 'sample.bin'
        self.file.write_bytes(b'original')
        self.manifest = {
            'storage_file_count': 1, 'storage_bytes': 8,
            'files': [{'path': 'storage/sample.bin', 'bytes': 8,
                       'sha256': hashlib.sha256(b'original').hexdigest()}],
        }
        self.write_manifest()

    def write_manifest(self):
        (self.root / 'storage-manifest.json').write_text(json.dumps(self.manifest))

    def test_valid_snapshot(self):
        self.assertEqual(verify(self.root), (1, 8))

    def test_same_size_corruption_is_detected(self):
        self.file.write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            verify(self.root)

    def test_missing_file_is_detected(self):
        self.file.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            verify(self.root)

    def test_manifest_cannot_escape_storage_directory(self):
        self.manifest['files'][0]['path'] = '../outside'
        self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            verify(self.root)

    def test_extra_file_is_detected(self):
        (self.root / 'storage' / 'unlisted.bin').write_bytes(b'other')
        with self.assertRaisesRegex(ValueError, 'disagree'):
            verify(self.root)


if __name__ == '__main__':
    unittest.main()
