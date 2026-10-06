import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_calculations.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/main.dart';

void main() {
  test('collectionProgress counts active participants and caps at target', () {
    final controller = CashbookController.forTesting();
    final target = controller.contributionTarget;
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      target,
    );
    final active = controller.participants
        .where((item) => item.state == ParticipantState.active)
        .length;

    expect(progress.paid + progress.partial + progress.unpaid, active);
    expect(progress.expected, target * active);
    expect(progress.collected, lessThanOrEqualTo(progress.expected));
    expect(progress.fraction, inInclusiveRange(0, 1));
    expect(payState(0, 100), PayState.unpaid);
    expect(payState(50, 100), PayState.partial);
    expect(payState(100, 100), PayState.paid);
  });

  testWidgets('summary shows progress and a tile jumps to filtered list', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    );
    await tester.pumpWidget(WargakasApp(controller: controller));

    expect(find.textContaining('Iuran terkumpul'), findsOneWidget);
    // Sync banner never shows an "offline" icon next to a "saved" message.
    expect(find.byIcon(Icons.wifi_off_outlined), findsNothing);

    await tester.scrollUntilVisible(find.text('Sebagian'), 200);
    await tester.tap(find.text('Sebagian'));
    await tester.pumpAndSettle();

    // Lands on Peserta with the Sebagian filter applied.
    expect(find.text('Tambah peserta'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Sebagian (${progress.partial})'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('Catat bayar opens the payment form prefilled and saves it', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));
    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();

    final before = controller.transactions.length;
    await tester.tap(find.text('Catat bayar').first);
    await tester.pumpAndSettle();

    expect(find.text('Catat pembayaran'), findsOneWidget);
    final amount = tester.widget<TextField>(
      find.byKey(const Key('transaction-amount')),
    );
    expect(amount.controller!.text, isNotEmpty);
    final description = tester.widget<TextField>(
      find.byKey(const Key('transaction-description')),
    );
    expect(description.controller!.text, 'Iuran peserta');

    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();

    expect(controller.transactions.length, before + 1);
    expect(
      controller.transactions.last.type,
      TransactionType.participantPayment,
    );
  });
}
