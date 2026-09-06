create or replace function public.sync_cashbook_state(
  p_event_id text,
  p_snapshot jsonb,
  p_base_version bigint,
  p_operation_id text,
  p_entity text,
  p_entity_id text,
  p_action text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_current public.cashbook_states%rowtype;
  v_event jsonb;
  v_active_count integer;
  v_payments_started boolean;
begin
  if v_user_id is null or not private.is_event_member(p_event_id) then
    raise exception 'event access denied';
  end if;
  if p_operation_id is null or p_snapshot is null or p_snapshot->'event' is null then
    raise exception 'operation id and cashbook snapshot are required';
  end if;

  select * into v_current
  from public.cashbook_states
  where event_id = p_event_id
  for update;

  if not found then
    raise exception 'event state not found';
  end if;

  if exists (
    select 1 from public.audit_entries
    where event_id = p_event_id
      and operation_id = p_operation_id
      and actor_id = v_user_id
  ) then
    return jsonb_build_object(
      'status', 'ok',
      'version', v_current.version,
      'snapshot', v_current.snapshot,
      'updated_by', v_current.updated_by,
      'updated_at', v_current.updated_at
    );
  end if;

  if v_current.version <> p_base_version then
    return jsonb_build_object(
      'status', 'conflict',
      'version', v_current.version,
      'snapshot', v_current.snapshot,
      'updated_by', v_current.updated_by,
      'updated_at', v_current.updated_at
    );
  end if;

  v_event := p_snapshot->'event';
  if coalesce(v_event->>'id', '') <> p_event_id then
    raise exception 'snapshot event id does not match target event';
  end if;
  if char_length(trim(coalesce(v_event->>'name', ''))) not between 1 and 120 then
    raise exception 'event name is required and must be at most 120 characters';
  end if;
  if split_part(v_event->>'endDate', 'T', 1)::date <
      split_part(v_event->>'startDate', 'T', 1)::date then
    raise exception 'event end date must be on or after start date';
  end if;
  if (v_event->>'participantCapacity')::integer <= 0 or
      (v_event->>'finalBudget')::bigint < 0 or
      coalesce((v_event->>'sponsorContribution')::bigint, 0) < 0 or
      coalesce((v_event->>'openingBalance')::bigint, 0) < 0 then
    raise exception 'event capacity and financial values are invalid';
  end if;

  select count(*) into v_active_count
  from jsonb_array_elements(coalesce(p_snapshot->'participants', '[]'::jsonb)) item
  where coalesce(item->>'state', 'active') = 'active';
  if (v_event->>'participantCapacity')::integer < v_active_count then
    raise exception 'event capacity is below the active participant count';
  end if;

  select exists (
    select 1
    from jsonb_array_elements(
      coalesce(v_current.snapshot->'transactions', '[]'::jsonb)
    ) item
    where item->>'type' = 'participantPayment'
  ) into v_payments_started;
  if v_payments_started and (
    coalesce(v_event->>'sponsorName', '') <>
      coalesce(v_current.snapshot#>>'{event,sponsorName}', '') or
    coalesce((v_event->>'sponsorContribution')::bigint, 0) <>
      coalesce((v_current.snapshot#>>'{event,sponsorContribution}')::bigint, 0)
  ) then
    raise exception 'sponsor is locked after participant payments begin';
  end if;

  update public.events
  set name = trim(v_event->>'name'),
      start_date = split_part(v_event->>'startDate', 'T', 1)::date,
      end_date = split_part(v_event->>'endDate', 'T', 1)::date,
      participant_capacity = (v_event->>'participantCapacity')::integer,
      final_budget = (v_event->>'finalBudget')::bigint,
      sponsor_name = coalesce(v_event->>'sponsorName', ''),
      sponsor_contribution = coalesce((v_event->>'sponsorContribution')::bigint, 0),
      opening_balance = coalesce((v_event->>'openingBalance')::bigint, 0),
      updated_by = v_user_id,
      updated_at = timezone('utc', now())
  where id = p_event_id;

  update public.cashbook_states
  set snapshot = p_snapshot,
      version = version + 1,
      updated_by = v_user_id,
      updated_at = timezone('utc', now()),
      last_operation_id = p_operation_id,
      last_entity = p_entity,
      last_entity_id = p_entity_id,
      last_action = p_action
  where event_id = p_event_id;

  select * into v_current
  from public.cashbook_states
  where event_id = p_event_id;
  return jsonb_build_object(
    'status', 'ok',
    'version', v_current.version,
    'snapshot', v_current.snapshot,
    'updated_by', v_current.updated_by,
    'updated_at', v_current.updated_at
  );
end;
$$;

revoke all on function public.sync_cashbook_state(
  text, jsonb, bigint, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.sync_cashbook_state(
  text, jsonb, bigint, text, text, text, text
) to authenticated;
