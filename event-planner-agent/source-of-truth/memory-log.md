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
- Added Flutter email/password auth, environment-based Supabase configuration, first-user Dieng workspace bootstrap, hosted state pull/push, and conflict preservation. Hosted mode is now the default; local demo mode requires an explicit build flag.
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

## 2026-08-27 Complete mobile auth journey

- Implemented the explicit hosted auth gate, account creation, confirmation-pending/resend state, password recovery, expired-link messaging, session loading, session-error handling, visible account area, logout confirmation, and unsynced-change warning.
- Scoped local snapshots and pending sync queues by authenticated user and workspace so a second account on the same device does not inherit the previous account's local data.
- Localized the account role labels to `Bendahara` and `Ketua acara` while keeping the internal Supabase roles unchanged.
- Added widget coverage for the hosted configuration boundary, expired-link guidance, account/logout flow, and unsynced logout warning. `flutter analyze`, 15 Flutter tests, hosted-path APK build, explicit demo APK build, and final debug APK build pass. Real email/Supabase two-account SIT on MuMu remains a manual follow-up.

## 2026-09-05 Physical phone iteration workflow

- Added `mobile/run-phone.ps1`, which reads the hosted Supabase values from the current PowerShell session and starts `flutter run` for a selected Android device.
- The intended development loop is one initial debug install followed by Flutter hot reload (`r`) or hot restart (`R`) for Dart changes. A standalone APK can be upgraded in place with `adb install -r` without uninstalling and losing local test data.
- The current machine has no authorized physical phone connected; ADB only reports an offline emulator, so physical-device auth and deep-link validation remain pending.

## 2026-09-05 Missing hosted build configuration fixed

- The reported configuration screen came from an APK without compile-time Supabase settings. Retrieved the linked project's publishable app key using the authenticated CLI and saved it in Git-ignored `mobile/supabase.local.json`; no secret/service-role key was embedded.
- Extended `run-phone.ps1` to load local settings, allow environment overrides, force hosted mode, support `-BuildApk`, and run from the mobile directory regardless of the caller's location. Corrected the README's unconfigured APK command.
- Verified Supabase Auth health returned HTTP 200, PowerShell syntax passed, Git ignores the local configuration, `git diff --check` passed, and the configured debug APK built successfully.
- Reconnected the running MuMu instance at `127.0.0.1:7555`, upgraded the app with `adb install -r`, and launched it. Logs confirm Supabase initialization; Android UI hierarchy confirms `Masuk ke Wargakas`, login, recovery, and signup controls instead of the configuration screen. Screenshot capture was black, so visual rendering and actual account sign-in remain unverified. Physical-phone and two-account SIT remain pending.

## 2026-09-06 Hosted authentication hardening

- Audited login, registration, confirmation resend, forgot-password, new-password, session refresh/expiry, workspace loading, and account-switch behavior against current Supabase semantics.
- Supabase deliberately obscures some duplicate-signup responses to prevent account enumeration. Wargakas now uses conditional wording instead of claiming that an account was created or an email was delivered, and directs existing users to login or recovery.
- Added centralized email/new-password validation, password confirmation and visibility controls, safe code-based Indonesian errors, 30-second request timeouts, one-request guards, disabled inputs while pending, and a shared 60-second email cooldown.
- Fixed recovery forms closing on token refresh/user update, the post-password-update loading loop, transient stream errors removing valid sessions, session-expiry guidance, duplicate workspace reloads, stale account-load responses, workspace timeout/retry, and the retry callback's asynchronous `setState` assertion.
- Restricted deep-link parsing to `io.wargakas.mobile://auth-callback/`; real-SDK tests verify signup/resend/recovery pass the callback and independent PKCE challenges.
- `flutter analyze` passed; all 66 tests passed; small-phone/large-text auth renders were inspected; the configured APK rebuilt, upgraded in MuMu, restored `merdekaid789@gmail.com`, and opened the hosted Wisata Dieng workspace. Live email delivery and link-driven confirmation/recovery remain manual; configure custom SMTP before external testing.

## 2026-09-06 Controlled MVP pilot implementation

- Secured the existing hosted authentication and SIT work in separate baseline commits before starting the pilot increment.
- Added one-event editing with validation, before/after confirmation, sponsor locking after participant payments, offline queueing, and server audit payloads.
- Added persisted whole-snapshot conflict resolution. Mutations stop until the user explicitly keeps the online version or submits the local version against the current server version.
- Added local PDF generation and WhatsApp-ready native sharing from a shared report model, including participant/refund status, detailed transactions, page numbers, and privacy redaction.
- Adopted `io.wargakas.mobile`, added ignored stable pilot signing configuration, a configured release APK workflow, and GitHub CI for analysis, tests, prototype checks, and a demo APK build.
- Automated checks and release packaging can be completed locally, but real email delivery, two-account RLS/data sharing, two-device offline conflict behavior, and audit evidence remain gated by the manual P0 SIT.

## 2026-09-06 Participant-payment entry safety

- MuMu testing exposed that the money-entry dialog silently defaulted to `Pengeluaran`. A user who entered an amount and note without deliberately changing the type would not increase the participant-payment total.
- The dialog now requires an explicit transaction type, explains that `Pembayaran peserta` requires a selected participant, and the controller rejects participant payments/refunds that have no valid participant. Unit and widget tests cover the calculation and the missing-type guard.

## 2026-09-07 Focused mobile UI refresh

- Added a labelled, persistent `Catat transaksi` floating shortcut on every authenticated tab. It opens one explicit transaction form; during a sync conflict, the same position instead directs the user to resolve the conflict.
- Reworked the transaction form for recognition and error prevention: four visible transaction choices, conditional participant selection, formatted rupiah input, outlined fields, inline guidance, and a disabled save action until the form is complete.
- Reduced repeated event-header height, placed report sharing actions before the long preview, grouped active and cancelled participants, clarified healthy offline status, and made confirmation resend contextual.
- Local verification covers analyzer, all tests, and an emulator visual pass. Usability validation with 2–3 treasurers aged 50+ remains a separate manual step.

## 2026-09-07 Event editor narrow-screen repair

- Replaced the compressed two-column date row with full-width, 56dp start and end date controls; widened the responsive dialog inset, made the form vertically scannable, and kept the action row visible while the fields scroll.
- Added a 320dp / 200% text-scale widget check and visually inspected the repaired editor on MuMu. Event validation, sponsor locking, confirmation, and audit behavior remain unchanged.

## 2026-09-07 Refund dialog lifecycle repair

- Reproduced Flutter's `_dependents.isEmpty` assertion while saving a participant refund: the form's text controllers were disposed before the dialog route and its participant dropdown had finished leaving the widget tree.
- Refund and cancellation dialogs now return the selected data first, then apply the cashbook mutation after the route closes. Widget coverage verifies cancellation and a selected participant refund; `flutter analyze` and the full test suite pass.

## 2026-09-08 Refund accounting guard

- Fixed the cancellation path so `Refund penuh` creates an explicit refund transaction for the participant's remaining paid amount, while `Refund sebagian` requires a valid amount before cancelling the participant.
- Manual refund entry now lists only participants with refundable value, shows the available maximum, and rejects any refund above the participant's net payment. Controller and widget regression coverage covers full refund creation, partial-refund caps, and over-refund rejection.

## 2026-09-08 Net payment status after refund

- Fixed the participant status and report display to use net payment (`participant payments - refunds`) rather than gross payment. A participant who was fully paid and receives a partial refund now shows `Sebagian`, with gross payment, refund, and net value visible for auditability.
