# Memory Log

## 2026-08-24

- User wants a persistent memory for the Event Planner Agent project.
- Chosen source of truth: GitHub repo `https://github.com/yukimurakanzaki/eventagent.git`.
- Reason for choosing GitHub: version history, reviewability, and proximity to future app code.
- Created `event-planner-agent/source-of-truth` as the project memory folder.
- Repo was fresh at setup time, with only `README.md` present.

## Working Notes

Add future dated notes below this line.

## 2026-08-24 Prototype increment

- Built a clickable low-fidelity cashbook prototype in `event-planner-agent/prototype`.
- Fixed scenario: Wisata Dieng, 12–14 September 2026, 18 participants; treasurer is the primary user.
- Covered the required Ringkasan, Peserta, Uang, and Laporan flow, including visible payment states, history-preserving replacement, budget/carry-over/sponsor context, additional contributions, and report handoff states.
- No backend persistence or permanent refund policy was invented; both remain explicit open questions.

## 2026-08-24 Backlog pass

- Added a minimal event/participant/transaction data model and documented derived cashbook rules.
- Added localStorage persistence with a resettable demo state, modal validation, computed balance/target values, and participant rendering.
- Added print-ready PDF handoff behavior and generated WhatsApp summary copy behavior.
- Headless render inspection caught and fixed the initially visible modal and an incorrect seed balance calculation.
- Community validation, refund policy, and final report wording remain open as documented questions.

## 2026-08-24 Confirmed product decisions

- Cancellation uses a per-participant refund choice: no refund, partial refund, or full refund; refunds are explicit transactions owned by the treasurer.
- Cancelled participants leave the active count, but event capacity remains fixed unless the event changes. A replacement's payment remains independent.
- Sponsor increases from the same sponsor are allowed before participant payments start; sponsor/opening-balance edits require confirmation and audit entries, and opening-balance changes recalculate the target.
- Production direction is a shared mobile app with login, hosted storage, backups, and audit history for chairperson and treasurer access.
- The remaining open questions are final report/WhatsApp wording and the production mobile/database stack.

## 2026-08-24 Report reference decision

- Reviewed the supplied blu portfolio PDFs as visual references only; they use a named period header, opening/income/expense/ending balance table, total row, page numbering, and disclaimer.
- Recommended a WargaKas portfolio/e-transcript with participant names, statuses, payment/refund amounts, expense details, creator role, and a no-bank-account-number disclaimer.
- Recommended WhatsApp copy with names and payment statuses for the community group, while excluding account numbers, login information, phone numbers, and identity documents.

## 2026-08-24 Next direction accepted

- Recommended next direction: Flutter Android-first app with Firebase Authentication and hosted data; final stack confirmation is still pending.
- Next implementation should begin with the mobile shell, hosted event model, authentication, role-aware shared access, and accounting-rule tests before Play Store submission work.

## 2026-08-25 Mobile shell started

- Installed Flutter stable 3.47.1 through Puro, Dart 3.13.1, Android Studio, and Android SDK 36 with accepted Android licenses.
- Added `event-planner-agent/mobile` as an Android-first Flutter shell with the fixed Indonesian navigation and static Dieng states for summary, participants, money, and reports.
- Flutter analysis, widget tests, and a debug APK build passed. The backend and authentication choice remains open.

## 2026-08-25 Mobile local-first slice

- Added typed Flutter records and calculation functions for events, participants, payments, refunds, expenses, reminders, and sync operations.
- Added device-local JSON persistence through `shared_preferences` and a pending sync queue; participant edits, cancellations, transactions, reminders, and queue acknowledgements are wired to the UI.
- Added mobile tests for contribution target, balance/refund accounting, serialization, queue behavior, sponsor locking, navigation, and participant history.
- The remaining production work is hosted sync/authentication, conflict resolution, structured/encrypted storage, and real report handoff generation.

## 2026-08-25 Local deadline notifications

- Added Android local notification scheduling for future Pengingat items, startup restoration, reboot receivers, and cancellation when a reminder is completed.
- Added a controller test for schedule/cancel behavior. The prototype uses Asia/Jakarta and inexact scheduling; production must validate device timezone handling and OEM battery restrictions.
- Hosted sync/authentication, structured/encrypted storage, audit history, and real PDF/WhatsApp generation remain unresolved production work.

## 2026-08-25 Supabase hosted slice

- Selected Supabase for the hosted implementation because the user already has a Supabase project; Flutter remains the Android-first client.
- Added a migration with workspaces, treasurer/chairperson memberships, events, versioned cashbook state, RLS policies, an optimistic sync RPC, and a database-triggered audit table.
- Added Flutter email/password auth, environment-based Supabase configuration, first-user Dieng workspace bootstrap, hosted state pull/push, conflict preservation, and local fallback when credentials are absent.
- Project `yytzncyxyulwqsanejcg` is now linked through the authenticated Supabase CLI and migration `202608260001_cashbook_shared_state.sql` is deployed. `supabase migration list` matches local and remote history; linked schema lint passes. Authenticated multi-device/RLS smoke tests still need a test account flow.

## 2026-08-25 Chairperson access

- Added a server-authorized `invite_workspace_member` RPC and a mobile account control for the treasurer to grant chairperson access to an existing Supabase account by email.
- The action is workspace-scoped and does not add email delivery or complex permissions. The migration is now deployed to the user's Supabase project; live treasurer/chairperson account testing remains.

## 2026-08-25 Mobile email confirmation callback

- The first account confirmation used Supabase's default `http://localhost:3000` Site URL and ended at an expired/dead web callback.
- Added `emailRedirectTo: io.wargakas.mobile://auth-callback/`, registered the Android deep-link intent filter, and added the exact callback to the linked Supabase Auth redirect allow-list.
- Disabled Flutter's competing default deep-link handler so `supabase_flutter`/`app_links` owns the callback, and made PKCE explicit during Supabase initialization.
- Rebuilt and installed the configured APK; Android resolves the callback to `MainActivity`. The user must install this latest APK and request a fresh confirmation email because the previous link was generated before the handler fix.

## 2026-08-24 Treasurer validation feedback

- Treasurer liked the core prototype flow.
- New validated production requirement: the app must remain usable without reliable internet signal while traveling.
- New validated production requirement: the treasurer needs deadline reminders for down-payments, collection rounds, headcount confirmation, and report preparation.
- Keep the fixed navigation unchanged; add reminders contextually under Ringkasan rather than introducing itinerary booking or calendar integrations.

## 2026-08-25 Email confirmation resend diagnosis

- Supabase Auth confirms the test account before the resend attempt; its `Confirmed at` timestamp is populated and the latest `/signup` request returned HTTP 200.
- Treat this state as an active account that should use `Masuk`, not as an account waiting for another signup email. The mobile confirmation state now provides a direct `Akun sudah dikonfirmasi? Masuk sekarang` action and uses neutral resend copy.

## 2026-08-25 SIT assertion fix

- Reproduced the Flutter `_dependents.isEmpty` assertion risk in the participant action flow: a bottom-sheet `BuildContext` was reused after the sheet had been popped.
- Reworked the action sheet to return `edit` or `cancel`, then opened the next dialog from the still-active page context. Also removed nested `MaterialApp` replacement from the Supabase auth/loading shell so inherited widgets remain under one root app during state changes.
- Added widget coverage for participant edit and cancellation, and verified the full Flutter suite, APK build, emulator install, and startup log.
