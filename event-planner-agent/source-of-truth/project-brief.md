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

## MVP Scope: Community-trip cashbook

Navigation is fixed as `Acara Saya → Ringkasan | Peserta | Uang | Laporan`.

The prototype at `event-planner-agent/prototype` covers creating an event, adding/editing participants, final budget, sponsor contribution, opening balance/carry-over, visible automatic contribution calculation, participant payments (lunas, sebagian, belum bayar), expenses, current balance, cancellation/replacement without deleting history, additional contributions, report preview, and PDF/WhatsApp handoff states. It also includes contextual onboarding, tooltips, empty guidance, validation-oriented forms, and confirmation messages.

It explicitly excludes AI, booking/accommodation integrations, maps, OCR, payment gateways, complex collaboration/permissions, and other unvalidated features.

## Open Questions

- The exact PDF template and WhatsApp message wording still need validation with a treasurer.
- The future production mobile stack and hosting provider are not selected yet.
- The prototype uses representative data and local browser persistence only; production requires login, hosted storage, shared access, backups, and audit history.
