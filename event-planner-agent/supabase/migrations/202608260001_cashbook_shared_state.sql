create extension if not exists pgcrypto;

create schema if not exists private;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 120),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('treasurer', 'chairperson')),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (workspace_id, user_id)
);

create table public.events (
  id text primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null check (end_date >= start_date),
  participant_capacity integer not null check (participant_capacity > 0),
  final_budget bigint not null check (final_budget >= 0),
  sponsor_name text not null default '',
  sponsor_contribution bigint not null default 0 check (sponsor_contribution >= 0),
  opening_balance bigint not null default 0 check (opening_balance >= 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  updated_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.cashbook_states (
  event_id text primary key references public.events(id) on delete cascade,
  snapshot jsonb not null,
  version bigint not null default 1 check (version > 0),
  updated_by uuid not null references auth.users(id) on delete restrict,
  updated_at timestamptz not null default timezone('utc', now()),
  last_operation_id text,
  last_entity text,
  last_entity_id text,
  last_action text
);

create table public.audit_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  event_id text not null references public.events(id) on delete cascade,
  operation_id text,
  actor_id uuid not null references auth.users(id) on delete restrict,
  entity text not null,
  entity_id text not null,
  action text not null,
  before_snapshot jsonb,
  after_snapshot jsonb not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (event_id, operation_id)
);

create index workspace_members_user_idx on public.workspace_members(user_id);
create index events_workspace_idx on public.events(workspace_id);
create index audit_entries_event_created_idx on public.audit_entries(event_id, created_at desc);

create or replace function private.is_workspace_member(p_workspace_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = p_workspace_id
      and user_id = (select auth.uid())
  );
$$;

create or replace function private.is_event_member(p_event_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.events e
    join public.workspace_members wm on wm.workspace_id = e.workspace_id
    where e.id = p_event_id
      and wm.user_id = (select auth.uid())
  );
$$;

create or replace function private.has_workspace_role(p_workspace_id uuid, p_role text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.workspace_members
    where workspace_id = p_workspace_id
      and user_id = (select auth.uid())
      and role = p_role
  );
$$;

create or replace function private.audit_cashbook_state()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_workspace_id uuid;
  v_before jsonb;
begin
  select workspace_id into v_workspace_id from public.events where id = new.event_id;
  v_before := case when tg_op = 'UPDATE' then old.snapshot else null end;

  insert into public.audit_entries (
    workspace_id,
    event_id,
    operation_id,
    actor_id,
    entity,
    entity_id,
    action,
    before_snapshot,
    after_snapshot
  ) values (
    v_workspace_id,
    new.event_id,
    coalesce(new.last_operation_id, 'system-' || new.version::text),
    coalesce((select auth.uid()), new.updated_by),
    coalesce(new.last_entity, 'cashbook'),
    coalesce(new.last_entity_id, new.event_id),
    coalesce(new.last_action, case when tg_op = 'INSERT' then 'create' else 'update' end),
    v_before,
    new.snapshot
  )
  on conflict (event_id, operation_id) do nothing;

  return new;
end;
$$;

revoke all on function private.is_workspace_member(uuid) from public, anon, authenticated;
grant execute on function private.is_workspace_member(uuid) to authenticated;
revoke all on function private.is_event_member(text) from public, anon, authenticated;
grant execute on function private.is_event_member(text) to authenticated;
revoke all on function private.has_workspace_role(uuid, text) from public, anon, authenticated;
grant execute on function private.has_workspace_role(uuid, text) to authenticated;
revoke all on function private.audit_cashbook_state() from public, anon, authenticated;

create trigger cashbook_state_audit_trigger
after insert or update on public.cashbook_states
for each row execute function private.audit_cashbook_state();

create or replace function public.create_workspace_with_event(
  p_workspace_name text,
  p_snapshot jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_workspace_id uuid;
  v_event_id text := gen_random_uuid()::text;
  v_snapshot jsonb;
  v_event jsonb;
begin
  if v_user_id is null then
    raise exception 'authenticated user required';
  end if;
  if p_snapshot is null or p_snapshot->'event' is null then
    raise exception 'cashbook snapshot is required';
  end if;

  v_workspace_id := gen_random_uuid();
  v_event := p_snapshot->'event';
  v_snapshot := jsonb_set(p_snapshot, '{event,id}', to_jsonb(v_event_id), true);

  insert into public.workspaces (id, name, created_by)
  values (v_workspace_id, trim(p_workspace_name), v_user_id);

  insert into public.workspace_members (workspace_id, user_id, role)
  values (v_workspace_id, v_user_id, 'treasurer');

  insert into public.events (
    id,
    workspace_id,
    name,
    start_date,
    end_date,
    participant_capacity,
    final_budget,
    sponsor_name,
    sponsor_contribution,
    opening_balance,
    created_by,
    updated_by
  ) values (
    v_event_id,
    v_workspace_id,
    v_event->>'name',
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
    event_id,
    snapshot,
    version,
    updated_by,
    last_operation_id,
    last_entity,
    last_entity_id,
    last_action
  ) values (
    v_event_id,
    v_snapshot,
    1,
    v_user_id,
    'bootstrap-' || v_event_id,
    'event',
    v_event_id,
    'bootstrap'
  );

  return jsonb_build_object(
    'workspace_id', v_workspace_id,
    'event_id', v_event_id,
    'version', 1,
    'snapshot', v_snapshot
  );
end;
$$;

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
begin
  if v_user_id is null or not private.is_event_member(p_event_id) then
    raise exception 'event access denied';
  end if;
  if p_operation_id is null or p_snapshot is null then
    raise exception 'operation id and snapshot are required';
  end if;

  select * into v_current from public.cashbook_states where event_id = p_event_id for update;

  if exists (
    select 1 from public.audit_entries
    where event_id = p_event_id and operation_id = p_operation_id and actor_id = v_user_id
  ) then
    return jsonb_build_object('status', 'ok', 'version', v_current.version, 'snapshot', v_current.snapshot);
  end if;

  if v_current.version <> p_base_version then
    return jsonb_build_object('status', 'conflict', 'version', v_current.version, 'snapshot', v_current.snapshot);
  end if;

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

  select * into v_current from public.cashbook_states where event_id = p_event_id;
  return jsonb_build_object('status', 'ok', 'version', v_current.version, 'snapshot', v_current.snapshot);
end;
$$;

create or replace function public.invite_workspace_member(
  p_workspace_id uuid,
  p_email text,
  p_role text default 'chairperson'
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target_id uuid;
  v_existing_role text;
begin
  if (select auth.uid()) is null or not private.has_workspace_role(p_workspace_id, 'treasurer') then
    raise exception 'only the treasurer can manage workspace access';
  end if;
  if p_role not in ('treasurer', 'chairperson') then
    raise exception 'unsupported workspace role';
  end if;
  if trim(coalesce(p_email, '')) = '' then
    raise exception 'email is required';
  end if;

  select id into v_target_id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_target_id is null then
    raise exception 'user must create an account before being added';
  end if;

  select role into v_existing_role
  from public.workspace_members
  where workspace_id = p_workspace_id and user_id = v_target_id;

  if v_existing_role is not null and v_existing_role <> p_role then
    raise exception 'user already has another role in this workspace';
  end if;

  insert into public.workspace_members (workspace_id, user_id, role)
  values (p_workspace_id, v_target_id, p_role)
  on conflict (workspace_id, user_id) do nothing;

  return jsonb_build_object(
    'workspace_id', p_workspace_id,
    'user_id', v_target_id,
    'role', p_role
  );
end;
$$;

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.events enable row level security;
alter table public.cashbook_states enable row level security;
alter table public.audit_entries enable row level security;

revoke all on table public.workspaces, public.workspace_members, public.events, public.cashbook_states, public.audit_entries from anon, authenticated;
grant select on table public.workspaces, public.workspace_members, public.events, public.cashbook_states, public.audit_entries to authenticated;

create policy workspaces_member_select on public.workspaces
for select to authenticated
using ((select private.is_workspace_member(id)));

create policy workspace_members_same_workspace_select on public.workspace_members
for select to authenticated
using ((select private.is_workspace_member(workspace_id)));

create policy events_member_select on public.events
for select to authenticated
using ((select private.is_workspace_member(workspace_id)));

create policy cashbook_states_member_select on public.cashbook_states
for select to authenticated
using ((select private.is_event_member(event_id)));

create policy audit_entries_member_select on public.audit_entries
for select to authenticated
using ((select private.is_workspace_member(workspace_id)));

revoke all on function public.create_workspace_with_event(text, jsonb) from public, anon, authenticated;
grant execute on function public.create_workspace_with_event(text, jsonb) to authenticated;

revoke all on function public.sync_cashbook_state(text, jsonb, bigint, text, text, text, text) from public, anon, authenticated;
grant execute on function public.sync_cashbook_state(text, jsonb, bigint, text, text, text, text) to authenticated;

revoke all on function public.invite_workspace_member(uuid, text, text) from public, anon, authenticated;
grant execute on function public.invite_workspace_member(uuid, text, text) to authenticated;
