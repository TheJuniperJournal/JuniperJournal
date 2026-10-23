# Production reset — October 23, 2026

Completed at the owner's explicit request, after resolving the duplicate Ricky Rios accounts in favor of `rjrios1`.

Preserved:
- Ben Yang (`btyang0710`) and Ricky Rios (`rjrios1`), including their existing login credentials.
- Mason Jar Terrariums, Juniper Journal Learning Kits, and Solar Aquaponics.
- All 23 journal entries in those projects, with IDs, titles, authors and content unchanged.
- Six linked impacts and the retained project collaboration.
- All 71 uploaded files referenced by the protected records; other retained-account files not implicated in the reset also remain.

Removed:
- All eight communities and their associated community data/chat records.
- Twelve other projects and their dependent project records.
- Nine other authentication accounts/profiles, including `rjrios2` and the QA recovery account.
- Sixty-nine uploaded files associated with removed accounts or content, through the Storage API.
- Deleted-community links/grants, obsolete project rewards, and orphaned conversations.

Verification:
- Rehearsed the database changes in a rolled-back transaction before applying them.
- Application/auth/storage row snapshot exported privately outside Git.
- All 172 original uploads backed up and checksum-verified (155,107,163 bytes).
- Recovery snapshot encrypted; decrypting the archive reproduced its original hash. This is not a full database service restore drill.
- Post-reset checks: two auth accounts/profiles, zero communities, three projects, 23 entries, six impacts, zero sessions or owned files for removed accounts.
- Verified all 71 protected referenced files remain and all 69 selected files were removed. Storage now contains 103 files.

Recovery material and detailed execution logs are private under the owner's JuniperLaunch backup directory, not in this repository. Do not run reset SQL as an application migration. The prior QA email/password-reset account is gone; use a new disposable account for future end-to-end tests. This reset does not close the remaining launch-readiness items.
