# Supabase Artifacts

This folder contains the backend assets needed to stand up the AdmitPath TestFlight MVP.

Contents:

- `migrations/`: schema, RLS, and storage setup
- `functions/`: Edge Functions used by the app
- `scripts/`: helper scripts for catalog seeding

Start with the operator guide:

- [BACKEND_AND_TESTFLIGHT_SETUP.md](/Users/nikitamahbub/Desktop/AdmitPath/BACKEND_AND_TESTFLIGHT_SETUP.md)

Recommended sequence:

1. Apply the initial migration.
2. Generate `seed.sql` from the bundled JSON data.
3. Deploy the Edge Functions.
4. Replace the placeholder values in `AdmitPath/Support/AppConfig.json`.
