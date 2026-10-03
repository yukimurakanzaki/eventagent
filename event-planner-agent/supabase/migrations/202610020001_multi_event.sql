-- Several events per workspace: the treasurer can add events and archive or
-- restore them. Archiving only hides an event from the active list; its
-- cashbook state, audit trail, and members stay untouched.

alter table public.events add column if not exists archived_at timestamptz;

create or replace function public.create_event(
  p_workspace_id uuid,
  p_snapshot jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_event_id text := gen_random_uuid()::text;
  v_event jsonb;
  v_snapshot jsonb;
begin
  if v_user_id is null or
      not private.has_workspace_role(p_workspace_id, 'treasurer') then
    raise exception 'only the treasurer can create events';
  end if;
  if p_snapshot is null or p_snapshot->'event' is null then
    raise exception 'cashbook snapshot is required';
  end if;

  v_event := p_snapshot->'event';
  if char_length(trim(coalesce(v_event->>'name', ''))) not between 1 and 120 then
    raise exception 'event name is required and must be at most 120 characters';
  end if;
  if split_part(v_event->>'endDate', 'T', 1)::date <
      split_part(v_event->>'startDate', 'T', 1)::date then
    raise exception 'event end date must be on or after start date';
  end if;
  if (v_event->>'participantCapacity')::integer <= 0 or
      (v_event->>'finalBudget')::bigint < 0 then
    raise exception 'event capacity and budget are invalid';
  end if;

  v_snapshot := jsonb_set(p_snapshot, '{event,id}', to_jsonb(v_event_id), true);

  insert into public.events (
    id, workspace_id, name, start_date, end_date, participant_capacity,
    final_budget, sponsor_name, sponsor_contribution, opening_balance,
    created_by, updated_by
  ) values (
    v_event_id,
    p_workspace_id,
    trim(v_event->>'name'),
    split_part(v_event->>'startDate', 'T', 1)::date,
    split_part(v_event->>'endDate', 'T', 1)::date,
    (v_event->>'participantCapacity')::integer,
    (v_event->>'finalBudget')::bigint,
    coalesce(v_event->>'sponsorName', ''),
    coalesce((v_event->>'sponsorContribution')::bigint, 0),
    coalesce((v_event->>'openingBalance')::bigint, 0),
    v_user_id,
    v_user_id
  );

  insert into public.cashbook_states (
    event_id, snapshot, version, updated_by,
    last_operation_id, last_entity, last_entity_id, last_action
  ) values (
    v_event_id, v_snapshot, 1, v_user_id,
    'bootstrap-' || v_event_id, 'event', v_event_id, 'bootstrap'
  );

  return jsonb_build_object(
    'event_id', v_event_id,
    'version', 1,
    'snapshot', v_snapshot
  );
end;
$$;

create or replace function public.set_event_archived(
  p_event_id text,
  p_archived boolean
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_workspace_id uuid;
begin
  select workspace_id into v_workspace_id
  from public.events
  where id = p_event_id;

  if v_workspace_id is null or
      not private.has_workspace_role(v_workspace_id, 'treasurer') then
    raise exception 'only the treasurer can archive events';
  end if;

  update public.events
  set archived_at = case when p_archived then timezone('utc', now()) else null end
  where id = p_event_id;
end;
$$;

revoke all on function public.create_event(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.create_event(uuid, jsonb) to authenticated;

revoke all on function public.set_event_archived(text, boolean)
  from public, anon, authenticated;
grant execute on function public.set_event_archived(text, boolean)
  to authenticated;
