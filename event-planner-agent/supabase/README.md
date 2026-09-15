# Supabase hosted cashbook slice

The migration in `migrations/202608260001_cashbook_shared_state.sql` adds the first hosted-data slice for Wargakas:

- email/password-authenticated users
- shared workspaces with `treasurer` and `chairperson` memberships
- the Wisata Dieng event and versioned cashbook snapshot
- server-side optimistic version checks for offline queue replay
- RLS policies scoped to workspace membership
- database-triggered audit entries for every cashbook-state write
- treasurer-approved chairperson access for an existing Supabase account

Migration `202609060001_mvp_pilot_sync.sql` hardens the pilot sync RPC. It validates configurable event fields, mirrors event data from the versioned snapshot into the relational event row, enforces the sponsor lock after participant payments begin, and returns the remote actor/time needed by explicit conflict resolution.

This repository is linked to project `yytzncyxyulwqsanejcg` and the migration has been applied there. For a fresh checkout or another environment:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The linked project was checked with `supabase migration list` and `supabase db lint --linked --fail-on error`.

For mobile email confirmation, add this redirect URL under Authentication → URL Configuration → Redirect URLs:

```text
io.wargakas.mobile://auth-callback/
```

Do not put a Supabase secret/service-role key in the Flutter app. The app only receives the project URL and publishable key through Dart defines:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The first authenticated user creates a Wargakas workspace and seeds the fixed Dieng scenario through the protected RPC. The treasurer can add a chairperson by email from the mobile account controls; the chairperson must create an account first. The invitation function is server-authorized and only grants membership inside the caller's workspace.

For MuMu or release-like testing, do not omit the Supabase Dart defines: without them the hosted app shows a configuration error. The local demo is an explicit separate build using `--dart-define=WARGAKAS_APP_MODE=demo`.
