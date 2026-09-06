import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';

class CashbookReport {
  const CashbookReport({
    required this.snapshot,
    required this.creatorRole,
    required this.generatedAt,
  });

  final CashbookSnapshot snapshot;
  final String creatorRole;
  final DateTime generatedAt;

  int get participantIncome => snapshot.transactions
      .where((item) => item.type == TransactionType.participantPayment)
      .fold(0, (sum, item) => sum + item.amount);
  int get sponsorIncome => snapshot.event.sponsorContribution;
  int get additionalIncome => snapshot.transactions
      .where((item) => item.type == TransactionType.additionalContribution)
      .fold(0, (sum, item) => sum + item.amount);
  int get refunds => snapshot.transactions
      .where((item) => item.type == TransactionType.refund)
      .fold(0, (sum, item) => sum + item.amount);
  int get expenses => expenseTotal(snapshot.transactions);
  int get endingBalance => currentBalance(
    snapshot.event,
    snapshot.transactions,
  );

  String get whatsappText {
    final event = snapshot.event;
    final buffer = StringBuffer()
      ..writeln('*Laporan Wargakas - ${sanitizeReportText(event.name)}*')
      ..writeln('${formatReportDate(event.startDate)} - ${formatReportDate(event.endDate)}')
      ..writeln()
      ..writeln('Saldo awal: ${formatReportRupiah(event.openingBalance)}')
      ..writeln('Sponsor: ${formatReportRupiah(sponsorIncome)}')
      ..writeln('Pembayaran peserta: ${formatReportRupiah(participantIncome)}')
      ..writeln('Iuran tambahan: ${formatReportRupiah(additionalIncome)}')
      ..writeln('Refund dan pengeluaran: ${formatReportRupiah(expenses)}')
      ..writeln('*Saldo akhir: ${formatReportRupiah(endingBalance)}*')
      ..writeln()
      ..writeln('*Status peserta*');
    for (final participant in snapshot.participants) {
      final paid = participantPaid(snapshot.transactions, participant.id);
      final status = participant.state == ParticipantState.cancelled
          ? 'Dibatalkan - ${refundPolicyLabelForReport(participant.refundPolicy)}'
          : paymentStatus(paid, participantTarget(event));
      buffer.writeln(
        '- ${sanitizeReportText(participant.name)}: $status, ${formatReportRupiah(paid)}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Dibuat oleh: ${reportRoleLabel(creatorRole)}')
      ..writeln('Dibuat: ${formatReportDateTime(generatedAt)}')
      ..writeln()
      ..writeln(
        'Privasi: jangan teruskan nomor rekening, kredensial, nomor telepon, atau dokumen identitas.',
      );
    return buffer.toString().trimRight();
  }

  Future<Uint8List> buildPdf() async {
    final document = pw.Document(
      title: 'Laporan Wargakas - ${snapshot.event.name}',
      author: reportRoleLabel(creatorRole),
    );
    final event = snapshot.event;
    final participantRows = snapshot.participants.map((participant) {
      final paid = participantPaid(snapshot.transactions, participant.id);
      final status = participant.state == ParticipantState.cancelled
          ? 'Dibatalkan - ${refundPolicyLabelForReport(participant.refundPolicy)}'
          : paymentStatus(paid, participantTarget(event));
      return [
        sanitizeReportText(participant.name),
        status,
        formatReportRupiah(paid),
      ];
    }).toList();
    final transactionRows = snapshot.transactions.map((transaction) {
      return [
        formatReportDate(transaction.createdAt),
        transactionTypeLabel(transaction.type),
        sanitizeReportText(transaction.description),
        formatReportRupiah(transaction.amount),
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(26),
        ),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.teal700, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'WARGAKAS',
                style: pw.TextStyle(
                  color: PdfColors.teal800,
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text('Laporan kas acara'),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dibuat ${formatReportDateTime(generatedAt)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            sanitizeReportText(event.name),
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periode ${formatReportDate(event.startDate)} - ${formatReportDate(event.endDate)}',
          ),
          pw.Text('Dibuat oleh ${reportRoleLabel(creatorRole)}'),
          pw.SizedBox(height: 12),
          _reportSectionTitle('Ringkasan'),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            headers: const ['Komponen', 'Nilai'],
            data: [
              ['Saldo awal', formatReportRupiah(event.openingBalance)],
              ['Sponsor', formatReportRupiah(sponsorIncome)],
              ['Pembayaran peserta', formatReportRupiah(participantIncome)],
              ['Iuran tambahan', formatReportRupiah(additionalIncome)],
              ['Refund dan pengeluaran', formatReportRupiah(expenses)],
              ['Saldo akhir', formatReportRupiah(endingBalance)],
            ],
          ),
          pw.SizedBox(height: 12),
          _reportSectionTitle('Peserta'),
          if (participantRows.isEmpty)
            pw.Text('Belum ada peserta.')
          else
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              headers: const ['Nama', 'Status', 'Dibayar'],
              data: participantRows,
            ),
          pw.SizedBox(height: 12),
          _reportSectionTitle('Transaksi'),
          if (transactionRows.isEmpty)
            pw.Text('Belum ada transaksi.')
          else
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              headers: const ['Tanggal', 'Jenis', 'Keterangan', 'Nominal'],
              data: transactionRows,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1.3),
                2: const pw.FlexColumnWidth(2.5),
                3: const pw.FlexColumnWidth(1.4),
              },
            ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey200,
            child: pw.Text(
              'Privasi: laporan ini tidak memuat nomor rekening, kredensial, nomor telepon, token, atau dokumen identitas. Periksa penerima sebelum membagikan laporan.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }
}

abstract interface class ReportShareGateway {
  Future<void> sharePdf(CashbookReport report);
  Future<void> shareWhatsAppText(CashbookReport report);
}

class PlatformReportShareGateway implements ReportShareGateway {
  const PlatformReportShareGateway();

  @override
  Future<void> sharePdf(CashbookReport report) async {
    final bytes = await report.buildPdf();
    final directory = await getTemporaryDirectory();
    final slug = report.snapshot.event.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final file = File('${directory.path}/wargakas-${slug.isEmpty ? 'laporan' : slug}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Laporan Wargakas - ${report.snapshot.event.name}',
      ),
    );
  }

  @override
  Future<void> shareWhatsAppText(CashbookReport report) async {
    await SharePlus.instance.share(ShareParams(text: report.whatsappText));
  }
}

pw.Widget _reportSectionTitle(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 7),
  child: pw.Text(
    title,
    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
  ),
);

String reportRoleLabel(String role) => switch (role) {
  'treasurer' => 'Bendahara',
  'chairperson' => 'Ketua acara',
  _ => 'Pengguna Wargakas',
};

String transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.participantPayment => 'Pembayaran peserta',
  TransactionType.sponsor => 'Sponsor',
  TransactionType.additionalContribution => 'Iuran tambahan',
  TransactionType.expense => 'Pengeluaran',
  TransactionType.refund => 'Refund',
  TransactionType.refundReversal => 'Koreksi refund',
};

String refundPolicyLabelForReport(RefundPolicy policy) => switch (policy) {
  RefundPolicy.none => 'tanpa refund',
  RefundPolicy.partial => 'refund sebagian',
  RefundPolicy.full => 'refund penuh',
  RefundPolicy.undecided => 'refund belum diputuskan',
};

String sanitizeReportText(String value) {
  var sanitized = value.trim();
  sanitized = sanitized.replaceAll(
    RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
    '[email disembunyikan]',
  );
  sanitized = sanitized.replaceAll(
    RegExp(r'(?<!\d)\+?\d[\d\s-]{7,}\d(?!\d)'),
    '[nomor disembunyikan]',
  );
  sanitized = sanitized.replaceAll(
    RegExp(
      r'(password|kata\s+sandi|token|api\s*key)\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    '[kredensial disembunyikan]',
  );
  return sanitized;
}

String formatReportRupiah(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${value < 0 ? '-' : ''}Rp $grouped';
}

String formatReportDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String formatReportDateTime(DateTime value) =>
    '${formatReportDate(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
