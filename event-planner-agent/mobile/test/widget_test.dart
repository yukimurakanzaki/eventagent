import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';

void main() {
  testWidgets('shows the fixed event navigation', (tester) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    expect(find.text('Acara Saya'), findsOneWidget);
    expect(find.text('Wisata Dieng'), findsOneWidget);
    expect(find.text('Ringkasan'), findsWidgets);
    expect(find.text('Peserta'), findsOneWidget);
    expect(find.text('Uang'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
  });

  testWidgets('switches to the participant page', (tester) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah peserta'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Ibu Rina'), findsOneWidget);
    expect(find.text('Dibatalkan • Tidak ada refund'), findsOneWidget);
  });

  testWidgets('opens participant edit from the action sheet', (tester) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibu Rina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit nama'));
    await tester.pumpAndSettle();

    expect(find.text('Edit peserta'), findsOneWidget);
  });

  testWidgets('opens participant cancellation from the action sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibu Sari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan peserta'));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan peserta'), findsOneWidget);
    expect(find.text('Simpan pembatalan'), findsOneWidget);
  });
}
