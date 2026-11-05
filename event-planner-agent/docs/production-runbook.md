# Wargakas Production Runbook

Current app version: `2.0.0+5` (`event-planner-agent/mobile/pubspec.yaml`). Release tag for it: `v2.0.0`.
Repo: https://github.com/yukimurakanzaki/eventagent. Placeholders appear in [square brackets].

## 0. Known issues to resolve BEFORE go-live

Found while preparing these docs. Treat items 1 and 2 as launch blockers.

1. **Phone numbers can reach the public share link.** `get_shared_cashbook` (migration `202611050001_global_release.sql`) returns `snapshot->'participants'` unchanged, and each participant record contains a `phone` field. The privacy policy promises that the public link never shows phone numbers. Fix with a new migration that strips `phone` from each participant (for example `jsonb_agg(p - 'phone')`), then verify with the curl test in section 1.6. Do not publish the privacy policy until this is verified.
2. **Receipt files are not deleted with the database rows.** `delete_my_account()` deletes a workspace when the treasurer is the last member, but Storage objects in `receipts/<event_id>/...` stay behind. Add a cleanup job (see section 8.4) or change the policy text; the privacy policy says "routine cleanup within [30] days".
3. Android reminders use a fixed Indonesian timezone (see `mobile/README.md`). Validate reminders on target phones outside Indonesia or fix before marketing globally.
4. `release.yml` builds Android only. iOS needs the manual steps in section 4.
5. Unit tests do not cover live RLS with a real project: run the QA checklist in section 9 against production-like data.

## 1. Supabase

### 1.1 Create the project and choose the region
- Create a project at https://supabase.com/dashboard. Choose the region closest to most users, and write it into the privacy policy ([Supabase region]). Suggested: Singapore (ap-southeast-1) for Indonesia/Southeast Asia. The region cannot be changed later without migrating.
- Plan: use **Pro** or higher for production (daily backups, Point-in-Time Recovery add-on, no pausing, higher limits). Free projects pause after inactivity and have no backups you can restore on demand.
- Store the database password in a password manager.

### 1.2 Link and push migrations
```bash
cd event-planner-agent
supabase login
supabase link --project-ref [PROJECT_REF]
supabase db push --dry-run     # review what will run
supabase db push               # applies, in order:
#   202608260001_cashbook_shared_state.sql
#   202609060001_mvp_pilot_sync.sql
#   202610020001_multi_event.sql
#   202611050001_global_release.sql
```
Always apply to a **staging** project first (create a second free project) and run the QA checklist there.

### 1.3 Verify
In SQL Editor:
```sql
-- currency column exists, default IDR, ISO check
select column_name, data_type, column_default
from information_schema.columns
where table_schema='public' and table_name='events' and column_name='currency';

-- functions exist
select proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and proname in
 ('get_shared_cashbook','create_share_link','revoke_share_links',
  'delete_my_account','sync_cashbook_state','create_event','invite_workspace_member');

-- RLS enabled on every public table (expect all true)
select tablename, rowsecurity from pg_tables where schemaname='public';

-- bucket
select id, public, file_size_limit, allowed_mime_types from storage.buckets where id='receipts';
-- expect public=false, 5242880, jpeg/png/webp/heic

-- storage policies
select policyname, cmd from pg_policies
where schemaname='storage' and tablename='objects' and policyname like 'receipts_%';
-- expect receipts_member_select, receipts_member_insert
```
`get_shared_cashbook` must be callable anonymously and must reject bad tokens:
```bash
curl -s -X POST "https://[PROJECT_REF].supabase.co/rest/v1/rpc/get_shared_cashbook" \
  -H "apikey: [PUBLISHABLE_KEY]" -H "Content-Type: application/json" \
  -d '{"p_token":"bad"}'
# expect an error "share link not found"
```
1.6 After creating a real test share link, confirm the response has **no `phone` field** and no `receiptPath`/`receiptStoragePath` (see section 0, item 1).

### 1.4 Authentication settings (Dashboard -> Authentication)
- Providers: Email enabled, **Confirm email ON**. Set a minimum password length of at least 8.
- URL Configuration:
  - Redirect URLs: add `io.wargakas.mobile://auth-callback/` (exact, with trailing slash).
  - Site URL: your web viewer URL, [Share base URL, e.g. https://yukimurakanzaki.github.io/eventagent/].
- **Custom SMTP** (Authentication -> Emails -> SMTP): required for production. The built-in sender is rate-limited and only for testing. Use a provider with a verified domain ([Email provider]), set sender `[no-reply@yourdomain]`, and configure SPF, DKIM and DMARC DNS records. Send a real confirmation and a password-reset to Gmail, Outlook and a regional provider.
- Email templates: translate/brand confirmation and recovery emails ([Brand text]); keep the `{{ .ConfirmationURL }}` link.
- Rate limits (Authentication -> Rate Limits): set sign-ups/sign-ins/emails per hour to values that fit your expected load; keep CAPTCHA (Turnstile/hCaptcha) available to turn on if abuse appears.
- Disable unused providers and anonymous sign-ins.

### 1.5 Backups and recovery
- Enable daily backups (Pro) and the **Point-in-Time Recovery** add-on (Dashboard -> Database -> Backups).
- **Restore drill** (do once before launch and every quarter): restore to a new project from a backup or PITR timestamp, point a staging build at it, sign in, open an event, confirm totals match. Write down how long it took (your real RTO).
- Storage objects are **not** covered by database backups. Periodically copy the `receipts` bucket (for example with `rclone` or the Supabase S3 endpoint) to separate storage.

### 1.6 Other settings
- Network: leave API open (the app is public); restrict direct database connections to trusted IPs if possible.
- Keys: the app uses only the **publishable (anon) key**. Never put the `service_role` or secret key, database password or JWT secret in the app, in GitHub variables used by builds, or in screenshots.
- Logs: ensure log retention is adequate; enable email alerts (section 5).

## 2. GitHub: secrets, variables, Pages

Settings -> Secrets and variables -> Actions.

| Name | Type | Value |
|---|---|---|
| `SUPABASE_URL` | Secret | `https://[PROJECT_REF].supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Secret | publishable (anon) key |
| `KEYSTORE_BASE64` | Secret | `base64 -w0 release.jks` of your upload keystore |
| `KEYSTORE_PASSWORD` | Secret | keystore password |
| `KEY_ALIAS` | Secret | key alias |
| `KEY_PASSWORD` | Secret | key password |
| `WARGAKAS_SHARE_BASE_URL` | Variable | Public viewer URL with trailing slash, e.g. `https://yukimurakanzaki.github.io/eventagent/` (or your custom domain) |

Signing key: create it once (`keytool -genkeypair -v -keystore release.jks -alias [alias] -keyalg RSA -keysize 2048 -validity 10000`). Back up the keystore and passwords in two secure places. With Play App Signing the keystore is your **upload key** (recoverable through Play support if lost), but keep it safe anyway.

Web viewer (GitHub Pages): Settings -> Pages -> Source: **GitHub Actions**. The workflow `web-viewer.yml` runs on every `v*` tag (and manually via "Run workflow"), builds Flutter web with base href `/<repo-name>/`, and deploys. The share links look like `https://<owner>.github.io/eventagent/?share=TOKEN`. If you use a custom domain, set it in Pages, update `WARGAKAS_SHARE_BASE_URL`, and also adjust `--base-href` in the workflow to `/`.
If the repository is private, GitHub Pages requires a paid plan; otherwise host the web build elsewhere (Cloudflare Pages, Netlify).

## 3. Cut a release (Android and web)

1. Make sure `main` is green (Mobile CI: analyze, tests, database migration test on Postgres 16).
2. Edit `pubspec.yaml` `version: X.Y.Z+N`. Increase `N` (build number = Play `versionCode`) for **every** Play upload. Commit to `main`.
3. Tag with the **exact** pubspec version (the release workflow fails otherwise):
   ```bash
   git tag v2.0.0 && git push origin v2.0.0
   ```
4. Two workflows start:
   - **Release APK and AAB**: analyze, test, builds signed `wargakas-v2.0.0.apk` and `.aab` with Supabase values, creates the GitHub release.
   - **Deploy participant web viewer**: publishes the web app to Pages.
5. Download the `.aab` from the GitHub release. Smoke-test the `.apk` on a real phone against production (sign up, create event, share link).
6. If a build fails: read the Actions log; fix; delete the tag (`git push --delete origin v2.0.0`, `git tag -d v2.0.0`), and re-tag after the fix.

## 4. Stores

### 4.1 Google Play
1. Play Console: create the app (name, default language, free, app category Finance). Complete **App content**: privacy policy URL, ads (No), app access (provide reviewer login), content rating, target audience (18+), Data safety, financial features declaration, **account deletion URL**. See [play-store-listing.md](play-store-listing.md).
2. Enrol in **Play App Signing** on first AAB upload.
3. **Internal testing** track: upload the `.aab`, add testers (up to 100). Verify install, login email flow, notifications, receipt upload.
4. **Closed testing**: new personal developer accounts must run a closed test with at least **12 testers for 14 continuous days** before applying for production access (check current Play rules). Start this early.
5. **Production**: create a release, upload the same or newer `.aab`, add release notes per language, start with a **staged rollout** (5-10% -> 50% -> 100%) while watching crash rate and support email.
6. Fill the store listing and upload screenshots from the shot-list.

### 4.2 iOS (on a Mac with Xcode; not automated yet)
Prerequisites: Apple Developer Program membership, Xcode, Flutter (same version as CI: 3.47.1), CocoaPods.
```bash
cd event-planner-agent/mobile
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://[PROJECT_REF].supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=[PUBLISHABLE_KEY] \
  --dart-define=WARGAKAS_VERSION=2.0.0 \
  --dart-define=WARGAKAS_SHARE_BASE_URL=https://yukimurakanzaki.github.io/eventagent/
```
Then: open `ios/Runner.xcworkspace`, set Bundle ID (`io.wargakas.mobile`), Team and automatic signing; confirm the URL scheme `io.wargakas.mobile` (auth callback) and `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` strings exist in `Info.plist`; upload the `.ipa` via Transporter or Xcode Organizer; wait for processing; add to **TestFlight** (internal testers first, then external beta which needs Beta App Review); finally submit for App Review with the privacy "nutrition label" and reviewer account. Verify that the iOS project (`mobile/ios/`) exists and builds; if it does not, run `flutter create --platforms=ios .` first and re-check notification and deep-link setup.

## 5. Monitoring and alerts

- Supabase Dashboard -> Reports: database CPU, memory, disk, connections, API requests, auth emails. Enable **spend cap awareness** and usage-limit emails.
- Logs Explorer: watch Postgres errors (`sync_cashbook_state`, RLS "event access denied"), Auth errors (email send failures), Storage errors.
- Weekly checks: database size and growth, Storage size, auth email delivery rate (SMTP provider dashboard), Play Console vitals (crash rate, ANR), App Store crash reports.
- Uptime: add a free external check (UptimeRobot/BetterStack) for `https://yukimurakanzaki.github.io/eventagent/` and `https://[PROJECT_REF].supabase.co/auth/v1/health`.
- The app has no crash-reporting SDK (a privacy choice). Use store crash reports and user email. If you add one later, update the Privacy Policy and the store data forms first.

## 6. Scaling notes

How data is stored: one `cashbook_states` row per event holds a whole JSON **snapshot** (event, participants, transactions) with an integer `version` for optimistic concurrency. Writes go through `sync_cashbook_state`, which locks the row (`for update`) and rejects stale base versions (device then offers the "choose online or device snapshot" conflict screen).

- **Size cap**: snapshot is capped at **5 MB** (about 20,000 transactions). Typical community events are far below. Watch the largest rows:
  ```sql
  select event_id, pg_column_size(snapshot) bytes from cashbook_states order by 2 desc limit 20;
  ```
- **Hot spots**: many people editing one event at the same time serialize on one row; acceptable for committees (a handful of editors). Large events with heavy simultaneous editing will see more conflicts.
- **Read amplification**: every sync sends/receives the whole snapshot. If average snapshot > ~500 KB, expect bandwidth growth; consider delta sync.
- **Indexes** that exist: `workspace_members(user_id)`, `events(workspace_id)`, `audit_entries(event_id, created_at desc)`, `event_share_links(event_id)`, plus primary keys. RLS helpers (`is_event_member`) hit these. Add indexes if `pg_stat_statements` shows seq scans. `audit_entries` grows without bound: plan archiving (partition by month or delete entries older than [N] years for closed events).
- **Connections**: the app talks to the REST API (PostgREST), which already pools. For heavy use pick a larger compute size and keep the pooler (Supavisor, transaction mode) for any direct Postgres clients, scripts or future server code.
- **Share link traffic**: `get_shared_cashbook` is anonymous. Consider caching at a CDN, Supabase API rate limits, or a Cloudflare rule if a link goes viral.
- **Storage**: receipts are capped at 5 MB each (the app compresses to about 1600 px, quality 72). Estimate: 1 million receipts is roughly 150-250 GB; add lifecycle cleanup for deleted workspaces.
- **When to move to per-row tables** (`transactions`, `participants`): when snapshots regularly exceed ~1 MB, conflicts are frequent, you need server-side reporting/search across events, or events exceed ~5,000 transactions. Plan a migration that splits the snapshot into rows, a new sync API with per-row versions, and keep `get_shared_cashbook` output unchanged for compatibility.

## 7. Security checklist

- [ ] RLS enabled on every `public` table (query in 1.3); no table grants to `anon`.
- [ ] All write paths are `security definer` RPCs with `set search_path` and execute granted only to `authenticated` (`get_shared_cashbook` is the only one granted to `anon`).
- [ ] App contains only the publishable key; `service_role`/secret key is not in GitHub secrets used for builds, source code or screenshots. Run `gitleaks` or GitHub secret scanning on the repo.
- [ ] `receipts` bucket private; policies limit access to event members; MIME types and 5 MB limit enforced.
- [ ] Share link token is 64 hex characters; revoke works; phone numbers absent from the shared payload (section 0).
- [ ] Email confirmation ON, custom SMTP, SPF/DKIM/DMARC, rate limits set.
- [ ] Dashboard accounts protected with 2FA; GitHub org/account 2FA; branch protection on `main`; limit who can push tags (they trigger releases).
- [ ] Keystore and passwords backed up; no keystore committed (`android/key.properties` is git-ignored).
- [ ] Dependencies updated (Dependabot); `flutter pub outdated` reviewed before each release.
- [ ] Privacy Policy and Terms hosted at public URLs and linked from the app/stores.

## 8. Incident response and rollback

### 8.1 Severity and first steps
1. Triage: data exposure (SEV1), data loss/corruption or outage (SEV1-2), partial feature failure (SEV3). Record the time and who is handling it.
2. Contain: for suspected link leakage, revoke the share links (treasurer: Share -> revoke; or SQL: `update event_share_links set revoked_at = now() where revoked_at is null and event_id = '[EVENT_ID]';`). For a leaked key: rotate it in Supabase (Settings -> API) and ship a new app build; the old publishable key is public by design, but a leaked **service_role/secret** key must be rotated immediately.
3. Communicate: tell affected users by email/in-app note. For personal-data breaches notify regulators as required (GDPR 72 hours; Indonesia UU PDP 3x24 hours) and keep a written incident record.
4. Fix and write a short post-mortem.

### 8.2 App rollback
- Play: halt the staged rollout; promote a previous release to production again (a rollback needs a **higher** versionCode, so re-upload the previous code with `+N` bumped). iOS: release the previous build via a new submission or pull the update with a phased-release pause.
- GitHub: the previous APK/AAB stays on its release page. Web viewer: re-run the workflow on the older tag (Actions -> "Deploy participant web viewer" -> Run workflow, choose that tag) or revert and re-tag.

### 8.3 Database rollback
- Migrations are forward-only. To undo a bad migration, write a new migration that reverses it and push it. For data damage use PITR to restore to a new project (see the restore drill), then copy the affected `cashbook_states` rows back (`version` must be set higher than clients hold, otherwise they will see conflicts).
- Never edit the database by hand in production without recording the SQL in a migration file.

### 8.4 Orphaned receipts cleanup (run monthly until automated)
```sql
-- objects whose event folder no longer exists
select o.name from storage.objects o
where o.bucket_id = 'receipts'
  and not exists (select 1 from public.events e where e.id = (storage.foldername(o.name))[1]);
```
Delete the results through the Storage API or dashboard (SQL deletes on `storage.objects` do not remove the files themselves).

## 9. Pre-launch QA checklist

Run on at least one low-end Android phone, one recent Android, one iPhone and the web viewer, against staging first, then production.

**Accounts**
- [ ] Sign up with a new email, receive the confirmation email (via custom SMTP), tap the link: the app opens via `io.wargakas.mobile://auth-callback/`.
- [ ] Wrong password message is clear; "Forgot password" and "Resend confirmation" work; cooldown shown.
- [ ] Invite a second user (must already have an account) as chairperson and as committee; roles behave (only treasurer manages access).

**Core**
- [ ] Create an event, add 18 participants, record contributions and expenses; balances correct.
- [ ] Languages: switch through all 13 languages, no clipped text; **Arabic shows right-to-left** correctly (icons, numbers, dialogs).
- [ ] Currencies: test zero-decimal (IDR, JPY, KRW, VND), two-decimal (USD, EUR, MYR) and three-decimal (KWD/BHD if offered) currencies; entry, totals, reports, CSV and PDF show correct decimals and symbols; amounts stay exact (no rounding drift).
- [ ] Large text: set the app text size to 150% and the phone to maximum font size; no overflow on primary screens. High contrast on.
- [ ] Dark mode and light mode readable; accent colours OK.
- [ ] Offline: turn on airplane mode, add transactions, restart the app, data still there; reconnect and verify it syncs; create a conflict from two devices and resolve it.
- [ ] Receipts: take a photo, choose from gallery, upload, view full screen on another member's device, check that a non-member cannot open the URL; uploads over 5 MB / wrong types rejected gracefully; web build shows an explanation instead of the camera.
- [ ] Reminders: schedule a notification; it fires; survives reboot; works with battery optimisation on common phones; WhatsApp reminder opens with the right number.
- [ ] Exports: PDF, CSV, WhatsApp text; **no phone numbers** in any.

**Sharing and privacy**
- [ ] Create share link; open it in a private browser window without login: totals, participants, transactions visible; **no phone numbers, no receipt images**; "has receipt" indicator only.
- [ ] Revoke as treasurer; the link stops working immediately (shows "not found"); a non-treasurer cannot revoke; creating again gives a new token.
- [ ] Account deletion: as a non-treasurer member (history remains, your name no longer linked); as treasurer with other members (role passes to another member); as the last member (workspace deleted); signing in afterwards fails; reinstall shows no data. Confirm the Supabase `auth.users` row is gone.
- [ ] Privacy policy, terms and support link are reachable from the app and the store listing.

**Release**
- [ ] `flutter analyze` and `flutter test` pass; CI green; tag equals pubspec version; build number higher than the last upload.
- [ ] Installed release build points to production Supabase (not staging or demo mode).
- [ ] Restore drill done; alerts configured; support email monitored; store listings, screenshots, Data safety and nutrition label completed.
