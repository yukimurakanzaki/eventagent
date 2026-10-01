# Project Brief

## Working Name

Event Planner Agent

## Product Idea

A community-event financial-accountability system whose first product is a shared trip cashbook. Its primary outcome is to prevent suspicion of fund misuse by making every contribution, expense, receipt, correction, and decision traceable to the group.

## Current Repo

GitHub repository: https://github.com/yukimurakanzaki/eventagent.git

## Source Of Truth Location

`event-planner-agent/source-of-truth`

## Fixed MVP Scenario

- Event: Wisata Dieng
- Dates: 12–14 September 2026
- Participants: 18
- Primary user: community treasurer, especially users aged 50+
- Chairperson: final authority for the plan, budget, roles, replacements, deficit handling, and closing-balance decisions; may exercise treasurer authority when the treasurer is unavailable.
- Optional vice-chairperson: receives chairperson authority only while an explicit delegation is active.
- Treasurer: manages participant-payment verification, cash receipt, balance, expenses, refunds, and reporting.
- Committee members: research and enter budget drafts, record expenses and advances, and maintain evidence with a complete audit trail.
- Participants: see read-only financial records and redacted receipts, upload transfer evidence, report errors while the event is open, and export reports.
- Primary validated problem for respondent 1: paper records and manually retyped reports create loss risk, reconciliation work, and suspicion that event funds were misused. Cross-community validation is still required.

## MVP Scope: Community-trip cashbook

Navigation is fixed as `Acara Saya → Ringkasan | Peserta | Uang | Laporan`.

The prototype at `event-planner-agent/prototype` covers creating an event, adding/editing participants, final budget, sponsor contribution, opening balance/carry-over, visible automatic contribution calculation, participant payments (lunas, sebagian, belum bayar), expenses, current balance, cancellation/replacement without deleting history, additional contributions, report preview, and PDF/WhatsApp handoff states. It also includes contextual onboarding, tooltips, empty guidance, validation-oriented forms, and confirmation messages.

The Android MVP currently supports one configurable event per workspace with offline-first local storage, queued sync, explicit whole-version conflict resolution, local deadline reminders, offline PDF generation, and native sharing. Discovery on 2026-09-19 identified a broader provisional role model and financial lifecycle that the current implementation does not yet cover: chairperson, delegated vice-chairperson, treasurer, committee, and participant; participant-submitted payment evidence; participant read-only transparency; reversible soft deletion; advances and sponsor conversion; budget revisions; participant-specific charges; receipt redaction; DOCX export; and event closing/reopening controls. These are respondent-1 requirements until repeated with additional users.

Destination selection, voting, vendor research, and itinerary discussion remain in WhatsApp. Wargakas records committee budget drafts and the chairperson-approved final plan; it does not need chat, polling, booking, maps, or automated itinerary planning in the first release. The fixed navigation remains `Acara Saya → Ringkasan | Peserta | Uang | Laporan` unless later usability evidence requires a change.

It explicitly excludes AI planning, booking/accommodation integrations, maps, payment gateways, in-app chat/polling, automated itinerary generation, and other unvalidated features. Limited automatic detection and masking of sensitive receipt data is a candidate requirement; the uploader must inspect and approve the redacted version before participants can see it.

## Current Discovery Status

- One detailed primary interview has been completed with a community-trip organizer.
- Strongest outcome: no unresolved suspicion or accusation of fund misuse caused by missing evidence or inconsistent reporting.
- Confirmed for this respondent: shared participant visibility, complete audit history, direct receipt access with sensitive-data masking, on-demand PDF/DOCX/text reports from one ledger, and explicit governance for plan, money, disputes, and closing.
- Evidence is not yet sufficient to claim these rules represent all treasurers or community groups.
- Technical SIT and further feature expansion are deferred until the problem and high-risk business rules are tested with additional treasurers and chairpersons.
- A second detailed interview was completed on 2026-09-20 with another community-trip organizer. Independence from respondent 1 is unconfirmed, so findings shared by both are treated as strong candidates rather than validated facts.
- Confirmed by both respondents: financial suspicion is real and recurring; the chairperson sets the contribution target; sponsors pledge fixed rupiah amounts; a replacement settles directly with the original participant without moving event cash; committee personal money is an advance repaid from event cash; participants are entitled to see expense evidence; the remaining balance is announced and carried into the next activity.
- Contradicted between respondents and unresolved: the first-vendor-payment refund cut-off, mandatory receipt redaction, event locking and reopening, participant-specific charges entering the ledger, and charity use of the surplus.
- Respondent 2 adds that suspicion can target the committee for not paying its own contribution, that an aggregate-only report triggers suspicion by itself, that verbal dispute resolution leaves no reusable trace, and that the paper records genuinely are incomplete.
- Adoption is not validated. Neither respondent has ever used or searched for an app or spreadsheet for event finances, so problem evidence must not be read as willingness to switch tools.

## Open Questions

- Validate the respondent-1 findings with 4–6 additional treasurers and 2–3 chairpersons before treating them as general product requirements.
- Validate whether automatic sensitive-data masking is trustworthy enough for real receipts and which fields must always be hidden.
- Validate the detailed PDF/DOCX layout and WhatsApp wording with older participants.
- The first production mobile stack is Flutter Android-first with Supabase Auth and hosted Postgres. Project `yytzncyxyulwqsanejcg` is linked and the first migration is deployed; publishable credentials remain build-time configuration and are not committed.
- The prototype remains representative-data/local-browser based; the mobile slice now has local storage, queued sync, and a deployed Supabase migration/client path. Production still requires backups, authenticated multi-device smoke tests, and release hardening.
- The existing whole-snapshot conflict model must be reassessed against the emerging multi-role, field-level audit and approval workflows before implementation resumes.
