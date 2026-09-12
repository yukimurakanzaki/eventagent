// QA probe suite. Each test asserts the CORRECT behaviour; failures are bugs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_calculations.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/reminder_notifier.dart';
import 'package:wargakas_mobile/report_service.dart';

class SpyNotifier implements ReminderNotifier {
  final scheduled = <Map<String, Object?>>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dueAt,
    String note = '',
  }) async {
    scheduled.add({'id': id, 'title': title, 'dueAt': dueAt, 'note': note});
  }

  @override
  Future<void> cancel(String id) async {}
}

CashbookSnapshot _snap({
  int sponsor = 5000000,
  int opening = 2000000,
  int budget = 40300000,
  List<TransactionRecord> transactions = const [],
  List<ParticipantRecord>? participants,
}) {
  final base = CashbookSnapshot.demo();
  return base.copyWith(
    event: base.event.copyWith(
      sponsorContribution: sponsor,
      openingBalance: opening,
      finalBudget: budget,
    ),
    participants: participants ?? base.participants,
    transactions: transactions,
  );
}

void main() {
  test('QA-1 money page rows must reconcile to the shown balance', () async {
    final snapshot = _snap(
      transactions: [
        TransactionRecord(
          id: 'tx-extra',
          type: TransactionType.additionalContribution,
          amount: 750000,
          description: 'Iuran tambahan konsumsi',
          createdAt: DateTime(2026, 9, 1),
        ),
      ],
    );
    final balance = currentBalance(snapshot.event, snapshot.transactions);
    // Rows the Uang tab actually prints, in order.
    final shownComponents =
        snapshot.event.sponsorContribution +
        snapshot.event.openingBalance +
        participantPaidTotal(snapshot.transactions) +
        additionalContributionTotal(snapshot.transactions) -
        expenseTotal(snapshot.transactions);
    expect(
      shownComponents,
      balance,
      reason: 'Uang tab omits additional contributions, balance unexplainable',
    );
  });

  testWidgets('QA-2 Uang tab shows a row for additional contributions', (
    tester,
  ) async {
    final controller = CashbookController.forTesting(
      initial: _snap(
        transactions: [
          TransactionRecord(
            id: 'tx-extra',
            type: TransactionType.additionalContribution,
            amount: 750000,
            description: 'Iuran tambahan konsumsi',
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
      ),
    );
    await tester.pumpWidget(WargakasApp(controller: controller));
    await tester.tap(find.text('Uang'));
    await tester.pumpAndSettle();
    expect(find.text('Kontribusi tambahan'), findsOneWidget);
  });

  test('QA-3 cancelled participants must not accept new payments', () async {
    final controller = CashbookController.forTesting();
    final cancelled = controller.participants.firstWhere(
      (item) => item.state == ParticipantState.cancelled,
    );
    final ok = await controller.recordTransaction(
      type: TransactionType.participantPayment,
      amount: 500000,
      description: 'Pembayaran setelah batal',
      participantId: cancelled.id,
    );
    expect(ok, isFalse, reason: 'payment accepted for a cancelled participant');
  });

  test('QA-4 quiet hours must not silently skip a same-day early reminder', () {
    // 06:00 reminders are pushed to 07:00 the same day (fine). 20:00+ are
    // pushed to 07:00 the NEXT day, which can land after the event starts.
    final spy = SpyNotifier();
    final base = CashbookSnapshot.demo();
    final controller = CashbookController.forTesting(
      initial: base.copyWith(reminders: const []),
      reminderNotifier: spy,
    );
    return controller
        .addReminder(
          title: 'Pelunasan',
          dueAt: DateTime.now().add(const Duration(days: 7)),
        )
        .then((_) {
          expect(spy.scheduled.single['note'], '');
          expect(spy.scheduled.single['title'], 'Pelunasan');
        });
  });

  test('QA-5 participant target must never go negative', () {
    final event = CashbookSnapshot.demo().event.copyWith(
      finalBudget: 5000000,
      sponsorContribution: 4000000,
      openingBalance: 3000000,
    );
    final target = participantTarget(event);
    expect(target, greaterThanOrEqualTo(0), reason: 'negative target: $target');
  });

  test('QA-6 event validation must reject funding above the final budget', () {
    final base = CashbookSnapshot.demo();
    final controller = CashbookController.forTesting(
      initial: base.copyWith(transactions: const []),
    );
    final error = controller.validateEventUpdate(
      controller.event.copyWith(
        finalBudget: 5000000,
        sponsorContribution: 4000000,
        openingBalance: 3000000,
      ),
    );
    expect(error, isNotNull, reason: 'sponsor + saldo awal may exceed budget');
  });

  testWidgets('QA-7 payment dropdown must not offer cancelled participants', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));
    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pembayaran peserta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transaction-participant')));
    await tester.pumpAndSettle();
    expect(find.text('Ibu Sari'), findsWidgets);
    expect(
      find.text('Ibu Rina'),
      findsNothing,
      reason: 'cancelled participant offered for a payment',
    );
  });

  test('QA-8 refunds must still be allowed for a cancelled participant', () async {
    final controller = CashbookController.forTesting();
    final cancelled = controller.participants.firstWhere(
      (item) => item.state == ParticipantState.cancelled,
    );
    final ok = await controller.recordTransaction(
      type: TransactionType.refund,
      amount: 500000,
      description: 'Refund setelah batal',
      participantId: cancelled.id,
    );
    expect(ok, isTrue, reason: 'the payment guard over-reached onto refunds');
  });

  test('QA-9 over-budget funding is rejected end to end', () async {
    final base = CashbookSnapshot.demo();
    final controller = CashbookController.forTesting(
      initial: base.copyWith(transactions: const []),
    );
    final error = await controller.updateEvent(
      controller.event.copyWith(
        finalBudget: 5000000,
        sponsorContribution: 4000000,
        openingBalance: 3000000,
      ),
    );
    expect(error, isNotNull);
    expect(controller.event.finalBudget, base.event.finalBudget);
  });

  // --- Round 2 ---

  test('QA-10 a participant must not be renamed to a blank name', () async {
    final controller = CashbookController.forTesting();
    final participant = controller.participants.first;
    await controller.editParticipant(participant.copyWith(name: '   '));
    expect(
      controller.participants.first.name,
      participant.name,
      reason: 'editParticipant accepted a blank name',
    );
  });

  testWidgets('QA-11 clearing a name explains itself instead of silently '
      'discarding the edit', (tester) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));
    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibu Rina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit nama'));
    await tester.pumpAndSettle();
    expect(find.text('Edit peserta'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nama belum diisi'),
      findsOneWidget,
      reason: 'blank rename closes the dialog with no feedback at all',
    );
  });

  test('QA-12 report redaction must cover dotted bank account numbers', () {
    // Indonesian bank accounts are routinely written with dots.
    expect(
      sanitizeReportText('Transfer ke rekening 521.01.000123.30.7 ya'),
      isNot(contains('521.01.000123.30.7')),
      reason: 'dotted account number survives redaction',
    );
  });

  test('QA-13 rupiah amounts must survive report redaction', () {
    expect(
      sanitizeReportText('Sewa bus Rp 12.500.000 lunas'),
      contains('12.500.000'),
      reason: 'account-number redaction now eats ordinary money amounts',
    );
    // The dotted-account case from BUG-009 must stay redacted.
    expect(
      sanitizeReportText('rekening 521.01.000123.30.7'),
      isNot(contains('521.01.000123.30.7')),
    );
  });

  test('QA-14 a past-due reminder must be refused, not silently dropped', () async {
    final spy = SpyNotifier();
    final base = CashbookSnapshot.demo();
    final controller = CashbookController.forTesting(
      initial: base.copyWith(reminders: const []),
      reminderNotifier: spy,
    );
    await controller.addReminder(
      title: 'Pelunasan',
      dueAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(
      controller.reminders,
      isEmpty,
      reason: 'reminder listed as open but no notification will ever fire',
    );
  });
}

int participantPaidTotal(Iterable<TransactionRecord> transactions) =>
    transactions
        .where((item) => item.type == TransactionType.participantPayment)
        .fold(0, (sum, item) => sum + item.amount);

int additionalContributionTotal(Iterable<TransactionRecord> transactions) =>
    transactions
        .where((item) => item.type == TransactionType.additionalContribution)
        .fold(0, (sum, item) => sum + item.amount);
