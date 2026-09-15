# QA Bug Tickets — Wargakas Mobile

**STATUS: all rounds closed.** BUG-001..011 fixed and verified.
BUG-006 closed in round 5 after the product call was made (see round 5).

Final verification (2026-09-15): `flutter test` **113/113 pass**,
`flutter analyze` **No issues found!**. Baseline before this QA pass was 91 tests,
all passing — every defect below was invisible to that suite.

Regression cover lives in `mobile/test/qa_probe_test.dart` (QA-1..QA-20).

Round 1 — 2026-09-12. Tester: senior QA.
Baseline: `flutter analyze` clean, `flutter test` 91/91 pass. All defects below are
**missed by the existing suite** and reproduced by `mobile/test/qa_probe_test.dart`.

Run the repro with:

```bash
flutter test test/qa_probe_test.dart
```

Definition of done for this round: `flutter test` (whole suite, including
`qa_probe_test.dart`) passes and `flutter analyze` stays clean.

---

## BUG-001 — Uang tab hides additional contributions, balance cannot be reconciled

- **Severity**: High (financial reporting, treasurer trust)
- **Repro**: `QA-1`, `QA-2` in `test/qa_probe_test.dart`
- **Location**: `lib/main.dart` — `MoneyPage.build` (rows: Anggaran final, Sponsor,
  Saldo awal, Pembayaran peserta, Pengeluaran bersih)

**Steps**: record a `Kontribusi tambahan` of Rp 750.000 via the global
`Catat transaksi` shortcut, open the `Uang` tab.

**Expected**: the listed rows account for every rupiah in `Saldo saat ini`.
**Actual**: `Saldo saat ini` is Rp 750.000 higher than the sum of the rows. No row
for additional contributions exists anywhere on the tab. A treasurer reading the
tab cannot explain the balance and will suspect a data error.

**Fix direction**: add a `Kontribusi tambahan` row sourced from
`TransactionType.additionalContribution`. Keep the existing row order and the
`Anggaran final` row (it is context, not a balance component).

---

## BUG-002 — Payments can be recorded against a cancelled participant

- **Severity**: High (data integrity; corrupts refund ceiling and report status)
- **Repro**: `QA-3` in `test/qa_probe_test.dart`
- **Location**: `lib/cashbook_controller.dart` `recordTransaction` (participant
  existence check does not test state); `lib/main.dart` transaction dialog
  participant dropdown (filters only for refunds).

**Steps**: cancel `Ibu Rina`, then `Catat transaksi` → `Pembayaran peserta` →
choose `Ibu Rina` → save.

**Expected**: a cancelled participant is not offered, and the controller refuses
the payment.
**Actual**: the dropdown lists cancelled participants, and
`recordTransaction` returns `true`. The payment inflates
`participantPaid`, raises `refundableAmountForParticipant` for someone who already
left, and the report prints a payment status for a cancelled member.

**Fix direction**: reject in `recordTransaction` when the target participant is not
`ParticipantState.active` — this is the shared path every caller routes through —
and filter the dropdown to active participants for
`TransactionType.participantPayment`. Refunds must still allow cancelled
participants (that is the whole point of a refund).

---

## BUG-003 — Participant target goes negative and marks unpaid members "Lunas"

- **Severity**: High (wrong money owed shown to every participant)
- **Repro**: `QA-5` in `test/qa_probe_test.dart`
- **Location**: `lib/cashbook_calculations.dart` `participantTarget`

**Steps**: event with `finalBudget` 5.000.000, `sponsorContribution` 4.000.000,
`openingBalance` 3.000.000.

**Expected**: target clamps at Rp 0 — nobody owes a negative amount.
**Actual**: `participantTarget` returns `-111111`. The UI prints a negative rupiah
target (`lib/main.dart:467`), and `paymentStatus(0, -111111)` returns `Lunas`, so
every participant who has paid nothing is reported as fully paid in the app and in
the shared WhatsApp/PDF report.

**Fix direction**: clamp the result to `>= 0` in `participantTarget`. Fixing it
there covers the UI, `paymentStatus`, and both report builders at once.

---

## BUG-004 — Event validation permits funding above the final budget

- **Severity**: Medium (root cause that makes BUG-003 reachable from the UI)
- **Repro**: `QA-6` in `test/qa_probe_test.dart`
- **Location**: `lib/cashbook_controller.dart` `validateEventUpdate`

**Steps**: with no participant payments yet, edit the event to
`finalBudget` 5.000.000, `sponsorContribution` 4.000.000, `openingBalance`
3.000.000 and save.

**Expected**: a validation message explaining sponsor + saldo awal cannot exceed the
final budget.
**Actual**: `validateEventUpdate` returns `null` and the edit is committed.

**Fix direction**: add the check next to the existing negative-value check, with an
Indonesian message matching the surrounding style.

Note: the existing suite appeared to cover this only because the demo snapshot has
participant payments, so the unrelated sponsor-lock message fired first.

---

## BUG-005 — Reminder notifications hardcode another event's name

- **Severity**: Low (wrong content on a user-visible notification)
- **Location**: `lib/reminder_notifier.dart:78`

**Steps**: rename the event to `Ziarah Walisongo`, add a reminder with an empty
note, wait for the notification.

**Expected**: a generic body, or the actual event name.
**Actual**: the body reads `Pengingat untuk acara Wisata Dieng.` for every event,
because the demo event name is baked into `LocalReminderNotifier.schedule`.

**Fix direction**: fall back to a generic body (e.g. `Pengingat acara Wargakas.`)
rather than threading the event name through the notifier — the notifier has no
business knowing about events.

---

## BUG-006 — Sponsor income is counted twice if a sponsor transaction is ever recorded

- **Severity**: Low (latent — no UI path creates `TransactionType.sponsor` today)
- **Location**: `lib/cashbook_calculations.dart` `currentBalance` /
  `incomeTotal`; `lib/report_service.dart` `sponsorIncome`

`currentBalance` adds `event.sponsorContribution` **and** `incomeTotal`, which
includes `TransactionType.sponsor`. Meanwhile the report's `sponsorIncome` reads
only the event field. `recordTransaction` explicitly supports the sponsor type
(guarded by `canAddSponsor`), so the first caller to use it inflates the balance and
desynchronises the report.

**Fix direction**: leave the behaviour alone this round, but record the decision —
either drop `TransactionType.sponsor` from `incomeTotal`, or make the report read
sponsor income from transactions. Do not change this without a product call.

**Resolved in round 5 (2026-09-15).** Product call made, fix verified. See round 5.


---
---

# Round 2 — 2026-09-12

Opened after round 1 was verified green. Reproduced by `QA-10`, `QA-11`, `QA-12`
in `mobile/test/qa_probe_test.dart`.

## BUG-007 — A participant can be renamed to a blank name

- **Severity**: Medium (corrupt data reaches the shared report)
- **Repro**: `QA-10`
- **Location**: `lib/cashbook_controller.dart` `editParticipant`

`addParticipant` rejects an empty name; `editParticipant` validates nothing and
commits whatever it is handed — including `'   '`. The blank name then propagates
into the sync queue payload and into the WhatsApp/PDF participant list.

**Fix direction**: trim and reject a blank name in `editParticipant`, mirroring
`addParticipant`. Return `String?` the way `addParticipant` does so the caller can
show the reason, and update the one call site in `lib/main.dart`.

## BUG-008 — Clearing a participant name silently discards the edit

- **Severity**: Medium (silent data loss from the user's point of view)
- **Repro**: `QA-11`
- **Location**: `lib/main.dart` `showEditParticipantDialog`

**Steps**: Peserta tab → tap a participant → `Edit nama` → clear the field → `Simpan`.

**Expected**: the same `Nama belum diisi` explanation the add dialog shows.
**Actual**: `if (name.isNotEmpty)` skips the save, then the dialog closes anyway.
The user sees the dialog dismiss with no message and no change — indistinguishable
from a successful save.

**Fix direction**: on a blank name call `showInfo(context, 'Nama belum diisi',
'Masukkan nama peserta terlebih dahulu.')` and keep the dialog open, matching
`showParticipantDialog`. Surface any error returned by `editParticipant` the same
way the add dialog surfaces `addParticipant`'s error.

## BUG-009 — Report redaction misses dotted bank account numbers

- **Severity**: Medium (privacy; the report is shared over WhatsApp)
- **Repro**: `QA-12`
- **Location**: `lib/report_service.dart` `sanitizeReportText`

The phone/account regex is `(?<!\d)\+?\d[\d\s-]{7,}\d(?!\d)` — the character
class allows only digits, spaces and hyphens. Indonesian bank accounts are routinely
written with dots (`521.01.000123.30.7`), so they pass through verbatim into the
shared report, which the project brief explicitly says must exclude account numbers.

**Fix direction**: allow `.` in the separator class. Keep the existing
digit-boundary guards so ordinary amounts and dates are not swallowed — verify
against the existing `report_test.dart` expectations, which must keep passing.

---

# Round 3 — 2026-09-12

## BUG-010 — Regression: account redaction now destroys rupiah amounts in the report

- **Severity**: High (introduced by the BUG-009 fix; makes shared reports unreadable)
- **Repro**: `QA-13` in `mobile/test/qa_probe_test.dart`
- **Location**: `lib/report_service.dart` `sanitizeReportText`

Widening the separator class to `[\d\s.-]` made the pattern match ordinary
thousands-grouped rupiah figures.

**Actual**: `sanitizeReportText('Sewa bus Rp 12.500.000 lunas')` returns
`'Sewa bus Rp [nomor disembunyikan] lunas'`. Every expense description containing a
price — which is most of them — loses its number in the WhatsApp text and the PDF
description column. The treasurer's report becomes useless.

**Expected**: `12.500.000` survives; `521.01.000123.30.7` is still redacted.

**Fix direction**: a rupiah amount is strictly `\d{1,3}(\.\d{3})+` — regular
three-digit groups, dots only. A bank account is not. Keep the widened match, but
use `replaceAllMapped` and leave the match untouched when it matches the rupiah
shape end to end. Both assertions in `QA-13` must pass, and `report_test.dart` must
stay green.

---

# Round 4 — 2026-09-12

## BUG-011 — A past-due reminder is accepted, listed as open, and never fires

- **Severity**: Medium (the treasurer relies on a reminder that will never ring)
- **Repro**: `QA-14` in `mobile/test/qa_probe_test.dart`
- **Location**: `lib/cashbook_controller.dart` `addReminder`;
  `lib/reminder_notifier.dart` `LocalReminderNotifier.schedule`;
  `lib/main.dart` reminder date picker (`firstDate`)

**Steps**: Ringkasan → add a reminder → open the date picker → pick yesterday (the
picker allows it: `firstDate: DateTime.now().subtract(const Duration(days: 1))`)
→ save.

**Expected**: the app refuses a due date in the past and says why.
**Actual**: `addReminder` stores it and returns `void`. `LocalReminderNotifier
.schedule` then hits `if (scheduled.isBefore(now)) return;` and discards it
silently. The reminder sits in the Pengingat list as open forever and no
notification is ever scheduled. Same silent drop happens via `toggleReminder` when
an overdue reminder is un-ticked.

**Fix direction**:
1. `addReminder` returns `Future<String?>` like `addParticipant`, rejecting a
   `dueAt` that is already past with an Indonesian message.
2. Surface that message in the add-reminder dialog the way the add-participant
   dialog does.
3. Set the picker's `firstDate` to today so the state is hard to reach in the
   first place.

Leave `LocalReminderNotifier.schedule`'s defensive early return in place.


---

# Round 5 — 2026-09-15 — BUG-006 verification

Tester: senior QA (independent adversarial verification, developer report and tech
lead review not relied on).
Baseline at start of round: `flutter test` 107/107 pass, `flutter analyze` clean.
After adding QA-15..QA-20: **`flutter test` 113/113 pass**, **`flutter analyze`
`No issues found!`**.

## Product call — do not re-litigate

**Decision maker: tech lead. Date: 2026-09-15.**

> `event.sponsorContribution` is the single source of truth for sponsor money.
> Sponsor must never also be a ledger transaction that moves the balance.

Rationale on record: the event field is validated against the final budget
(BUG-004), is locked once participant payments begin, and feeds `participantTarget`.
A `TransactionType.sponsor` ledger row has none of those properties, so the two can
never be made to agree. The alternative option listed in BUG-006's fix direction
(make the report read sponsor income from transactions) is **rejected** — it would
have to drop the budget validation and the lock.

## BUG-006 — verdict: PASS, closed

Verified independently against the change, not against the developer's report.

- `TransactionType.sponsor` removed from the `income` set in `incomeTotal`
  (`lib/cashbook_calculations.dart:20`) — confirmed. `currentBalance` still adds
  `event.sponsorContribution` exactly once (`:52`).
- `recordTransaction` rejects `TransactionType.sponsor` unconditionally
  (`lib/cashbook_controller.dart:212`) — confirmed.
- `canAddSponsor` → `sponsorEditable` rename: zero stale references anywhere in
  source or docs (only in pre-existing `.dart_tool` build artefacts). Both call
  sites negate correctly — `lib/cashbook_controller.dart:361` and
  `lib/main.dart:1612` are exact equivalents of the inline predicates they replaced.
  The lock boundary is unchanged: the sponsor fields become uneditable on the first
  `participantPayment`, and an expense or additional contribution does not lock them.
- The enum member, `toJson`/`fromJson` and the `Sponsor` label
  (`lib/report_service.dart:296`) are untouched, so a legacy or server-supplied
  sponsor record still deserializes and still prints in the PDF transaction table —
  it just contributes 0 to the balance.

**Mutation checks (probes proven to have teeth, not vacuous):**

1. Re-adding `TransactionType.sponsor` to the `income` set failed QA-15, QA-19 and
   QA-20. QA-15 reproduced the original BUG-006 symptom exactly —
   `Expected: <8450000>` (`endingBalance`) vs `Actual: <7950000>` (the sum of the
   report's own printed rows), a gap equal to the sponsor record.
2. Inverting `sponsorLocked` at `lib/main.dart:1612` failed QA-17 and QA-18
   (`Expected: true / Actual: <false>` and `Expected: false / Actual: <true>`).

## Transaction insertion paths — audited

`recordTransaction` is **not** the only way a transaction enters state. Three paths
exist:

1. `recordTransaction` — now rejects sponsor.
2. `cancelParticipant` — writes a refund straight through `_commitBatch`, bypassing
   `recordTransaction`. Cannot produce a sponsor record.
3. Deserialization — `bootstrap` (`remote ?? saved`) and
   `resolveConflictWithRemote`. This path **can** introduce a sponsor record and
   does not validate types.

Path 3 is handled coherently: the record is kept (not dropped, no crash) and
contributes 0. Covered by QA-20.

## QA calls made during this round

- **Three definitions of "income" (`lib/main.dart:1952`) — rejected as a ticket.**
  Only one of the three is an actual duplicate. `CashbookReport`
  (`participantIncome` / `additionalIncome`) and `MoneyPage`
  (`lib/main.dart:678-683`) deliberately split income into the two separate rows the
  treasurer reads — collapsing them into `incomeTotal` would undo BUG-001. The one
  genuine duplicate is `_ConflictVersionCard`'s inline sum at `lib/main.dart:1952`,
  which is now byte-equivalent to `incomeTotal`. It is a read-only informational card
  in the conflict dialog, it sits one line above a `currentBalance(...)` call that
  already uses the shared function, and any drift shows up as its own two lines
  disagreeing on screen. Cost of a ticket exceeds the one-line substitution it would
  ask for. Fold it into this branch if convenient; otherwise accept.
- **The existing test `does not add a sponsor after participant payments start`
  (`test/cashbook_test.dart:221`) is now tautological.** Sponsor is rejected
  unconditionally, so it no longer proves anything about lock *timing*. Left in
  place; QA-16 now covers the real boundary.
- **The widget-level sponsor lock had zero coverage before this round.** The full
  pre-existing suite (`cashbook_test` + `widget_test` + `report_test`, 42 tests)
  passes with `sponsorLocked` inverted. The rename was therefore a silent-inversion
  risk that nothing would have caught. Closed by QA-17 and QA-18.

## New probes

| Probe | Asserts |
|-------|---------|
| QA-15 | report breakdown reconciles to `endingBalance` with a sponsor record present |
| QA-16 | sponsor lock engages on the first participant payment, not on an expense or extra contribution |
| QA-17 | sponsor name/amount fields are enabled while no participant has paid |
| QA-18 | sponsor name/amount fields are disabled, with the lock helper text, once a payment exists |
| QA-19 | a stored sponsor record round-trips through JSON and keeps its `Sponsor` label |
| QA-20 | a sponsor record arriving from the server survives conflict resolution and moves nothing |

No new defects found. No lib/ changes made by QA.


---

# Closing notes

## Verified fixed

| ID | Area | Round |
|----|------|-------|
| BUG-001 | Uang tab did not reconcile to the balance | 1 |
| BUG-002 | Payments accepted for cancelled participants | 1 |
| BUG-003 | Negative participant target, unpaid shown as Lunas | 1 |
| BUG-004 | Event funding could exceed the final budget | 1 |
| BUG-005 | Reminder body hardcoded another event's name | 1 |
| BUG-006 | Sponsor income double-counted if a sponsor transaction existed | 1, fixed and verified in 5 |
| BUG-007 | Participant renameable to a blank name | 2 |
| BUG-008 | Blank rename silently discarded with no feedback | 2 |
| BUG-009 | Dotted bank account numbers survived redaction | 2 |
| BUG-010 | Regression: redaction ate rupiah amounts | 3 |
| BUG-011 | Past-due reminders accepted but never fire | 4 |

## QA calls made during review

- The round-1 fix also changed `paymentStatus` so a zero target no longer reads
  `Lunas`. **Reverted.** After BUG-004, a target of 0 means sponsor + saldo awal
  exactly cover the budget, so nobody owes anything and `Lunas` is correct. The
  real defect was the negative target, which the clamp fixes on its own.
- Three test fixtures used hardcoded 2026 dates that went stale once BUG-011 added
  a wall-clock check (`cashbook_test.dart` ×2, `qa_probe_test.dart` ×1). Replaced
  with relative future dates so they cannot rot again.

## Still open — not defects, but not verified either

- **Sponsor money that arrives after the first participant payment has no recording
  path at all.** The event field is locked and a sponsor transaction is refused, so
  the treasurer's only option is to log it as `Kontribusi tambahan`. This is a
  consequence of the tech lead's round-5 product call, not a regression — the
  pre-fix code refused it too (`canAddSponsor` was already false in that state).
  Flagged so the limitation is a known product choice rather than a surprise. Raise
  a product ticket if pilot treasurers hit it.
- A legacy sponsor record makes the PDF's `Transaksi` table not sum to the printed
  `Saldo akhir` — the row shows a rupiah amount that the balance deliberately
  ignores. Accepted: it is the intended outcome of the product call, and only
  reachable from server- or storage-supplied data, never from the app.
- `CashbookReport.refunds` (`lib/report_service.dart:30`) is dead — no caller in
  lib/ or test/. It also counts `refund` without netting `refundReversal`, unlike
  `expenses`. Harmless while unused; delete it or fix it before anyone wires it up.
- A dotted account number that happens to match the rupiah shape exactly
  (`123.456.789`) is preserved by the BUG-010 fix. Accepted: it is indistinguishable
  from an amount without more context.
- Everything device- or network-dependent is untested here and still open in
  `backlog.md`: Android notification delivery under battery optimisation, the
  two-account Supabase SIT, live hosted auth on real inboxes, and PDF/WhatsApp
  sharing on a real device. Unit and widget tests cannot close those.
