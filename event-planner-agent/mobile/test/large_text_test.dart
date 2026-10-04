import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';

/// Every main screen and dialog must lay out without overflow on a 320dp phone
/// at 2x system text (the 50+ treasurer's setting).
void main() {
  testWidgets('screens and dialogs fit at 2x text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        onSignOut: () async {},
        onInviteChairperson: (_) async {},
        accountEmail: 'bendahara@example.com',
        accountRole: 'treasurer',
      ),
    );
    await tester.pumpAndSettle();

    Future<void> dismiss() async {
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
    }

    for (final tab in ['Ringkasan', 'Peserta', 'Uang', 'Laporan']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab');
    }
    for (final tip in ['Edit acara', 'Bantuan', 'Akun', 'Tambah ketua acara']) {
      await tester.tap(find.byTooltip(tip));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'dialog $tip');
      await dismiss();
    }
    await tester.tap(find.text('Peserta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah peserta').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'dialog Tambah peserta');
    await dismiss();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'dialog Transaksi');
  });
}
