import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/csv_export.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/money.dart';
import 'package:wargakas_mobile/report_service.dart';
import 'package:wargakas_mobile/share_link.dart';

class _Gateway implements ReportShareGateway {
  @override
  Future<String?> sharePdf(CashbookReport report) async => null;
  @override
  Future<void> shareWhatsAppText(CashbookReport report) async {}
}

class _FakeLinks implements ShareLinkService {
  _FakeLinks({this.canRevoke = true});
  int created = 0;
  int revoked = 0;
  @override
  final bool canRevoke;
  @override
  Future<String> createLink() async {
    created++;
    return 'https://example.test/?share=abc';
  }

  @override
  Future<void> revokeLinks() async => revoked++;
}

EventRecord _event(String currency) => EventRecord(
  id: 'e',
  name: 'Trip',
  currency: currency,
  startDate: DateTime(2026, 1, 1),
  endDate: DateTime(2026, 1, 3),
  participantCapacity: 5,
  finalBudget: 0,
  sponsorName: 'S',
  sponsorContribution: 0,
  openingBalance: 0,
);

void main() {
  tearDown(() => Money.currency = defaultCurrencyCode);

  test('CSV: BOM, quoting, injection and USD cents', () {
    final snapshot = CashbookSnapshot.demo().copyWith(
      event: _event('USD'),
      participants: const [ParticipantRecord(id: 'p', name: '=Evil, "Bob"')],
      transactions: [
        TransactionRecord(
          id: 't1',
          type: TransactionType.expense,
          amount: 1250,
          description: '=HYPERLINK("x")\nline2',
          createdAt: DateTime(2026, 1, 2),
          participantId: 'p',
          category: ExpenseCategory.food,
        ),
        TransactionRecord(
          id: 't2',
          type: TransactionType.participantPayment,
          amount: 5,
          description: '+cash',
          createdAt: DateTime(2026, 1, 1),
          participantId: 'p',
        ),
      ],
    );
    final csv = buildLedgerCsv(snapshot);
    expect(csv.startsWith('﻿'), isTrue);
    expect(csv, contains('"\'=HYPERLINK(""x"")\nline2"'));
    expect(csv, contains('"\'=Evil, ""Bob"""'));
    expect(csv, contains(',12.50,USD,'));
    expect(csv, contains(',0.05,USD,'));
    expect(csv, contains("'+cash"));
    // Running balance after payment 0.05 then expense -12.50 = -12.45.
    expect(csv, contains('-12.45'));
    expect(csv, isNot(contains("'-12.45")));
  });

  test('CSV: whole-unit currency has no decimals', () {
    expect(csvAmount(1500000, currencySpec('IDR')), '1500000');
    expect(csvAmount(-5, currencySpec('USD')), '-0.05');
  });

  test('report text has category, receipt gap and committee mark', () {
    final base = CashbookSnapshot.demo();
    final snapshot = base.copyWith(
      participants: [
        ParticipantRecord(
          id: 'c',
          name: 'Budi',
          role: ParticipantRole.committee,
          phone: '0899000111222',
        ),
        ...base.participants,
      ],
      transactions: [
        ...base.transactions,
        TransactionRecord(
          id: 'x1',
          type: TransactionType.expense,
          amount: 50000,
          description: 'Bensin',
          createdAt: DateTime(2026, 9, 6),
          category: ExpenseCategory.transport,
        ),
        TransactionRecord(
          id: 'x2',
          type: TransactionType.expense,
          amount: 20000,
          description: 'Snack',
          createdAt: DateTime(2026, 9, 6),
          category: ExpenseCategory.food,
          receiptPath: '/tmp/r.jpg',
        ),
      ],
    );
    final text = CashbookReport(
      snapshot: snapshot,
      creatorRole: 'treasurer',
      generatedAt: DateTime(2026, 9, 7),
    ).whatsappText;
    expect(text, contains('Pengeluaran per kategori'));
    expect(text, contains('Transportasi'));
    expect(text, contains('tanpa nota'));
    expect(text, contains('ada nota'));
    expect(text, contains('Budi (Panitia)'));
    expect(text, isNot(contains('0899000111222')));
  });

  Future<void> pump(WidgetTester tester, ShareLinkService? links) async {
    await tester.binding.setSurfaceSize(const Size(500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: wargakasTheme(),
        home: Scaffold(
          body: ReportPage(
            controller: CashbookController.forTesting(),
            creatorRole: 'treasurer',
            shareGateway: _Gateway(),
            shareLinkService: links,
          ),
        ),
      ),
    );
  }

  testWidgets('share card hidden without a service', (tester) async {
    await pump(tester, null);
    expect(find.text('Tautan baca-saja untuk peserta'), findsNothing);
    expect(find.text('Ekspor CSV (Excel)'), findsOneWidget);
  });

  testWidgets('share card creates and revokes link', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final links = _FakeLinks();
    await pump(tester, links);
    expect(find.text('Tautan baca-saja untuk peserta'), findsOneWidget);
    await tester.tap(find.text('Buat / salin tautan'));
    await tester.pumpAndSettle();
    expect(links.created, 1);
    expect(clipboard, 'https://example.test/?share=abc');
    expect(find.text('https://example.test/?share=abc'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Matikan tautan'));
    await tester.tap(find.text('Matikan tautan'));
    await tester.pumpAndSettle();
    expect(links.revoked, 0);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Matikan tautan'),
      ),
    );
    await tester.pumpAndSettle();
    expect(links.revoked, 1);
    expect(find.text('https://example.test/?share=abc'), findsNothing);
  });

  testWidgets('revoke hidden when not allowed', (tester) async {
    await pump(tester, _FakeLinks(canRevoke: false));
    expect(find.text('Matikan tautan'), findsNothing);
  });
}
