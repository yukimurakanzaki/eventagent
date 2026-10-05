import 'cashbook_calculations.dart';
import 'cashbook_models.dart';

/// Category = [TransactionType]; the model has no separate category field.
/// Empty [types] means every category. [from]/[to] are inclusive calendar days.
class TransactionFilter {
  const TransactionFilter({this.types = const {}, this.from, this.to});

  final Set<TransactionType> types;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => types.isEmpty && from == null && to == null;

  bool matches(TransactionRecord transaction) {
    if (types.isNotEmpty && !types.contains(transaction.type)) return false;
    final day = _day(transaction.createdAt);
    if (from != null && day.isBefore(_day(from!))) return false;
    if (to != null && day.isAfter(_day(to!))) return false;
    return true;
  }

  TransactionFilter copyWith({
    Set<TransactionType>? types,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
  }) => TransactionFilter(
    types: types ?? this.types,
    from: clearRange ? null : from ?? this.from,
    to: clearRange ? null : to ?? this.to,
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// One ledger line. [counted] is false for corrected originals and the
/// correction rows themselves; [balanceAfter] is the event balance after it.
class LedgerEntry {
  const LedgerEntry({
    required this.transaction,
    required this.counted,
    required this.balanceAfter,
  });

  final TransactionRecord transaction;
  final bool counted;
  final int balanceAfter;
}

bool isOutflow(TransactionType type) =>
    type == TransactionType.expense ||
    type == TransactionType.refund ||
    type == TransactionType.refundReversal;

/// Signed effect on the balance (0 for sponsor rows and corrections, which
/// move no money here; see [incomeTotal]).
int balanceEffect(TransactionRecord transaction) => switch (transaction.type) {
  TransactionType.participantPayment ||
  TransactionType.additionalContribution => transaction.amount,
  TransactionType.expense || TransactionType.refund => -transaction.amount,
  TransactionType.refundReversal => transaction.amount,
  TransactionType.sponsor || TransactionType.correction => 0,
};

/// Chronological ledger over ALL transactions with a running balance, newest
/// last. The running balance always uses the full history, never the filter.
List<LedgerEntry> buildLedger(
  EventRecord event,
  Iterable<TransactionRecord> transactions,
) {
  final all = transactions.toList();
  final corrected = correctedTransactionIds(all);
  final ordered = [...all]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  var balance = event.openingBalance + event.sponsorContribution;
  return [
    for (final transaction in ordered)
      () {
        final counted =
            transaction.type != TransactionType.correction &&
            !corrected.contains(transaction.id);
        if (counted) balance += balanceEffect(transaction);
        return LedgerEntry(
          transaction: transaction,
          counted: counted,
          balanceAfter: balance,
        );
      }(),
  ];
}

List<LedgerEntry> filterLedger(
  List<LedgerEntry> ledger,
  TransactionFilter filter,
) => ledger.where((entry) => filter.matches(entry.transaction)).toList();

class LogSummary {
  const LogSummary({
    required this.count,
    required this.inflow,
    required this.outflow,
    required this.byType,
  });

  final int count;
  final int inflow;
  final int outflow;

  /// Counted amount per category, only categories with counted rows.
  final Map<TransactionType, int> byType;

  int get net => inflow - outflow;
}

LogSummary summarize(Iterable<LedgerEntry> entries) {
  var inflow = 0, outflow = 0, count = 0;
  final byType = <TransactionType, int>{};
  for (final entry in entries) {
    count++;
    if (!entry.counted) continue;
    final amount = entry.transaction.amount;
    final type = entry.transaction.type;
    byType[type] = (byType[type] ?? 0) + amount;
    final effect = balanceEffect(entry.transaction);
    if (effect > 0) inflow += effect;
    if (effect < 0) outflow -= effect;
  }
  return LogSummary(
    count: count,
    inflow: inflow,
    outflow: outflow,
    byType: byType,
  );
}

/// Counted inflow/outflow per calendar month ("yyyy-MM"), oldest first.
Map<String, ({int inflow, int outflow})> monthlyTotals(
  Iterable<LedgerEntry> entries,
) {
  final months = <String, ({int inflow, int outflow})>{};
  for (final entry in entries.where((e) => e.counted)) {
    final date = entry.transaction.createdAt;
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final effect = balanceEffect(entry.transaction);
    final current = months[key] ?? (inflow: 0, outflow: 0);
    months[key] = (
      inflow: current.inflow + (effect > 0 ? effect : 0),
      outflow: current.outflow + (effect < 0 ? -effect : 0),
    );
  }
  return Map.fromEntries(
    months.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}
