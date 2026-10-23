#!/usr/bin/env python3
"""Create a private, dated database and file backup outside the repository.

Requires an authenticated Supabase CLI, and Docker/Podman for database exports.
No retention cleanup or production restore is performed by this program.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--storage-only', action='store_true', help='Explicitly create an incomplete, file-only backup')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    root = args.output.expanduser().resolve()
    if root.is_relative_to(repo):
        parser.error('Backups must be outside the source repository')
    cli = os.environ.get('SUPABASE_BIN', 'supabase')
    if not shutil.which(cli):
        parser.error('Supabase CLI is required')
    if not args.storage_only and not (shutil.which('docker') or shutil.which('podman')):
        parser.error('Database backup needs Docker/Podman; do not count a storage-only backup as a complete backup')
    os.umask(0o077)
    root.mkdir(mode=0o700, parents=True, exist_ok=False)

    def run(arguments, *, capture=False):
        result = subprocess.run([cli, *arguments], cwd=repo, text=True, capture_output=True)
        if result.returncode:
            # CLI diagnostics may contain connection details. Keep them private.
            (root / 'failure.log').write_text(result.stdout + result.stderr)
            raise RuntimeError('Backup failed; inspect the private failure.log. No complete manifest was written.')
        return json.loads(result.stdout) if capture else None

    query = "select coalesce(jsonb_agg(jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types)), '[]'::jsonb) as buckets from storage.buckets"
    rows = run(['db', 'query', '--project-ref', args.project_ref, query], capture=True)['rows']
    buckets = rows[0]['buckets']
    (root / 'buckets.json').write_text(json.dumps(buckets, indent=2))
    if not args.storage_only:
        for name, flags in [('roles.sql', ['--role-only']), ('schema.sql', []), ('data.sql', ['--data-only', '--use-copy'])]:
            run(['db', 'dump', '--project-ref', args.project_ref, '--file', str(root / name), *flags])
    for bucket in buckets:
        name = bucket['id']
        if '/' in name or name in ('', '.', '..'):
            raise ValueError('Unsafe bucket name')
        target = root / 'storage' / name
        target.mkdir(parents=True, mode=0o700)
        run(['storage', 'cp', '--project-ref', args.project_ref, '--recursive', '--experimental', f'ss:///{name}', str(target)])
    files = sorted(p for p in (root / 'storage').rglob('*') if p.is_file())
    manifest = {
        'created_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'project_ref': args.project_ref,
        'database_backup_complete': not args.storage_only,
        'restore_tested': False,
        'storage_file_count': len(files),
        'storage_bytes': sum(p.stat().st_size for p in files),
        'files': [{'path': str(p.relative_to(root)), 'bytes': p.stat().st_size,
                   'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files],
    }
    (root / 'storage-manifest.json').write_text(json.dumps(manifest, indent=2))
    print(f'Backup created: {root}')
    print(f"Storage: {len(files)} files. Database exported: {manifest['database_backup_complete']}. Restore test still required.")


if __name__ == '__main__':
    main()
