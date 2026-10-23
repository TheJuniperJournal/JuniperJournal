# Public community profiles

Clicking a community's photo now opens its profile for guests as well as signed-in
viewers. Owners and accepted community members keep their existing Progress and
Members views. Guests and signed-in nonmembers receive a restricted summary:

- Community admin identities only (owner plus accepted admins).
- Count of unique accepted members including the creator; pending invites excluded.
- Subject progress bars and EcoPoints based on published, completed, public journal
  entries belonging to public projects linked to the community.
- Related public projects, using the shared Explore project card and the existing
  permission-gated project dashboard.

Visitor mode never calls the full member-list repository method. The community
home header checks only the current user's membership, rather than fetching the
roster to decide whether to show workspace controls.

## Database deployment is required

`20261023030000_public_community_profile.sql` provides the summary RPC and a
restrictive member-roster SELECT policy. It uses existing membership/audience
schema prerequisites, including `user_in_project_community`. It has **not been
applied to hosted Supabase from this workspace**. Until it is deployed, opening a
visitor profile shows the existing retry/error state; it never falls back to
fetching or exposing the full roster, or claims unknown member counts are zero.

The RPC refuses private communities, whitelists administrator/profile/project
fields, and exposes counts rather than ordinary member identities. A restrictive
policy also prevents older broad SELECT policies from exposing community rosters
to anonymous users and signed-in nonmembers. Pending users can read their own
membership row; this does not expose other members.

Local tests cover guest/nonmember restricted rendering and no roster fetch, plus
preservation of owner and accepted-member behavior. An isolated PostgreSQL runtime
executed the migration and checked public/private community access, administrator
filtering, accepted-member counts, draft/private content exclusion, progress
aggregation, project whitelisting and anonymous roster denial. Hosted policies
still need deployment and testing against the live schema.
