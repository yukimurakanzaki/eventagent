import 'package:flutter/material.dart';

import 'cashbook_models.dart';
import 'l10n/l10n.dart';

String expenseCategoryLabel(ExpenseCategory category) => switch (category) {
  ExpenseCategory.transport => tr('Transportasi'),
  ExpenseCategory.lodging => tr('Penginapan'),
  ExpenseCategory.food => tr('Makan & minum'),
  ExpenseCategory.tickets => tr('Tiket & aktivitas'),
  ExpenseCategory.equipment => tr('Perlengkapan'),
  ExpenseCategory.donation => tr('Donasi & sosial'),
  ExpenseCategory.other => tr('Lainnya'),
};

IconData expenseCategoryIcon(ExpenseCategory category) => switch (category) {
  ExpenseCategory.transport => Icons.directions_bus_outlined,
  ExpenseCategory.lodging => Icons.hotel_outlined,
  ExpenseCategory.food => Icons.restaurant_outlined,
  ExpenseCategory.tickets => Icons.confirmation_number_outlined,
  ExpenseCategory.equipment => Icons.backpack_outlined,
  ExpenseCategory.donation => Icons.volunteer_activism_outlined,
  ExpenseCategory.other => Icons.category_outlined,
};

String participantRoleLabel(ParticipantRole role) => switch (role) {
  ParticipantRole.participant => tr('Peserta'),
  ParticipantRole.committee => tr('Panitia'),
};

/// Totals of live (not voided) expenses per category, largest first.
/// Uncategorised expenses count as "other".
List<(ExpenseCategory, int)> expenseTotalsByCategory(
  Iterable<TransactionRecord> transactions,
  Set<String> voidedIds,
) {
  final totals = <ExpenseCategory, int>{};
  for (final transaction in transactions) {
    if (transaction.type != TransactionType.expense) continue;
    if (voidedIds.contains(transaction.id)) continue;
    final category = transaction.category ?? ExpenseCategory.other;
    totals[category] = (totals[category] ?? 0) + transaction.amount;
  }
  final list = [for (final entry in totals.entries) (entry.key, entry.value)];
  list.sort((a, b) => b.$2.compareTo(a.$2));
  return list;
}
