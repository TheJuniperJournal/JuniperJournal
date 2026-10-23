# Separate testing environment

Firebase preview channels isolate a frontend release, **not** its database.
The existing preview/old-version site still uses production Supabase unless
explicitly built with separate credentials. Do not run destructive tests there.

`tool/deploy_web_staging.sh` now refuses the production Supabase reference before
building or deploying. It also rejects placeholders and localhost backends for a
publicly hosted staging site. Its production-ref rejection was exercised.

To activate hosted staging:

1. Create a separate Supabase project after reviewing the account's current free
   allowance or extra compute cost. No paid project was created by this task.
2. Establish a clean schema baseline and apply reviewed migrations. The repo's
   migration chain currently assumes historical tables, and is not proven to
   rebuild an empty database. Do not run `db push` blindly against production.
3. Set up the same bucket visibility/RLS and Edge Functions. Use synthetic data;
   do not populate public staging with production users or uploaded youth photos.
4. Copy `.env.staging.example` to `.env.staging` with the test project's public
   URL and anon/publishable key. This file is ignored by Git. Never use service
   keys in the browser build.
5. Add the exact staging origin to the **test** Auth redirect allowlist. Configure
   an email capture service or controlled test inboxes and separate OAuth config.
6. Run with `FLUTTER_BIN` and `FIREBASE_BIN` set as needed:

   ```sh
   sh tool/deploy_web_staging.sh
   ```

   It uses an expiring Firebase `staging` preview channel and does not deploy the
   live channel. Record both frontend URL and backend ref in each test report.
7. Run unit/widget tests, the rollback SQL tests against the test backend, and
   `tool/smoke_test_accounts.py` with two disposable confirmed accounts. Review
   all failures before promoting the exact build to production.

The guard and deployment recipe are prepared. A separate backend and functioning
hosted staging environment are **not yet active**. Local Supabase is another
option after installing Docker/Podman; that runtime is absent on this Mac.
