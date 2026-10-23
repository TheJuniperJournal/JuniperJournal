# Journal participants and editing

Implementation now includes Who is involved? at the end of Overview. Discovery and Ideation retain their first-stage pickers; Build and Test have a picker in Component, Technical Analysis in its first stage, and Free Notes near the top. Participant IDs are saved with entry content and preserved when member data has not finished loading. Implementation previews display saved participants.

The entry author and project owner can edit, delete and manage the participant list. Selected participants who are still accepted project members receive Edit only. Being a project member without being selected does not grant editing. New entries must first be explicitly kept/saved to the project before other participants can access them; local temporary drafts remain local.

Apply `supabase/migrations/20261022030000_journal_participant_editing.sql` to enforce participant edit permissions. It adds an update policy and a restrictive check, protects author/project identity and the participant roster, and keeps deletion restricted to the author or project owner. Run `supabase/tests/journal_participant_editing.sql` after migration in a database with a project and at least two users. The test rolls back. These SQL changes have not been applied from this workspace.

## Concurrent editing is a separate feature

Current journal autosave replaces an entry snapshot. It is not a collaborative document engine and should not be presented as safe simultaneous co-editing. Recommended next step: live editor presence, a lease for each section (e.g. “Morgan is editing Overview”), server revision checks that reject stale writes, and retaining conflicted edits locally. Different sections could be edited in parallel. Same-field simultaneous typing would require operational transforms or a CRDT, plus version history and reconnection handling.
