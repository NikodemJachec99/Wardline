-- RLS and RPC behaviour (#31, docs/PLAN.md §12.1). Run with `supabase test db`.
--
-- Covers: anon reads nothing; staff can't write tables directly (patients,
-- history, profiles); history can't be updated or deleted; transfer_patient
-- role checks, effects, PT401/403/404/409/422 and idempotency; the
-- set_patient_status rules not covered by 0003_set_patient_status_roles_test
-- (#60): PT409, PT422 and idempotency.
--
-- Written to stay valid when 0002_rls.sql lands (#27, #28): a refused direct
-- write is accepted either as "0 rows" (RLS without a policy, today) or as
-- insufficient_privilege (revoked grants / append-only triggers, later), and
-- every refusal is followed by a check that the data did not change.
-- Not covered yet (needs #27): authenticated staff CAN read patients.
begin;
create extension if not exists pgtap with schema extensions;
select plan(51);

-- ------------------------------------------------------------- fixtures
-- As the test owner (bypasses RLS). Fictional data only.
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'nurse1.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'doctor1.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a3', 'admin.test@wardline.test');
insert into public.locations (id, display_name, kind, floor, beds) values
  ('ER',  'Emergency Department', 'emergency',  0, 24),
  ('RAD', 'Radiology',            'diagnostic', 0, 14),
  ('INT', 'Internal Medicine',    'ward',       1, 32);
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'Test Nurse', 'nurse'),
  ('00000000-0000-4000-8000-0000000000a2', 'Test Doctor', 'doctor'),
  ('00000000-0000-4000-8000-0000000000a3', 'Test Admin', 'admin');
-- location_updated_at an hour ago: now() is fixed inside this transaction,
-- so the transfer's new timestamp must differ from the fixture's.
insert into public.patients
  (id, patient_code, first_name, last_name, age, condition, current_location, location_updated_at)
values
  ('00000000-0000-4000-8000-0000000000b1', 'HPT-7K3M9QX2', 'Jan', 'Test', 54, 'Test', 'ER', now() - interval '1 hour'),
  ('00000000-0000-4000-8000-0000000000b2', 'HPT-4QW8N2KD', 'Maria', 'Test', 67, 'Test', 'INT', now() - interval '1 hour');
-- One existing history row of each kind, to try to edit or delete.
insert into public.location_history (event_id, patient_id, from_location, to_location, updated_by) values
  ('00000000-0000-4000-8000-0000000000e1', '00000000-0000-4000-8000-0000000000b2', null, 'INT',
   '00000000-0000-4000-8000-0000000000a1');
insert into public.status_history (event_id, patient_id, from_status, to_status, changed_by) values
  ('00000000-0000-4000-8000-0000000000e2', '00000000-0000-4000-8000-0000000000b2', null, 'admitted',
   '00000000-0000-4000-8000-0000000000a2');

-- --------------------------------------------------------------- helpers
-- Acts as a signed-in user, like a request with that user's JWT.
create function pg_temp.sign_in_as(p_user uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- Runs one statement as the current role: 'ok' or the SQLSTATE it raised.
create function pg_temp.try_sql(p_sql text) returns text
language plpgsql as $$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

-- The DETAIL of the error a statement raises (null if it doesn't raise).
create function pg_temp.error_detail(p_sql text) returns text
language plpgsql as $$
declare v_detail text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_detail = pg_exception_detail;
  return v_detail;
end $$;

-- Rows of a table the current role can see (0 when it may not read it).
create function pg_temp.visible(p_table text) returns integer
language plpgsql as $$
declare v integer;
begin
  execute format('select count(*) from public.%I', p_table) into v;
  return v;
exception when insufficient_privilege then
  return 0;
end $$;

-- ======================================================= anon reads nothing
set local role anon;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
select is(pg_temp.visible('patients'), 0, 'anon sees no patients');
select is(pg_temp.visible('location_history'), 0, 'anon sees no transfer history');
select is(pg_temp.visible('status_history'), 0, 'anon sees no status history');
select is(pg_temp.visible('profiles'), 0, 'anon sees no staff profiles');
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000c0')$$,
  '42501', null, 'anon cannot execute transfer_patient');

-- ============================================ staff can't write tables directly
reset role;
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');  -- nurse

select ok(pg_temp.try_sql($$update public.patients set current_location = 'RAD', version = version + 1
    where id = '00000000-0000-4000-8000-0000000000b1'$$) in ('ok', '42501'),
  'nurse: direct UPDATE of a patient is refused or touches no row');
select ok(pg_temp.try_sql($$insert into public.location_history (patient_id, from_location, to_location, updated_by)
    values ('00000000-0000-4000-8000-0000000000b1', 'ER', 'RAD', '00000000-0000-4000-8000-0000000000a1')$$) = '42501',
  'nurse: direct INSERT into location_history is refused');
select ok(pg_temp.try_sql($$update public.location_history set to_location = 'RAD'
    where event_id = '00000000-0000-4000-8000-0000000000e1'$$) in ('ok', '42501'),
  'nurse: UPDATE of location_history is refused or touches no row');
select ok(pg_temp.try_sql($$delete from public.location_history
    where event_id = '00000000-0000-4000-8000-0000000000e1'$$) in ('ok', '42501'),
  'nurse: DELETE of location_history is refused or touches no row');
select ok(pg_temp.try_sql($$update public.profiles set role = 'admin'
    where id = '00000000-0000-4000-8000-0000000000a1'$$) in ('ok', '42501'),
  'nurse: changing her own role is refused or touches no row');

select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');  -- doctor
select ok(pg_temp.try_sql($$update public.status_history set to_status = 'discharged'
    where event_id = '00000000-0000-4000-8000-0000000000e2'$$) in ('ok', '42501'),
  'doctor: UPDATE of status_history is refused or touches no row');
select ok(pg_temp.try_sql($$delete from public.status_history
    where event_id = '00000000-0000-4000-8000-0000000000e2'$$) in ('ok', '42501'),
  'doctor: DELETE of status_history is refused or touches no row');
select ok(pg_temp.try_sql($$update public.patients set status = 'discharged'
    where id = '00000000-0000-4000-8000-0000000000b1'$$) in ('ok', '42501'),
  'doctor: direct UPDATE of a status is refused or touches no row');

-- Nothing above changed anything.
reset role;
select is((select current_location from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'ER', 'patient location unchanged after direct writes');
select is((select status::text from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'admitted', 'patient status unchanged after direct writes');
select is((select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'patient version unchanged after direct writes');
select is((select count(*)::int from public.location_history), 1, 'location_history still has its one row');
select is((select to_location from public.location_history where event_id = '00000000-0000-4000-8000-0000000000e1'),
  'INT', 'the transfer history row was not edited');
select is((select count(*)::int from public.status_history), 1, 'status_history still has its one row');
select is((select to_status::text from public.status_history where event_id = '00000000-0000-4000-8000-0000000000e2'),
  'admitted', 'the status history row was not edited');
select is((select role::text from public.profiles where id = '00000000-0000-4000-8000-0000000000a1'),
  'nurse', 'the nurse is still a nurse');

-- ===================================================== transfer_patient roles
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');  -- doctor
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000c1')$$,
  'PT403', 'FORBIDDEN', 'a doctor cannot move a patient (PT403)');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');  -- admin
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000c2')$$,
  'PT403', 'FORBIDDEN', 'an admin cannot move a patient (PT403)');
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000c3')$$,
  'PT401', 'UNAUTHENTICATED', 'no session cannot move a patient (PT401)');
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');  -- nurse
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 1,
      '00000000-0000-4000-8000-0000000000c4')$$,
  'PT403', 'FORBIDDEN', 'a nurse cannot change status (PT403, see also #60)');

-- ================================================ transfer_patient PT404/422
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-00000000ffff', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000c5')$$,
  'PT404', 'UNKNOWN_PATIENT', 'unknown patient (PT404)');
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'XYZ', 1,
      '00000000-0000-4000-8000-0000000000c6')$$,
  'PT422', 'INVALID_LOCATION', 'unknown department (PT422)');
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'ER', 1,
      '00000000-0000-4000-8000-0000000000c7')$$,
  'PT422', 'SAME_LOCATION', 'moving to the current department (PT422)');
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1, null)$$,
  'PT422', 'REQUEST_ID_REQUIRED', 'a transfer without a request id (PT422)');

-- ============================================ transfer_patient: the happy path
select lives_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000d1', 'NFC')$$,
  'a nurse moves a patient');

reset role;
select is((select current_location from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'RAD', 'the patient is in the new department');
select is((select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  2, 'the version moved by one');
select is((select location_updated_at from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  now(), 'location_updated_at is the server time of the transfer');
select is((select status::text from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'admitted', 'a transfer does not change the status');
select is((select count(*)::int from public.location_history
    where patient_id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'exactly one history row for the transfer');
select results_eq(
  $$select from_location, to_location, updated_by, identified_by, created_at
      from public.location_history where client_request_id = '00000000-0000-4000-8000-0000000000d1'$$,
  $$values ('ER'::text, 'RAD'::text, '00000000-0000-4000-8000-0000000000a1'::uuid, 'NFC'::text, now())$$,
  'the history row has from, to, the nurse from the session and server time');

-- ======================================================= idempotency (transfer)
-- Same request again (double tap, "Check status" after a timeout), even with
-- the now-stale version 1: the same event comes back, nothing new is written.
-- The nurse can't read history (RLS), so keep the returned id and compare
-- it as the owner.
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select set_config('wardline_test.retry_event',
  (public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'RAD', 1,
    '00000000-0000-4000-8000-0000000000d1')).event_id::text, true);
reset role;
select is(
  current_setting('wardline_test.retry_event')::uuid,
  (select event_id from public.location_history where client_request_id = '00000000-0000-4000-8000-0000000000d1'),
  'the same request id returns the same transfer event');
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b2', 'RAD', 1,
      '00000000-0000-4000-8000-0000000000d1')$$,
  'PT422', 'REQUEST_ID_REUSED', 'a request id used for another patient (PT422)');

-- ============================================================ conflict PT409
-- Another device already moved the patient (version is 2 now).
select throws_ok(
  $$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'INT', 1,
      '00000000-0000-4000-8000-0000000000d2')$$,
  'PT409', 'STALE_VERSION', 'a transfer with a stale version is a conflict (PT409)');
select is(
  pg_temp.error_detail($$select public.transfer_patient('00000000-0000-4000-8000-0000000000b1', 'INT', 1,
      '00000000-0000-4000-8000-0000000000d3')$$)::jsonb,
  '{"current_location": "RAD", "status": "admitted", "version": 2}'::jsonb,
  'the conflict says where the patient is now, for the conflict screen');

reset role;
select is((select count(*)::int from public.location_history
    where patient_id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'retries and conflicts wrote no extra transfer rows');
select is((select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  2, 'retries and conflicts did not move the version');

-- ================================================ set_patient_status: 409/422
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');  -- doctor
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 1,
      '00000000-0000-4000-8000-0000000000f1')$$,
  'PT409', 'STALE_VERSION', 'a status change with a stale version is a conflict (PT409)');
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'admitted', 2,
      '00000000-0000-4000-8000-0000000000f2')$$,
  'PT422', 'SAME_STATUS', 'setting the current status (PT422)');
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'discharged', 2,
      '00000000-0000-4000-8000-0000000000f3', '  ')$$,
  'PT422', 'REASON_REQUIRED', 'discharging without a reason (PT422)');
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 2, null)$$,
  'PT422', 'REQUEST_ID_REQUIRED', 'a status change without a request id (PT422)');

-- ===================================================== idempotency (status)
select lives_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 2,
      '00000000-0000-4000-8000-0000000000f4')$$,
  'a doctor changes the status');
select set_config('wardline_test.retry_status',
  (public.set_patient_status('00000000-0000-4000-8000-0000000000b1', 'in_treatment', 2,
    '00000000-0000-4000-8000-0000000000f4')).event_id::text, true);

reset role;
select is(
  current_setting('wardline_test.retry_status')::uuid,
  (select event_id from public.status_history where client_request_id = '00000000-0000-4000-8000-0000000000f4'),
  'the same request id returns the same status event');
select is((select count(*)::int from public.status_history
    where patient_id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'exactly one status history row despite the retry');
select is((select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  3, 'one status change moved the shared version once');
select is((select current_location from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'RAD', 'a status change does not move the patient');

select * from finish();
rollback;
