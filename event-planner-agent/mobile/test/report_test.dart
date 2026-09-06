import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/report_service.dart';

void main() {
  test('builds accurate private report text and a valid PDF', () async {
    final snapshot = CashbookSnapshot.demo().copyWith(
      transactions: [
        ...CashbookSnapshot.demo().transactions,
        TransactionRecord(
          id: 'sensitive-description',
          type: TransactionType.expense,
          amount: 100000,
          description: 'Transfer ke 081234567890 token=secret-value',
          createdAt: DateTime(2026, 9, 6),
        ),
      ],
    );
    final report = CashbookReport(
      snapshot: snapshot,
      creatorRole: 'chairperson',
      generatedAt: DateTime(2026, 9, 6, 14, 30),
    );

    expect(report.whatsappText, contains('Wisata Dieng'));
    expect(report.whatsappText, contains('Ketua acara'));
    expect(report.whatsappText, contains('Saldo akhir'));
    expect(report.whatsappText, isNot(contains('081234567890')));
    expect(report.whatsappText, isNot(contains('secret-value')));

    final bytes = await report.buildPdf();
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final output = Directory('build/reports');
    await output.create(recursive: true);
    await File('${output.path}/wargakas-sample.pdf').writeAsBytes(bytes);
  });

  test('redacts email, phone/account-like numbers and credentials', () {
    final sanitized = sanitizeReportText(
      'user@example.com 123456789012 password=rahasia',
    );

    expect(sanitized, isNot(contains('user@example.com')));
    expect(sanitized, isNot(contains('123456789012')));
    expect(sanitized, isNot(contains('rahasia')));
  });
}
