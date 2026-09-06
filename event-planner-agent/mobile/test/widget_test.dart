import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/supabase_app.dart';
import 'package:wargakas_mobile/supabase_backend.dart';

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
}
