import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'formatting.dart';
import 'l10n/l10n.dart';
import 'labels.dart';
import 'money.dart';
import 'pdf_fonts.dart';
import 'ledger_pdf.dart';
import 'transaction_log.dart';

enum ReportKind { summary, log, portfolio }

class CashbookReport {
  const CashbookReport({
    required this.snapshot,
    required this.creatorRole,
    required this.generatedAt,
    this.kind = ReportKind.summary,
    this.filter = const TransactionFilter(),
  });

  /// [filter] only applies to [ReportKind.log].
  final ReportKind kind;
  final TransactionFilter filter;

  final CashbookSnapshot snapshot;
  final String creatorRole;
  final DateTime generatedAt;

  int get participantIncome =>
      effectiveTransactions(snapshot.transactions)
          .where((item) => item.type == TransactionType.participantPayment)
          .fold(0, (sum, item) => sum + item.amount);
  int get sponsorIncome => snapshot.event.sponsorContribution;
  int get additionalIncome =>
      effectiveTransactions(snapshot.transactions)
          .where((item) => item.type == TransactionType.additionalContribution)
          .fold(0, (sum, item) => sum + item.amount);
  int get expenses => expenseTotal(snapshot.transactions);
  int get target => participantTarget(
    snapshot.event,
    activeParticipantCount(snapshot.participants),
  );
  int get endingBalance =>
      currentBalance(snapshot.event, snapshot.transactions);

  String get whatsappText {
    final event = snapshot.event;
    final buffer = StringBuffer()
      ..writeln(
        tr('*Laporan Wargakas - {name}*', {
          'name': sanitizeReportText(event.name),
        }),
      )
      ..writeln(
        '${formatReportDate(event.startDate)} - ${formatReportDate(event.endDate)}',
      )
      ..writeln()
      ..writeln(
        tr('Saldo awal: {amount}', {
          'amount': formatReportRupiah(event.openingBalance),
        }),
      )
      ..writeln(
        tr('Sponsor: {amount}', {'amount': formatReportRupiah(sponsorIncome)}),
      )
      ..writeln(
        tr('Pembayaran peserta: {amount}', {
          'amount': formatReportRupiah(participantIncome),
        }),
      )
      ..writeln(
        tr('Iuran tambahan: {amount}', {
          'amount': formatReportRupiah(additionalIncome),
        }),
      )
      ..writeln(
        tr('Refund dan pengeluaran: {amount}', {
          'amount': formatReportRupiah(expenses),
        }),
      )
      ..writeln(
        tr('*Saldo akhir: {amount}*', {
          'amount': formatReportRupiah(endingBalance),
        }),
      )
      ..writeln()
      ..writeln(tr('*Status peserta*'));
    for (final participant in snapshot.participants) {
      final grossPaid = participantPaid(snapshot.transactions, participant.id);
      final refunds = refundTotalForParticipant(
        snapshot.transactions,
        participant.id,
      );
      final netPaid = grossPaid - refunds;
      final status = participant.state == ParticipantState.cancelled
          ? tr('Dibatalkan - {policy}', {
              'policy': refundPolicyLabelForReport(participant.refundPolicy),
            })
          : paymentStatus(netPaid, target);
      final breakdown = refunds == 0
          ? ''
          : ' ${tr('(bayar {paid}, refund {refund})', {'paid': formatReportRupiah(grossPaid), 'refund': formatReportRupiah(refunds)})}';
      buffer.writeln(
        '- ${participantReportName(participant)}: $status, ${formatReportRupiah(netPaid)}$breakdown',
      );
    }
    final corrected = correctedTransactionIds(snapshot.transactions);
    final categoryTotals = expenseTotalsByCategory(
      snapshot.transactions,
      corrected,
    );
    if (categoryTotals.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('*${tr('Pengeluaran per kategori')}*');
      for (final (category, total) in categoryTotals) {
        buffer.writeln(
          '- ${expenseCategoryLabel(category)}: ${formatReportRupiah(total)}',
        );
      }
    }
    final expenseLines = snapshot.transactions
        .where(
          (item) =>
              item.type == TransactionType.expense &&
              !corrected.contains(item.id),
        )
        .toList();
    if (expenseLines.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('*${tr('Rincian pengeluaran')}*');
      for (final item in expenseLines) {
        buffer.writeln(
          '- ${formatReportDate(item.createdAt)} ${expenseDetailText(item)}: ${formatReportRupiah(item.amount)}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln(
        tr('Dibuat oleh: {role}', {'role': reportRoleLabel(creatorRole)}),
      )
      ..writeln(
        tr('Dibuat: {date}', {'date': formatReportDateTime(generatedAt)}),
      )
      ..writeln()
      ..writeln(
        tr(
          'Privasi: jangan teruskan nomor rekening, kredensial, nomor telepon, atau dokumen identitas.',
        ),
      );
    return buffer.toString().trimRight();
  }

  String _describe(String? transactionId) =>
      snapshot.transactions
          .where((item) => item.id == transactionId)
          .firstOrNull
          ?.description ??
      tr('transaksi');

  Future<Uint8List> buildPdf() async {
    if (kind != ReportKind.summary) return buildLedgerPdf(this);
    final theme = await loadPdfTheme();
    final document = pw.Document(
      title: tr('Laporan Wargakas - {name}', {'name': snapshot.event.name}),
      author: reportRoleLabel(creatorRole),
      theme: theme,
    );
    final event = snapshot.event;
    final participantRows = snapshot.participants.map((participant) {
      final grossPaid = participantPaid(snapshot.transactions, participant.id);
      final refunds = refundTotalForParticipant(
        snapshot.transactions,
        participant.id,
      );
      final netPaid = grossPaid - refunds;
      final status = participant.state == ParticipantState.cancelled
          ? tr('Dibatalkan - {policy}', {
              'policy': refundPolicyLabelForReport(participant.refundPolicy),
            })
          : paymentStatus(netPaid, target);
      return [
        participantReportName(participant),
        status,
        refunds == 0
            ? formatReportRupiah(netPaid)
            : tr('{net}\nBayar {paid} • Refund {refund}', {
                'net': formatReportRupiah(netPaid),
                'paid': formatReportRupiah(grossPaid),
                'refund': formatReportRupiah(refunds),
              }),
      ];
    }).toList();
    final corrected = correctedTransactionIds(snapshot.transactions);
    final categoryTotals = expenseTotalsByCategory(
      snapshot.transactions,
      corrected,
    );
    final transactionRows = snapshot.transactions.map((transaction) {
      final voided =
          corrected.contains(transaction.id) ||
          transaction.type == TransactionType.correction;
      return [
        formatReportDate(transaction.createdAt),
        transactionTypeLabel(transaction.type),
        transaction.type == TransactionType.correction
            ? tr('Membatalkan {name}. Alasan: {reason}', {
                'name': sanitizeReportText(
                  _describe(transaction.relatedTransactionId),
                ),
                'reason': sanitizeReportText(transaction.description),
              })
            : '${transaction.type == TransactionType.expense ? expenseDetailText(transaction) : sanitizeReportText(transaction.description)}${corrected.contains(transaction.id) ? ' ${tr('(dikoreksi)')}' : ''}',
        voided
            ? tr('({amount}) tidak dihitung', {
                'amount': formatReportRupiah(transaction.amount),
              })
            : formatReportRupiah(transaction.amount),
      ];
    }).toList();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(26),
          theme: theme,
          textDirection: pdfTextDirection,
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
              pw.Text(tr('Laporan kas acara')),
            ],
          ),
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              tr('Dibuat {date}', {'date': formatReportDateTime(generatedAt)}),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Text(
              tr('Halaman {page} dari {pages}', {
                'page': context.pageNumber,
                'pages': context.pagesCount,
              }),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
            tr('Periode {start} - {end}', {
              'start': formatReportDate(event.startDate),
              'end': formatReportDate(event.endDate),
            }),
          ),
          pw.Text(
            tr('Dibuat oleh {role}', {'role': reportRoleLabel(creatorRole)}),
          ),
          pw.SizedBox(height: 12),
          _reportSectionTitle(tr('Ringkasan')),
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
            headerStyle: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            headers: [tr('Komponen'), tr('Nilai')],
            data: [
              [tr('Saldo awal'), formatReportRupiah(event.openingBalance)],
              [tr('Sponsor'), formatReportRupiah(sponsorIncome)],
              [tr('Pembayaran peserta'), formatReportRupiah(participantIncome)],
              [tr('Iuran tambahan'), formatReportRupiah(additionalIncome)],
              [tr('Refund dan pengeluaran'), formatReportRupiah(expenses)],
              [tr('Saldo akhir'), formatReportRupiah(endingBalance)],
            ],
          ),
          pw.SizedBox(height: 12),
          _reportSectionTitle(tr('Peserta')),
          if (participantRows.isEmpty)
            pw.Text(tr('Belum ada peserta.'))
          else
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
              headerStyle: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              headers: [tr('Nama'), tr('Status'), tr('Dibayar')],
              data: participantRows,
            ),
          if (categoryTotals.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _reportSectionTitle(tr('Pengeluaran per kategori')),
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
              headerStyle: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              headers: [tr('Kategori'), tr('Total')],
              data: [
                for (final (category, total) in categoryTotals)
                  [expenseCategoryLabel(category), formatReportRupiah(total)],
              ],
            ),
          ],
          pw.SizedBox(height: 12),
          _reportSectionTitle(tr('Transaksi')),
          if (transactionRows.isEmpty)
            pw.Text(tr('Belum ada transaksi.'))
          else
            pw.TableHelper.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
              headerStyle: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 11),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
              headers: [
                tr('Tanggal'),
                tr('Jenis'),
                tr('Keterangan'),
                tr('Nominal'),
              ],
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
              tr(
                'Privasi: laporan ini tidak memuat nomor rekening, kredensial, nomor telepon, token, atau dokumen identitas. Periksa penerima sebelum membagikan laporan.',
              ),
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }
}

abstract interface class ReportShareGateway {
  /// Returns the path of a saved copy, or null if none could be written.
  Future<String?> sharePdf(CashbookReport report);
  Future<void> shareWhatsAppText(CashbookReport report);
}

class PlatformReportShareGateway implements ReportShareGateway {
  const PlatformReportShareGateway();

  @override
  Future<String?> sharePdf(CashbookReport report) async {
    final bytes = await report.buildPdf();
    final slug = report.snapshot.event.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final name =
        'wargakas-${report.kind.name}-${slug.isEmpty ? 'laporan' : slug}.pdf';
    final subject = tr('Laporan Wargakas - {name}', {
      'name': report.snapshot.event.name,
    });
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, name: name, mimeType: 'application/pdf'),
          ],
          subject: subject,
        ),
      );
      return null;
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    // Android cannot tell us when the share sheet has no target apps, so
    // always keep a copy the user can reach without sharing.
    String? savedPath;
    try {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        savedPath = (await file.copy(
          '${external.path}/${file.uri.pathSegments.last}',
        )).path;
      }
    } catch (_) {}
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: subject,
      ),
    );
    return savedPath;
  }

  @override
  Future<void> shareWhatsAppText(CashbookReport report) async {
    // Copy first so the text can be pasted if no share target exists.
    await Clipboard.setData(ClipboardData(text: report.whatsappText));
    await SharePlus.instance.share(ShareParams(text: report.whatsappText));
  }
}

/// Participant name for reports; committee members are marked. Never
/// includes the phone number.
String participantReportName(ParticipantRecord participant) {
  final name = sanitizeReportText(participant.name);
  return participant.role == ParticipantRole.committee
      ? '$name (${participantRoleLabel(ParticipantRole.committee)})'
      : name;
}

/// Expense description with its category and whether a receipt exists.
String expenseDetailText(TransactionRecord transaction) {
  final category = expenseCategoryLabel(
    transaction.category ?? ExpenseCategory.other,
  );
  final receipt = transaction.hasReceipt ? tr('ada nota') : tr('tanpa nota');
  return '${sanitizeReportText(transaction.description)} [$category, $receipt]';
}

pw.Widget _reportSectionTitle(String title) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 7),
  child: pw.Text(
    title,
    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
  ),
);

String reportRoleLabel(String role) => switch (role) {
  'treasurer' => tr('Bendahara'),
  'chairperson' => tr('Ketua acara'),
  'committee' => tr('Panitia'),
  _ => tr('Pengguna Wargakas'),
};

String transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.participantPayment => tr('Pembayaran peserta'),
  TransactionType.sponsor => tr('Sponsor'),
  TransactionType.additionalContribution => tr('Iuran tambahan'),
  TransactionType.expense => tr('Pengeluaran'),
  TransactionType.refund => tr('Refund'),
  TransactionType.refundReversal => tr('Koreksi refund'),
  TransactionType.correction => tr('Koreksi'),
};

String refundPolicyLabelForReport(RefundPolicy policy) => switch (policy) {
  RefundPolicy.none => tr('tanpa refund'),
  RefundPolicy.partial => tr('refund sebagian'),
  RefundPolicy.full => tr('refund penuh'),
  RefundPolicy.undecided => tr('refund belum diputuskan'),
};

String sanitizeReportText(String value) {
  var sanitized = value.trim();
  sanitized = sanitized.replaceAll(
    RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'),
    tr('[email disembunyikan]'),
  );
  // ponytail: a rupiah amount is strictly 1-3 digits then .ddd groups; anything
  // else that long (accounts, phones, card numbers) gets redacted.
  final rupiahAmount = RegExp(r'^\d{1,3}(\.\d{3})+$');
  // ISO dates (2026-12-01) are not account numbers; the first alternative
  // consumes them so the long-digit-run alternative never sees them.
  sanitized = sanitized.replaceAllMapped(
    RegExp(r'(?<!\d)\d{4}-\d{2}-\d{2}(?!\d)|(?<!\d)\+?\d[\d\s.-]{7,}\d(?!\d)'),
    (match) =>
        rupiahAmount.hasMatch(match[0]!) ||
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(match[0]!)
        ? match[0]!
        : tr('[nomor disembunyikan]'),
  );
  sanitized = sanitized.replaceAll(
    RegExp(
      r'(password|kata\s+sandi|token|api\s*key)\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    tr('[kredensial disembunyikan]'),
  );
  return sanitized;
}

String formatReportRupiah(int value) => formatMoney(value);

String formatReportDate(DateTime value) => formatDate(value);

String formatReportDateTime(DateTime value) => formatDateTime(value);
