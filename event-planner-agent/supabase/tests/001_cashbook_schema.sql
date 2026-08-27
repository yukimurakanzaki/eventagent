begin;

select plan(9);

select has_schema('private');
select has_table('public', 'workspaces');
select has_table('public', 'workspace_members');
select has_table('public', 'events');
select has_table('public', 'cashbook_states');
select has_table('public', 'audit_entries');
select has_function(
  'public',
  'sync_cashbook_state',
  array['text', 'jsonb', 'bigint', 'text', 'text', 'text', 'text']
);
select has_function(
  'public',
  'invite_workspace_member',
  array['uuid', 'text', 'text']
);
select col_is_pk('public', 'cashbook_states', 'event_id');

select * from finish();
rollback;
