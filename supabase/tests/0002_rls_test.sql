-- 0002_rls.sql (#27): read policies and revoked write grants.
-- Acceptance: RLS on all 5 tables; staff read, nobody writes directly
-- (PATCH /rest/v1/patients → permission denied); anon reads nothing;
-- the RPCs still work. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(31);

-- ------------------------------------------------------------ structure
select ok((select relrowsecurity from pg_class where oid = 'public.locations'::regclass),        'RLS on locations');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),         'RLS on profiles');
select ok((select relrowsecurity from pg_class where oid = 'public.patients'::regclass),         'RLS on patients');
select ok((select relrowsecurity from pg_class where oid = 'public.location_history'::regclass), 'RLS on location_history');
select ok((select relrowsecurity from pg_class where oid = 'public.status_history'::regclass),   'RLS on status_history');

-- Only read policies: no table has an INSERT/UPDATE/DELETE policy.
select policies_are('public', 'locations',        array['read_locations'], 'locations: read policy only');
select policies_are('public', 'profiles',         array['read_profiles'],  'profiles: read policy only');
select policies_are('public', 'patients',         array['read_patients'],  'patients: read policy only');
select policies_are('public', 'location_history', array['read_lhist'],     'location_history: read policy only');
select policies_are('public', 'status_history',   array['read_shist'],     'status_history: read policy only');

select table_privs_are('public', 'locations',        'authenticated', array['SELECT'], 'authenticated: SELECT only on locations');
select table_privs_are('public', 'profiles',         'authenticated', array['SELECT'], 'authenticated: SELECT only on profiles');
select table_privs_are('public', 'patients',         'authenticated', array['SELECT'], 'authenticated: SELECT only on patients');
select table_privs_are('public', 'location_history', 'authenticated', array['SELECT'], 'authenticated: SELECT only on location_history');
select table_privs_are('public', 'status_history',   'authenticated', array['SELECT'], 'authenticated: SELECT only on status_history');

select table_privs_are('public', 'locations',        'anon', array[]::text[], 'anon: no privileges on locations');
select table_privs_are('public', 'profiles',         'anon', array[]::text[], 'anon: no privileges on profiles');
select table_privs_are('public', 'patients',         'anon', array[]::text[], 'anon: no privileges on patients');
select table_privs_are('public', 'location_history', 'anon', array[]::text[], 'anon: no privileges on location_history');
select table_privs_are('public', 'status_history',   'anon', array[]::text[], 'anon: no privileges on status_history');

-- ------------------------------------------------------------- fixtures
-- As the test owner. Fictional data only.
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'nurse1.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'doctor1.test@wardline.test');
insert into public.locations (id, display_name, kind, floor, beds) values
  ('ER', 'Emergency Department', 'emergency', 0, 24),
  ('RAD', 'Radiology', 'diagnostic', 0, 14);
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'Test Nurse', 'nurse'),
  ('00000000-0000-4000-8000-0000000000a2', 'Test Doctor', 'doctor');
insert into public.patients (id, patient_code, first_name, last_name, age, condition, current_location)
  values ('00000000-0000-4000-8000-0000000000b1', 'HPT-7K3M9QX2', 'Jan', 'Test', 54, 'Test', 'ER');
insert into public.status_history (event_id, patient_id, from_status, to_status, changed_by) values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', null, 'admitted',
   '00000000-0000-4000-8000-0000000000a2');

create function pg_temp.sign_in_as(p_user uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- --------------------------------------------------------- staff read
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');  -- nurse
select is((select count(*)::int from public.patients), 1, 'a nurse reads patients');
select is((select count(*)::int from public.profiles), 2, 'a nurse reads staff profiles (names for "moved by")');

-- ------------------------------------------- no direct writes, loudly
select throws_ok(
  $$update public.patients set current_location = 'RAD' where id = '00000000-0000-4000-8000-0000000000b1'$$,
  '42501', null, 'a direct UPDATE of patients is "permission denied" (REST PATCH)');
select throws_ok(
  $$insert into public.location_history (patient_id, from_location, to_location, updated_by)
    values ('00000000-0000-4000-8000-0000000000b1', 'ER', 'RAD', '00000000-0000-4000-8000-0000000000a1')$$,
  '42501', null, 'a direct INSERT into location_history is "permission denied"');
select throws_ok(
  $$delete from public.status_history where event_id = '00000000-0000-4000-8000-0000000000e2'$$,
  '42501', null, 'a direct DELETE from status_history is "permission denied"');
select throws_ok(
  $$update public.profiles set role = 'admin' where id = '00000000-0000-4000-8000-0000000000a1'$$,
  '42501', null, 'a nurse cannot make herself admin');

-- ----------------------------------------------------- anon reads nothing
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
select throws_ok(
  $$select count(*) from public.patients$$,
  '42501', null, 'anon cannot read patients');

-- ------------------------------------------- the RPCs still work
reset role;
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select lives_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000d1')$$,
  'transfer_patient still works for a nurse (SECURITY DEFINER)');
select is((select count(*)::int from public.location_history), 1,
  'the nurse reads the new history row');
select is((select current_location from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'RAD', 'the patient moved, through the RPC only');
select is((select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  2, 'refused direct writes did not touch the version');

select * from finish();
rollback;
