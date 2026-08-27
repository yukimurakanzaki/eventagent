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

## Pending

- Validate the PDF/WhatsApp handoff wording and cancellation refund policy with treasurers.
- Choose a production app platform, persistence model, and authentication approach after prototype review.
