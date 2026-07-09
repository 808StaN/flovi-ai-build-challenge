# Prompt Log

Use this document to record the key prompts and iterations from the Flovi AI Build Challenge.

## Prompt Entry Template

### Prompt Number


### Goal


### Prompt Summary


### AI Output Summary


### What Changed


### What Broke Or Needed Correction


### Why The Next Iteration Was Needed


## Entries

### Prompt Number

1

### Goal

Create a practical implementation plan from the assignment requirements before generating files.

### Prompt Summary

Asked the AI to inspect the provided assignment requirements, treat them as the source of truth, and produce a realistic phase-by-phase plan for two connected Flovi relocation apps.

### AI Output Summary

The AI proposed a monorepo with Vue dispatcher app, Flutter driver app, Supabase backend, Vercel deployment, phased implementation, commit checkpoints, risks, and a five-minute demo flow.

### What Changed

No files changed during planning.

### What Broke Or Needed Correction

The plan needed small corrections before implementation: static-first Flutter Web deployment, an explicit status constraint, atomic booking RPC behavior, simple RLS, and a demo setup note.

### Why The Next Iteration Was Needed

The next iteration starts Phase 1 and creates the repository foundation with the corrected backend and deployment assumptions.

### Prompt Number

2

### Goal

Scaffold the dispatcher web app only, without implementing request CRUD.

### Prompt Summary

Asked the AI to proceed with Phase 2 by creating the Vue 3, Vite, Tailwind CSS dispatcher app, adding Supabase Google OAuth shell behavior, running relevant checks, and committing the result.

### AI Output Summary

The AI generated the dispatcher app scaffold, Supabase client setup, Flovi-inspired auth/dashboard shell, and environment example while intentionally leaving relocation request CRUD for a later phase.

### What Changed

Created the dispatcher Vue 3 app scaffold with Vite, Tailwind CSS, Supabase client setup, `.env.example`, Google OAuth sign-in/sign-out shell, and a Flovi-inspired dashboard landing state.

### What Broke Or Needed Correction

Review caught several Tailwind opacity utilities using non-default values like `/8` and `/68`. They were corrected to bracketed arbitrary opacity syntax, then `npm run build` passed again.

### Why The Next Iteration Was Needed

The next iteration is needed to add the actual relocation request workflow: create, list, edit, status badges, and Supabase realtime refresh.

### Prompt Number

3

### Goal

Implement the dispatcher relocation workflow.

### Prompt Summary

Asked the AI to add the create request form, list all requests, status badges, edit/update existing requests, Supabase realtime/refetch after changes, checks, and a commit.

### AI Output Summary

The AI implemented authenticated dispatcher CRUD for request creation and detail updates, a polished operations queue, status summary cards, clear status badges, manual refresh, and realtime refetch on `relocation_requests` changes.

### What Changed

`apps/dispatcher-web/src/App.vue` now contains the full dispatcher workflow against Supabase while preserving the Flovi-inspired design system.

### What Broke Or Needed Correction

Review caught a couple of Tailwind opacity utilities that needed bracketed arbitrary syntax. After correction, `npm run build` passed.

### Why The Next Iteration Was Needed

The next iteration can move to the driver Flutter app scaffold and later connect driver booking to the same Supabase data.

### Prompt Number

4

### Goal

Scaffold the Driver Flutter app with Supabase OAuth shell only.

### Prompt Summary

Asked the AI to create the Flutter app in `apps/driver-app`, initialize Supabase through `SUPABASE_URL` and `SUPABASE_ANON_KEY` dart defines, add Google OAuth login/logout, create a mobile-first Flovi-inspired UI shell, avoid booking, run Flutter checks, and commit.

### AI Output Summary

The AI created a Flutter driver app scaffold manually because Flutter was not installed in the environment. The app includes Supabase initialization through dart defines, Google OAuth login/logout shell behavior, and a mobile-first Flovi-inspired UI.

### What Changed

Added `apps/driver-app` with `pubspec.yaml`, lint options, web entry files, README setup notes, `lib/main.dart`, and a widget test for the auth shell.

### What Broke Or Needed Correction

`flutter`, `dart`, and `fvm` were not available on PATH. `flutter pub get` and `flutter analyze` could not run in this environment and failed with `CommandNotFoundException`.

### Why The Next Iteration Was Needed

The next iteration needs Flutter installed locally to run dependency resolution and analysis before implementing driver gig browsing and booking.

### Prompt Number

5

### Goal

Fix/verify Flutter, then implement the driver booking workflow.

### Prompt Summary

Asked the AI to check `flutter --version`, fix PATH or install a local non-committed Flutter SDK if missing, enable web support, run `flutter pub get`, `flutter analyze`, and `flutter build web --release`, then implement available gigs, booking confirmation, booked gigs, realtime/refetch, update the prompt log, and commit.

### AI Output Summary

Flutter was missing from PATH and common install locations, so the AI cloned Flutter stable into `C:\Users\nasty\AppData\Local\Temp\opencode\flutter`, enabled web support, and used that SDK for this session. Baseline Flutter checks passed after updating Supabase initialization from deprecated `anonKey` to `publishableKey`. The AI then implemented the connected driver workflow.

### What Changed

`apps/driver-app/lib/main.dart` now fetches available relocation requests, shows booked gigs for the signed-in driver, confirms booking in a bottom sheet, books via `book_relocation_request`, refetches after changes, and subscribes to Supabase realtime table changes. `apps/driver-app/pubspec.lock` was generated by `flutter pub get` and committed for reproducible app dependencies.

### What Broke Or Needed Correction

Initial Flutter verification failed because no SDK was installed or on PATH. Baseline analysis also caught a deprecated Supabase `anonKey` parameter, which was corrected to `publishableKey`. Final `flutter pub get`, `flutter analyze`, and `flutter build web --release` passed. The build emitted a non-fatal Flutter font warning, but produced `build/web` successfully.

### Why The Next Iteration Was Needed

The next iteration can focus on final integration testing with real Supabase credentials, deployment prep, Vercel URLs, and presentation docs.

### Prompt Number

6

### Goal

Prepare integration and deployment documentation without adding product features.

### Prompt Summary

Asked the AI to verify both apps use the same Supabase schema and RPC, update Vercel deployment instructions, document required Supabase env vars and OAuth redirect URLs, add a smoke-test checklist, ensure build output and the temporary Flutter SDK are not committed, update prompt/reflection docs, run available checks, and commit.

### AI Output Summary

The AI verified both apps use `public.relocation_requests`, the driver books through `book_relocation_request`, and both apps subscribe/refetch around the shared table. It expanded root and Supabase docs with deployment, env var, redirect, smoke-test, and cleanup guidance.

### What Changed

Updated `README.md`, `supabase/README.md`, `docs/reflection.md`, and this prompt log with integration/deployment preparation details.

### What Broke Or Needed Correction

No product correction was needed. `npm run build`, `flutter pub get`, `flutter analyze`, and `flutter build web --release` passed. Build output stayed ignored, and the temporary Flutter SDK remained outside the repository.

### Why The Next Iteration Was Needed

The next iteration should use real Supabase credentials and deployed Vercel URLs to execute the smoke-test checklist end to end.
