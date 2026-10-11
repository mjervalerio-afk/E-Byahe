-- E-Byahe isolated GPS simulator storage.
-- Apply only to a DEVELOPMENT Supabase project. This deliberately creates
-- a dedicated test table and never writes to a production shuttle location table.

create table if not exists public.gps_locations_test (
  id uuid primary key default gen_random_uuid(),
  shuttle_id text not null check (shuttle_id = 'shuttle-test-01'),
  trip_id text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  recorded_at timestamptz not null,
  source_type text not null check (source_type = 'simulated'),
  created_at timestamptz not null default now()
);

alter table public.gps_locations_test enable row level security;

-- This test-only table contains no passenger information. Anonymous access is
-- limited to simulated rows for a fixed test shuttle; there are no update/delete
-- policies. Do not copy these policies onto production tables.
drop policy if exists "public can read simulated test GPS" on public.gps_locations_test;
create policy "public can read simulated test GPS"
  on public.gps_locations_test for select to anon
  using (shuttle_id = 'shuttle-test-01' and source_type = 'simulated');

drop policy if exists "public can insert simulated test GPS" on public.gps_locations_test;
create policy "public can insert simulated test GPS"
  on public.gps_locations_test for insert to anon
  with check (shuttle_id = 'shuttle-test-01' and source_type = 'simulated');

-- Enable Supabase Realtime on this dedicated table, idempotently.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'gps_locations_test'
  ) then
    alter publication supabase_realtime add table public.gps_locations_test;
  end if;
end $$;

comment on table public.gps_locations_test is
  'DEVELOPMENT ONLY: simulated GPS points; never use as the production shuttle feed';
