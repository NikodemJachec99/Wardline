-- Append-only history (#28, docs/PLAN.md §5.2, §2 req. 22).
-- UPDATE, DELETE and TRUNCATE on location_history and status_history fail
-- with PT403 for everyone: the table owner, service_role and app users.
-- Adding rows (the RPCs) still works. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_trigger('public', 'location_history', 'lhist_no_mutation', 'location_history: no update/delete trigger');
select has_trigger('public', 'status_history',   'shist_no_mutation', 'status_history: no update/delete trigger');
select has_trigger('public', 'location_history', 'lhist_no_truncate', 'location_history: no truncate trigger');
select has_trigger('public', 'status_history',   'shist_no_truncate', 'status_history: no truncate trigger');

-- Fixtures, as the table owner. Fictional data only.
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'nurse1.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'doctor1.test@wardline.test');
insert into public.locations (id, display_name, kind, floor, beds) values
  ('ER', 'Emergency Department', 'emergency', 0, 24),
  ('RAD', 'Radiology', 'diagnostic', 0, 14),
  ('INT', 'Internal Medicine', 'ward', 1, 32);
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'Test Nurse', 'nurse'),
  ('00000000-0000-4000-8000-0000000000a2', 'Test Doctor', 'doctor');
insert into public.patients (id, patient_code, first_name, last_name, age, condition, current_location)
  values ('00000000-0000-4000-8000-0000000000b1', 'HPT-7K3M9QX2', 'Jan', 'Test', 54, 'Test', 'ER');
insert into public.location_history (event_id, patient_id, from_location, to_location, updated_by) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b1', null, 'ER',
   '00000000-0000-4000-8000-0000000000a1');
insert into public.status_history (event_id, patient_id, from_status, to_status, changed_by) values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b1', null, 'admitted',
   '00000000-0000-4000-8000-0000000000a2');

-- ------------------------------------------------- the table owner
select throws_ok(
  $$update public.location_history set to_location = 'RAD' where event_id = '00000000-0000-4000-8000-0000000000e1'$$,
  'PT403', 'History is append-only', 'owner: UPDATE location_history fails (PT403)');
select throws_ok(
  $$delete from public.location_history where event_id = '00000000-0000-4000-8000-0000000000e1'$$,
  'PT403', 'History is append-only', 'owner: DELETE location_history fails (PT403)');
select throws_ok(
  $$update public.status_history set to_status = 'discharged' where event_id = '00000000-0000-4000-8000-0000000000e2'$$,
  'PT403', 'History is append-only', 'owner: UPDATE status_history fails (PT403)');
select throws_ok(
  $$delete from public.status_history where event_id = '00000000-0000-4000-8000-0000000000e2'$$,
  'PT403', 'History is append-only', 'owner: DELETE status_history fails (PT403)');
select throws_ok(
  $$truncate public.location_history$$,
  'PT403', 'History is append-only', 'owner: TRUNCATE location_history fails (PT403)');
select throws_ok(
  $$truncate public.status_history$$,
  'PT403', 'History is append-only', 'owner: TRUNCATE status_history fails (PT403)');

-- --------------------------- service_role (bypasses RLS, has grants)
set local role service_role;
select throws_ok(
  $$update public.location_history set to_location = 'RAD' where event_id = '00000000-0000-4000-8000-0000000000e1'$$,
  'PT403', 'History is append-only', 'service_role: UPDATE location_history fails (PT403)');
select throws_ok(
  $$delete from public.status_history where event_id = '00000000-0000-4000-8000-0000000000e2'$$,
  'PT403', 'History is append-only', 'service_role: DELETE status_history fails (PT403)');

-- --------------------------- app users are stopped earlier, by the grants
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-0000000000a2', 'role', 'authenticated')::text, true);
select throws_ok(
  $$delete from public.status_history where event_id = '00000000-0000-4000-8000-0000000000e2'$$,
  '42501', null, 'doctor: DELETE status_history fails (no grant)');

reset role;
select results_eq(
  $$select to_location from public.location_history$$,
  $$values ('ER'::text)$$,
  'location_history is unchanged');
select results_eq(
  $$select to_status::text from public.status_history$$,
  $$values ('admitted'::text)$$,
  'status_history is unchanged');

-- ----------------------------------------------- adding rows still works
select lives_ok(
  $$insert into public.location_history (patient_id, from_location, to_location, updated_by)
    values ('00000000-0000-4000-8000-0000000000b1', 'ER', 'INT', '00000000-0000-4000-8000-0000000000a1')$$,
  'owner: INSERT into history still works (append)');

set local role authenticated;
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-0000000000a1', 'role', 'authenticated')::text, true);
select lives_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000d1')$$,
  'transfer_patient still appends history');
select set_config('request.jwt.claims',
  json_build_object('sub', '00000000-0000-4000-8000-0000000000a2', 'role', 'authenticated')::text, true);
select lives_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 2,
      '00000000-0000-4000-8000-0000000000d2')$$,
  'set_patient_status still appends status history');

reset role;
select is((select count(*)::int from public.location_history), 3,
  'location_history grew by the owner insert and the RPC transfer');
select is((select count(*)::int from public.status_history), 2,
  'status_history grew by the RPC status change');

select * from finish();
rollback;
