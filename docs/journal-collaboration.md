# Journal collaboration: initial implementation

Status: implemented behind `JOURNAL_COLLABORATION_ENABLED`; **off by default**.
The hosted database migration has not been deployed from this workspace.

## Current behavior

- New entries remain local until the user explicitly keeps a draft or completes it.
  Looking around stages still does not create a shared entry.
- Saved entries have a roster of current editors, with names, avatars and stages.
  Presence refreshes every three seconds. It is polling, not streaming cursors.
- Guided entries have one editor per stage; other editors can use the stage picker
  above the editor to choose another stage. Prototype work (component/build/test/
  materials) shares one lease, because it currently shares one persistence object.
- Database row locking serializes acquisition. Leases last 20 seconds and are
  renewed by heartbeat; the client stops writing after connection loss.
- Different guided stages merge on save. Existing controls do not hydrate remote
  guided state automatically: **Load latest changes** saves first, then reopens
  the authorized entry with the latest data.
- Free Notes automatically receives acknowledged snapshots when no local edit or
  IME composition is pending. Blocks have stable IDs. Text in separate blocks and
  disjoint text edits can merge. Concurrent insertions are ordered by server save.
- This is not a CRDT editor. Overlapping text replacements, unkeyed collections,
  and delete-vs-edit conflicts reject the save and preserve the local snapshot.
  **Review my changes** offers copying local data or explicitly using the saved
  version. No silent last-writer-wins fallback exists.
- No mouse pointers, remote selection rendering or per-character cursors yet.
  These need a proper text operation/CRDT layer before claiming Docs-style editing.
- Entry author/project owner/selected accepted participant authorization is checked
  on every RPC. Presence does not grant permission. A participant removed during a
  session loses access on the next RPC. Public viewers receive no editor presence.

## Deployment

Apply prerequisite migrations in order, including participant editing and public
project documentation, then `20261023020000_journal_collaboration.sql`.
Run `supabase/tests/journal_collaboration.sql` and permission tests against the
actual Supabase schema. Build with:

```
JUNIPER_PREVIEW_CACHE_BUST=1 FLUTTER_BIN=/path/to/flutter ./tool/build_web.sh --no-pub --no-wasm-dry-run --dart-define=JOURNAL_COLLABORATION_ENABLED=true
```

Do not enable the switch before deploying the migration. Missing RPCs deliberately
stop collaborative writes; they never fall back to unsafe whole-entry updates.
The switch does not create a new public page or expose draft content.

## Testing together

1. Use a disposable project and a saved draft. Sign in as its owner in one browser
   and as a separate test account in a private window or another browser.
2. Add the test account as an accepted project member and select that person in
   the entry's participants. Reopen the same entry in both sessions.
3. Confirm both avatars appear. Open the same guided stage: one editor should be
   read-only. Select a different stage using the collaboration picker: both can
   work. Save, then load latest; confirm neither stage lost work.
4. For Free Notes, type in different blocks, then at different positions in the
   same block. Confirm updates arrive within a few seconds. Deliberately replace
   the same words: confirm a conflict preserves local text and offers review.
5. Disconnect one browser, wait 20 seconds, and confirm its stage becomes
   available. Reconnect: it must reacquire before saving. Repeat with two tabs of
   the same account; they still have separate lease identities.
6. Confirm a nonparticipant cannot call heartbeat/save or query session rows.
   Check refresh recovery, empty browsing, draft exit, completion and public feeds.

Codex can operate the separate test browser session while the human uses their
own browser, after the human signs that session into a test account. Passwords
need not be shared in chat. Production entries should not be used for this test.

## Validation performed locally

Service tests cover UUID identities, lock denial, disconnect/reconnect, stale-base
protection and selection adjustment. Existing draft-exit and participant tests run
alongside them. An isolated PostgreSQL-compatible runtime executed the migration
and exercised real SQL transactions for leases, separate-stage saves, merge
conflicts, anonymous denial and legacy overwrite protection. Its authorization
helpers were stubs: it does not establish that deployed Supabase RLS is correct.
The repository SQL assertions cover pure merging and grants; actual hosted
role/permission testing and a two-browser UI test remain deployment steps.
