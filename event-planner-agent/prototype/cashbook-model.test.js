const assert = require('node:assert/strict');
const test = require('node:test');
const model = require('./cashbook-model.js');

const event = {
  participantCapacity: 18,
  finalBudget: 14000000,
  sponsorContribution: 0,
  openingBalance: 500000
};

test('calculates a visible contribution target from final budget inputs', () => {
  assert.equal(model.participantTarget(event), 750000);
});

test('uses cash transactions once for income and expenses', () => {
  const transactions = [
    { type: 'participant_payment', amount: 11100000 },
    { type: 'expense', amount: 5050000 },
    { type: 'refund', amount: 100000 }
  ];
  assert.equal(model.incomeTotal(transactions), 11100000);
  assert.equal(model.expenseTotal(transactions), 5150000);
  assert.equal(model.currentBalance(event, transactions), 6450000);
});

test('keeps partial and unpaid states understandable', () => {
  assert.equal(model.paymentStatus(750000, 750000), 'Lunas');
  assert.equal(model.paymentStatus(300000, 750000), 'Sebagian');
  assert.equal(model.paymentStatus(0, 750000), 'Belum bayar');
});

test('blocks new sponsor contribution after participant payments start', () => {
  assert.equal(model.canAddSponsor([{ type: 'expense', amount: 100 }]), true);
  assert.equal(model.canAddSponsor([{ type: 'participant_payment', amount: 100 }]), false);
});

test('fixed capacity remains 18 even when a participant is cancelled', () => {
  assert.equal(model.participantTarget({ ...event, participantCapacity: 18 }), 750000);
  assert.equal(model.participantTarget({ ...event, participantCapacity: 18, activeParticipantCount: 17 }), 750000);
});

test('supports per-participant no, partial, and full refund choices', () => {
  assert.equal(model.refundAmount('none', 300000, 300000), 0);
  assert.equal(model.refundAmount('partial', 300000, 100000), 100000);
  assert.equal(model.refundAmount('full', 300000, 100000), 300000);
  assert.equal(model.refundAmount('undecided', 300000, 100000), 0);
});

test('refund history can be corrected without deleting the original transaction', () => {
  const transactions = [
    { type: 'refund', participantId: 'p-budi', amount: 300000 },
    { type: 'refund_reversal', participantId: 'p-budi', amount: 200000 }
  ];
  assert.equal(model.refundTotalForParticipant(transactions, 'p-budi'), 100000);
  assert.equal(model.expenseTotal(transactions), 100000);
  assert.equal(transactions.length, 2);
});

test('cancelled and replacement participant payments remain separate income records', () => {
  const transactions = [
    { type: 'participant_payment', participantId: 'p-budi', amount: 300000 },
    { type: 'participant_payment', participantId: 'p-roni', amount: 750000 }
  ];
  assert.equal(model.incomeTotal(transactions), 1050000);
  assert.notEqual(transactions[0].participantId, transactions[1].participantId);
});
