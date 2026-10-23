# Public Explore

Signed-out visitors land on PublicExploreScreen. The /explore route also opens it directly. Log in and Create account open standalone authentication pages; explicit sign-out continues to open the standalone login page.

Explore reuses project search, subject collections, filters, and public community search. Guest bookmarking opens login. Guests see no personal profile or navigation sidebars. Community browsing now reuses CommunityHomeScreen with Entries and Projects tabs, and the shared Explore project cards. Community chat remains limited to accepted community members. See public-project-viewing.md for the project workspace rules and required follow-up migration.

Apply supabase/migrations/20261023000000_public_explore.sql before enabling anonymous browsing in production. The migration grants read-only anonymous access to public projects, public communities, published/completed public journals, and their linked impacts. Restrictive policies exclude private projects/communities and drafts even if older permissive policies exist. It does not grant write access or expose private profiles, memberships, or chat.

The migration has been prepared locally, not deployed. Test against the target Supabase database with anonymous requests before rollout, since existing restrictive policies may further limit reads. Existing signed-in project/community workflows are retained.
