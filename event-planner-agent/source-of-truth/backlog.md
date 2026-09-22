# Backlog

## Current Gate: Problem Validation And BRD

- [x] Complete the first detailed organizer interview and extract the problem, roles, lifecycle, money rules, controls, and success outcome.
- [x] Reframe the primary outcome as preventing suspicion of fund misuse through shared evidence, consistent calculations, and complete audit history.
- [ ] Interview 4–6 additional community treasurers using the same last-real-event, non-leading approach. Respondent 2 completed on 2026-09-20; independence from respondent 1 is unconfirmed.
- [ ] Confirm respondent 2 is not from respondent 1's community or social circle; both described a Dieng trip, a paper notebook, and a Word/PDF/text report.
- [ ] Re-test with respondent 1: committee members as payers in the participant list, per-transaction report detail, the communal-money ledger boundary, and whether participant-specific charges enter the book only when the shared cash pays first.
- [ ] Ask respondent 2 the topics not yet covered: delegation when the chairperson is unavailable, participant comprehension of the ledger, and error reporting.
- [ ] Test willingness to move from paper to an application. Both respondents confirm the problem but neither has ever searched for a tool, so adoption is a separate and currently unsupported hypothesis.
- [ ] Interview 2–3 chairpersons to test authority, delegation, closing-balance, replacement, charity, and deficit decisions.
- [ ] Test the highest-risk rules: first-vendor-payment refund cutoff, reversible sponsor conversion, direct replacement settlement, immediate unapproved expenses, named advances, participant-specific charges, equal surplus distribution, and event closing/reopening.
- [ ] Validate participant comprehension and privacy using redacted receipt, arrears-list, audit-history, PDF, DOCX, and error-reporting examples, including older participants.
- [ ] Classify every proposed requirement as `Validated`, `Assumed`, `Rejected`, or `Needs more evidence` across respondents.
- [ ] Revise the data model, role matrix, acceptance criteria, and implementation backlog only after the discovery gate is reviewed.

Technical SIT, SMTP setup, release rehearsal, and new implementation are intentionally deferred until this gate is complete.

## Existing Implementation Status

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
- [x] Keep destination voting and planning discussion in WhatsApp; record committee budget drafts and the chairperson-approved result in Wargakas.
- [x] Use the absence of unresolved suspicion of fund misuse as the primary business outcome for respondent 1.
- [ ] Confirm whether the respondent-1 role and governance model transfers to other community groups.
- [ ] Confirm whether automatic receipt redaction is reliable and understandable enough for participant-facing evidence.

## Later

- [x] Create the initial Flutter Android shell with `Acara Saya → Ringkasan | Peserta | Uang | Laporan` and verify a debug APK can be built.
- [x] Add local persistence and report handoff generation to the prototype.
- [x] Add static deployment/run notes in `prototype/README.md`.
- Prepare Play Store assets, privacy policy, Data safety declaration, signed AAB, internal test, and closed-test release after the mobile MVP is functional.
