import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/app_settings.dart';
import 'package:wargakas_mobile/app_shell.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/l10n/l10n.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/money.dart';
import 'package:wargakas_mobile/shared_view_page.dart';

void main() {
  tearDown(() {
    L10n.code = 'id';
    Money.currency = 'IDR';
  });

  group('money', () {
    test('keeps the rupiah format unchanged for existing data', () {
      expect(
        formatMoney(1250000, currency: 'IDR', languageCode: 'id'),
        'Rp 1.250.000',
      );
      expect(
        formatMoney(-5000, currency: 'IDR', languageCode: 'id'),
        '-Rp 5.000',
      );
    });

    test('formats decimals and grouping per locale', () {
      expect(
        formatMoney(123456, currency: 'USD', languageCode: 'en'),
        r'$1,234.56',
      );
      expect(
        formatMoney(123456, currency: 'EUR', languageCode: 'de'),
        '€1.234,56',
      );
      expect(formatMoney(5000, currency: 'JPY', languageCode: 'ja'), '¥5,000');
      expect(
        formatMoney(1050, currency: 'CHF', languageCode: 'en'),
        'CHF 10.50',
      );
    });

    test('parses typed amounts into minor units', () {
      expect(
        parseMoneyInput('1.250.000', currency: 'IDR', languageCode: 'id'),
        1250000,
      );
      expect(
        parseMoneyInput('12.5', currency: 'USD', languageCode: 'en'),
        1250,
      );
      expect(
        parseMoneyInput('1.234,56', currency: 'EUR', languageCode: 'de'),
        123456,
      );
      expect(parseMoneyInput('', currency: 'USD', languageCode: 'en'), 0);
      expect(
        formatMoneyInput(1250, currency: 'USD', languageCode: 'en'),
        '12.50',
      );
    });

    test('input formatter groups digits and limits decimals', () {
      final formatter = MoneyTextInputFormatter(
        currency: 'USD',
        languageCode: 'en',
      );
      TextEditingValue type(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
      expect(type('1234567').text, '1,234,567');
      expect(type('1234.567').text, '1,234.56');
      final idr = MoneyTextInputFormatter(currency: 'IDR', languageCode: 'id');
      expect(
        idr
            .formatEditUpdate(
              TextEditingValue.empty,
              const TextEditingValue(text: '150000'),
            )
            .text,
        '150.000',
      );
    });

    test('old events without a currency load as rupiah', () {
      final json = CashbookSnapshot.demo().event.toJson()..remove('currency');
      expect(EventRecord.fromJson(json).currency, 'IDR');
    });
  });

  group('localisation', () {
    test('falls back to English, then to the source text', () {
      expect(L10n.lookup('Teks yang tidak ada', 'fr'), 'Teks yang tidak ada');
      L10n.code = 'id';
      expect(tr('Halo {name}', {'name': 'Ana'}), 'Halo Ana');
    });

    test('uses singular forms where the language has them', () {
      L10n.code = 'en';
      expect(
        tr('{count} peserta belum bayar', {'count': 1}),
        '1 participant has not paid yet',
      );
      expect(
        tr('{count} peserta belum bayar', {'count': 3}),
        contains('participants'),
      );
      L10n.code = 'ja';
      expect(
        tr('{count} peserta belum bayar', {'count': 1}),
        isNot(contains('participant ')),
      );
    });

    test('signed amounts stay one unit in right-to-left languages', () {
      final ar = formatSignedMoney(
        5000,
        outflow: false,
        currency: 'IDR',
        languageCode: 'ar',
      );
      expect(ar, startsWith('\u2066+'));
      expect(ar, endsWith('\u2069'));
      expect(
        formatSignedMoney(
          5000,
          outflow: true,
          currency: 'IDR',
          languageCode: 'id',
        ),
        '−Rp 5.000',
      );
    });

    test('resolves the phone language or English', () {
      expect(L10n.resolve('ms'), 'ms');
      expect(L10n.resolve('sw'), 'en');
      expect(L10n.resolve(null), 'en');
    });

    test('currency suggestion follows the phone region', () {
      expect(currencyForCountry('MY'), 'MYR');
      expect(currencyForCountry('FR'), 'EUR');
      expect(currencyForCountry('ZZ'), isNull);
    });
  });

  testWidgets(
    'settings opens from the event screen and switching language keeps it open',
    (tester) async {
      final settings = AppSettings();
      await tester.pumpWidget(
        WargakasApp(
          controller: CashbookController.forTesting(),
          settings: settings,
        ),
      );
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Pengaturan'), findsOneWidget);

      await settings.setLanguage('en');
      await tester.pumpAndSettle();
      expect(
        find.byType(SwitchListTile),
        findsWidgets,
        reason: 'still on settings',
      );
      expect(L10n.code, 'en');

      await settings.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    },
  );

  testWidgets('text size setting scales text on top of the phone setting', (
    tester,
  ) async {
    final settings = AppSettings();
    await settings.setTextScale(1.5);
    late double scale;
    await tester.pumpWidget(
      WargakasMaterialApp(
        settings: settings,
        home: Builder(
          builder: (context) {
            scale = MediaQuery.textScalerOf(context).scale(10) / 10;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(scale, closeTo(1.5, 0.01));
  });

  testWidgets('first-run welcome shows once and then the app', (tester) async {
    final settings = AppSettings();
    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        settings: settings,
        enableOnboarding: true,
      ),
    );
    expect(find.text('Selamat datang di Wargakas'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(settings.onboardingDone, isTrue);
    expect(find.text('Acara Saya'), findsOneWidget);
  });

  testWidgets('account deletion needs an explicit confirmation', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        onSignOut: () async {},
        accountRole: 'treasurer',
        onDeleteAccount: () async => deleted = true,
      ),
    );
    await tester.tap(find.byTooltip('Akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm-delete-account'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });

  testWidgets('treasurer can invite a committee member', (tester) async {
    String? invitedRole;
    await tester.pumpWidget(
      WargakasApp(
        controller: CashbookController.forTesting(),
        onInviteChairperson: (_) async {},
        onInviteMember: (email, role) async => invitedRole = role,
      ),
    );
    await tester.tap(find.byTooltip('Tambah ketua acara'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panitia'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'panitia@example.com');
    await tester.tap(find.text('Berikan akses'));
    await tester.pumpAndSettle();
    expect(invitedRole, 'committee');
  });

  group('participant share view', () {
    Map<String, dynamic> payload() {
      final demo = CashbookSnapshot.demo();
      final expense = demo.transactions.firstWhere(
        (t) => t.type == TransactionType.expense,
        orElse: () => demo.transactions.first,
      );
      return {
        'event': demo.event.toJson(),
        'participants': [
          for (final p in demo.participants)
            {...p.toJson(), 'phone': '+62 811 000'},
        ],
        'transactions': [
          for (final t in demo.transactions)
            {...t.toJson(), 'hasReceipt': t.id == expense.id},
        ],
        'updatedAt': '2026-11-01T10:00:00Z',
      };
    }

    testWidgets('shows balance, participants and transactions read-only', (
      tester,
    ) async {
      await tester.pumpWidget(
        SharedViewApp(token: 'x' * 64, loader: (_) async => payload()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wisata Dieng'), findsOneWidget);
      expect(find.text('Saldo kas sekarang'), findsOneWidget);
      expect(
        find.textContaining('+62'),
        findsNothing,
        reason: 'phones never shown',
      );
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('a revoked link shows guidance instead of crashing', (
      tester,
    ) async {
      await tester.pumpWidget(
        SharedViewApp(
          token: 'gone',
          loader: (_) async => throw StateError('share link not found'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tautan tidak dapat dibuka'), findsOneWidget);
    });
  });

  test('a replaced receipt photo is uploaded again', () async {
    final uploads = <String>[];
    final controller = CashbookController.forTesting(
      receiptUploader: (eventId, transactionId, path) async {
        uploads.add(path);
        return '$eventId/$transactionId.jpg';
      },
    );
    await controller.recordTransaction(
      type: TransactionType.expense,
      amount: 1000,
      description: 'Parkir',
      receiptPath: '/tmp/a.jpg',
    );
    await Future<void>.delayed(Duration.zero);
    final id = controller.transactions.last.id;
    expect(controller.transactions.last.receiptStoragePath, isNotNull);
    await controller.attachReceipt(id, localPath: '/tmp/b.jpg');
    expect(uploads, ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(controller.transactions.last.receiptPath, '/tmp/b.jpg');
    expect(controller.transactions.last.receiptStoragePath, isNotNull);
  });
}
