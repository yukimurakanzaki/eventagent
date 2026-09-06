# Supabase Two-Account SIT Test Cases

## Purpose

Validate the hosted mobile slice with real Supabase accounts before wider treasurer usability testing or Play Store testing.

This is a test document, not a replacement for the product brief. The product scope and requirements remain in `project-brief.md`.

## Scope

- Flutter Android app using Supabase Auth and hosted Postgres.
- Prefilled rehearsal scenario: Wisata Dieng, 12–14 September 2026, capacity 18; the single event is configurable.
- Roles: treasurer and chairperson; both edit cashbook content, while only the treasurer manages membership.
- Shared event data, local-first changes, queued sync, conflict preservation, and audit history.
- Email confirmation and the Android `io.wargakas.mobile://auth-callback/` return path.

Out of scope: Play Store release testing, production backups, payment gateways, booking integrations, maps, OCR, AI, and complex permissions.

## Test environment

Record the values used for each run:

| Item | Value |
|---|---|
| Supabase project | `yytzncyxyulwqsanejcg` |
| App build / commit | |
| Android device A | |
| Android device B | |
| Android version(s) | |
| Network control | Wi-Fi/mobile data toggled manually |
| Test date and timezone | Asia/Jakarta |

### Test accounts

Use dedicated test accounts. Do not use real participant financial data.

| Account | Role | Email | Password stored where? |
|---|---|---|---|
| T1 | Treasurer | | |
| C1 | Chairperson | | |
| X1 optional | Non-member/isolation check | | |

The X1 account is recommended for testing RLS isolation. If it is not available, record that isolation was not fully exercised.

### Preconditions

1. The Supabase migration is deployed to the target project.
2. The app is built with the target Supabase URL and publishable key.
3. The exact mobile callback `io.wargakas.mobile://auth-callback/` is present in Supabase Auth redirect URLs.
4. Device A and device B can install the same debug or internal-test APK.
5. T1, C1, and optional X1 do not already have test data in this project, or the test workspace is clearly identified.
6. Record the starting Supabase Auth user count and the target workspace/event IDs if visible.

## Execution rules

- Mark each case `PASS`, `FAIL`, or `BLOCKED`.
- Attach evidence for every failure: screenshot, timestamp, device, account, and relevant Supabase log or row ID.
- A pass requires the expected result and no Flutter red-screen assertion, unhandled exception, or silent data loss.
- Never paste passwords, service-role keys, access tokens, or refresh tokens into this document.
- Reset only the dedicated test workspace between runs; do not delete unrelated production data.

## Test cases

### 2026-09-05 authentication hardening scope and acceptance

Implementation plan: preserve Supabase's account privacy behavior, make every form response truthful and actionable, centralize validation/errors, prevent overlapping requests, then repair recovery/session transitions. Verify with deterministic fake-backend widget tests and a configured APK; keep real email delivery and device-link checks separate.

| Area | Defect / edge case | Required behavior |
|---|---|---|
| Registration | Existing confirmed address can return an obfuscated success | Never claim an account was created or mail delivered; direct existing users to sign-in/recovery; translate explicit duplicate errors |
| Input | Only checking for `@`; no registration password confirmation | Validate email structure and matching new passwords; preserve password whitespace; do not enforce new-password length on login |
| Login | Wrong password treated like an expired link; raw server errors | Indonesian, code-specific guidance; confirmation resend only for an unconfirmed email |
| Mail | Unknown recovery address; resend rate limits; delivery failure | Conditional success wording, spam/latest-link/same-device guidance, shared email cooldown, distinct server throttling/SMTP messages |
| Async | Double tap, editable request target, route changes, network timeout | One pending request, disabled fields/actions, bounded wait, safe widget disposal and retry |
| Recovery | Token refresh/user update exits recovery early; completion can spin forever | Keep recovery active until explicit completion/cancel; then load the authenticated workspace |
| Sessions | Every refresh reloads controller; stale async load may cross account changes | Preserve same-user state on refresh, invalidate old loads on identity changes, safe loading/error/sign-out states |
| Verification | Existing tests mostly exercise the demo shell | Add backend-response, form, recovery, and auth-event regression tests; report live email/device limitations honestly |

### Authentication and first workspace

#### SIT-AUTH-001 — Treasurer creates an account

**Priority:** P0  
**Actor:** T1  
**Precondition:** T1 does not exist.

**Steps**

1. Install and open the configured app on device A.
2. Choose `Buat akun`.
3. Enter T1 email and a test password of at least six characters.
4. Submit the form.
5. Confirm that the app explains that email confirmation is required.

**Expected result**

- Supabase creates one Auth user.
- The app does not show a Flutter assertion or dead-end error.
- The confirmation state offers a clear path to resend or `Masuk`.

**Evidence:** Auth user ID, confirmation-screen screenshot.

#### SIT-AUTH-002 — Email confirmation returns to the mobile app

**Priority:** P0  
**Actor:** T1

**Steps**

1. Open the newest confirmation email on device A.
2. Tap the confirmation link once.
3. If Gmail shows a browser choice, choose the installed Wargakas app when offered.
4. Return to Wargakas if the browser remains open.

**Expected result**

- The one-time link is accepted once.
- Android routes the callback to Wargakas, not `localhost`.
- The app does not show a blank page or Flutter assertion.
- Supabase shows a non-null confirmation time for T1.

**Evidence:** device screenshot and Supabase Auth user confirmation timestamp.

#### SIT-AUTH-003 — Treasurer signs in after confirmation

**Priority:** P0  
**Actor:** T1

**Steps**

1. Choose `Masuk`.
2. Enter T1 credentials.
3. Submit.

**Expected result**

- T1 reaches `Acara Saya`.
- The fixed navigation is visible: `Ringkasan`, `Peserta`, `Uang`, `Laporan`.
- The first hosted event is `Wisata Dieng` with capacity 18.
- No second or nested app shell appears during loading.

#### SIT-AUTH-004 — Existing confirmed account does not loop on resend

**Priority:** P1  
**Actor:** T1

**Steps**

1. From the account-created or confirmation state, choose the resend action.
2. Observe the result.
3. Switch to `Masuk` and sign in with T1.

**Expected result**

- The app does not promise a new confirmation email when the account is already confirmed.
- The app provides a direct sign-in path.
- T1 can sign in normally.

#### SIT-AUTH-005 — Wrong password and unknown email remain private

**Priority:** P0

1. Try an incorrect password for a known account, then an unused email.
2. Observe the messages without repeatedly submitting.

**Expected result:** The app gives safe Indonesian guidance, does not expose raw server details, and does not reveal whether an arbitrary email is registered.

#### SIT-AUTH-006 — Recovery email and callback

**Priority:** P0

1. From `Lupa kata sandi?`, request recovery for T1.
2. Confirm the button and fields are locked during the request and email actions have a 60-second cooldown.
3. Open only the newest email on the same device.
4. Enter matching new passwords, save once, and continue to the event.

**Expected result:** The initial response is conditional, the callback opens Wargakas, refresh/user-update events do not close the form, the password is saved once, and the hosted event loads without a spinner loop.

#### SIT-AUTH-007 — Expired/wrong-device link and delivery failure

**Priority:** P0

1. Open an expired or previously used link and verify the replacement-link guidance.
2. Exercise a test recipient rejected by the configured sender, or capture an approved SMTP failure in a controlled environment.
3. Restore delivery and retry after the cooldown.

**Expected result:** The app explains newest-link/same-device requirements; it never claims delivery after a server error; throttling and SMTP errors are distinct and retryable.

#### SIT-AUTH-008 — Network, timeout, session expiry, and account switch

**Priority:** P0

1. Interrupt login, registration, recovery, and workspace loading requests.
2. Expire a stored test session and sign in as a different test user.

**Expected result:** Requests time out safely, double taps do not duplicate calls, transient auth errors preserve a valid session, expired sessions return to login with an explanation, and a late response from the old account cannot replace the new account's workspace.

## Workspace and role sharing

#### SIT-ROLE-001 — Treasurer bootstraps the hosted event

**Priority:** P0  
**Actor:** T1

**Steps**

1. Sign in as T1 on device A.
2. Wait for the event to load.
3. Open each fixed navigation item.

**Expected result**

- T1 has treasurer membership in one workspace.
- The hosted event loads without requiring a manual database action.
- Event details match the fixed scenario: Wisata Dieng, 12–14 September 2026, capacity 18.
- The local cache remains usable if the network is disabled after the first successful load.

**Evidence:** workspace ID, event ID, screenshots of all four tabs.

#### SIT-ROLE-002 — Treasurer grants chairperson access

**Priority:** P0  
**Actor:** T1

**Steps**

1. Ensure C1 has a registered Supabase account.
2. From the treasurer account controls, enter C1 email.
3. Submit `Berikan akses`.

**Expected result**

- The action succeeds only for T1.
- C1 receives chairperson membership in the same workspace.
- No duplicate membership is created when the action is repeated for the same email.
- A confirmation message is shown to T1.

#### SIT-ROLE-003 — Chairperson signs in and sees the shared event

**Priority:** P0  
**Actor:** C1  
**Precondition:** SIT-ROLE-002 passed.

**Steps**

1. Install the same APK on device B.
2. Sign in as C1.
3. Open `Acara Saya` and all four tabs.

**Expected result**

- C1 can open the same Wisata Dieng event.
- C1 sees the same participant, transaction, reminder, and sync state as T1 after refresh.
- C1 does not see an unrelated workspace.

#### SIT-ROLE-004 — Non-member cannot read another workspace

**Priority:** P0  
**Actor:** X1 optional

**Steps**

1. Sign in as X1.
2. Try to load the event created by T1.
3. If a direct event or workspace ID can be supplied, try that path as well.

**Expected result**

- X1 cannot read T1 workspace rows.
- X1 cannot call the workspace invite or sync mutation for T1 workspace.
- The app shows a safe empty/error state without leaking event data.

**Evidence:** Supabase response/log and screenshot. If X1 is unavailable, mark `BLOCKED`, not `PASS`.

## Shared data and accounting behavior

#### SIT-DATA-000 — Both roles edit the single configurable event

**Priority:** P0
**Actors:** T1, C1

1. As T1, edit the event name, dates, capacity, final budget, and opening balance; confirm the before/after summary.
2. Verify the changes from C1, then make a second allowed correction as C1.
3. After a participant payment exists, attempt to change sponsor name or contribution.

**Expected result:** Both roles can synchronize allowed event edits, capacity cannot fall below active participants, sponsor fields are locked after payments begin, and each accepted correction has an audit entry and matching relational event values.

#### SIT-DATA-001 — Treasurer records a payment and chairperson receives it

**Priority:** P0  
**Actors:** T1, C1

**Steps**

1. On device A as T1, record a participant payment for `Ibu Sari`.
2. Note the amount, description, and timestamp.
3. On device B as C1, refresh or reopen the event.

**Expected result**

- The payment is stored once with the correct participant ID.
- The contribution target remains understandable and based on capacity 18.
- C1 sees the same payment and updated balance.
- Reopening or retrying does not duplicate the transaction.

#### SIT-DATA-002 — Expense and additional contribution update balance

**Priority:** P0  
**Actor:** T1

**Steps**

1. Record an expense with a positive amount and description.
2. Record an additional contribution with a positive amount and description.
3. Compare the displayed balance with the expected income-minus-expense calculation.
4. Verify the same values from C1.

**Expected result**

- Each transaction is stored exactly once.
- Balance changes in the correct direction.
- Both accounts see the same final values.

#### SIT-DATA-003 — Cancellation preserves history and replacement remains independent

**Priority:** P0  
**Actor:** T1

**Steps**

1. Cancel an active participant and select `Tidak ada refund`.
2. Record a payment for the replacement participant.
3. Open the participant list and report preview.

**Expected result**

- The cancelled participant is excluded from the active participant count.
- Event capacity remains 18.
- The cancelled participant and original payment history remain visible.
- The replacement payment is linked to the replacement, not silently transferred.

#### SIT-DATA-004 — Refund is an explicit transaction

**Priority:** P0  
**Actor:** T1

**Steps**

1. Cancel a participant using `Refund sebagian` or `Refund penuh`.
2. Record the refund transaction.
3. Open `Uang` and `Laporan`.

**Expected result**

- Refund appears as a separate transaction.
- Original payment remains in history.
- Balance reflects the refund exactly once.
- The report shows participant name, payment status, and refund status.

## Offline, sync, and recovery

#### SIT-REPORT-001 — PDF and WhatsApp handoff work offline

**Priority:** P0
**Actors:** T1, C1

1. Disable the network after the event is loaded.
2. Generate and share the PDF from T1; share the WhatsApp-ready text from C1.
3. Compare event dates, participant/refund status, transaction detail, opening balance, income, expenses, ending balance, creator role, and generation time with the app preview.
4. Enter an email, phone/account-like number, and credential-like value in a rehearsal transaction description and regenerate both outputs.

**Expected result:** Both outputs work without network access, totals match the preview, Android's share sheet opens, PDF pages are readable and numbered, and sensitive patterns are redacted.

#### SIT-SYNC-001 — Treasurer records data without signal

**Priority:** P0  
**Actor:** T1

**Steps**

1. Confirm the event has loaded once online.
2. Disable Wi-Fi and mobile data on device A.
3. Record a participant payment, expense, and reminder.
4. Close and reopen the app while still offline.

**Expected result**

- The app remains usable.
- All three changes remain visible locally.
- The summary indicates pending synchronization without losing data.
- No unhandled exception or red screen appears.

#### SIT-SYNC-002 — Queued changes replay after signal returns

**Priority:** P0  
**Actor:** T1, C1

**Steps**

1. With changes queued from SIT-SYNC-001, re-enable the network.
2. Reopen or refresh the event.
3. Verify from device B as C1.

**Expected result**

- Queued changes upload once.
- Pending count returns to zero after successful sync.
- The server version advances.
- C1 receives the changes without duplicates.

#### SIT-SYNC-003 — Two-device version conflict is visible and non-destructive

**Priority:** P0  
**Actors:** T1 on devices A and B

**Steps**

1. Load the same event/version on both devices.
2. Disable network on both devices.
3. Make different changes on each device.
4. Re-enable network and sync device A first.
5. Sync device B second.

**Expected result**

- The second sync does not silently overwrite the first device’s server state.
- The app blocks further editing and shows summaries for the complete local and online versions.
- Choosing online replaces local state only after confirmation; choosing local rebases it against the latest remote version and creates a new audit operation.
- If another remote update lands during resolution, the app presents the newer conflict instead of overwriting it.
- The resolution is logged with the actor, timestamp, and chosen operation.

**Note:** This case passes only when both explicit choices preserve the selected version and no silent merge or overwrite occurs.

#### SIT-SYNC-004 — New device recovers hosted data

**Priority:** P0  
**Actor:** T1

**Steps**

1. Sign out on device A.
2. Install the app on a clean device B, or clear only the app’s local data.
3. Sign in as T1.

**Expected result**

- The event, participants, transactions, reminders, and server version are restored from Supabase.
- No data depends on the previous device’s local storage.
- The app does not create a duplicate workspace or event.

## Audit and error handling

#### SIT-AUDIT-001 — Hosted mutations create audit entries

**Priority:** P0  
**Actor:** T1

**Steps**

1. Record a participant edit, payment, expense, reminder, cancellation, and chairperson access change.
2. Inspect the hosted audit table using an authorized project-admin method.

**Expected result**

- Each mutation has an audit entry with actor, workspace/event scope, action, entity, and timestamp.
- No service-role secret is present in the mobile app or committed repository.

#### SIT-ERR-001 — Network failure does not corrupt local state

**Priority:** P0  
**Actor:** T1

**Steps**

1. Start an online mutation.
2. Interrupt the network before sync completes.
3. Reopen the app and restore signal.

**Expected result**

- The local change is retained.
- The sync error is understandable in Indonesian.
- Retry does not create a duplicate transaction or participant.

#### SIT-ERR-002 — Auth shell handles loading and sign-out safely

**Priority:** P1  
**Actor:** T1, C1

**Steps**

1. Launch the app with a stored session.
2. Sign out while the event is loading or after it is visible.
3. Sign in again.

**Expected result**

- No `_dependents.isEmpty` assertion, blank screen, or nested navigation shell appears.
- The login screen returns after sign-out.
- The event shell returns after successful sign-in.

## Exit criteria

The hosted two-account SIT is ready for sign-off when:

- All P0 cases pass.
- No Flutter assertion, fatal exception, or data-duplication defect remains.
- T1 and C1 can use the same event from separate devices.
- Offline changes survive restart and synchronize after reconnect.
- Conflict behavior is visible and non-destructive.
- Hosted audit entries exist for tested mutations.
- Any blocked case has an owner and a documented follow-up in `backlog.md`.

## Run record

| Case | Result | Evidence / issue ID | Tester | Date |
|---|---|---|---|---|
| SIT-DATA-000 | | | | |
| SIT-REPORT-001 | | | | |
| SIT-AUTH-001 | | | | |
| SIT-AUTH-002 | | | | |
| SIT-AUTH-003 | | | | |
| SIT-AUTH-004 | | | | |
| SIT-AUTH-005 | | | | |
| SIT-AUTH-006 | | | | |
| SIT-AUTH-007 | | | | |
| SIT-AUTH-008 | | | | |
| SIT-ROLE-001 | | | | |
| SIT-ROLE-002 | | | | |
| SIT-ROLE-003 | | | | |
| SIT-ROLE-004 | | | | |
| SIT-DATA-001 | | | | |
| SIT-DATA-002 | | | | |
| SIT-DATA-003 | | | | |
| SIT-DATA-004 | | | | |
| SIT-SYNC-001 | | | | |
| SIT-SYNC-002 | | | | |
| SIT-SYNC-003 | | | | |
| SIT-SYNC-004 | | | | |
| SIT-AUDIT-001 | | | | |
| SIT-ERR-001 | | | | |
| SIT-ERR-002 | | | | |
