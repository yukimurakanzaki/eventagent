begin;

select plan(18);

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
select has_column('public', 'events', 'archived_at');
select has_function('public', 'create_event', array['uuid', 'jsonb']);
select has_function('public', 'set_event_archived', array['text', 'boolean']);

select has_column('public', 'events', 'currency');
select has_table('public', 'event_share_links');
select has_function('public', 'create_share_link', array['text']);
select has_function('public', 'revoke_share_links', array['text']);
select has_function('public', 'get_shared_cashbook', array['text']);
select has_function('public', 'delete_my_account', array[]::text[]);

select * from finish();
rollback;
