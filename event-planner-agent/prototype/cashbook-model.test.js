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
