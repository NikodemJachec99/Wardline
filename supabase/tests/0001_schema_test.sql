-- Schema smoke test (issue #14). RLS and RPC behaviour tests belong to #31.
begin;
create extension if not exists pgtap with schema extensions;
select plan(20);

select has_table('public', 'locations', 'locations exists');
select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'patients', 'patients exists');
select has_table('public', 'location_history', 'location_history exists');
select has_table('public', 'status_history', 'status_history exists');

select has_enum('public', 'user_role', 'user_role enum exists');
select enum_has_labels('public', 'patient_status',
  array['admitted', 'in_treatment', 'ready_for_discharge', 'discharged'],
  'patient_status has the four statuses in order');

select col_is_unique('public', 'patients', 'patient_code', 'patient_code is unique');
select col_is_unique('public', 'location_history', 'client_request_id', 'transfer request id is unique (idempotency)');
select col_is_unique('public', 'status_history', 'client_request_id', 'status request id is unique (idempotency)');

-- patient_code format: HPT- + 8 Crockford Base32 characters (no I, L, O, U).
select lives_ok(
  $$insert into public.locations (id, display_name, kind, floor, beds) values ('TST', 'Test ward', 'ward', 1, 4)$$,
  'a location can be created');
select lives_ok(
  $$insert into public.patients (patient_code, first_name, last_name, age, condition, current_location)
    values ('HPT-7K3M9QX2', 'Jan', 'Test', 54, 'Test', 'TST')$$,
  'a valid patient code is accepted');
select throws_ok(
  $$insert into public.patients (patient_code, first_name, last_name, age, condition, current_location)
    values ('HPT-7K3M9QXL', 'Bad', 'Code', 54, 'Test', 'TST')$$,
  '23514', null, 'a code with L is rejected by the CHECK');
select throws_ok(
  $$insert into public.patients (patient_code, first_name, last_name, age, condition, current_location)
    values ('hpt-7k3m9qx3', 'Lower', 'Case', 54, 'Test', 'TST')$$,
  '23514', null, 'a lower-case code is rejected (the app normalises first)');

select has_function('public', 'transfer_patient',
  array['uuid', 'text', 'integer', 'uuid', 'text'], 'transfer_patient exists');
select is_definer('public', 'transfer_patient',
  array['uuid', 'text', 'integer', 'uuid', 'text'], 'transfer_patient is SECURITY DEFINER');
select has_function('public', 'set_patient_status',
  array['uuid', 'patient_status', 'integer', 'uuid', 'text'], 'set_patient_status exists');
select is_definer('public', 'set_patient_status',
  array['uuid', 'patient_status', 'integer', 'uuid', 'text'], 'set_patient_status is SECURITY DEFINER');
select function_privs_are('public', 'transfer_patient',
  array['uuid', 'text', 'integer', 'uuid', 'text'], 'anon', array[]::text[],
  'anon cannot call transfer_patient');
select function_privs_are('public', 'set_patient_status',
  array['uuid', 'patient_status', 'integer', 'uuid', 'text'], 'anon', array[]::text[],
  'anon cannot call set_patient_status');

select * from finish();
rollback;
