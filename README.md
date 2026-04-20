# AdmitPath

AdmitPath is an iPhone-first SwiftUI admissions workspace for Bangladeshi students targeting universities in Canada, the UK, USA, Australia, Malaysia, Hong Kong, Germany, the Netherlands, and Ireland. The app combines deterministic shortlisting, scholarship guidance, application planning, SOP drafting, and a trust-aware peer network.

This repo now targets a real TestFlight MVP shape:

- Google sign-in via Supabase OAuth
- cloud-backed workspace persistence
- live catalog and community stores
- deterministic matching and scholarship ranking
- lightweight in-app staff tools for moderation, verification, and catalog freshness
- Mac Catalyst kept buildable for internal QA, with iPhone as the release beta surface

## Current architecture

- `AdmitPath/App`, `Core`, `Models`, `Repositories`, `Services`, `ViewModels`, `Views`, and `Components` keep the app architecture modular while preserving a single `AppState`.
- `AppState` is the runtime source of truth for auth, sync, onboarding, matching, applications, SOP state, community actions, and staff operations.
- `AuthAndCloudServices.swift` contains the production runtime seams:
  - `AuthStore`
  - `CatalogStore`
  - `WorkspaceStore`
  - `CommunityStore`
  - `AdminStore`
  - `SOPGateway`
- Bundled seed JSON remains in `AdmitPath/SeedData` as fallback and test/demo data, but the production path is Supabase-backed.

## Backend and release setup

The operator guide lives at:

- [BACKEND_AND_TESTFLIGHT_SETUP.md](/Users/nikitamahbub/Desktop/AdmitPath/BACKEND_AND_TESTFLIGHT_SETUP.md)

Supabase project artifacts live under:

- [supabase/README.md](/Users/nikitamahbub/Desktop/AdmitPath/supabase/README.md)
- [supabase/migrations/20260419_000001_initial_schema.sql](/Users/nikitamahbub/Desktop/AdmitPath/supabase/migrations/20260419_000001_initial_schema.sql)
- [supabase/functions/sop-generate/index.ts](/Users/nikitamahbub/Desktop/AdmitPath/supabase/functions/sop-generate/index.ts)
- [supabase/functions/staff-ops/index.ts](/Users/nikitamahbub/Desktop/AdmitPath/supabase/functions/staff-ops/index.ts)
- [supabase/scripts/generate_seed_sql.py](/Users/nikitamahbub/Desktop/AdmitPath/supabase/scripts/generate_seed_sql.py)

## Local development

1. Generate or refresh the Xcode project:

```bash
ruby Scripts/generate_xcodeproj.rb
```

2. Open `AdmitPath.xcodeproj` in Xcode.
3. Use an iPhone simulator or physical iPhone for the production beta flow.
4. Keep Mac Catalyst for internal smoke testing and staff QA.

`AdmitPath/Support/AppConfig.json` contains checked-in placeholder values. Replace them with a real Supabase project URL and anon key when you configure the backend.

## Validation

Logic tests:

```bash
swift test
```

Full validation script:

```bash
./Scripts/validate_builds.sh
```

That script runs:

- SwiftPM tests
- Xcode project regeneration
- Mac Catalyst command-line build
- iPhone simulator build-for-testing
- iPhone simulator UI smoke tests when a compatible simulator runtime is available

## Current constraints

- Live Google auth and live cloud sync still require real Supabase and Google OAuth credentials in `AppConfig.json`.
- TestFlight distribution still requires your App Store Connect app, signing setup, and archive/upload workflow.
- iPhone simulator validation depends on a healthy local Xcode/CoreSimulator installation.
