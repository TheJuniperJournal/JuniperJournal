# Wider-launch readiness — 2026-10-23

**Overall: not yet signed off for a larger audience, especially school/youth use.**
This is a tested progress record, not a statement that every launch item passed.
No paid account or subscription was created or upgraded.

## Checklist status

| Area | Result | Evidence / remaining work |
| --- | --- | --- |
| Signup and confirmation email | Passed for two controlled accounts | User confirmed both Gmail-alias emails; both accounts then signed in through Auth. This does not prove delivery to unrelated domains or production SMTP capacity. |
| Login/logout | Passed through live API | Both logins, both logouts, and rejection of both revoked refresh tokens passed. Browser-specific session handling still needs device checks. |
| Project/journal saving | Passed through live API | Created a private project and journal and cleaned them up. Fixed an owner INSERT/RETURNING RLS failure. |
| Upload ownership and private attachments | Passed through live API | Owner image upload, other-user overwrite/delete denial, private attachment access for owner, and denial for outsider/anonymous all passed. Fixed public image write policies and private attachment cleanup. |
| Collaboration | Passed through live API | Invitation stays pending without access; invitee receives it, accepts it, and then can read the project. No real users were invited. |
| Private project/journal data | Targeted checks passed | Outsider could not read/edit private rows. Public documentation redaction, participant access, and anonymous collaboration-RPC permissions passed rollback SQL checks. |
| Private inline images | **Open blocker** | Some journal/learning image editors still upload to the public `images` bucket. A private row does not make its public media URL private. Move private media to authorized storage and migrate references without breaking public avatars/workshop images. Do not treat all private photos as protected yet. |
| Password recovery | Implemented; live end-to-end test pending | Added Forgot Password, email request, new-password screen, current-origin redirect, and verified recovery-event routing. Unverified callbacks cannot update a cached account. User has been asked to complete the real email/reset/login test. |
| Account/data deletion | Representative live case passed | Initially failed on projects_user_id_fkey. Updated cleanup, required Storage API deletion first, and removed disposable Account B with a project, journal, and image. Subsequent sign-in failed as expected. SQL rollback also verified profile/project deletion and refusal to orphan files. Broader combinations of owned learning modules/challenges/shared content still need isolated fixtures. |
| Phone/tablet/desktop | Partial | Responsive/widget tests exercised narrow and wide layouts: selected run had 30 passes and 1 existing failure. Actual Safari/Chrome/Firefox and physical iOS/Android/tablet checks are not signed off. Browser automation timed out. |
| File backup and restore | Local file portion passed | All 172 files / 155,107,163 bytes copied, hashed, encrypted with age, decrypted, and reverified. A sample public-image upload/download restore also matched and was removed. |
| Database backup and full restore | **Blocked** | Supabase export needs Docker/Podman, which is absent. No complete database export or database+files service restore has been demonstrated. |
| Recurring/off-site backups | **Not activated** | Backup tooling and retention/restore procedure prepared. Independent private destination, encryption-key recovery, scheduler and failure alerts remain. |
| Administrator MFA | Owner action required | Not enabled or verified by this task. The GitHub API returned no MFA status; do not infer enabled/disabled. Authenticator enrollment and recovery-code custody belong to the owner. |
| Privacy, safety and moderation | Reviewed; operational work open | See review below. Public policy wording alone does not establish consent, reporting operations, or school compliance. |
| Separate staging | Prepared, not active | Staging deploy guard rejects production. A separately provisioned backend, clean baseline, synthetic data and working staging URL still need setup. Existing preview/old app connects to production. |

## Verification totals and limits

- Live two-account API run: **26/26** checks, including fixture cleanup. These
  exercised production APIs with dedicated accounts, not every visible UI path.
- Live disposable account-deletion run: **8/8** checks, including upload cleanup,
  refusal to delete with owned uploads remaining, account deletion and failed
  subsequent login. Only QA Account B was deleted. QA Account A remains for
  password recovery testing.
- Targeted database recheck: **6/6** (creation, collaboration RPCs, participant
  editing, public/private projections, storage ownership, project deletion), plus
  the updated account-deletion rollback check passed after deployment.
- New account-storage/recovery/navigation/auth tests: **8/8** passed. Backup
  verifier tests: **5/5**, including corruption, missing/extra files and traversal.
- Final full Flutter suite: **380 passed, 58 failed**. Initial baseline was
  375 passed / the same 58 failures before the five new tests. Examples include
  missing `journal_embed_codec.dart`, uninitialized backend fixtures, and stale
  UI expectations. The whole suite is not green and must be triaged before a
  release gate can be trusted.
- Initial Supabase advisor scan found two definer-view flags, broad executable
  definer-function warnings, and leaked-password protection unavailable/disabled.
  The public documentation views intentionally use authorized redacted functions;
  targeted tests passed, but every remaining function was not individually
  audited. Do not interpret the advisor flag count as a count of proven exploits.

Private credentials/raw diagnostic logs remain outside Git in JuniperLaunch and
temporary local files. They contain no production credentials in these docs.
QA fixture projects/files were removed; normal production content was preserved.

## Changes applied

Three reviewed SQL migrations were run directly against production after focused
checks, rather than pushing the historical migration chain:

1. `20261023150000_launch_access_hardening.sql`: owner INSERT/RETURNING policy;
   authenticated image ownership policies; revoke anonymous collaboration writes.
2. `20261023151000_attachment_owner_cleanup.sql`: private file owners can read
   their own metadata and remove their own bytes, including abandoned uploads.
3. `20261023152000_account_deletion_cleanup.sql`: authenticated, transactional
   owned-data cleanup; refuse orphaned files; remove the login only after cleanup.

The website build adds recovery screens, file cleanup before account deletion,
and clarifies two duplicated policy headings. No policy consent claim was
silently rewritten or legally certified. Production Hosting deployment succeeded.

## Privacy/safety review and required decisions

Current public pages say private content is accessible only to authorized users,
while some inline images remain public. Resolve that implementation mismatch
before a larger launch. Review the content license's promotional use against the
actual intended school/child data uses. Current age wording mentions supervision;
no verified parental/school-consent workflow was found. DOB collection alone is
not a demonstrated consent system. The FTC's guidance explains school-consent
limits and operators' responsibilities:
https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions.
School/vendor arrangements also need review against applicable student-record
requirements: https://studentprivacy.ed.gov/resources/responsibilities-third-party-service-providers-under-ferpa.
This inspection is not legal approval for school adoption.

Current reporting routes to support@junejournal.org. No staffed moderation queue,
appeal workflow, reporting SLA, or comprehensive in-app report/block flow was
established by this review. Before wider youth/school use, the owner should:

1. Confirm the support mailbox is monitored; designate a primary and backup
   reviewer and a private incident register. Set a realistic response target.
2. For a report, record the URL/content ID, category, timestamp and reporter's
   contact with minimal necessary data. Keep youth information out of public Git
   issues and ordinary analytics logs.
3. Triage urgent safety reports immediately; involve the appropriate responsible
   adults/authorities through an agreed escalation process. Limit exposure of
   harmful material and preserve only necessary restricted evidence.
4. Verify the report, restrict/remove violating content where warranted, and
   document the decision and access used. Do not grant blanket admin access to
   every educator or user.
5. Notify affected users as appropriate, provide a review/appeal route, and audit
   outcomes. Publish retention/deletion periods that match actual operations,
   including expiring backups and removal of uploaded bytes.
6. Review age eligibility, parental/school authorization, public profiles/photos,
   direct messaging, and default visibility with a qualified school/privacy
   reviewer before inviting children at scale.

## Owner security and setup steps

Enable MFA on the accounts that administer Supabase, Google/Firebase, GitHub,
Porkbun/DNS, the support mailbox, the SMTP provider and the backup destination.
Use an authenticator/security key, verify enrollment, and save recovery codes in
the owner's password manager plus an independent recovery location. Do not put
codes in this chat, repository, backup archive or support tickets. Start with
Supabase's account MFA guide:
https://supabase.com/docs/guides/platform/multi-factor-authentication.

Choose the independent backup destination (Backblaze B2 is the recommendation;
see backup-and-restore.md), save the age recovery key independently, install/start
the local container runtime or provision an isolated test project after checking
costs, and run a full database-and-files restore drill. Neither recurring backups
nor staging should be checked off until those are actually running and verified.
