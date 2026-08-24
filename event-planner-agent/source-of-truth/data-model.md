# Prototype Data Model

This is the smallest model needed to move the cashbook prototype toward a persistent MVP. It is a working technical definition, not a replacement for the product brief.

## Event

`id`, `name`, `startDate`, `endDate`, `participantCapacity`, `finalBudget`, `sponsorContribution`, `openingBalance`, `createdAt`, `updatedAt`.

Derived values:

- `participantNeed = finalBudget - sponsorContribution - openingBalance`
- `targetPerPerson = participantNeed / participantCapacity`
- `currentBalance = openingBalance + sponsorContribution + participantPayments + otherIncome - expenses`

## Participant

`id`, `eventId`, `name`, `status` (`active`, `cancelled`), `refundPolicy` (`none`, `partial`, `full`), `replacementForId`, `replacedById`, `notes`, `createdAt`, `updatedAt`.

Cancellation never deletes the participant or their transactions. A replacement is a new participant linked by `replacementForId`; their payment is never transferred to or counted as the cancelled participant's payment. Cancelled participants are excluded from the active count, while event capacity remains unchanged unless the event is edited.

## Transaction

`id`, `eventId`, `type` (`participant_payment`, `sponsor`, `opening_balance`, `expense`, `additional_contribution`, `refund`), `participantId`, `label`, `category`, `amount`, `date`, `notes`, `createdAt`.

## Audit entry

`id`, `eventId`, `type`, `actorId`, `before`, `after`, `reason`, `createdAt`.

Sponsor and opening-balance edits create audit entries. A production audit entry should identify the treasurer who made the change and preserve the before/after values.

## Prototype persistence

The current static prototype stores the active event state in browser `localStorage` under `eventagent.cashbook.v1`. This is intentionally local-only and is not authentication, multi-user collaboration, or production storage.

If the treasurer changes phones, clears app/browser data, or loses the device before production sync exists, local-only data can be lost and the chairperson cannot see the latest copy. Production hosted storage, login, backups, and audit history are therefore required rather than optional conveniences.

## Provisional cancellation behavior

The treasurer chooses no refund, partial refund, or full refund per cancelled participant. A refund is an explicit `refund` transaction. The prototype does not silently transfer money to a replacement or change event capacity.
