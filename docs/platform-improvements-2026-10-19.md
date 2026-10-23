# Platform improvements — 19 October 2026

Combined implementation checklist from the three distinct user requirement documents and accompanying screenshots/recordings. Preserve existing Flutter/Supabase architecture and previously accepted data.

- [x] Forum composer balanced padding, compact title, persistent Title/Post body labels; 15 widget checks and web build passed.
- [x] Collaboration only after creation; initial setup retains membership/community controls.
- [x] Role caret beside label; removal separate.
- [x] Community-member source in project member picker, alongside friends/search.
- [x] Project invitations pending/accepted/declined/cancelled; one Send Invites confirmation; notifications, deduplication, acceptance and refresh.
- [x] Community-level project invitations; shared admin review, single decision, history and creator notification; only accepted links grant access.
- [x] Journal creator immutable attribution; excluded from selectable/removable contributors; staged contributor picker and centered action.
- [x] Overview image editing, proportional consistent project covers/cards.
- [x] Budget numeric cost alignment, existing-project component selection/None, balanced modal, aligned budget rows, centered location field.
- [x] Compact expandable short inputs, neutral root cause panel, green selected states, question-specific placeholders.
- [x] PDFs and external links open in editor and authorized viewer modes.
- [x] Explicit modal dismissal and unsaved-change protection.
- [x] Interactive assessments for all existing types; numeric filtering, grading, user response persistence and submission states; author sandbox.
- [x] Central backend reward ledger/configuration: journal completion 20 × difficulty × scale × confirmed contribution (capped), evidence +5/+10 deduplicated, immutable award snapshot.
- [x] Capped documented impact reward; no uncalibrated raw-quantity reward; duplicate protection.
- [x] Assessment participation +5/+5 correctness, once per user/source; no author preview rewards, server grading and secure answer keys.
- [x] Consistent profile/dashboard totals, reward feedback, adjustment/reversal support.
- [x] Profile popup: centered View Profile, correct destination, top-right X.
- [x] Targeted UI/repository/database security checks and final preview build.

Decisions from requirements: numeric responses retain the existing explicit minimum/maximum acceptance bounds; paragraph responses remain ungraded. Quantity-based environmental bonuses stay disabled until category thresholds are calibrated, as explicitly requested. Existing accepted memberships/community links remain accepted; new links require approval.


## Delivery verification

- 73 targeted Flutter UI/repository tests passed together in `/tmp/platform-delivery-tests.txt`; the implementation impact-card regression also passed (74 distinct checks).
- Installed Supabase invitation checks cover pending access, duplicate requests/decisions, acceptance/decline/cancellation, community authorization, and compatibility with existing clients accepting their own invitations.
- Installed assessment/reward checks cover numeric, single/multiple choice, true/false, matching, ungraded written responses, protected answer keys under the authenticated role, forged-ledger rejection, evidence caps/hash deduplication, immutable creators and completion snapshots, and confirmed contributor eligibility.
- Impact checks verify server-owned amounts, inflated quantity rejection, repeated-record/edit deduplication, and the configurable 10-point per-entry impact cap. Existing impact estimates were normalized through the same backend rules.
- Live browser verification showed community members above friends, staged selection, a centered Send Invites footer and a discard confirmation. No actual invitations were sent during this UI check. The original user tab was preserved.
- Production Dart source analysis has no errors. The repository-wide analyzer still identifies an older test importing the absent `journal_embed_codec.dart`, along with existing warnings/style diagnostics; the entire repository suite is not represented as clean.

## Operational notes

Backend migrations through `20261019203000_normalize_impact_rewards.sql` were applied to the connected Supabase project. The web preview was rebuilt locally. No Git commit, push, native app release, or hosted-site publication was performed.

New supporting-context PDFs/files use the private `journal-attachments` bucket, with permission-checked signed URLs. Historical files already uploaded to the public images bucket retain their existing public URLs; this work does not retroactively relocate those objects or revoke copies of old URLs.

Raw-quantity impact bonuses remain disabled pending category calibration. Written assessment responses are saved without automatic correctness grading. Existing budget records have item, cost, currency and optional component fields; no unsupported quantity or unit-price schema was invented.
