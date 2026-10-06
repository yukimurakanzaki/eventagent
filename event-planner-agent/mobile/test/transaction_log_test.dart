import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_calculations.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/report_service.dart';
import 'package:wargakas_mobile/transaction_log.dart';

TransactionRecord _t(
  String id,
  TransactionType type,
  int amount,
  DateTime at, {
  String? related,
}) => TransactionRecord(
  id: id,
  type: type,
  amount: amount,
  description: id,
  createdAt: at,
  relatedTransactionId: related,
);

void main() {
  final event = CashbookSnapshot.demo().event;
  final txs = [
    _t('pay', TransactionType.participantPayment, 500, DateTime(2026, 9, 1)),
    _t('bus', TransactionType.expense, 200, DateTime(2026, 9, 5)),
    _t('oops', TransactionType.expense, 999, DateTime(2026, 9, 6)),
    _t(
      'fix',
      TransactionType.correction,
      999,
      DateTime(2026, 9, 7),
      related: 'oops',
    ),
  ];

  test('ledger running balance matches currentBalance and skips voided', () {
    final ledger = buildLedger(event, txs);
    expect(ledger.last.balanceAfter, currentBalance(event, txs));
    expect(ledger.where((e) => !e.counted).map((e) => e.transaction.id), [
      'oops',
      'fix',
    ]);
  });

  test('filters by category and inclusive date range', () {
    final ledger = buildLedger(event, txs);
    expect(
      filterLedger(
        ledger,
        const TransactionFilter(types: {TransactionType.expense}),
      ).length,
      2,
    );
    final ranged = filterLedger(
      ledger,
      TransactionFilter(from: DateTime(2026, 9, 5), to: DateTime(2026, 9, 6)),
    );
    expect(ranged.map((e) => e.transaction.id), ['bus', 'oops']);
    final summary = summarize(ranged);
    expect(summary.count, 2);
    expect(summary.outflow, 200);
    expect(summary.inflow, 0);
  });

  test('log and portfolio PDFs build', () async {
    final snapshot = CashbookSnapshot.demo();
    for (final kind in [ReportKind.log, ReportKind.portfolio]) {
      final bytes = await CashbookReport(
        snapshot: snapshot,
        creatorRole: 'treasurer',
        generatedAt: DateTime(2026, 9, 6),
        kind: kind,
        filter: const TransactionFilter(types: {TransactionType.expense}),
      ).buildPdf();
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }
  });

  testWidgets('log page filters by category chip', (tester) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );
    await tester.tap(find.text('Uang').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Filter & laporan rinci'), 200);
    await tester.tap(find.text('Filter & laporan rinci'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat transaksi'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Pengeluaran'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
  });
}
