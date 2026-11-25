-- 0002_rls.sql — read policies, revoked write grants (#27) and append-only
-- history (#28). docs/PLAN.md §5.2.
--
-- After this migration:
--   anon           reads nothing and writes nothing (no grants at all).
--   authenticated  reads the 5 tables (SELECT + a policy) and writes nothing
--                  directly: no INSERT/UPDATE/DELETE grant, so a REST
--                  `PATCH /rest/v1/patients` fails with "permission denied"
--                  (42501) instead of silently touching 0 rows.
--   writes         only through the SECURITY DEFINER RPCs in 0003_rpc.sql
--                  (transfer_patient for nurses, set_patient_status for
--                  doctors), which check the role themselves.
-- Realtime applies the same SELECT policies (PLAN §5.4).

-- Already on since 0001; repeated so this file states the whole rule.
alter table public.locations        enable row level security;
alter table public.profiles         enable row level security;
alter table public.patients         enable row level security;
alter table public.location_history enable row level security;
alter table public.status_history   enable row level security;

-- Signed-in staff read everything they need: wards, staff names and roles
-- (for "moved by"), patients and both history tables. Nobody else.
create policy read_locations on public.locations        for select to authenticated using (true);
create policy read_profiles  on public.profiles         for select to authenticated using (true);
create policy read_patients  on public.patients         for select to authenticated using (true);
create policy read_lhist     on public.location_history for select to authenticated using (true);
create policy read_shist     on public.status_history   for select to authenticated using (true);

-- Zero direct writes. There are no INSERT/UPDATE/DELETE policies, and the
-- grants are gone too, so the database refuses loudly. Supabase grants ALL
-- (incl. TRUNCATE, REFERENCES, TRIGGER) to anon and authenticated by
-- default: take everything away, then give back only SELECT.
revoke all on public.locations, public.profiles, public.patients,
              public.location_history, public.status_history
  from anon, authenticated;
grant select on public.locations, public.profiles, public.patients,
                public.location_history, public.status_history
  to authenticated;

-- Tables added by later migrations don't become readable by anon by
-- accident (a new table without RLS would otherwise be public).
alter default privileges in schema public revoke all on tables from anon;

-- History is append-only, for everyone (#28, PLAN §2 req. 22). The grants
-- above already stop app users; these triggers also stop the table owner and
-- anyone holding the service_role key "by accident" (dashboard, scripts).
-- Rows are only ever added, by the RPCs in 0003_rpc.sql.
create function public.forbid_history_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  raise exception 'History is append-only' using errcode = 'PT403',
    hint = format('%s on %s is not allowed; history rows are never changed or removed.',
                  tg_op, tg_table_name);
end
$$;

-- UPDATE and DELETE, row by row.
create trigger lhist_no_mutation before update or delete on public.location_history
  for each row execute function public.forbid_history_mutation();
create trigger shist_no_mutation before update or delete on public.status_history
  for each row execute function public.forbid_history_mutation();

-- TRUNCATE skips row triggers, so it needs its own statement trigger.
create trigger lhist_no_truncate before truncate on public.location_history
  for each statement execute function public.forbid_history_mutation();
create trigger shist_no_truncate before truncate on public.status_history
  for each statement execute function public.forbid_history_mutation();
