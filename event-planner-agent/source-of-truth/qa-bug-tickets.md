# QA Bug Tickets — Wargakas Mobile

**STATUS: all rounds closed.** BUG-001..005, 007..011 fixed and verified.
BUG-006 deferred — needs a product decision, do not fix silently.

Final verification (2026-09-12): `flutter test` **105/105 pass**,
`flutter analyze` **No issues found!**. Baseline before this QA pass was 91 tests,
all passing — every defect below was invisible to that suite.

Regression cover lives in `mobile/test/qa_probe_test.dart` (QA-1..QA-14).

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

# Closing notes

## Verified fixed

| ID | Area | Round |
|----|------|-------|
| BUG-001 | Uang tab did not reconcile to the balance | 1 |
| BUG-002 | Payments accepted for cancelled participants | 1 |
| BUG-003 | Negative participant target, unpaid shown as Lunas | 1 |
| BUG-004 | Event funding could exceed the final budget | 1 |
| BUG-005 | Reminder body hardcoded another event's name | 1 |
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

- **BUG-006** (sponsor double-count) is latent and deferred pending a product call.
- A dotted account number that happens to match the rupiah shape exactly
  (`123.456.789`) is preserved by the BUG-010 fix. Accepted: it is indistinguishable
  from an amount without more context.
- Everything device- or network-dependent is untested here and still open in
  `backlog.md`: Android notification delivery under battery optimisation, the
  two-account Supabase SIT, live hosted auth on real inboxes, and PDF/WhatsApp
  sharing on a real device. Unit and widget tests cannot close those.
