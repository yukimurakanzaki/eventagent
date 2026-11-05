-- Global release: currencies, late sponsor money, committee members,
-- participant read-only share links, receipt storage, account deletion.

------------------------------------------------------------------------------
-- 1. Per-event currency (amounts stay integers in the currency's minor unit)
------------------------------------------------------------------------------
alter table public.events
  add column if not exists currency text not null default 'IDR';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'events_currency_iso'
  ) then
    alter table public.events
      add constraint events_currency_iso check (currency ~ '^[A-Z]{3}$');
  end if;
end;
$$;

------------------------------------------------------------------------------
-- 2. Committee role: can record money like the chairperson, cannot manage
--    access or events.
------------------------------------------------------------------------------
alter table public.workspace_members
  drop constraint if exists workspace_members_role_check;
alter table public.workspace_members
  add constraint workspace_members_role_check
  check (role in ('treasurer', 'chairperson', 'committee'));

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
  if (select auth.uid()) is null or
      not private.has_workspace_role(p_workspace_id, 'treasurer') then
    raise exception 'only the treasurer can manage workspace access';
  end if;
  if p_role not in ('chairperson', 'committee') then
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

revoke all on function public.invite_workspace_member(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.invite_workspace_member(uuid, text, text)
  to authenticated;

------------------------------------------------------------------------------
-- 3. Sync: sponsor money may arrive or change after payments start (both
--    interviewed treasurers), currency is validated, snapshot size capped.
------------------------------------------------------------------------------
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
  v_currency text;
begin
  if v_user_id is null or not private.is_event_member(p_event_id) then
    raise exception 'event access denied';
  end if;
  if p_operation_id is null or p_snapshot is null or p_snapshot->'event' is null then
    raise exception 'operation id and cashbook snapshot are required';
  end if;
  -- About 20k transactions; protects the shared row from runaway clients.
  if pg_column_size(p_snapshot) > 5 * 1024 * 1024 then
    raise exception 'cashbook snapshot is too large';
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
  v_currency := coalesce(v_event->>'currency', 'IDR');
  if v_currency !~ '^[A-Z]{3}$' then
    raise exception 'event currency must be an ISO 4217 code';
  end if;

  select count(*) into v_active_count
  from jsonb_array_elements(coalesce(p_snapshot->'participants', '[]'::jsonb)) item
  where coalesce(item->>'state', 'active') = 'active';
  if (v_event->>'participantCapacity')::integer < v_active_count then
    raise exception 'event capacity is below the active participant count';
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
      currency = v_currency,
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

------------------------------------------------------------------------------
-- 4. Participant read-only share links
------------------------------------------------------------------------------
create table if not exists public.event_share_links (
  token text primary key,
  event_id text not null references public.events(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz
);

create index if not exists event_share_links_event_idx
  on public.event_share_links(event_id);

alter table public.event_share_links enable row level security;
revoke all on table public.event_share_links from anon, authenticated;
grant select on table public.event_share_links to authenticated;

drop policy if exists event_share_links_member_select on public.event_share_links;
create policy event_share_links_member_select on public.event_share_links
for select to authenticated
using ((select private.is_event_member(event_id)));

-- Returns the active link for the event, creating one if needed.
create or replace function public.create_share_link(p_event_id text)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token text;
begin
  if (select auth.uid()) is null or not private.is_event_member(p_event_id) then
    raise exception 'event access denied';
  end if;

  select token into v_token
  from public.event_share_links
  where event_id = p_event_id and revoked_at is null
  order by created_at desc
  limit 1;

  if v_token is null then
    -- Two v4 UUIDs: 244 random bits, not guessable, URL-safe hex.
    v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into public.event_share_links (token, event_id, created_by)
    values (v_token, p_event_id, (select auth.uid()));
  end if;
  return v_token;
end;
$$;

-- Revokes every link for the event; the next create makes a fresh token.
create or replace function public.revoke_share_links(p_event_id text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_workspace_id uuid;
begin
  select workspace_id into v_workspace_id
  from public.events where id = p_event_id;
  if v_workspace_id is null or
      not private.has_workspace_role(v_workspace_id, 'treasurer') then
    raise exception 'only the treasurer can revoke share links';
  end if;
  update public.event_share_links
  set revoked_at = timezone('utc', now())
  where event_id = p_event_id and revoked_at is null;
end;
$$;

-- Public, read-only view of one event for participants. No account needed.
-- Strips device-only state (sync queue, conflicts, reminders), participant
-- phone numbers and receipt storage paths; it only says whether a receipt
-- exists.
create or replace function public.get_shared_cashbook(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_event_id text;
  v_state public.cashbook_states%rowtype;
  v_transactions jsonb;
  v_participants jsonb;
begin
  if p_token is null or char_length(p_token) <> 64 then
    raise exception 'share link not found';
  end if;

  select event_id into v_event_id
  from public.event_share_links
  where token = p_token and revoked_at is null;
  if v_event_id is null then
    raise exception 'share link not found';
  end if;

  select * into v_state from public.cashbook_states where event_id = v_event_id;
  if not found then
    raise exception 'share link not found';
  end if;

  select coalesce(jsonb_agg(
    (item - 'receiptPath' - 'receiptStoragePath') ||
      jsonb_build_object(
        'hasReceipt',
        coalesce(item->>'receiptStoragePath', item->>'receiptPath', '') <> ''
      )
  ), '[]'::jsonb)
  into v_transactions
  from jsonb_array_elements(coalesce(v_state.snapshot->'transactions', '[]'::jsonb)) item;

  -- Phone numbers are for the committee's personal reminders only.
  select coalesce(jsonb_agg(item - 'phone'), '[]'::jsonb)
  into v_participants
  from jsonb_array_elements(coalesce(v_state.snapshot->'participants', '[]'::jsonb)) item;

  return jsonb_build_object(
    'event', v_state.snapshot->'event',
    'participants', v_participants,
    'transactions', v_transactions,
    'updatedAt', v_state.updated_at,
    'version', v_state.version
  );
end;
$$;

revoke all on function public.create_share_link(text) from public, anon, authenticated;
grant execute on function public.create_share_link(text) to authenticated;
revoke all on function public.revoke_share_links(text) from public, anon, authenticated;
grant execute on function public.revoke_share_links(text) to authenticated;
revoke all on function public.get_shared_cashbook(text) from public, anon, authenticated;
grant execute on function public.get_shared_cashbook(text) to anon, authenticated;

------------------------------------------------------------------------------
-- 5. Receipt photos: private bucket, one folder per event, members only.
------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts', 'receipts', false, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

drop policy if exists receipts_member_select on storage.objects;
create policy receipts_member_select on storage.objects
for select to authenticated
using (
  bucket_id = 'receipts'
  and (select private.is_event_member((storage.foldername(name))[1]))
);

drop policy if exists receipts_member_insert on storage.objects;
create policy receipts_member_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'receipts'
  and (select private.is_event_member((storage.foldername(name))[1]))
);

-- Replacing a receipt photo overwrites the same object (upsert).
drop policy if exists receipts_member_update on storage.objects;
create policy receipts_member_update on storage.objects
for update to authenticated
using (
  bucket_id = 'receipts'
  and (select private.is_event_member((storage.foldername(name))[1]))
)
with check (
  bucket_id = 'receipts'
  and (select private.is_event_member((storage.foldername(name))[1]))
);

------------------------------------------------------------------------------
-- 6. Account deletion (required by app stores). History stays with the
--    group; the departing user's id is cleared from it.
------------------------------------------------------------------------------
alter table public.workspaces alter column created_by drop not null;
alter table public.events alter column created_by drop not null;
alter table public.events alter column updated_by drop not null;
alter table public.cashbook_states alter column updated_by drop not null;
alter table public.audit_entries alter column actor_id drop not null;

alter table public.workspaces drop constraint if exists workspaces_created_by_fkey;
alter table public.workspaces add constraint workspaces_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;
alter table public.events drop constraint if exists events_created_by_fkey;
alter table public.events add constraint events_created_by_fkey
  foreign key (created_by) references auth.users(id) on delete set null;
alter table public.events drop constraint if exists events_updated_by_fkey;
alter table public.events add constraint events_updated_by_fkey
  foreign key (updated_by) references auth.users(id) on delete set null;
alter table public.cashbook_states drop constraint if exists cashbook_states_updated_by_fkey;
alter table public.cashbook_states add constraint cashbook_states_updated_by_fkey
  foreign key (updated_by) references auth.users(id) on delete set null;
alter table public.audit_entries drop constraint if exists audit_entries_actor_id_fkey;
alter table public.audit_entries add constraint audit_entries_actor_id_fkey
  foreign key (actor_id) references auth.users(id) on delete set null;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_membership record;
  v_successor uuid;
begin
  if v_user_id is null then
    raise exception 'not signed in';
  end if;

  for v_membership in
    select workspace_id, role from public.workspace_members where user_id = v_user_id
  loop
    if v_membership.role = 'treasurer' then
      select user_id into v_successor
      from public.workspace_members
      where workspace_id = v_membership.workspace_id and user_id <> v_user_id
      order by case role when 'chairperson' then 0 else 1 end, created_at
      limit 1;

      if v_successor is null then
        -- Nobody else can see this money: remove the workspace entirely.
        delete from public.workspaces where id = v_membership.workspace_id;
      else
        update public.workspace_members
        set role = 'treasurer'
        where workspace_id = v_membership.workspace_id and user_id = v_successor;
      end if;
    end if;
  end loop;

  delete from public.workspace_members where user_id = v_user_id;
  delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
