# Decisions

## Accepted

### 2026-08-24: Use GitHub As Persistent Project Memory

Decision: Keep the source of truth in the GitHub repository instead of Google Drive.

Reasoning: GitHub provides version history and lets project memory evolve alongside the application code.

### 2026-08-24: Start with a community-trip cashbook MVP

Decision: Build the first prototype around a treasurer managing the Wisata Dieng trip (12–14 September 2026, 18 participants).

Reasoning: This narrows the first user journey to a concrete task: knowing who has paid, what has been spent, and what can be reported to the group.

### 2026-08-24: Keep accounting rules visible

Decision: Show the contribution calculation, payment status, balance formula, and history-preserving cancellation states in plain Indonesian.

Reasoning: The primary user may be aged 50+, so the prototype should not require remembering accounting rules or infer hidden state.

### 2026-08-24: Use a dependency-free static prototype

Decision: Put the clickable artifact in `event-planner-agent/prototype` using HTML, CSS, and JavaScript.

Reasoning: The repository had no application scaffold; a direct-open prototype is the smallest useful increment and keeps review easy.

### 2026-08-24: Use local-only persistence for prototype validation

Decision: Persist demo edits in browser `localStorage` under `eventagent.cashbook.v1` and provide a reset action.

Reasoning: This validates stateful interactions without inventing authentication, collaboration, or a production backend.

### 2026-08-24: Keep refund policy provisional

Decision: Preserve cancelled participants and payment history, and let the treasurer choose `Tidak ada refund`, `Refund sebagian`, or `Refund penuh` for each cancellation. Any refund is recorded as an explicit transaction.

Reasoning: A no-refund case is valid for the current family use case, but future events may require another policy. The choice belongs to the treasurer and must remain visible in history.

### 2026-08-24: Keep event capacity separate from active participants

Decision: An event has a participant capacity (18 for Wisata Dieng) that does not decrease when someone cancels. A cancelled participant is excluded from the active participant count, and a replacement's payment is independent of the cancelled participant's payment.

Reasoning: The trip cost and allowed capacity are event-level facts; participant payments belong to individual people and must not be silently transferred.

### 2026-08-24: Sponsor and opening-balance changes are audited

Decision: The treasurer may increase sponsor contribution from the same sponsor, and may edit opening balance/carry-over, but every change requires confirmation and creates an audit entry. Sponsor contribution cannot be added after participant payments have started.

Reasoning: These values affect the participant target and must be explainable after money has moved.

### 2026-08-24: Target a shared mobile app with hosted persistence

Decision: The production direction is a mobile app with login, hosted database storage, shared chairperson/treasurer access, backups, and audit history.

Reasoning: Local browser storage is not safe when a treasurer changes phones or clears app/browser data, and the chairperson and treasurer need a shared source of truth.

### 2026-08-24: Make handoff testable without integrations

Decision: Use the browser print dialog for “Simpan sebagai PDF” and copy a generated Indonesian summary for WhatsApp.

Reasoning: This validates the handoff state without adding external integrations or pretending a gateway exists.

### 2026-08-24: Use a named portfolio/e-transcript report

Decision: The final report shows participant names, payment/refund status, participant net balance, expense detail, opening balance, income, expense, ending balance, report period, and the report creator role. Both the treasurer and chairperson can generate it.

Reasoning: The uploaded portfolio references use a named, period-based statement with clear opening/income/expense/ending totals. That structure is understandable to older users and supports accountability without exposing bank account numbers.

### 2026-08-24: Recommend low-privacy WhatsApp copy with safety boundaries

Decision: The recommended WhatsApp summary may include participant names, payment status, and nominal amounts for the community group, but must not include bank account numbers, login details, phone numbers, or sensitive identity documents.

Reasoning: The user prefers low privacy for practical group coordination, but financial account credentials and identity data remain unsafe to broadcast.

### 2026-08-24: Proposed Flutter and Firebase production direction

Proposal: Use Flutter for the Android-first mobile app and Firebase for Authentication, hosted data, backups/supporting services, and crash reporting. This remains pending final stack confirmation.

Reasoning: This provides a practical Play Store path, simple shared access for treasurer and chairperson, and room for a future iOS build without changing the product model. Security rules and audit writes must be designed before real financial data is used.

### 2026-08-25: Select Supabase for the first hosted mobile slice

Decision: Use Supabase for the first hosted implementation because the user already has a Supabase project. Keep Flutter as the Android-first client. Supabase Auth provides email/password login; Postgres stores workspace membership, events, versioned cashbook state, and audit entries; Row Level Security enforces authenticated workspace membership.

Reasoning: This uses an existing user-owned service and supports the required hosted database, shared access, and audit history without putting a service-role secret in the app. The first implementation keeps local JSON and the queue as the offline fallback. The treasurer grants chairperson access to an already registered email; live project verification remains follow-up work.

### 2026-08-25: Keep shared access simple

Decision: The treasurer can grant the `chairperson` role to an existing Supabase account by email from the mobile account controls. The server function checks that the caller is a treasurer in the same workspace; no invitation email service or complex permissions are added.

Reasoning: This meets the validated shared-access need while keeping the first mobile MVP understandable for a 50+ treasurer and avoiding an unvalidated collaboration system.

### 2026-08-25: Return email confirmation to the mobile app

Decision: Use the explicit `io.wargakas.mobile://auth-callback/` redirect for email confirmation and register the same callback in the Android app and Supabase Auth allow-list. Keep the Supabase Site URL unchanged for now because the mobile signup call supplies `emailRedirectTo` directly.

Reasoning: The previous default Site URL was `http://localhost:3000`, which sent confirmation links to a dead web endpoint. A native callback returns the user to Wargakas without adding a web authentication surface.

### 2026-08-24: Make the production app offline-first

Decision: The mobile app must keep the current event, participant, transaction, and reminder data usable without a network connection. Changes are saved locally and queued for synchronization when signal returns.

Reasoning: The treasurer may travel through areas with weak signal. A network outage must not prevent recording a payment, expense, cancellation, or reminder.

### 2026-08-24: Add local deadline reminders

Decision: Add manual reminders for collection and planning deadlines, shown contextually in Ringkasan and delivered as device notifications. Examples include bus or accommodation down-payment deadlines, participant collection dates, final headcount confirmation, and report deadlines.

Reasoning: These reminders are useful even without signal because the device can schedule them locally. They do not require booking integrations or an itinerary service.

### 2026-08-24: Keep reminder scope simple

Decision: Reminders are event tasks with title, due date/time, optional note, status, and creator. Shared updates sync when online; local notifications remain the primary guarantee for the device that created the reminder.

Reasoning: This supports the validated use case without adding complex collaboration, calendar integrations, or automated planning.

### 2026-08-25: Start the mobile shell without locking the backend

Decision: Create the first Android-first Flutter shell in `event-planner-agent/mobile` with the fixed Indonesian navigation and a static Wisata Dieng content slice. Keep the hosted-data and authentication implementation separate until the pending production stack decision is confirmed.

Reasoning: The mobile direction is accepted, but the repository still records Firebase as a proposal while the user has also mentioned Supabase. A working shell lets us validate navigation and readability without silently making the backend decision.

### 2026-08-25: Keep the first mobile slice local-first

Decision: Store the current mobile snapshot as JSON in device-local preferences and append every participant, transaction, or reminder change to a pending sync queue. The queue can be acknowledged locally, but it does not claim to sync to a hosted backend yet.

Reasoning: This makes weak-signal use real and testable now while avoiding a permanent Firebase or Supabase decision. Before production financial data is used, the local store should be replaced or backed by a structured database with encrypted storage, authenticated sync, retries, conflict rules, and server-side audit history.

### 2026-08-25: Schedule deadline reminders on the device

Decision: The mobile slice schedules future reminders as Android local notifications, restores pending reminders after app startup and device reboot, and cancels them when the treasurer marks them complete. The scenario uses Asia/Jakarta and inexact scheduling to avoid requiring exact-alarm access in the prototype.

Reasoning: The treasurer needs deadlines to remain useful without signal. The exact production timezone behavior, quiet hours, and battery-optimization guidance remain open until tested on target phones.

### 2026-08-27: Make hosted authentication explicit

Decision: Hosted Supabase mode is the default for release and test builds. The local demo is available only through an explicit demo-mode build flag and must show that it is not connected to hosted data.

Decision: Add a complete email/password journey with sign-in, account creation, confirmation-pending, resend, password recovery, expired-link handling, session loading, session expiry, and sign-out states. Keep the direct `io.wargakas.mobile://auth-callback/` return path.

Decision: Show account access and `Keluar` in a dedicated, visible account area. Signing out requires confirmation when local changes are still waiting to sync.

Decision: Local snapshots and pending sync operations are scoped to the authenticated user/workspace. Signing out must not expose the previous account's local data to another account on the same device.

Decision: Treasurer remains responsible for payments, expenses, refunds, participants, reports, and access. Chairperson can access the shared event and planning/budget information; no complex permissions are introduced.

Reasoning: The MuMu test exposed that a build without Dart-defined Supabase credentials silently opened the local shell, making it look as if authentication was missing. Explicit modes and a complete session gate make test results trustworthy and protect local financial data during account changes.

### 2026-09-06: Define the controlled Android MVP pilot

Decision: The pilot supports exactly one configurable event per workspace. Both the treasurer and chairperson may edit all event and cashbook content, while workspace membership management remains treasurer-only. This supersedes the 2026-08-27 content-permission split.

Decision: Event corrections show before/after values and create an audit operation. Sponsor name and contribution remain locked after the first participant payment; capacity cannot be lower than the active participant count.

Decision: Offline conflicts never merge silently. Editing stops until the user explicitly keeps the complete online version or rebases and submits the complete local version as a new audited operation.

Decision: PDF and WhatsApp-ready reports are generated from the same local snapshot and use Android's native share sheet. Free-text report content redacts email addresses, phone/account-like numbers, and credential-like values.

Decision: Distribute a release-signed APK outside the Play Store for the controlled pilot. Use realistic rehearsal data first; real trip data is allowed only after all P0 two-account SIT cases pass.

Reasoning: This keeps the pilot narrow enough for one engineer while making financial edits explainable, conflict handling non-destructive, and handoff useful without a network connection.

### 2026-09-08: Reminder recipient and timezone

Decision: A reminder created by the chairperson notifies the treasurer. Production reminders follow the device timezone automatically. Quiet hours are 20:00–07:00 in the device timezone.

Reasoning: The treasurer remains accountable for collections, deadlines, and financial reporting, while automatic device-timezone handling keeps deadline reminders understandable when travelling without adding timezone configuration to the MVP. The quiet-hours window prevents routine reminders from disturbing the community at night.

### 2026-09-19: Reframe Wargakas around financial accountability

Decision: Treat Wargakas primarily as a shared financial-accountability system for community activities, not only as a cashbook. The primary business outcome is that participants do not suspect fund misuse because the ledger, evidence, decisions, and corrections are visible and traceable.

Reasoning: The first detailed BRD interview identified reputational harm and loss of trust as the most serious consequence. Manual paper records, retyping reports, missing history, personal advances, and inconsistent participant-payment evidence make accusations difficult to resolve and can cause the committee to stop organizing future activities.

### 2026-09-19: Keep trip discovery outside the first product boundary

Decision: Continue destination voting, vendor research discussion, and itinerary coordination in WhatsApp. Wargakas stores committee-entered budget drafts and the chairperson-approved final plan, budget, capacity, and itinerary summary.

Reasoning: This captures the information needed for financial planning without expanding the first product into chat, polling, booking, maps, or itinerary automation.

### 2026-09-19: Treat the first BRD interview as provisional product evidence

Decision: Use the respondent's rules as requirements for that community and as hypotheses for the broader product. Do not treat implemented behavior as proof of user validation, and do not generalize the interview until the highest-risk rules are repeated with additional treasurers and chairpersons.

Provisional rules include:

- The chairperson is final authority and holds treasurer authority; an optional vice-chairperson receives chairperson authority only during explicit delegation.
- Committee members may edit shared records with before/after audit history. Transactions use reversible soft deletion and remain visible as cancelled history.
- Participants have read-only ledger access, may upload transfer evidence, and may report errors while an event remains open. Only the treasurer or acting chairperson confirms participant payments.
- Expenses apply immediately. Receipt is optional only with a mandatory no-receipt reason. If cash is insufficient, the shortfall becomes a named person's advance rather than a negative balance.
- Advances must be repaid before closing or may be converted to sponsorship by the funder. Sponsor withdrawal is allowed only before the first vendor payment.
- The first vendor payment is the global refund cutoff. After it, an unavailable participant must transfer the slot to a replacement, who pays the original participant directly; only the chairperson approves the replacement.
- Sponsor funds and overpayments remain in the event balance. The chairperson decides after the event whether the balance is carried forward, used for documented charity/additional costs, or distributed equally to all participants who travelled.
- Committee members may revise budget drafts, but only a chairperson-finalized version changes the target. Recalculation may create shared additional contributions or participant-specific charges.
- Receipts shown to participants must be automatically redacted and then approved by the uploader; original receipts remain committee-only.
- PDF and DOCX reports are generated on demand from the same ledger, embed redacted receipt images and authenticated links, and may be downloaded by participants.
- An event cannot be locked while disputes, unverified payment evidence, unresolved advances, or incomplete required data remain. The chairperson may reopen a locked event with an audited reason.

Reasoning: These rules resolve concrete scenarios from the respondent's most recent workflow, but their frequency, comprehension, and transferability remain untested.

### 2026-09-20: Record respondent-2 evidence and keep conflicting rules separate

Decision: Record the second interview as independent evidence and classify every affected rule rather than merging respondent 2 into respondent 1. Where the two respondents disagree, both positions stay recorded as conflicting evidence and neither becomes the product rule yet.

Decision: Do not confirm any finding as `Validated` until respondent 2 is shown to come from a different community and social circle than respondent 1. Both described a Dieng trip, a paper notebook, and a Word/PDF/text report, so the apparent agreement may be one community counted twice.

Converging across both respondents (`Needs more evidence` until 4–6 treasurers, but strongest candidates):

- Financial suspicion is a real and recurring problem triggered by detail and evidence that were never shared.
- The chairperson sets and changes the participant contribution target.
- Sponsors pledge a fixed rupiah amount, not a share of the cost.
- A replacement settles directly with the original participant and the event cash balance does not move.
- Committee personal money is an advance repaid from event cash.
- Participants are entitled to see expense evidence.
- The remaining balance is announced and carried into the next activity.
- Planning stays in WhatsApp; the report is retyped by hand and shared as PDF plus plain text.

Conflicting evidence, recorded and unresolved:

- First-vendor-payment refund cut-off: respondent 1 closes refunds after it; respondent 2 has no vendor and still refunds when no replacement is found. The refund cut-off must not be hard-coded as a product rule.
- Receipt redaction: respondent 1 requires automatic redaction and uploader approval; respondent 2 photographs original receipts into the group. Respondent 2 collects cash only, so no transfer slips exist. Redaction may depend on payment method rather than being universal.
- Event locking and reopening: respondent 1 defines blocking conditions and audited reopening; respondent 2 has no closing step at all, only an announced remaining balance.
- Participant-specific charges: respondent 1 records them in the ledger; respondent 2 keeps them entirely outside it because the book holds communal money only. Possible reconciliation, untested: money enters the book when it passes through the shared cash, not according to who benefits.
- Surplus used for charity: respondent 1 lists it as an option; respondent 2 never mentions it.

Respondent-2 findings not previously recorded (`Assumed`, n=1):

- The accusation targets the committee for not paying its own contribution, so committee members must appear as payers in the same participant list.
- An aggregate-only report triggers suspicion even when a report exists; per-transaction detail is required.
- Dispute resolution happened by phone and left no trace; answers must attach to the transaction and be visible to everyone.
- The underlying records really are incomplete, so capture must happen when the money is spent, and an incomplete ledger must label its own gaps or exposing it can increase suspicion.
- A sponsor pledge and a sponsor receipt are two different objects: the pledge drives the target and may be reduced or cancelled, while only received money enters the book and the balance.
- The ledger boundary is communal money only.
- The contribution target divides by the actual active headcount, not by fixed capacity.
- Participants need read access after the event has ended.

Rules whose priority drops, with no respondent-2 support and no observed failure case: advance-to-sponsorship conversion, advances blocking event closure, equal distribution of the surplus, charity use of the surplus, automatic receipt redaction, and the locking/reopening machinery.

Implementation conflicts now supported by two respondents, recorded as requirement gaps and not as authorization to change code: sponsor locking after the first participant payment, independent replacement payments, and `targetPerPerson = need / participantCapacity`.

Adoption: neither respondent has ever searched for or used an app or spreadsheet for event finances. Respondent 2 gave availability and phone-only working as the reason. The problem is confirmed twice; willingness to switch tools has no supporting evidence. These remain two separate hypotheses and the second one is currently unsupported.

Reasoning: The second interview strengthens a small set of rules, contradicts several respondent-1 rules outright, and removes the justification for some of the heavier machinery. Recording the disagreement keeps the requirement set honest and prevents one community's governance model from being treated as the product.

## Pending

- Repeat the problem interview with 4–6 additional treasurers and 2–3 chairpersons.
- Validate the provisional role hierarchy, first-vendor-payment refund cutoff, replacement settlement, sponsor reversibility, advances, participant-specific charges, charity, and event-locking rules.
- Validate automatic receipt redaction and the PDF/DOCX/WhatsApp handoff with older participants.
- Validate reminder wording with treasurers; respondent 1 prefers a shareable arrears list instead of automatic daily participant reminders.
- Confirm that respondent 2 belongs to a different community and social circle than respondent 1 before counting any finding as two independent sources.
- Re-test with respondent 1: committee members appearing as payers, per-transaction report detail, the communal-money ledger boundary, and whether participant-specific charges enter the book only when the shared cash pays first.
- Test willingness to move from paper to an application. Two respondents have never searched for any tool, so the problem evidence does not yet imply adoption.
