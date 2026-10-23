# Project activity feed

Recent Activity displays the three newest authorized events. View more activity opens a dedicated history, loading 15 events at a time. Each row identifies the actor, action and timestamp. Rows open the related journal entry, timeline event, materials log, impact log, member directory or forum post.

Apply `supabase/migrations/20261022010000_project_activity_feed.sql` through the normal Supabase migration process. The local web build does not apply this migration. It extends existing notification triggers with a shared project history, rather than repurposing recipient notifications. It also records saved drafts, journal comments/flowers and impact changes. Repeated edits to the same item by the same person are grouped over five minutes. Autosaves with unchanged content and automatic EcoPoint counter changes are ignored.

Activity is read-only for clients. Internal events require project participation; journal activity follows current journal access, with drafts restricted to authorized participants/authors. Deleted journal entries remove their linked activity records. Nonparticipants never receive internal materials, forum or membership activity.

Existing journal entries seed the history once. Past edits and comments cannot be reconstructed. Until the migration is applied, the UI shows snapshots from accessible existing journal entries, not fabricated historical events. No local click logs are used as a substitute for shared history.

Validation: `test/src/features/project/widgets/project_activity_feed_test.dart` covers the compact feed, pagination, selecting an event, empty state and legacy fallback. `supabase/tests/project_activity_feed.sql` validates grouping and access restrictions in a transaction that rolls back; run it against a database containing a project after applying the migration.
