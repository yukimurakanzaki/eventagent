import 'cashbook_models.dart';

int participantTarget(EventRecord event) {
  final capacity = event.participantCapacity < 1 ? 1 : event.participantCapacity;
  return ((event.finalBudget - event.sponsorContribution - event.openingBalance) / capacity).round();
}

int incomeTotal(Iterable<TransactionRecord> transactions) {
  const income = {
    TransactionType.participantPayment,
    TransactionType.sponsor,
    TransactionType.additionalContribution,
  };
  return transactions
      .where((transaction) => income.contains(transaction.type))
      .fold(0, (sum, transaction) => sum + transaction.amount);
}

int expenseTotal(Iterable<TransactionRecord> transactions) {
  const expenses = {
    TransactionType.expense,
    TransactionType.refund,
    TransactionType.refundReversal,
  };
  return transactions.where((transaction) => expenses.contains(transaction.type)).fold(
        0,
        (sum, transaction) => sum +
            (transaction.type == TransactionType.refundReversal
                ? -transaction.amount
                : transaction.amount),
      );
}

int currentBalance(EventRecord event, Iterable<TransactionRecord> transactions) {
  return event.openingBalance + event.sponsorContribution + incomeTotal(transactions) - expenseTotal(transactions);
}

String paymentStatus(int paidAmount, int target) {
  if (paidAmount >= target) return 'Lunas';
  if (paidAmount > 0) return 'Sebagian';
  return 'Belum bayar';
}

bool canAddSponsor(Iterable<TransactionRecord> transactions) {
  return !transactions.any((transaction) => transaction.type == TransactionType.participantPayment);
}

int refundAmount(RefundPolicy policy, int paidAmount, int requestedAmount) {
  switch (policy) {
    case RefundPolicy.full:
      return paidAmount;
    case RefundPolicy.partial:
      return requestedAmount < 0 ? 0 : requestedAmount;
    case RefundPolicy.none:
    case RefundPolicy.undecided:
      return 0;
  }
}

int participantPaid(Iterable<TransactionRecord> transactions, String participantId) {
  return transactions
      .where((transaction) =>
          transaction.type == TransactionType.participantPayment &&
          transaction.participantId == participantId)
      .fold(0, (sum, transaction) => sum + transaction.amount);
}

int refundTotalForParticipant(Iterable<TransactionRecord> transactions, String participantId) {
  return transactions.where((transaction) {
    return transaction.participantId == participantId &&
        (transaction.type == TransactionType.refund ||
            transaction.type == TransactionType.refundReversal);
  }).fold(
    0,
    (sum, transaction) => sum +
        (transaction.type == TransactionType.refundReversal
            ? -transaction.amount
            : transaction.amount),
  );
}
