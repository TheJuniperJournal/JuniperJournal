# Public documentation and project workspaces

ProjectDashboard resolves membership through ProjectsRepo.canViewInternalProjectLogs (owner or accepted collaborator). Caller-supplied isOwner flags do not grant access. Settings remain restricted to owners/admins through canManageProject. Pending invitations do not grant internal access.

| Viewer | Overview / Development | Collaboration directory | Timeline / forum / activity | Management |
| --- | --- | --- | --- | --- |
| Signed-out visitor | Public, completed documentation | Read-only public directory | Hidden and denied | Sign-in prompt for account actions |
| Signed-in nonmember | Content permitted by existing project audience | Read-only directory | Hidden and denied | Existing public interactions only |
| Accepted member | Existing documentation and drafts | Existing workspace sections | Retained | Existing role rules |
| Owner / admin | Existing access | Existing role controls | Retained | Existing role rules |

ExploreProjectCard is shared by Explore, the community Projects tab, and profile portfolios. Community Projects now uses ProjectBrowsePage instead of its separate card/filter implementation. PublicCommunityScreen delegates to CommunityHomeScreen; it no longer has a separate public-community layout. Community Entries reuses CommunityEntriesFeed and JournalLogEntryCard, with published entry IDs authorized at the database. JournalEntryView re-fetches its entry through the audience projection, so stale objects or direct navigation cannot display inaccessible drafts.

## Database deployment required

Apply the migrations in order, including the prerequisite public Explore migration:

- supabase/migrations/20261023000000_public_explore.sql
- supabase/migrations/20261023010000_public_project_documentation.sql

The second migration exposes project_documentation and journal_documentation as read-only, permission-filtered projections. Nonmembers receive only project documentation fields, no timeline/budget/sharing configuration, and no linked internal timeline details in journal content. Raw project and journal rows are restricted to current project participants. Public identity directory RPC returns only ID, display name, username, and avatar; it does not expose private profile fields.

Internal forum/history policies are restrictive, so a broader legacy permissive policy cannot reopen those sections. Nonmembers also cannot modify internal discussions or edit/delete journal entries. Existing role-specific write rules continue to apply to members. Public journal comments and flowers remain available to authenticated audience viewers through the redacted journal projection; guests receive authentication choices. Private/shared project audience rules and community membership checks are preserved.

Community project/entry RPCs verify the community audience as well as the project's audience, and retain explicitly shared community projects. Only completed entries populate public community feeds.

Run supabase/tests/public_project_documentation.sql and supabase/tests/project_activity_feed.sql against a migrated database with existing test users/projects. The tests roll back their changes. These database migrations and SQL tests were prepared but not applied/run from this workspace; deployment and live RLS verification are required before production rollout. The client intentionally does not fall back to unrestricted raw rows for public readers if the projection is unavailable.

## Compatibility before view deployment

If a documentation view is missing (`PGRST205` or `42P01`), personal project
details and journal reads may retry the existing tables **only for project IDs
independently verified as owned by the viewer or having their accepted membership**.
The retry is explicitly scoped to those IDs and remains subject to database RLS.
Guest and nonmember project reads never receive this fallback; permission failures
never trigger it. Mixed batches retry only verified member IDs. This keeps existing
projects usable before deployment without exposing internal documentation publicly.
Feed read failures propagate to the loading-error state instead of being presented
as an empty account. Public-view migrations are still required for public browsing.
