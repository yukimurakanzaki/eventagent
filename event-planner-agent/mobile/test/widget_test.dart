import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/cashbook_sync.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/report_service.dart';
import 'package:wargakas_mobile/supabase_app.dart';
import 'package:wargakas_mobile/supabase_backend.dart';

class RecordingReportGateway implements ReportShareGateway {
  bool pdfCalled = false;
  bool messageCalled = false;
  bool shouldFail = false;

  @override
  Future<void> sharePdf(CashbookReport report) async {
    pdfCalled = true;
    if (shouldFail) throw StateError('share failed');
  }

  @override
  Future<void> shareWhatsAppText(CashbookReport report) async {
    messageCalled = true;
    if (shouldFail) throw StateError('share failed');
  }
}

class WidgetConflictAdapter implements CashbookSyncAdapter {
  @override
  Future<CashbookSnapshot?> load() async => null;

  @override
  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  }) async {
    return SyncResult.conflict(
      version: 2,
      remoteSnapshot: CashbookSnapshot.demo().copyWith(syncVersion: 2),
    );
  }
}

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

  testWidgets('cancels a participant after its refund choice dialog closes', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));

    await tester.tap(find.text('Peserta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ibu Sari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan peserta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan pembatalan'));
    await tester.pumpAndSettle();

    expect(
      controller.participants
          .singleWhere((participant) => participant.name == 'Ibu Sari')
          .state,
      ParticipantState.cancelled,
    );
  });

  testWidgets('global transaction shortcut is available on every event tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    for (final tab in ['Ringkasan', 'Peserta', 'Uang', 'Laporan']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('global-transaction-shortcut')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();
    expect(find.text('Catat transaksi'), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Simpan transaksi'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('transaction shortcut saves a selected transaction', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));

    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengeluaran'));
    await tester.enterText(
      find.byKey(const Key('transaction-amount')),
      '125000',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'Uang muka bus',
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Simpan transaksi'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi berhasil disimpan.'), findsOneWidget);
    expect(controller.transactions.last.amount, 125000);
  });

  testWidgets('transaction form reveals a participant only when needed', (
    tester,
  ) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );

    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-participant')), findsNothing);

    await tester.tap(find.text('Pembayaran peserta'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-participant')), findsOneWidget);

    await tester.tap(find.text('Pengeluaran'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-participant')), findsNothing);
  });

  testWidgets('saves a participant refund after closing its form', (
    tester,
  ) async {
    final controller = CashbookController.forTesting();
    await tester.pumpWidget(WargakasApp(controller: controller));

    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refund peserta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transaction-participant')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ibu Sari').last);
    await tester.enterText(
      find.byKey(const Key('transaction-amount')),
      '50000',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'Refund pembatalan',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();

    expect(controller.transactions.last.type, TransactionType.refund);
    expect(controller.transactions.last.participantId, 'p-sari');
    expect(controller.transactions.last.amount, 50000);
  });

  testWidgets(
    'shows a clear setup screen instead of silently opening demo mode',
    (tester) async {
      expect(SupabaseBackend.isDemoMode, isFalse);
      expect(SupabaseBackend.configurationError, isNotNull);

      await tester.pumpWidget(
        const ConfigurationErrorApp(
          message: 'Build ini belum terhubung ke Supabase.',
        ),
      );

      expect(
        find.text('Aplikasi belum dikonfigurasi untuk login.'),
        findsOneWidget,
      );
      expect(
        find.text('Build ini belum terhubung ke Supabase.'),
        findsOneWidget,
      );
    },
  );

  test('translates an expired auth link into an actionable message', () {
    final message = authErrorMessage(StateError('access_denied: otp_expired'));

    expect(message, contains('kedaluwarsa atau tidak valid'));
    expect(message, contains('Minta link baru'));
  });

  testWidgets('shows the account area and signs out explicitly', (
    tester,
  ) async {
    var signOutCalled = false;
    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        accountEmail: 'treasurer@example.com',
        accountRole: 'treasurer',
        onSignOut: () async => signOutCalled = true,
      ),
    );

    await tester.tap(find.byTooltip('Akun'));
    await tester.pumpAndSettle();
    expect(find.text('treasurer@example.com'), findsOneWidget);
    expect(find.text('Bendahara'), findsOneWidget);

    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(signOutCalled, isTrue);
  });

  testWidgets('warns before signing out with unsynced changes', (tester) async {
    final controller = CashbookController.forTesting();
    await controller.addParticipant('Perubahan lokal');
    var signOutCalled = false;

    await tester.pumpWidget(
      WargakasApp(
        controller: controller,
        onSignOut: () async => signOutCalled = true,
      ),
    );

    await tester.tap(find.byTooltip('Akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();

    expect(find.text('Perubahan belum tersinkron'), findsOneWidget);
    expect(find.text('Tetap di sini'), findsOneWidget);
    expect(signOutCalled, isFalse);

    await tester.tap(find.text('Tetap di sini'));
    await tester.pumpAndSettle();
    expect(find.text('Perubahan belum tersinkron'), findsNothing);
    expect(signOutCalled, isFalse);
  });

  testWidgets(
    'edits configurable event after showing before and after values',
    (tester) async {
      final controller = CashbookController.forTesting();
      await tester.pumpWidget(WargakasApp(controller: controller));

      await tester.tap(find.byTooltip('Edit acara'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama acara'),
        'Wisata Bandung',
      );
      await tester.tap(find.text('Tinjau perubahan'));
      await tester.pumpAndSettle();

      expect(find.text('Simpan perubahan acara?'), findsOneWidget);
      expect(
        find.textContaining('Wisata Dieng -> Wisata Bandung'),
        findsOneWidget,
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(controller.event.name, 'Wisata Bandung');
      expect(find.text('Wisata Bandung'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps the event editor readable on a narrow screen at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await tester.pumpWidget(
        WargakasApp(controller: CashbookController.forTesting()),
      );
      await tester.tap(find.byTooltip('Edit acara'));
      await tester.pumpAndSettle();

      expect(find.text('Tanggal acara'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Pilih tanggal Mulai, 12/09/2026'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Pilih tanggal Selesai, 14/09/2026'),
        findsOneWidget,
      );
      expect(find.text('Tinjau perubahan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('blocks edits and offers both conflict choices', (tester) async {
    final controller = CashbookController.forTesting(
      syncAdapter: WidgetConflictAdapter(),
    );
    await controller.addParticipant('Perubahan lokal');
    await tester.pumpWidget(WargakasApp(controller: controller));

    expect(find.text('Pilih versi data sebelum melanjutkan'), findsOneWidget);
    expect(find.text('Selesaikan konflik'), findsOneWidget);
    expect(
      find.byTooltip('Selesaikan konflik sebelum mengedit acara'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('global-transaction-shortcut')));
    await tester.pumpAndSettle();

    expect(find.text('Perangkat ini'), findsOneWidget);
    expect(find.text('Data online'), findsOneWidget);
    expect(find.text('Gunakan data online'), findsOneWidget);
    expect(find.text('Gunakan perangkat ini'), findsOneWidget);
  });

  testWidgets('shares report through injected gateway and shows failures', (
    tester,
  ) async {
    final gateway = RecordingReportGateway();
    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        reportShareGateway: gateway,
      ),
    );

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat dan bagikan PDF'));
    await tester.pumpAndSettle();
    expect(gateway.pdfCalled, isTrue);

    gateway.shouldFail = true;
    await tester.tap(find.text('Bagikan pesan WhatsApp'));
    await tester.pumpAndSettle();
    expect(gateway.messageCalled, isTrue);
    expect(
      find.text('Pesan belum dapat dibagikan. Coba lagi.'),
      findsOneWidget,
    );
  });
}
