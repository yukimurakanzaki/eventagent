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
