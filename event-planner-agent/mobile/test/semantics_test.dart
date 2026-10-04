import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';

void main() {
  testWidgets('summary reads as labelled amounts and announces sync status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    // One node per amount: label and value read together, icon skipped.
    final balance = tester.getSemantics(find.text('Saldo saat ini'));
    expect(balance.label, matches(r'Saldo saat ini\nRp'));
    final contribution = tester.getSemantics(find.text('Iuran per peserta'));
    expect(contribution.label, matches(r'Iuran per peserta\nRp'));

    // Sync status is a live region so changes are announced.
    final sync = tester.getSemantics(find.textContaining('sinkronisasi').first);
    expect(sync.flagsCollection.isLiveRegion, isTrue);

    // The transaction shortcut is exposed once, as a button.
    final fab = find.bySemanticsLabel('Catat transaksi');
    expect(fab, findsOneWidget);
    handle.dispose();
  });
}
