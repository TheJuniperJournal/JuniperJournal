#!/usr/bin/env python3
"""Verify an offline storage snapshot without opening or uploading user content."""
import argparse
import hashlib
import json
from pathlib import Path


def verify(root):
    root = Path(root).resolve()
    manifest = json.loads((root / 'storage-manifest.json').read_text())
    files = manifest['files']
    if len(files) != manifest['storage_file_count']:
        raise ValueError('Manifest file count does not match')
    seen = set()
    total = 0
    for entry in files:
        path = (root / entry['path']).resolve()
        if not path.is_relative_to(root / 'storage') or path in seen:
            raise ValueError('Unsafe or duplicate manifest path')
        seen.add(path)
        if not path.is_file() or path.stat().st_size != entry['bytes']:
            raise ValueError('Missing or truncated backup file')
        digest = hashlib.sha256()
        with path.open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                digest.update(block)
        if digest.hexdigest() != entry['sha256']:
            raise ValueError('Backup checksum mismatch')
        total += entry['bytes']
    if total != manifest['storage_bytes']:
        raise ValueError('Manifest byte count does not match')
    actual = {p.resolve() for p in (root / 'storage').rglob('*') if p.is_file()}
    if actual != seen:
        raise ValueError('Storage directory and manifest disagree')
    return len(files), total


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory')
    args = parser.parse_args()
    count, size = verify(args.directory)
    print(f'Verified {count} storage files ({size} bytes).')
    print('This checks file integrity; it does not prove a database or service restore.')
