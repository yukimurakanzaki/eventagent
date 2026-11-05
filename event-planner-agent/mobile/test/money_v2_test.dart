import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/labels.dart';
import 'package:wargakas_mobile/main.dart';

CashbookController _controller(List<TransactionRecord> transactions) =>
    CashbookController.forTesting(
      initial: CashbookSnapshot.demo().copyWith(transactions: transactions),
    );

TransactionRecord _expense(String id, String description, {String? storage}) =>
    TransactionRecord(
      id: id,
      type: TransactionType.expense,
      amount: 150000,
      description: description,
      createdAt: DateTime(2026, 1, 5),
      category: ExpenseCategory.transport,
      receiptStoragePath: storage,
    );

Future<void> _openMoney(WidgetTester tester, CashbookController c) async {
  await tester.pumpWidget(WargakasApp(controller: c));
  await tester.tap(find.text('Uang').last);
  await tester.pumpAndSettle();
}

Future<void> _scrollToHistory(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 200);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recording an expense with a category stores it', (tester) async {
    final controller = CashbookController.forTesting();
    await _openMoney(tester, controller);
    await tester.tap(find.text('Catat transaksi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengeluaran').last);
    await tester.pumpAndSettle();
    expect(find.text('Kategori'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('transaction-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transaction-category')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(expenseCategoryLabel(ExpenseCategory.transport)).last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-amount')),
      '50000',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'Sewa angkot',
    );
    await tester.pump();
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();
    final saved = controller.transactions.firstWhere(
      (t) => t.description == 'Sewa angkot',
    );
    expect(saved.category, ExpenseCategory.transport);
    expect(saved.receiptPath, isNull);
  });

  testWidgets('category card lists totals', (tester) async {
    await _openMoney(
      tester,
      _controller([_expense('e1', 'Bensin bus', storage: 'a/b.jpg')]),
    );
    await tester.scrollUntilVisible(
      find.text('Pengeluaran per kategori'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pengeluaran per kategori'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    expect(
      find.text(expenseCategoryLabel(ExpenseCategory.transport)),
      findsWidgets,
    );
  });

  testWidgets('no category card without expenses', (tester) async {
    await _openMoney(tester, _controller(const []));
    expect(find.text('Pengeluaran per kategori'), findsNothing);
  });

  testWidgets('Tanpa nota labels expenses missing a receipt', (tester) async {
    await _openMoney(tester, _controller([_expense('e1', 'Bensin bus')]));
    await _scrollToHistory(tester, 'Bensin bus');
    expect(find.text('Tanpa nota'), findsOneWidget);
    expect(find.text('Lampirkan nota'), findsOneWidget);
  });

  testWidgets('expense with receipt shows no Tanpa nota', (tester) async {
    await _openMoney(
      tester,
      _controller([_expense('e1', 'Bensin bus', storage: 'a/b.jpg')]),
    );
    await _scrollToHistory(tester, 'Bensin bus');
    expect(find.text('Tanpa nota'), findsNothing);
    expect(find.text('Ganti nota'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsWidgets);
  });
}
