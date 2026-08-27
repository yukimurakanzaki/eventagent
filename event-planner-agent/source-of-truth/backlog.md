# Backlog

## Next

- [x] Expand the mobile shell into a typed local data model and sync queue; keep hosted backend selection open until the hosted-data decision is confirmed.
- [x] Set up Supabase Authentication and hosted event data with treasurer/chairperson access. Project `yytzncyxyulwqsanejcg` is linked and the migration is deployed; authenticated account/RLS smoke tests remain.
- [x] Port the target, cash-balance, payment-state, fixed-capacity, sponsor-lock, refund, and replacement rules into the mobile model with tests.
- Implement hosted sync transport, retry/conflict handling, and server-side audit writes for payments, expenses, participants, and reminders. Client optimistic replay, conflict preservation, migration, and audit trigger are added; authenticated multi-device verification remains.
- [x] Add a contextual Pengingat card under Ringkasan with local reminder state and Android local notification scheduling. Production timezone and battery-optimization behavior still need validation.
- Validate reminder wording and timing with the treasurer using real planning dates.
- Run usability testing with 2–3 community treasurers aged 50+ using the mobile shell.

## Questions

- [x] Agree on the named portfolio/e-transcript report and low-privacy WhatsApp wording, with account numbers and credentials excluded.
- [x] Choose Flutter + Supabase as the first hosted direction; retain Flutter Android-first.
- [Open] If the same reminder is edited on two devices while offline, which change should win and how should the treasurer be notified?
- [Open] Should chairperson-created reminders notify the treasurer, the chairperson, or both?
- [Open] What quiet hours and notification tone are appropriate for the 50+ user group?
- [Open] Should production reminders use the phone timezone automatically, and which Android battery-optimization guidance should be shown to the treasurer?
- [x] Use a simple treasurer-approved email membership action for an existing chairperson account; no complex permissions are added.

## Later

- [x] Create the initial Flutter Android shell with `Acara Saya → Ringkasan | Peserta | Uang | Laporan` and verify a debug APK can be built.
- [x] Add local persistence and report handoff generation to the prototype.
- [x] Add static deployment/run notes in `prototype/README.md`.
- Prepare Play Store assets, privacy policy, Data safety declaration, signed AAB, internal test, and closed-test release after the mobile MVP is functional.
