# Project activity time

The Time Spent card shows a participant their own active time, and other authorized viewers the sum of participant time. Viewing as a nonparticipant does not contribute to that total. This is an estimate of foreground interaction, not proof of work.

Project dashboards, phase dashboards, journal editors and journal previews share one meter per signed-in user and project. Nested editor routes inherit the project context. Counting pauses when the app is hidden/unfocused or after 90 seconds without pointer, scroll, or keyboard input. Each active second is cached locally; cumulative session totals synchronize every 15 seconds and when leaving/backgrounding the project. Absolute session totals make retries idempotent. Previous unsynchronized sessions are retried on reopening the project.

## Database setup

Apply `supabase/migrations/20261022000000_project_activity_time.sql` to the app's Supabase database using the project's normal migration process. Run `supabase/tests/project_activity_time.sql` against a database with at least one project to validate cumulative writes and anonymous write rejection; the test rolls back.

The migration has not been applied by the local web build. Until it is applied, participants can accumulate locally cached time, but cross-device persistence and combined participant totals are unavailable. Viewers see “Time tracking unavailable” instead of an invented zero. Earlier untracked activity is not backfilled.

Only accepted project participants can write time. Readers must already have access to the project. No individual participant breakdown is exposed to nonparticipant viewers.
