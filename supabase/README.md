# Supabase Backend

This directory contains the shared backend setup for both Flovi challenge apps.

## Files

- `schema.sql`: database table, constraints, indexes, RLS policies, trigger, realtime publication setup, and atomic booking RPC.

## Setup Steps

1. Create a Supabase project.
2. Enable Google OAuth in Supabase Auth.
3. Run `schema.sql` in the Supabase SQL editor.
4. Copy the project URL and anon key into both apps.
5. Add local and deployed app URLs to the Supabase Auth redirect allowlist.

## Auth And Redirects

Use the same Supabase project for the dispatcher and driver apps.

In Google Cloud OAuth, configure this authorized redirect URI:

```text
https://your-project-ref.supabase.co/auth/v1/callback
```

In Supabase Auth URL configuration, allow these redirect URLs:

```text
http://localhost:5173/**
http://localhost:5174/**
https://your-dispatcher-vercel-url.vercel.app/**
https://your-driver-vercel-url.vercel.app/**
```

Recommended local ports are `5173` for the Vite dispatcher app and `5174` for the Flutter Web driver app.

## App Environment Values

Dispatcher web app:

```text
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-supabase-anon-or-publishable-key
```

Driver Flutter app:

```bash
--dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-or-publishable-key
```

## Data Model

The core table is `public.relocation_requests`.

Status is constrained to:

- `available`
- `booked`
- `completed`

## RLS Strategy

Policies are intentionally simple and demo-safe:

- Authenticated users can read relocation requests.
- Authenticated users can create requests only for their own `dispatcher_id`.
- Dispatchers can update requests they created.
- Drivers book requests through the `book_relocation_request` RPC instead of broad direct update permissions.

This avoids a complex role system while still protecting the main workflow.

## Atomic Booking RPC

`public.book_relocation_request(request_id uuid)` only books a request when:

- the request exists,
- `status = 'available'`, and
- `driver_id is null`.

It returns a single-row result with:

- `success`: boolean
- `message`: clear success or failure message
- request fields when booking succeeds

## Realtime

The schema adds `relocation_requests` to the `supabase_realtime` publication. Both apps should fetch initial data, subscribe to row changes, and refetch relevant lists when changes arrive.

## Smoke Test

1. Dispatcher logs in.
2. Dispatcher creates a request.
3. Driver logs in.
4. Driver sees the request as available.
5. Driver books the request through `book_relocation_request`.
6. Dispatcher sees status change to `booked`.
