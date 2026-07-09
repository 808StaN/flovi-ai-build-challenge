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
