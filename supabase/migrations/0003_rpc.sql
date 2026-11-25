-- 0003_rpc.sql — the only write paths (docs/PLAN.md §5.3). Issues #29, #30.
--
-- Error codes, mapped in the app (app/lib/domain/failures.dart):
--   PT401 no session · PT403 wrong role · PT404 unknown patient
--   PT409 stale version (conflict, never auto-retry) · PT422 invalid request
-- Time and actor always come from the server: now() and auth.uid(); the
-- client never sends them. One client_request_id per user intent makes
-- retries (double tap, "Check status" after a timeout) return the same event.

create function public.transfer_patient(
  p_patient_id       uuid,
  p_to               text,
  p_expected_version integer,
  p_request_id       uuid,
  p_identified_by    text default null
)
returns public.location_history
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.user_role;
  v_pat  public.patients;
  v_evt  public.location_history;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'PT401';
  end if;
  v_role := public.current_user_role();
  if v_role is distinct from 'nurse' then
    raise exception 'FORBIDDEN' using errcode = 'PT403',
      hint = 'Only nurses can move patients.';
  end if;
  if p_request_id is null then
    raise exception 'REQUEST_ID_REQUIRED' using errcode = 'PT422';
  end if;
  if not exists (select 1 from public.locations where id = p_to) then
    raise exception 'INVALID_LOCATION' using errcode = 'PT422';
  end if;

  -- Row lock: concurrent transfers of the same patient run one after another.
  select * into v_pat from public.patients where id = p_patient_id for update;
  if not found then
    raise exception 'UNKNOWN_PATIENT' using errcode = 'PT404';
  end if;

  -- Idempotency: same request = same event, even if the version moved on.
  select * into v_evt from public.location_history where client_request_id = p_request_id;
  if found then
    if v_evt.patient_id <> p_patient_id then
      raise exception 'REQUEST_ID_REUSED' using errcode = 'PT422';
    end if;
    return v_evt;
  end if;

  if v_pat.version <> p_expected_version then
    raise exception 'STALE_VERSION' using errcode = 'PT409',
      detail = json_build_object(
        'current_location', v_pat.current_location,
        'status', v_pat.status,
        'version', v_pat.version
      )::text;
  end if;
  if v_pat.current_location = p_to then
    raise exception 'SAME_LOCATION' using errcode = 'PT422';
  end if;

  update public.patients
     set current_location    = p_to,
         location_updated_at = now(),
         last_updated        = now(),
         version             = version + 1
   where id = p_patient_id;

  insert into public.location_history
    (patient_id, from_location, to_location, updated_by, identified_by, client_request_id)
  values
    (p_patient_id, v_pat.current_location, p_to, auth.uid(), p_identified_by, p_request_id)
  returning * into v_evt;

  return v_evt;  -- both changes or neither: one transaction
end
$$;

create function public.set_patient_status(
  p_patient_id       uuid,
  p_status           public.patient_status,
  p_expected_version integer,
  p_request_id       uuid,
  p_reason           text default null
)
returns public.status_history
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_role public.user_role;
  v_pat  public.patients;
  v_evt  public.status_history;
begin
  if auth.uid() is null then
    raise exception 'UNAUTHENTICATED' using errcode = 'PT401';
  end if;
  v_role := public.current_user_role();
  if v_role is distinct from 'doctor' then
    raise exception 'FORBIDDEN' using errcode = 'PT403',
      hint = 'Only doctors can change a patient''s status.';
  end if;
  if p_request_id is null then
    raise exception 'REQUEST_ID_REQUIRED' using errcode = 'PT422';
  end if;

  select * into v_pat from public.patients where id = p_patient_id for update;
  if not found then
    raise exception 'UNKNOWN_PATIENT' using errcode = 'PT404';
  end if;

  select * into v_evt from public.status_history where client_request_id = p_request_id;
  if found then
    if v_evt.patient_id <> p_patient_id then
      raise exception 'REQUEST_ID_REUSED' using errcode = 'PT422';
    end if;
    return v_evt;
  end if;

  if v_pat.version <> p_expected_version then
    raise exception 'STALE_VERSION' using errcode = 'PT409',
      detail = json_build_object(
        'current_location', v_pat.current_location,
        'status', v_pat.status,
        'version', v_pat.version
      )::text;
  end if;
  if v_pat.status = p_status then
    raise exception 'SAME_STATUS' using errcode = 'PT422';
  end if;
  -- Design: discharging is destructive and needs a reason.
  if p_status = 'discharged' and coalesce(trim(p_reason), '') = '' then
    raise exception 'REASON_REQUIRED' using errcode = 'PT422';
  end if;

  update public.patients
     set status = p_status, last_updated = now(), version = version + 1
   where id = p_patient_id;

  insert into public.status_history
    (patient_id, from_status, to_status, reason, changed_by, client_request_id)
  values
    (p_patient_id, v_pat.status, p_status, nullif(trim(p_reason), ''), auth.uid(), p_request_id)
  returning * into v_evt;

  return v_evt;
end
$$;

revoke all on function public.transfer_patient(uuid, text, integer, uuid, text) from public, anon;
revoke all on function public.set_patient_status(uuid, public.patient_status, integer, uuid, text) from public, anon;
grant execute on function public.transfer_patient(uuid, text, integer, uuid, text) to authenticated;
grant execute on function public.set_patient_status(uuid, public.patient_status, integer, uuid, text) to authenticated;
