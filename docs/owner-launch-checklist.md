# Juniper Journal launch checklist

Use https://the-juniper-journal.web.app/ in a separate browser profile or private window. Use a disposable account you control, not your main account. Use synthetic content and photos. Record the device, browser, date and result for each item. A check is complete only after its expected result is observed.

## 1. Account access and password recovery

- [ ] Sign up with a fresh email address. Confirmation arrives and its link opens the correct site.
- [ ] Confirm the account, log in, refresh, then log out. Private pages are no longer accessible after logout.
- [ ] From Log In, choose Forgot Password. Request recovery for this test account.
- [ ] Open the recovery email in the same browser used for the request. It opens a new-password form rather than Home, a blank screen or an error.
- [ ] Set a new password; mismatched passwords are rejected.
- [ ] Log out. The new password works and the old password fails.
- [ ] Reuse the reset link; it cannot reset the password again. An expired/invalid link offers a way to request another email.
- [ ] Request recovery while logged out and while another account has an existing session; it must not change the wrong account's password.
- [ ] Repeat confirmation and recovery on the final custom domain once it is active. Check spam and delivery to another email provider if available.

Never put passwords, email recovery links or codes in bug reports or this chat.

## 2. Projects, journal entries and uploads

- [ ] Create a private project. Title, settings and cover image survive refresh and a fresh login.
- [ ] Start a journal entry, add text and photos, leave, reopen and refresh. Draft content and photos remain.
- [ ] Complete a journal with no impacts. Impact is labeled Optional and does not block completion.
- [ ] Add an impact to another journal. Assessment points appear; completion includes journal plus eligible impact points.
- [ ] Reopen/edit the completed journal. Saving again does not award the same points twice.
- [ ] Use Back and Done from an entry opened normally and from a pasted entry URL. Both return to a working page.
- [ ] Check the journal detail, phase list and Home card. Photos belong to that specific entry. A photo in another entry or project cover must not appear as its photo.
- [ ] Test two entries in the same project with different photos; reopen each and confirm they do not swap or disappear.
- [ ] Home initially displays at most 10 feed cards. If more are available, Load more adds the next 10 without duplicates or a scroll reset. No button appears when all cards are shown.

## 3. Privacy and collaboration — two accounts

Keep your main account in one browser profile and the test account in another.

- [ ] Before an invitation is accepted, the test account cannot view or edit your private project/journal through its direct URL.
- [ ] Open a private photo/attachment URL while logged out. It must not reveal the file. **Private inline photos are an outstanding launch blocker until storage access is fixed.**
- [ ] Invite the test account. It receives the invitation, accepts and gains the intended access.
- [ ] Test permissions separately: viewing, journal editing, uploads, deleting content and changing project settings. Each matches the assigned role.
- [ ] Remove access, refresh and retry the project URL and files. Access is denied.
- [ ] Public content is visible while logged out; drafts and private content are not included in public feeds/search.

## 4. Deletion and support

- [ ] Delete a disposable photo and journal; refresh and verify they remain deleted.
- [ ] Delete the disposable account after the other tests. Its owned data/uploads are removed as intended and it cannot log in again.
- [ ] Repeat deletion with representative shared content in an isolated test environment; verify other users' content is preserved.
- [ ] Send a test support/report request yourself and confirm it reaches a monitored inbox and can be handled.

## 5. Devices and visible behavior

- [ ] Repeat core signup/reset, journal save, upload and completion on a real phone and desktop.
- [ ] Check Safari, Chrome and Firefox; include a tablet if it is a supported target.
- [ ] Check narrow screens, long text, keyboard navigation, touch targets and hover bounds. No overflow, inaccessible buttons or blank pages.
- [ ] Paste a project/entry URL into a fresh tab and refresh. Check both signed-in and logged-out behavior.

## Remaining work before a wider launch

These items are not signed off by the existing audit:

- [ ] **Protect private inline photos:** move private journal/learning media to authorized storage, migrate existing references and verify outsider access is denied. Refreshing an image URL is not a privacy fix.
- [ ] **Complete real password recovery:** owner-run email → reset → logout → new-password login test. The feature is implemented; its real browser/email flow is still awaiting confirmation.
- [ ] **Confirm email delivery readiness:** production sender configuration, confirmation/recovery redirect URLs and delivery/rate-limit capacity for the expected audience.
- [ ] **Full backup and restore:** database plus uploaded files restored together into an isolated environment. Only local file backup/restore has been demonstrated.
- [ ] **Activate recurring off-site backups:** encryption, independently saved recovery key, retention and failure notifications. Existing local backup tooling is not an active backup service.
- [ ] **Enable administrator MFA** and save recovery codes independently for hosting/database, source control, domain, email and backup accounts.
- [ ] **Activate independent staging:** separate backend and synthetic data. The comparison preview currently uses production and is not isolated staging.
- [ ] **Triage the failing automated tests:** focused fixes pass, but the full suite has outstanding failures and is not yet a reliable release gate.
- [ ] **Finish real-device/browser checks**, broader collaboration/deletion scenarios and the owner checklist above.
- [ ] **Prepare youth/school operations:** review consent, visibility, reporting, moderation, retention and deletion practices before wider school/youth use. Assign someone to monitor support and handle incidents.
- [ ] **Verify final domain and service ownership:** HTTPS, final-domain links, support email and billing/renewal access work before canceling any remaining Wix/email service that is still providing them.

The site is publicly reachable, but the wider-launch checklist remains incomplete. A successful single-account walkthrough does not close the privacy, backup, staging or school-use items.
