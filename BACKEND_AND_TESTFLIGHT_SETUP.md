# AdmitPath Backend And TestFlight Setup

This document is the operator runbook for taking the repo from local code to a working private TestFlight beta with Google sign-in, Supabase-backed storage, and a repeatable release process.

## 1. What this MVP uses

- Backend: Supabase
- Auth: Google OAuth through Supabase Auth
- Structured data: Supabase Postgres
- Binary storage: Supabase Storage
- Server-side logic: Supabase Edge Functions
- Beta distribution: App Store Connect + TestFlight
- Public release target: iPhone
- Internal QA target: Mac Catalyst stays buildable from Xcode

## 2. Free-tier operating assumptions

The repo is designed to start on Supabase free tier by keeping most app data in Postgres rather than object storage.

Expected free-tier-safe usage:

- small private beta
- small avatar uploads
- small peer artifact uploads
- no personal document vault uploads

Upgrade before a larger beta if:

- the free project pause behavior becomes a problem
- storage/egress grows materially
- you need stronger uptime expectations

## 3. Create the Supabase project

1. Create a Supabase account and organization.
2. Create a new project in the region closest to your expected beta users.
3. Record:
   - Project URL
   - anon public key
   - service role key

Use the service role key only for local CLI deployment and secure backend operations. Never place it in the iOS app.

## 4. Configure the database schema

The initial schema lives here:

- [supabase/migrations/20260419_000001_initial_schema.sql](/Users/nikitamahbub/Desktop/AdmitPath/supabase/migrations/20260419_000001_initial_schema.sql)

Recommended flow:

1. Install the Supabase CLI.
2. Link the local repo to your Supabase project.
3. Apply the migration with either:
   - `supabase db push`
   - or paste the migration into the Supabase SQL editor for the first bootstrap

The schema creates:

- public catalog tables
- `user_profiles`
- `user_workspaces`
- community tables
- moderation/verification tables
- audit table
- row-level security policies
- storage buckets and storage policies

## 5. Seed the live catalog

The seed generator lives here:

- [supabase/scripts/generate_seed_sql.py](/Users/nikitamahbub/Desktop/AdmitPath/supabase/scripts/generate_seed_sql.py)

Run:

```bash
python3 supabase/scripts/generate_seed_sql.py > supabase/seed.sql
```

Then either:

- run `supabase db push` if you fold the generated SQL into your local workflow, or
- paste `supabase/seed.sql` into the SQL editor, or
- execute it with `psql` against the linked Postgres instance

The script imports:

- universities
- programs
- program requirements
- program deadlines
- scholarships
- peer profiles
- peer posts
- peer replies
- peer artifacts

## 6. Create storage buckets

The migration creates these buckets:

- `avatars`
- `peer-artifacts`
- `verification-evidence`

MVP storage rules:

- `avatars`: public, image only, small uploads
- `peer-artifacts`: private, PDF/image only, small uploads
- `verification-evidence`: private, image/PDF only, staff-reviewed

Do not use Supabase Storage for:

- passport archives
- transcript vaults
- visa documents
- large media

Those are intentionally out of scope for this MVP.

## 7. Configure Google OAuth

### Google Cloud

1. Create a Google Cloud project.
2. Configure the OAuth consent screen.
3. Create the OAuth client used by Supabase Google sign-in.
4. In Google, allow the callback URL shown by the Supabase Google provider settings.

### Supabase Auth

1. Open `Authentication > Providers > Google`.
2. Enable Google.
3. Enter the Google client ID and secret.
4. Add this redirect URL to the allowed redirects:

```text
admitpath://auth/callback
```

The app is already wired to use that callback scheme through:

- [AdmitPath-Info.plist](/Users/nikitamahbub/Desktop/AdmitPath/AdmitPath/Support/AdmitPath-Info.plist)

## 8. Configure app-side backend values

Update:

- [AppConfig.json](/Users/nikitamahbub/Desktop/AdmitPath/AdmitPath/Support/AppConfig.json)

Replace the placeholders:

- `supabaseURL`
- `supabaseAnonKey`

Recommended production values:

- `productionRequiresSignIn`: `true`
- `enableRemoteCatalog`: `true`
- `enableRemoteWorkspace`: `true`
- `enableSOPGateway`: `true`
- `enableAdminPreview`: `false` for release builds unless you explicitly want the local bypass available in beta
- `enableTestMockAuth`: `false` for release builds
- `staffAdminEmails`: your internal staff emails only

Example:

```json
{
  "enableAdminPreview": false,
  "enableRemoteCatalog": true,
  "enableRemoteWorkspace": true,
  "enableSOPGateway": true,
  "enableTestMockAuth": false,
  "googleScopes": "openid email profile",
  "productionRequiresSignIn": true,
  "redirectHost": "auth",
  "redirectPath": "/callback",
  "redirectScheme": "admitpath",
  "staffAdminEmails": ["you@example.com"],
  "supabaseAnonKey": "YOUR_REAL_ANON_KEY",
  "supabaseURL": "https://YOUR_REAL_PROJECT.supabase.co"
}
```

## 9. Deploy Edge Functions

Function sources:

- [supabase/functions/sop-generate/index.ts](/Users/nikitamahbub/Desktop/AdmitPath/supabase/functions/sop-generate/index.ts)
- [supabase/functions/staff-ops/index.ts](/Users/nikitamahbub/Desktop/AdmitPath/supabase/functions/staff-ops/index.ts)

### `sop-generate`

Purpose:

- server-side SOP generation endpoint used by the app
- deterministic fallback implementation that works without external AI keys

You can later replace the deterministic function body with a real LLM call if you want, but the MVP does not depend on that.

### `staff-ops`

Purpose:

- moderation status updates
- verification status approval
- catalog freshness updates
- audit log insertion

Required secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `STAFF_ADMIN_EMAILS`

Deploy with the Supabase CLI after setting secrets in your project.

## 10. Staff allowlist and roles

There are two layers:

- App-side visibility:
  - driven by `staffAdminEmails` in `AppConfig.json`
- Backend authority:
  - driven by `STAFF_ADMIN_EMAILS` in the `staff-ops` function
  - or by manually marking rows in `user_profiles.role = 'staff'`

For MVP simplicity:

1. keep a tight internal email allowlist
2. manually promote staff users in `user_profiles` after their first sign-in
3. keep privileged writes behind the `staff-ops` function

## 11. Xcode project and signing

Generate the Xcode project:

```bash
ruby Scripts/generate_xcodeproj.rb
```

Then open `AdmitPath.xcodeproj`.

Before TestFlight:

1. Select the `AdmitPath` target.
2. Replace the placeholder bundle ID if needed.
3. Set your Apple developer team.
4. Confirm the URL scheme is present:
   - `admitpath`
5. Keep iPhone as the supported release destination.
6. Keep Mac Catalyst enabled for internal QA only.

## 12. App Store Connect and TestFlight

1. Create the app in App Store Connect.
2. Match the bundle ID to the Xcode target.
3. Fill in app metadata and privacy details.
4. Create internal tester groups first.
5. Archive the app from Xcode.
6. Upload the archive to App Store Connect.
7. Wait for processing.
8. Start with internal TestFlight testers.
9. Move to external testing only after live auth and sync are stable.

## 13. Validation workflow

### Automated

Run:

```bash
./Scripts/validate_builds.sh
```

That covers:

- `swift test`
- Xcode project regeneration
- Mac Catalyst build
- iPhone simulator build-for-testing
- iPhone simulator UI smoke tests when a compatible simulator exists

### Manual live smoke checklist

Before inviting beta users, verify on a physical iPhone:

1. Fresh install launches into Google sign-in.
2. Google sign-in succeeds.
3. First login routes into onboarding.
4. Onboarding saves and resumes correctly.
5. Saved shortlist survives relaunch.
6. Applications, tasks, and planner items sync.
7. SOP generation and save flow works.
8. Community post and reply submission works.
9. Report flow works.
10. Verification request submission works.
11. Staff account can open moderation tools.
12. Staff account can approve verification.
13. Archive installs from TestFlight and updates cleanly.

## 14. Internal development launch modes

These are still useful locally:

- `-AdmitPathGuestMode`
- `-AdmitPathMockAuthenticated`
- `-AdmitPathLoadSampleData`
- `-AdmitPathAdminPreview`

They are for development and UI testing. Do not rely on them for the release beta path.

## 15. Common failure modes

### Google sign-in opens but never returns to the app

Check:

- `admitpath://auth/callback` is present in Supabase redirect allow list
- the URL scheme exists in `AdmitPath-Info.plist`
- Google provider callback URL is correctly registered in Google Cloud

### App says Supabase is not configured

Check:

- `AppConfig.json` still contains placeholders
- the real file is bundled into the app target

### Signed-in user cannot save or sync

Check:

- RLS policies were applied
- `user_profiles` row exists
- `user_workspaces` table exists
- the anon key belongs to the right project

### Staff tools show but actions fail

Check:

- `STAFF_ADMIN_EMAILS` is set for the `staff-ops` Edge Function
- the signed-in email is present in the allowlist
- the service role key is configured for the function

### iPhone simulator validation fails locally

Check:

- Xcode and CoreSimulator runtime versions match
- at least one iOS simulator runtime is installed

### TestFlight archive uploads but sign-in fails only in beta

Check:

- release bundle ID and OAuth settings match
- the release app still contains the `admitpath` URL scheme
- the production `AppConfig.json` values were used during archive

## 16. Recommended operator sequence

1. Apply the schema migration.
2. Generate and run the seed SQL.
3. Configure Google OAuth in Google Cloud and Supabase.
4. Fill `AppConfig.json` with real values.
5. Deploy the Edge Functions and secrets.
6. Run `./Scripts/validate_builds.sh`.
7. Smoke test on simulator.
8. Smoke test on physical iPhone.
9. Archive and upload to TestFlight.
10. Start with internal testers only.
