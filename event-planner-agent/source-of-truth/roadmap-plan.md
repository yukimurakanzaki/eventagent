# Roadmap Plan (draft for review, written 2026-10-01)

Status: DRAFT. Not yet adopted into `backlog.md` or `decisions.md`.

## Where things stand

- Mobile app (Flutter + Supabase) is feature-complete for a single-treasurer, single-device pilot: per-head target, void-with-reason corrections, empty hosted start, offline queue, PDF + WhatsApp share, release signing.
- 11 QA bugs found and fixed over 5 rounds; ledger rules extracted and unit-tested.
- Branch `qa/cashbook-defect-sweep` is 3 commits ahead of origin and **not merged to main**. Main lacks all pilot work.
- Respondent-3 pilot was due to start the week of 2026-09-28. Backlog shows none of its setup steps ticked. **Unknown whether it started.**
- Problem confirmed by 2 interviews (independence unverified). Adoption (willingness to switch from paper) has zero evidence. The pilot is the test of it.

Core principle: the only open question that can kill the project is adoption. Everything below is ordered to answer it cheaply before building more.

## Phase 0 — Housekeeping (1 session)

1. Run `flutter analyze` + `flutter test`; confirm green.
2. Push the 3 local commits; open PR `qa/cashbook-defect-sweep` -> `main`; confirm CI passes; merge.
3. Fold this plan into `backlog.md` / `decisions.md` once approved; mark stale items.

Exit: main contains the pilot build; CI green.

## Phase 1 — Pilot readiness (1-2 sessions + manual steps by you)

From the existing backlog gate, nothing new:

1. Create respondent 3's account in the Supabase dashboard; sign in once on her phone.
2. Build hosted release APK; install on her phone.
3. Minimum SIT on that device: SIT-AUTH-003, SIT-ROLE-001, SIT-DATA-001 (treasurer half: payment syncs, survives reinstall/relogin).
4. Dummy-trip rehearsal (event, participants, payments, expenses, one correction, one cancellation, share PDF + WhatsApp), then reset to empty.

**Decide before handover (new):** write down pilot success/fail criteria, e.g.
- She enters a real event's money in the app, not only the notebook.
- App totals match her notebook at event end.
- Still using it unprompted 2 weeks in.
- Count of times she needed help, and what for.

Exit: she has the app, empty event, and agreed criteria.

## Phase 2 — Pilot run + observation (2-4 weeks, mostly you)

- Weekly 15-min check-in; log in `memory-log.md`.
- Watch the already-predicted friction: late sponsor money, replacement paid directly, committee as payers, receipt photos.
- Collect every workaround she invents; these are the real backlog.
- Bug fixes only during the pilot. No feature work unless it blocks ledger correctness.

Exit: pass / partial / fail against Phase 1 criteria.

## Phase 3 — Validation in parallel (no code)

- Confirm respondent 2 is independent of respondent 1.
- Interview 2-3 more treasurers from unrelated communities; ask adoption directly (would you switch, what would stop you).
- Interview 1-2 chairpersons.
- Build the Validated / Assumed / Rejected / Needs-more-evidence table from the decisions log.

Exit: classified requirements table; adoption verdict with n>=3.

## Phase 4 — Build, gated on Phase 2/3 (only if pilot is pass/partial)

Ranked by link to the primary outcome (no suspicion of misuse):

1. Participant read-only view (link or invite), since today transparency is only a PDF/WhatsApp text. Biggest gap vs the stated outcome.
2. Per-transaction detail in reports (aggregate-only triggers suspicion per respondent 2).
3. Receipt photo attachment per expense, with a visible "no receipt" label for gaps.
4. Committee members as payers in the participant list.
5. Sponsor pledge vs sponsor receipt as separate objects; unlock late sponsor money.
6. Chairperson account + approval.

Deliberately deferred (conflicting or single-source evidence): receipt auto-redaction, event lock/reopen, advance-to-sponsor conversion, vice-chair delegation, DOCX, charity/equal-surplus distribution, first-vendor-payment cutoff.

Each item gets its own small spec and is re-checked against respondent evidence before build.

## Phase 5 — Production hardening (only if adoption is supported)

- Custom SMTP; non-member RLS check; two-account SIT.
- Backups and restore drill for hosted Postgres.
- Play Store: privacy policy, Data safety form, signed AAB, internal then closed test.

## Decision gates

| Gate | After | Pass means |
|---|---|---|
| G1 | Phase 2 | She actually uses it -> continue to Phase 4 |
| G2 | Phase 3 | >=3 independent treasurers confirm problem and some adoption interest -> Phase 5 |
| Fail at G1 | Phase 2 | Diagnose why (UX, trust, habit). Pivot or stop. Do not build Phase 4 on hope. |

## Schedule at 5 hours/week (pilot not yet started as of 2026-10-01)

Rule: Phases 2 and 3 run side by side; Phase 4 never starts before G1.

| Week | Hours | Work |
|---|---|---|
| 1 | 5 | Phase 0 (about 1h). Phase 1: account, release APK, minimum SIT on her phone (about 4h). |
| 2 | 5 | Dummy rehearsal (about 2h), reset to empty, agree pass/fail criteria, hand over. Book interview 3. |
| 3-5 | 3 pilot (check-in, bug fixes) + 2 interviews | Phase 2 + Phase 3. Interviews 3 and 4, independence check on respondent 2. |
| 6 | 5 | G1 review: pass, partial, or fail against criteria. Classify requirements table. |
| 7+ | 5 | If pass/partial: Phase 4 item 1 (participant read-only view), one item per 1-2 weeks. |

Earliest realistic G1: about 2026-11-10. Phase 4 item 1 ships about late November. Phase 5 is out of scope until adoption is supported.

Pilot start is gated on her real event date. If no real event is within about 4 weeks, run the pilot on a past event's data re-entered alongside her notebook, which still tests usability but only weakly tests adoption.

## Open questions for you

Answered: pilot not started; budget 5 hours/week.

1. When is respondent 3's next real event? It sets the pilot start and whether adoption can truly be tested.
2. Goal: community tool, or Play Store product? Plan assumes community tool; Phase 5 stays deferred.
