-- 0001_schema.sql — Wardline schema (docs/PLAN.md §5.1). Issue #14.
-- SIMULATION ONLY: the app stores fictional patients.
--
-- RLS is enabled at the end of this file with no policies (deny by default).
-- Read policies, revoked grants and append-only history are 0002_rls.sql
-- (#27, #28). RPCs are 0003_rpc.sql (#29, #30).

create extension if not exists pg_trgm with schema extensions;

create type public.user_role      as enum ('nurse', 'doctor', 'admin');
create type public.patient_status as enum ('admitted', 'in_treatment', 'ready_for_discharge', 'discharged');
create type public.location_kind  as enum ('emergency', 'ward', 'diagnostic', 'lab', 'surgery', 'icu', 'other');

-- Departments. map_* = floor-plan rectangle in design units (10 x 6 per floor,
-- design/handoff/sample-data.json), used by the hospital map.
create table public.locations (
  id           text primary key check (id ~ '^[A-Z]{2,4}$'),   -- 'ER', 'RAD', 'INT', ...
  display_name text not null,
  short_name   text,
  kind         public.location_kind not null,
  floor        smallint not null check (floor between 0 and 20),  -- 0 = ground
  beds         smallint not null default 0 check (beds >= 0),
  map_x numeric, map_y numeric, map_w numeric, map_h numeric
);

-- One row per staff account. The role is set by an admin / trusted seed only
-- (#17, #18): the app never updates it (no UPDATE grant or policy, see 0002).
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null check (length(trim(full_name)) > 0),
  role          public.user_role not null,
  initials      text generated always as (
                  upper(left(split_part(full_name, ' ', 1), 1) || left(split_part(full_name, ' ', 2), 1))
                ) stored,
  home_location text references public.locations (id),
  shift_label   text
);

create table public.patients (
  id                  uuid primary key default gen_random_uuid(),
  patient_code        text not null unique
                      check (patient_code ~ '^HPT-[0-9A-HJKMNP-TV-Z]{8}$'),
  first_name          text not null,
  last_name           text not null,
  age                 smallint not null check (age between 0 and 120),
  condition           text not null,
  admission_date      timestamptz not null default now(),
  current_location    text not null references public.locations (id),
  status              public.patient_status not null default 'admitted',
  last_updated        timestamptz not null default now(),
  location_updated_at timestamptz not null default now(),
  -- Shared optimistic-lock version for location AND status (PLAN §5.3 decision).
  version             integer not null default 1 check (version >= 1)
);
create index patients_name_trgm on public.patients
  using gin ((first_name || ' ' || last_name) extensions.gin_trgm_ops);
create index patients_location_idx on public.patients (current_location);

-- Transfers. from_location null = admission. created_at is server time.
create table public.location_history (
  event_id          uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references public.patients (id),
  from_location     text references public.locations (id),
  to_location       text not null references public.locations (id),
  created_at        timestamptz not null default now(),
  updated_by        uuid not null references public.profiles (id),
  -- How the nurse opened the record: 'NFC', 'QR' or 'Search' (audit only).
  identified_by     text check (identified_by in ('NFC', 'QR', 'Search')),
  client_request_id uuid unique,
  check (from_location is distinct from to_location)
);
create index location_history_patient_idx on public.location_history (patient_id, created_at);
create index location_history_to_idx on public.location_history (to_location, created_at);
create index location_history_from_idx on public.location_history (from_location, created_at);

create table public.status_history (
  event_id          uuid primary key default gen_random_uuid(),
  patient_id        uuid not null references public.patients (id),
  from_status       public.patient_status,
  to_status         public.patient_status not null,
  reason            text,
  created_at        timestamptz not null default now(),
  changed_by        uuid not null references public.profiles (id),
  client_request_id uuid unique,
  check (from_status is distinct from to_status)
);
create index status_history_patient_idx on public.status_history (patient_id, created_at);

-- Role of the signed-in user (null without a session or profile). Used by the
-- RPCs and by RLS policies (#27). SECURITY DEFINER so it works even when the
-- caller can't read profiles.
create function public.current_user_role()
returns public.user_role
language sql stable security definer set search_path = public, pg_temp
as $$ select role from public.profiles where id = auth.uid() $$;

revoke all on function public.current_user_role() from public, anon;
grant execute on function public.current_user_role() to authenticated;

-- Locked by default: RLS on, no policies yet, so anon/authenticated read and
-- write nothing directly (the RPCs in 0003 are SECURITY DEFINER and
-- still work). Read policies, revoked grants and append-only triggers come
-- in 0002_rls.sql (#27, #28).
alter table public.locations        enable row level security;
alter table public.profiles         enable row level security;
alter table public.patients         enable row level security;
alter table public.location_history enable row level security;
alter table public.status_history   enable row level security;
