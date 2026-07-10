-- Flovi AI Build Challenge Supabase schema
-- Run this file in the Supabase SQL editor for a fresh project.

create extension if not exists "pgcrypto";

create table if not exists public.relocation_requests (
  id uuid primary key default gen_random_uuid(),
  origin text not null,
  destination text not null,
  move_date date not null,
  notes text,
  status text not null default 'available',
  dispatcher_id uuid not null references auth.users(id) on delete cascade,
  driver_id uuid references auth.users(id) on delete set null,
  booked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint relocation_requests_status_check check (status in ('available', 'booked', 'completed')),
  constraint relocation_requests_booking_consistency check (
    (status = 'available' and driver_id is null and booked_at is null)
    or (status in ('booked', 'completed') and driver_id is not null and booked_at is not null)
  )
);

create index if not exists relocation_requests_status_idx
  on public.relocation_requests(status);

create index if not exists relocation_requests_dispatcher_id_idx
  on public.relocation_requests(dispatcher_id);

create index if not exists relocation_requests_driver_id_idx
  on public.relocation_requests(driver_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists relocation_requests_set_updated_at on public.relocation_requests;

create trigger relocation_requests_set_updated_at
before update on public.relocation_requests
for each row
execute function public.set_updated_at();

alter table public.relocation_requests enable row level security;

drop policy if exists "Authenticated users can read relocation requests" on public.relocation_requests;
create policy "Authenticated users can read relocation requests"
on public.relocation_requests
for select
to authenticated
using (true);

drop policy if exists "Dispatchers can create own relocation requests" on public.relocation_requests;
create policy "Dispatchers can create own relocation requests"
on public.relocation_requests
for insert
to authenticated
with check (dispatcher_id = auth.uid());

drop policy if exists "Dispatchers can update own relocation requests" on public.relocation_requests;
create policy "Dispatchers can update own relocation requests"
on public.relocation_requests
for update
to authenticated
using (dispatcher_id = auth.uid())
with check (dispatcher_id = auth.uid());

drop function if exists public.book_relocation_request(uuid);

create or replace function public.book_relocation_request(request_id uuid)
returns table (
  success boolean,
  message text,
  id uuid,
  origin text,
  destination text,
  move_date date,
  notes text,
  status text,
  dispatcher_id uuid,
  driver_id uuid,
  booked_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return query
    select
      false::boolean,
      'Authentication is required to book a relocation request.'::text,
      null::uuid,
      null::text,
      null::text,
      null::date,
      null::text,
      null::text,
      null::uuid,
      null::uuid,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz;
    return;
  end if;

  return query
  with booked as (
    update public.relocation_requests rr
    set
      status = 'booked',
      driver_id = auth.uid(),
      booked_at = now()
    where rr.id = $1
      and rr.status = 'available'
      and rr.driver_id is null
    returning
      rr.id,
      rr.origin,
      rr.destination,
      rr.move_date,
      rr.notes,
      rr.status,
      rr.dispatcher_id,
      rr.driver_id,
      rr.booked_at,
      rr.created_at,
      rr.updated_at
  )
  select
    true::boolean,
    'Relocation request booked successfully.'::text,
    booked.id,
    booked.origin,
    booked.destination,
    booked.move_date,
    booked.notes,
    booked.status,
    booked.dispatcher_id,
    booked.driver_id,
    booked.booked_at,
    booked.created_at,
    booked.updated_at
  from booked;

  if not found then
    return query
    select
      false::boolean,
      case
        when exists (select 1 from public.relocation_requests rr where rr.id = $1) then
          'This relocation request is no longer available.'
        else
          'Relocation request was not found.'
      end::text,
      null::uuid,
      null::text,
      null::text,
      null::date,
      null::text,
      null::text,
      null::uuid,
      null::uuid,
      null::timestamptz,
      null::timestamptz,
      null::timestamptz;
  end if;
end;
$$;

revoke execute on function public.book_relocation_request(uuid) from public;
revoke execute on function public.book_relocation_request(uuid) from anon;
grant execute on function public.book_relocation_request(uuid) to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'relocation_requests'
    ) then
    alter publication supabase_realtime add table public.relocation_requests;
  end if;
end;
$$;
