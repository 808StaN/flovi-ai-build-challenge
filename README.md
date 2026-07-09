# Flovi AI Build Challenge

Two connected apps for a Flovi relocation workflow, built for a 4-hour AI engineering sprint.

## Apps

- `apps/dispatcher-web`: Vue 3 + Vite + Tailwind CSS dispatcher dashboard.
- `apps/driver-app`: Flutter 3 mobile-first driver app, deployed as Flutter Web.
- `supabase`: shared database schema, auth notes, and backend setup.
- `docs`: prompt log and reflection notes for the presentation.

## Target Workflow

1. Dispatcher signs in with Google.
2. Dispatcher creates a relocation request with origin, destination, date, and notes.
3. Driver signs in with Google.
4. Driver sees the request as available.
5. Driver books the gig with one tap.
6. Dispatcher sees the request status update to booked.

## Tech Stack

- Vue 3 + Vite + Tailwind CSS for the dispatcher web app.
- Flutter 3 for the driver app.
- Supabase Auth, PostgreSQL, RPC, and realtime for the backend.
- Vercel for both public deployments.

## Supabase Setup

1. Create a Supabase project.
2. Enable Google OAuth in Supabase Auth.
3. Run `supabase/schema.sql` in the Supabase SQL editor.
4. Add local and deployed app URLs to Supabase Auth redirect URLs.
5. Configure each app with the same Supabase URL and anon key.

See `supabase/README.md` for schema and policy details.

## Vercel Deployment Plan

### Dispatcher Web

- Vercel root directory: `apps/dispatcher-web`
- Framework preset: Vite
- Build command: `npm run build`
- Output directory: `dist`
- Environment variables:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_ANON_KEY`

### Driver Flutter Web

Use static-output deployment first for reliability.

Preferred flow:

1. Build locally with `flutter build web --release` from `apps/driver-app`.
2. Deploy the generated `apps/driver-app/build/web` directory to Vercel as a static site.

If a Vercel Flutter build setup proves reliable, it can be used later, but the challenge demo should prioritize a known-good static web build.

Environment values for Flutter should be passed with `--dart-define` during build:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

## Recommended Demo Setup

Use two browser profiles or two Google accounts to simulate the dispatcher and driver as separate authenticated users. This makes the end-to-end status sync easier to demonstrate clearly.

## Commit Strategy

Commit at key milestones instead of only at the end:

1. Repository foundation and docs.
2. Supabase schema and setup notes.
3. Dispatcher scaffold.
4. Dispatcher workflow.
5. Driver scaffold.
6. Driver booking workflow.
7. Deployment and final polish.

## Scope Guardrails

Skip maps, payments, native APK packaging, push notifications, chat, complex role systems, and marketing-site recreation. Prioritize a polished working demo.
