# Backlog

## Next

- [x] Expand the mobile shell into a typed local data model and sync queue; keep hosted backend selection open until the hosted-data decision is confirmed.
- [x] Set up Supabase Authentication and hosted event data with treasurer/chairperson access. Project `yytzncyxyulwqsanejcg` is linked and the migration is deployed; authenticated account/RLS smoke tests remain.
- [x] Port the target, cash-balance, payment-state, fixed-capacity, sponsor-lock, refund, and replacement rules into the mobile model with tests.
- Implement hosted sync transport, retry/conflict handling, and server-side audit writes for payments, expenses, participants, and reminders. Client optimistic replay, conflict preservation, migration, and audit trigger are added; authenticated multi-device verification remains.
- [x] Add one-event editing for name, dates, capacity, final budget, sponsor, and opening balance with validation, confirmation, offline queueing, and audit payloads.
- [x] Add persisted explicit conflict resolution that blocks edits and lets the user keep the online or local whole snapshot.
- [x] Add offline PDF generation and WhatsApp-ready native sharing with shared totals and privacy redaction.
- [x] Add permanent Android application identity, stable local pilot signing, configured release builds, and repository CI.
- [ ] Execute the two-account Supabase SIT in `source-of-truth/supabase-sit-test-cases.md`, including an optional non-member RLS check.
- [ ] Finish live hosted authentication SIT on real inboxes/devices. Login/session restore and account area are verified on MuMu; registration, delivery, confirmation callback, recovery callback, and logout still require deliberate live execution without exposing passwords.
- [ ] Run the realistic-data rehearsal and approve the gate before entering any real trip financial data.
- [ ] Configure and verify custom SMTP before inviting external testers. The app handles restricted delivery and rate limits safely, but Supabase's built-in test sender is not a production email service.
- [x] Add a contextual Pengingat card under Ringkasan with local reminder state and Android local notification scheduling. Production timezone and battery-optimization behavior still need validation.
- [x] Refresh the mobile UI for 50+ treasurers: compact event context, clearer financial hierarchy, grouped participant states, contextual authentication actions, report actions above the preview, and a global `Catat transaksi` shortcut with explicit transaction choices.
- Validate reminder wording and timing with the treasurer using real planning dates.
- Run usability testing with 2–3 community treasurers aged 50+ using the mobile shell.

## Questions

- [x] Agree on the named portfolio/e-transcript report and low-privacy WhatsApp wording, with account numbers and credentials excluded.
- [x] Choose Flutter + Supabase as the first hosted direction; retain Flutter Android-first.
- [x] Use explicit whole-snapshot conflict resolution: choose the online version or the device version; never merge or overwrite silently.
- [x] Chairperson-created reminders notify the treasurer.
- [x] Quiet hours are 20:00–07:00 in the device timezone. Notification wording still needs treasurer validation.
- [x] Production reminders use the phone timezone automatically. Android battery-optimization guidance still needs validation with the treasurer.
- [x] Use a simple treasurer-approved email membership action for an existing chairperson account; no complex permissions are added.

## Later

- [x] Create the initial Flutter Android shell with `Acara Saya → Ringkasan | Peserta | Uang | Laporan` and verify a debug APK can be built.
- [x] Add local persistence and report handoff generation to the prototype.
- [x] Add static deployment/run notes in `prototype/README.md`.
- Prepare Play Store assets, privacy policy, Data safety declaration, signed AAB, internal test, and closed-test release after the mobile MVP is functional.
