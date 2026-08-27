# Project Brief

## Working Name

Event Planner Agent

## Product Idea

An event planning assistant whose first validated artifact is a community-trip cashbook for treasurers.

## Current Repo

GitHub repository: https://github.com/yukimurakanzaki/eventagent.git

## Source Of Truth Location

`event-planner-agent/source-of-truth`

## Fixed MVP Scenario

- Event: Wisata Dieng
- Dates: 12–14 September 2026
- Participants: 18
- Primary user: community treasurer, especially users aged 50+
- Chairperson: provides the final budget and handles planning/accommodation.
- Treasurer: manages participant payments, expenses, balance, and reporting.
- Validated need: the treasurer must be able to work with weak or unavailable signal and receive reminders for collection and planning deadlines.

## MVP Scope: Community-trip cashbook

Navigation is fixed as `Acara Saya → Ringkasan | Peserta | Uang | Laporan`.

The prototype at `event-planner-agent/prototype` covers creating an event, adding/editing participants, final budget, sponsor contribution, opening balance/carry-over, visible automatic contribution calculation, participant payments (lunas, sebagian, belum bayar), expenses, current balance, cancellation/replacement without deleting history, additional contributions, report preview, and PDF/WhatsApp handoff states. It also includes contextual onboarding, tooltips, empty guidance, validation-oriented forms, and confirmation messages.

The production mobile app must extend this with offline-first local storage, queued sync when signal returns, and local deadline reminders for collection and planning tasks. The fixed navigation remains `Acara Saya → Ringkasan | Peserta | Uang | Laporan`; reminders appear contextually in Ringkasan and the event detail rather than replacing the fixed navigation.

It explicitly excludes AI, booking/accommodation integrations, maps, OCR, payment gateways, complex collaboration/permissions, and other unvalidated features.

## Open Questions

- The exact PDF template and WhatsApp message wording still need validation with a treasurer.
- The first production mobile stack is Flutter Android-first with Supabase Auth and hosted Postgres. Project `yytzncyxyulwqsanejcg` is linked and the first migration is deployed; publishable credentials remain build-time configuration and are not committed.
- The prototype remains representative-data/local-browser based; the mobile slice now has local storage, queued sync, and a deployed Supabase migration/client path. Production still requires backups, authenticated multi-device smoke tests, and release hardening.
- The sync-conflict policy, reminder ownership, quiet hours, and notification wording still need validation.
