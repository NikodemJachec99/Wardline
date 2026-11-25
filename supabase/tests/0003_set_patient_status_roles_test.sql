-- Permission rule: only a doctor changes a patient's status (#60).
-- Matrix row "Zmiana statusu pacjenta" (docs/PLAN.md §2.2): Nurse no,
-- Doctor yes, Admin no, Anon no. This is acceptance test 5 ("bypass UI"):
-- the rule is enforced by the database, not by hiding a button.
--
-- How it is enforced: set_patient_status() is SECURITY DEFINER and checks
-- current_user_role() (PT403 for other roles, PT401 without a session);
-- EXECUTE is revoked from anon; RLS on patients has no write policy, so a
-- direct UPDATE changes nothing. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

-- Fixtures (as the test owner, bypassing RLS). Fictional data only.
insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-0000000000a1', 'nurse.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a2', 'doctor.test@wardline.test'),
  ('00000000-0000-4000-8000-0000000000a3', 'admin.test@wardline.test');
insert into public.locations (id, display_name, kind, floor, beds)
  values ('TST', 'Test ward', 'ward', 1, 4);
insert into public.profiles (id, full_name, role) values
  ('00000000-0000-4000-8000-0000000000a1', 'Test Nurse', 'nurse'),
  ('00000000-0000-4000-8000-0000000000a2', 'Test Doctor', 'doctor'),
  ('00000000-0000-4000-8000-0000000000a3', 'Test Admin', 'admin');
insert into public.patients (id, patient_code, first_name, last_name, age, condition, current_location)
  values ('00000000-0000-4000-8000-0000000000b1', 'HPT-7K3M9QX2', 'Jan', 'Test', 54, 'Test', 'TST');

-- Acts as a signed-in user, like a request with that user's JWT.
create function pg_temp.sign_in_as(p_user uuid) returns void
language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

-- 1. Nurse: the RPC refuses with PT403.
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a1');
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1',
      'in_treatment', 1, '00000000-0000-4000-8000-0000000000c1')$$,
  'PT403', 'FORBIDDEN', 'a nurse cannot change status (PT403)');

-- 2. Nurse: a direct UPDATE (bypassing the app) does not raise anything
--    unexpected. Today RLS filters it to 0 rows; once grants are revoked
--    (#27) it raises insufficient_privilege. Either way nothing changes,
--    which is checked below.
select lives_ok(
  $$do $d$ begin
      update public.patients set status = 'discharged', version = version + 1
       where id = '00000000-0000-4000-8000-0000000000b1';
    exception when insufficient_privilege then null;
    end $d$$$,
  'a nurse''s direct UPDATE on patients is not an error path into the data');

-- 3. Admin manages people, not patients: PT403 too.
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a3');
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1',
      'in_treatment', 1, '00000000-0000-4000-8000-0000000000c2')$$,
  'PT403', 'FORBIDDEN', 'an admin cannot change status (PT403)');

-- 4. Authenticated role but no user in the token: PT401.
select set_config('request.jwt.claims', '{"role": "authenticated"}', true);
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1',
      'in_treatment', 1, '00000000-0000-4000-8000-0000000000c3')$$,
  'PT401', 'UNAUTHENTICATED', 'no session cannot change status (PT401)');

-- 5. Anon (no JWT at all): may not even call the function.
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
select throws_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1',
      'in_treatment', 1, '00000000-0000-4000-8000-0000000000c4')$$,
  '42501', null, 'anon cannot execute set_patient_status');

-- 6-8. After every refused attempt the patient is untouched.
reset role;
select is(
  (select status::text from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'admitted', 'refused attempts left the status unchanged');
select is(
  (select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  1, 'refused attempts left the version unchanged');
select is(
  (select count(*)::int from public.status_history),
  0, 'refused attempts wrote no status history');

-- 9. Doctor: allowed.
set local role authenticated;
select pg_temp.sign_in_as('00000000-0000-4000-8000-0000000000a2');
select lives_ok(
  $$select public.set_patient_status('00000000-0000-4000-8000-0000000000b1',
      'in_treatment', 1, '00000000-0000-4000-8000-0000000000c5')$$,
  'a doctor can change status');

-- 10-13. Exactly one change, attributed to the doctor by the server.
reset role;
select is(
  (select status::text from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  'in_treatment', 'the doctor''s change is saved');
select is(
  (select version from public.patients where id = '00000000-0000-4000-8000-0000000000b1'),
  2, 'the version moved by one');
select is(
  (select count(*)::int from public.status_history),
  1, 'exactly one status history row');
select is(
  (select changed_by from public.status_history),
  '00000000-0000-4000-8000-0000000000a2'::uuid,
  'the history row names the doctor from the session (auth.uid())');

select * from finish();
rollback;
