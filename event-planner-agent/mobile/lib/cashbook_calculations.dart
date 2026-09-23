import 'cashbook_models.dart';

/// Costs are per head, so the need is split across active participants, not
/// capacity. Capacity only caps how many can join.
int participantTarget(EventRecord event, int activeCount) {
  final divisor = activeCount < 1 ? 1 : activeCount;
  final target =
      ((event.finalBudget -
                  event.sponsorContribution -
                  event.openingBalance) /
              divisor)
          .round();
  return target < 0 ? 0 : target;
}

int activeParticipantCount(Iterable<ParticipantRecord> participants) =>
    participants.where((item) => item.state == ParticipantState.active).length;

Set<String> correctedTransactionIds(Iterable<TransactionRecord> transactions) =>
    {
      for (final transaction in transactions)
        if (transaction.type == TransactionType.correction &&
            transaction.relatedTransactionId != null)
          transaction.relatedTransactionId!,
    };

/// Transactions that still move money: corrected originals and the correction
/// rows themselves are kept for the audit trail but count for nothing.
List<TransactionRecord> effectiveTransactions(
  Iterable<TransactionRecord> transactions,
) {
  final corrected = correctedTransactionIds(transactions);
  return transactions
      .where(
        (transaction) =>
            transaction.type != TransactionType.correction &&
            !corrected.contains(transaction.id),
      )
      .toList();
}

int incomeTotal(Iterable<TransactionRecord> transactions) {
  // ponytail: sponsor money lives on event.sponsorContribution, which
  // currentBalance already adds. Sponsor transactions contribute 0 here so a
  // legacy persisted record still renders in the ledger without double-counting.
  const income = {
    TransactionType.participantPayment,
    TransactionType.additionalContribution,
  };
  return effectiveTransactions(transactions)
      .where((transaction) => income.contains(transaction.type))
      .fold(0, (sum, transaction) => sum + transaction.amount);
}

int expenseTotal(Iterable<TransactionRecord> transactions) {
  const expenses = {
    TransactionType.expense,
    TransactionType.refund,
    TransactionType.refundReversal,
  };
  return effectiveTransactions(transactions)
      .where((transaction) => expenses.contains(transaction.type))
      .fold(
        0,
        (sum, transaction) =>
            sum +
            (transaction.type == TransactionType.refundReversal
                ? -transaction.amount
                : transaction.amount),
      );
}

int currentBalance(
  EventRecord event,
  Iterable<TransactionRecord> transactions,
) {
  return event.openingBalance +
      event.sponsorContribution +
      incomeTotal(transactions) -
      expenseTotal(transactions);
}

String paymentStatus(int paidAmount, int target) {
  if (paidAmount >= target) return 'Lunas';
  if (paidAmount > 0) return 'Sebagian';
  return 'Belum bayar';
}

/// The sponsor field stays editable until the first participant payment.
bool sponsorEditable(Iterable<TransactionRecord> transactions) {
  return !transactions.any(
    (transaction) => transaction.type == TransactionType.participantPayment,
  );
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

int participantPaid(
  Iterable<TransactionRecord> transactions,
  String participantId,
) {
  return effectiveTransactions(transactions)
      .where(
        (transaction) =>
            transaction.type == TransactionType.participantPayment &&
            transaction.participantId == participantId,
      )
      .fold(0, (sum, transaction) => sum + transaction.amount);
}

int refundTotalForParticipant(
  Iterable<TransactionRecord> transactions,
  String participantId,
) {
  return effectiveTransactions(transactions)
      .where((transaction) {
        return transaction.participantId == participantId &&
            (transaction.type == TransactionType.refund ||
                transaction.type == TransactionType.refundReversal);
      })
      .fold(
        0,
        (sum, transaction) =>
            sum +
            (transaction.type == TransactionType.refundReversal
                ? -transaction.amount
                : transaction.amount),
      );
}

int refundableAmountForParticipant(
  Iterable<TransactionRecord> transactions,
  String participantId,
) {
  final remaining = participantNetPaid(transactions, participantId);
  return remaining < 0 ? 0 : remaining;
}

int participantNetPaid(
  Iterable<TransactionRecord> transactions,
  String participantId,
) =>
    participantPaid(transactions, participantId) -
    refundTotalForParticipant(transactions, participantId);
