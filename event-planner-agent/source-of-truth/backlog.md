# Backlog

## Next

- Create the Flutter Android app shell with the four fixed navigation destinations.
- Set up Firebase Authentication and hosted event data with treasurer/chairperson access.
- [Prototype] Extract and test target, cash-balance, payment-state, fixed-capacity, and sponsor-lock rules in `cashbook-model.js`. Production mobile port still required.
- Design the production offline-first sync queue and conflict handling for payments, expenses, participants, and reminders. The prototype now shows a local queued-change model.
- [Prototype] Add a contextual Pengingat card under Ringkasan with local reminder state. Production device notifications remain part of the mobile shell.
- Validate reminder wording and timing with the treasurer using real planning dates.
- Run usability testing with 2–3 community treasurers aged 50+ using the mobile shell.

## Questions

- [x] Agree on the named portfolio/e-transcript report and low-privacy WhatsApp wording, with account numbers and credentials excluded.
- [Proposed] Choose Flutter + Firebase as the first production direction.
- [Open] If the same reminder is edited on two devices while offline, which change should win and how should the treasurer be notified?
- [Open] Should chairperson-created reminders notify the treasurer, the chairperson, or both?
- [Open] What quiet hours and notification tone are appropriate for the 50+ user group?

## Later

- [x] Add local persistence and report handoff generation to the prototype.
- [x] Add static deployment/run notes in `prototype/README.md`.
- Prepare Play Store assets, privacy policy, Data safety declaration, signed AAB, internal test, and closed-test release after the mobile MVP is functional.
