-- End-to-end checks for the global-release migration (run after ci_stub_platform.sql and all migrations).
\set ON_ERROR_STOP 1
insert into auth.users values ('11111111-1111-1111-1111-111111111111','t@x.com'),('22222222-2222-2222-2222-222222222222','c@x.com'),('33333333-3333-3333-3333-333333333333','o@x.com');
set test.uid = '11111111-1111-1111-1111-111111111111';
select public.create_workspace_with_event('WS', '{"event":{"id":"ev1","name":"Trip","startDate":"2026-12-01T00:00:00","endDate":"2026-12-02T00:00:00","participantCapacity":5,"finalBudget":1000,"sponsorName":"","sponsorContribution":0,"openingBalance":0,"currency":"USD"},"participants":[{"id":"p1","name":"Ana","state":"active","refundPolicy":"undecided","phone":"+6281100000"}],"transactions":[{"id":"t0","type":"participantPayment","amount":10,"description":"x","createdAt":"2026-11-01T00:00:00","receiptStoragePath":"ev1/r.jpg"}],"reminders":[]}'::jsonb) ->> 'event_id' as ev \gset
select version from cashbook_states where event_id = :'ev';
-- late sponsor after payments: should be OK now
select public.sync_cashbook_state(:'ev', jsonb_set((select snapshot from cashbook_states where event_id=:'ev'), '{event,sponsorContribution}', '300'), (select version from cashbook_states where event_id=:'ev'), 'op1','event',:'ev','update')->>'status' as late_sponsor;
select currency, sponsor_contribution from events where id=:'ev';
select (currency = 'USD' and sponsor_contribution = 300) as sponsor_ok from events where id = :'ev' \gset
\if :sponsor_ok
\else
  \echo 'late sponsor or currency not stored'
  select 1/0;
\endif
select public.invite_workspace_member((select workspace_id from events where id=:'ev'), 'c@x.com', 'committee')->>'role' as invited;
select public.create_share_link(:'ev') as tok \gset
select length(:'tok') as toklen, public.create_share_link(:'ev') = :'tok' as stable;
select (length(:'tok') = 64 and public.create_share_link(:'ev') = :'tok') as tok_ok \gset
\if :tok_ok
\else
  \echo 'share token not stable'
  select 1/0;
\endif
reset test.uid;
set role anon;
select jsonb_pretty(public.get_shared_cashbook(:'tok')->'transactions');
select (public.get_shared_cashbook(:'tok')::text not like '%+6281100000%') as phone_hidden \gset
\if :phone_hidden
\else
  \echo 'participant phone leaked through share link'
  select 1/0;
\endif
reset role;
-- outsider cannot create link
set test.uid = '33333333-3333-3333-3333-333333333333';
do $$ begin perform public.create_share_link((select id from public.events limit 1)); raise exception 'SHOULD FAIL'; exception when others then if sqlerrm = 'SHOULD FAIL' then raise; end if; raise notice 'outsider blocked: %', sqlerrm; end $$;
-- treasurer deletes account -> committee member becomes treasurer
set test.uid = '11111111-1111-1111-1111-111111111111';
select public.revoke_share_links(:'ev');
select public.delete_my_account();
select user_id, role from workspace_members;
do $$ begin assert (select role = 'treasurer' from workspace_members where user_id = '22222222-2222-2222-2222-222222222222'), 'treasurer role not handed over'; end $$;
select count(*) as users_left from auth.users;
select actor_id is null as actor_cleared, count(*) from audit_entries group by 1;
-- revoked link fails
do $$ begin perform public.get_shared_cashbook((select token from event_share_links limit 1)); raise exception 'SHOULD FAIL'; exception when others then if sqlerrm = 'SHOULD FAIL' then raise; end if; raise notice 'revoked blocked: %', sqlerrm; end $$;
-- last member deletes -> workspace gone
set test.uid = '22222222-2222-2222-2222-222222222222';
select public.delete_my_account();
select (select count(*) from workspaces) ws, (select count(*) from events) ev;
do $$ begin assert (select count(*) from workspaces) = 0, 'orphan workspace kept'; end $$;
