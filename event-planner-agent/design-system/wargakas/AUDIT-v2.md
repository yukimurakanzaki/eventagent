# Wargakas UI/UX Audit v2 (2026-10-06)

Scope: Flutter app `mobile/lib` at commit `d373a78` (after the 2026-10-04 audit's theme, large-text, semantics, dark-mode and wide-layout work). Method: code read of every screen, plus the demo build driven on an Android emulator (540x960, dark mode), plus the existing 141 widget tests. Screenshots: `mobile/docs-shots/before-*.png` and `after-*.png`.

Primary user unchanged: treasurer aged 50+, Indonesian UI, trust/accountability product (see `source-of-truth/project-brief.md`).

## What the first audit already fixed (verified, no action)
Fonts bundled, 16sp+ body, `StatusColors` extension with icon+label, dark theme, rail at >=840dp, semantics on amounts, text-scale test at 2x, snackbar live regions. Summary-PDF fonts are now 10-11pt.

## Findings

| # | Sev | Finding | Evidence | v2 |
|---|-----|---------|----------|----|
| 1 | High | Recording a payment is the treasurer's core loop and takes FAB, 4-radio dialog, participant dropdown, amount, description (6 inputs). | `showTransactionDialog` | Fixed: "Catat bayar" on every unpaid participant row and in the row sheet; dialog opens with participant, amount (remaining) and "Iuran peserta" prefilled and no type picker; "Lunasi Rp X" chip in the normal dialog. |
| 2 | High | Ringkasan never answers "how much is collected, who has not paid". Half the screen is empty. | before-1 | Fixed: collection progress bar, tappable Lunas/Sebagian/Belum bayar counts that open the filtered list, last 3 transactions. |
| 3 | High | Peserta rows show no amount still owed, cannot be filtered, and the trailing status chip (max 120dp) truncates "Dibatalkan • Tidak ada refund". | before-2, `_ParticipantTile` | Fixed: "Kurang Rp X", filter chips with counts, chip in the flow (cannot be squeezed), initials avatar. |
| 4 | Med | Sync banner shows a wifi-off icon next to "tidak ada perubahan menunggu sinkronisasi" (icon contradicts text); pending state looks identical to synced. | before-1, `_SyncStatusBanner` | Fixed: cloud-done vs cloud-upload, pending gets the info tone. |
| 5 | Med | Event header card + app bar cost ~110dp on all four tabs. | before-1..4 | Fixed: one 56dp line, no card; edit stays labelled. |
| 6 | Med | Uang: six equal-weight rows, a static error-red "Periksa peserta yang belum lunas" card that does nothing, an unbounded inline list that duplicates the log page, no day grouping. | before-3 | Fixed: balance hero with the three flows visible (QA-2 rule kept), setup facts collapsed, actionable "N peserta belum bayar" nudge in info tone, day headers, 15-row cap with "Lihat semua". |
| 7 | Med | Laporan preview is unaligned plain text; heading hard-coded 22sp; participant status is text only. | before-4 | Fixed: label/amount rows with tabular figures, status chips with "kurang Rp X", generated timestamp. |
| 8 | Low | Numeric dates (12/09/2026) read slowly. | everywhere | Partly fixed: "12 Sep 2026" in header, day groups, report; pickers and tiles stay numeric. |
| 9 | Low | Recovery page hard-codes `fontSize: 24`. | `auth_forms.dart` | Fixed: theme `headlineSmall`. |

## Not fixed in v2: needs a product or backend decision

| # | Sev | Recommendation | Why it is not a UI-only change |
|---|-----|----------------|-------------------------------|
| R1 | High | Let the treasurer set the transaction date. | `createdAt` is always "now". People who catch up from a notebook will write wrong dates into a trust ledger. Needs model + controller + sync payload. |
| R2 | High | Show who recorded each transaction and when (time, not just date); attach a receipt photo. | `TransactionRecord` has no actor or evidence. The hosted audit trigger already stores actors; the client does not read them. This is the product's whole thesis (brief: "traceable to the group"). |
| R3 | Med | Edit-event and New-event forms: move from `AlertDialog` to a full-screen form with grouped sections. Apply the rupiah formatter (they show raw `15000000`). | Pure UI, but large; kept out of this pass to stay reviewable. |
| R4 | Med | Transaction entry as a full-screen route or bottom sheet with a segmented type control. | The dialog still stacks four radios above the fields and fights the keyboard on 540x960. |
| R5 | Med | FAB covers amounts while scrolling the Uang list (before-3). Collapse to icon on scroll, or show it only on Peserta/Uang. | Interaction decision for the treasurer. |
| R6 | Low | App bar has three icon-only actions (add chairperson, help, account). Consider a labelled overflow menu. | Needs a check with a real 50+ user. |
| R7 | Low | Participant search once a trip passes ~20 people. | Brief fixes the trip at 18. |
| R8 | Low | Ledger/portfolio PDFs still use 9-10pt (`ledger_pdf.dart`). Raise to 11. | Page count grows; check with the treasurer. |

## Not verified
Light mode and TalkBack on a device; hosted mode (demo build only); the physical phone. Large text is covered by `large_text_test.dart` only.

## Design direction (unchanged)
Trust and authority, calm minimalism, high legibility. Brand green kept. See `AUDIT.md` for tokens; `MASTER.md` stays a palette reference only.
