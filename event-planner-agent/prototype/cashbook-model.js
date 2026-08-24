(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.CashbookModel = factory();
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const incomeTypes = ['participant_payment', 'sponsor', 'additional_contribution'];
  const expenseTypes = ['expense', 'refund', 'refund_reversal'];

  function participantTarget(event) {
    const capacity = Math.max(1, Number(event.participantCapacity || event.participantTarget || 18));
    return Math.round((Number(event.finalBudget || 0) - Number(event.sponsorContribution || 0) - Number(event.openingBalance || 0)) / capacity);
  }

  function transactionTotal(transactions, types) {
    return (transactions || []).filter((item) => types.includes(item.type)).reduce((sum, item) => sum + Number(item.amount || 0), 0);
  }

  function incomeTotal(transactions) {
    return transactionTotal(transactions, incomeTypes);
  }

  function expenseTotal(transactions) {
    return (transactions || []).filter((item) => expenseTypes.includes(item.type)).reduce((sum, item) => sum + (item.type === 'refund_reversal' ? -Number(item.amount || 0) : Number(item.amount || 0)), 0);
  }

  function currentBalance(event, transactions) {
    return Number(event.openingBalance || 0) + Number(event.sponsorContribution || 0) + incomeTotal(transactions) - expenseTotal(transactions);
  }

  function paymentStatus(amount, target) {
    const paid = Number(amount || 0);
    const goal = Number(target || 0);
    return paid >= goal ? 'Lunas' : paid > 0 ? 'Sebagian' : 'Belum bayar';
  }

  function canAddSponsor(transactions) {
    return !(transactions || []).some((item) => item.type === 'participant_payment');
  }

  function refundAmount(policy, paidAmount, requestedAmount) {
    if (policy === 'full') return Number(paidAmount || 0);
    if (policy === 'partial') return Math.max(0, Number(requestedAmount || 0));
    return 0;
  }

  function refundTotalForParticipant(transactions, participantId) {
    return (transactions || []).filter((item) => item.participantId === participantId && ['refund', 'refund_reversal'].includes(item.type)).reduce((sum, item) => sum + (item.type === 'refund' ? Number(item.amount || 0) : -Number(item.amount || 0)), 0);
  }

  return { participantTarget, incomeTotal, expenseTotal, currentBalance, paymentStatus, canAddSponsor, refundAmount, refundTotalForParticipant };
}));
