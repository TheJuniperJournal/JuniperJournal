# Juniper Journal backup and restore procedure

## Coverage and current status

Database exports and uploaded files are separate backups. A Firebase deployment
or Git commit contains application code, not the live Supabase database or user
uploads. Supabase database backups contain storage metadata, not image/video
bytes: https://supabase.com/docs/guides/platform/backups.

On 2026-10-23 all 172 production storage files (155,107,163 bytes) were copied to
`/Users/benjaminyang/JuniperLaunch/backups/2026-10-23`. The SHA-256 manifest passed
verification. A single public-image restore/upload/download round trip matched
the original bytes, and its temporary object was removed. This is **not** a full
service restore. The full database export could not run because Docker/Podman is
not installed. No recurring or off-site backup job is active yet.

## Create and verify a backup

1. Install and start Docker or Podman, authenticate the Supabase CLI, and ensure
   the production database connection works. Keep credentials in the environment
   or a password manager, never source files or shell command arguments.
2. Use a new destination outside the repository:

   ```sh
   python3 tool/backup_supabase.py --project-ref mltoisbukuhkxrdvndxl \
     --output /absolute/private/backup-directory
   python3 tool/verify_backup.py /absolute/private/backup-directory
   ```

   `--storage-only` explicitly makes an incomplete backup when only files can be
   copied. An export failure prevents a completion manifest. The tool never
   deletes older snapshots. Do not count an integrity check as a restore test.

3. Keep database roles, schema, data, storage files, and bucket configuration
   together. Also retain the source commit, custom storage policies/auth triggers,
   migration history, Auth redirect/SMTP configuration, Edge Function source and
   required secret names. Recover secrets from the password manager. Managed
   backup/restore has additional encryption-key considerations for Supabase Vault;
   follow the current official procedure before restoring.

## Restore rehearsal: isolated target only

Never test restoration over production. Create a new test Supabase project or a
local stack. Keep outbound email disabled/captured; use synthetic accounts for
regular staging rather than copied production identities or youth data.

Follow the current Supabase procedure for restoring roles/schema/data into that
empty target: https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore.
Reapply custom storage RLS policies and Auth triggers separately, recreate bucket
settings, and upload every file at its original bucket/path using the Storage API.
Do not insert/delete physical file metadata directly with SQL.

Download restored files from the test target and compare every SHA-256 checksum.
Verify table counts, ownership, private/public access, login, project/journal
reads, and representative photo/video playback. URLs and email redirects need
the test project's origin. Record the target, source snapshot, completion time,
checksums/counts, issues, and recovery time. A successful `pg_dump`, upload, or
checksum scan alone does not establish that the app can be recovered.

## Ongoing backups to activate

Recommended starting policy: daily backups, 7 daily and 4 weekly restore points,
monthly isolated restore rehearsal, and a quarterly complete drill. Confirm this
retention matches the published deletion/retention policy before activation.
Make the retention job prune only after a newer backup has passed verification.

Keep one local copy and an independently owned cloud copy. Backblaze B2 is a
reasonable small-project destination; its published pay-as-you-go storage rate
starts at $6.95/TB/month as checked on 2026-10-23:
https://www.backblaze.com/cloud-storage/pricing. Transfer and Supabase egress
charges depend on usage. No paid account, bucket, or subscription was created.

Use a private bucket, client-side encryption, a narrowly scoped backup key,
account MFA, and a separate recovery copy of the encryption key. A shared public
Drive folder is not an appropriate backup destination. The local snapshot is
access-restricted. An encrypted `age` archive was subsequently created at
`/Users/benjaminyang/JuniperLaunch/backups/2026-10-23-storage.tar.gz.age` and fully
decrypted into a temporary folder: all 172 SHA-256 checksums passed. The recovery
key is outside the backup folder at
`/Users/benjaminyang/JuniperLaunch/recovery-keys/juniper-backups-age.key`; it is
not committed or printed. The owner still needs to import it into a password
manager and keep a separate recovery copy before any raw working copy/key file
is removed. The original working snapshot remains access-restricted plaintext,
and FileVault was off when checked. Only the encrypted archive should be sent
off-site. If this Mac is the scheduler, backups stop while it is
asleep/offline. Prefer an independent runner with failure alerts for production.
