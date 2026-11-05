import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'formatting.dart';
import 'l10n/l10n.dart';
import 'report_service.dart';
import 'transaction_log.dart';

String filterLabel(TransactionFilter filter) {
  final range = filter.from == null && filter.to == null
      ? tr('Semua tanggal')
      : '${filter.from == null ? '...' : formatReportDate(filter.from!)} - ${filter.to == null ? '...' : formatReportDate(filter.to!)}';
  final types = filter.types.isEmpty
      ? tr('Semua kategori')
      : filter.types.map(transactionTypeLabel).join(', ');
  return '$types, $range';
}

String _monthLabel(String key) {
  final parts = key.split('-');
  return formatMonthYear(DateTime(int.parse(parts[0]), int.parse(parts[1])));
}

pw.Widget _table(
  List<String> headers,
  List<List<String>> data, [
  Map<int, pw.TableColumnWidth>? columnWidths,
]) => pw.TableHelper.fromTextArray(
  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal50),
  headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
  cellStyle: const pw.TextStyle(fontSize: 10),
  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  headers: headers,
  data: data,
  columnWidths: columnWidths,
);

pw.Widget _section(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
  ),
);

/// Transaction-log PDF (filtered) or whole-event portfolio PDF, chosen by
/// [CashbookReport.kind]. Running balances always use the full history.
Future<Uint8List> buildLedgerPdf(CashbookReport report) {
  final portfolio = report.kind == ReportKind.portfolio;
  final snapshot = report.snapshot;
  final event = snapshot.event;
  final ledger = buildLedger(event, snapshot.transactions);
  final rows = portfolio ? ledger : filterLedger(ledger, report.filter);
  final summary = summarize(rows);
  final names = {for (final p in snapshot.participants) p.id: p.name};
  final byId = {for (final t in snapshot.transactions) t.id: t};
  final title = portfolio ? tr('Portofolio acara') : tr('Riwayat transaksi');
  final document = pw.Document(
    title: '$title - ${event.name}',
    author: reportRoleLabel(report.creatorRole),
  );

  String detail(TransactionRecord t) => [
    sanitizeReportText(t.description),
    if (names[t.participantId] != null)
      sanitizeReportText(names[t.participantId]!),
    if (t.type == TransactionType.correction)
      tr('membatalkan {name}', {
        'name': sanitizeReportText(
          byId[t.relatedTransactionId]?.description ?? tr('transaksi'),
        ),
      }),
  ].join(' - ');

  final ledgerTable = rows.isEmpty
      ? pw.Text(tr('Tidak ada transaksi pada filter ini.'))
      : _table(
          [
            tr('Tanggal'),
            tr('Kategori'),
            tr('Keterangan'),
            tr('Nominal'),
            tr('Saldo'),
          ],
          [
            for (final entry in rows)
              [
                formatReportDate(entry.transaction.createdAt),
                transactionTypeLabel(entry.transaction.type),
                detail(entry.transaction),
                entry.counted
                    ? '${isOutflow(entry.transaction.type) ? '-' : ''}${formatReportRupiah(entry.transaction.amount)}'
                    : tr('({amount}) tidak dihitung', {
                        'amount': formatReportRupiah(entry.transaction.amount),
                      }),
                formatReportRupiah(entry.balanceAfter),
              ],
          ],
          {
            0: const pw.FlexColumnWidth(1.1),
            1: const pw.FlexColumnWidth(1.3),
            2: const pw.FlexColumnWidth(2.6),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.4),
          },
        );

  final byType = [
    for (final type in TransactionType.values)
      if (summary.byType[type] != null)
        [transactionTypeLabel(type), formatReportRupiah(summary.byType[type]!)],
  ];
  final months = monthlyTotals(rows);
  final participantRows = [
    for (final p in snapshot.participants)
      () {
        final paid = participantPaid(snapshot.transactions, p.id);
        final refunds = refundTotalForParticipant(snapshot.transactions, p.id);
        return [
          sanitizeReportText(p.name),
          p.state == ParticipantState.cancelled
              ? tr('Dibatalkan - {policy}', {
                  'policy': refundPolicyLabelForReport(p.refundPolicy),
                })
              : paymentStatus(paid - refunds, report.target),
          formatReportRupiah(paid),
          formatReportRupiah(refunds),
          formatReportRupiah(paid - refunds),
        ];
      }(),
  ];

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
            pw.Text(title),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            tr('Dibuat {date} oleh {role}', {
              'date': formatReportDateTime(report.generatedAt),
              'role': reportRoleLabel(report.creatorRole),
            }),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            tr('Halaman {page} dari {pages}', {
              'page': context.pageNumber,
              'pages': context.pagesCount,
            }),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Text(
          sanitizeReportText(event.name),
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          tr('Periode {start} - {end}', {
            'start': formatReportDate(event.startDate),
            'end': formatReportDate(event.endDate),
          }),
        ),
        if (!portfolio)
          pw.Text(
            tr('Filter: {filter}', {'filter': filterLabel(report.filter)}),
          ),
        _section(portfolio ? tr('Ikhtisar keuangan') : tr('Ringkasan filter')),
        _table(
          [tr('Komponen'), tr('Nilai')],
          [
            if (portfolio) ...[
              [tr('Anggaran final'), formatReportRupiah(event.finalBudget)],
              [tr('Saldo awal'), formatReportRupiah(event.openingBalance)],
              [
                tr('Sponsor ({name})', {
                  'name': sanitizeReportText(event.sponsorName),
                }),
                formatReportRupiah(event.sponsorContribution),
              ],
              [
                tr('Peserta aktif'),
                tr('{active} dari {capacity}', {
                  'active': activeParticipantCount(snapshot.participants),
                  'capacity': event.participantCapacity,
                }),
              ],
              [tr('Target per peserta'), formatReportRupiah(report.target)],
            ],
            [tr('Jumlah transaksi'), '${summary.count}'],
            [tr('Total pemasukan'), formatReportRupiah(summary.inflow)],
            [tr('Total pengeluaran'), formatReportRupiah(summary.outflow)],
            [tr('Selisih'), formatReportRupiah(summary.net)],
            if (portfolio)
              [tr('Saldo akhir'), formatReportRupiah(report.endingBalance)],
          ],
        ),
        if (byType.isNotEmpty) ...[
          _section(tr('Per kategori')),
          _table([tr('Kategori'), tr('Total')], byType),
        ],
        if (portfolio && months.isNotEmpty) ...[
          _section(tr('Arus kas per bulan')),
          _table(
            [tr('Bulan'), tr('Pemasukan'), tr('Pengeluaran'), tr('Selisih')],
            [
              for (final m in months.entries)
                [
                  _monthLabel(m.key),
                  formatReportRupiah(m.value.inflow),
                  formatReportRupiah(m.value.outflow),
                  formatReportRupiah(m.value.inflow - m.value.outflow),
                ],
            ],
          ),
        ],
        if (portfolio) ...[
          _section(tr('Peserta')),
          if (participantRows.isEmpty)
            pw.Text(tr('Belum ada peserta.'))
          else
            _table([
              tr('Nama'),
              tr('Status'),
              tr('Bayar'),
              tr('Refund'),
              tr('Bersih'),
            ], participantRows),
        ],
        _section(portfolio ? tr('Buku kas lengkap') : tr('Daftar transaksi')),
        ledgerTable,
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          color: PdfColors.grey200,
          child: pw.Text(
            tr(
              'Privasi: laporan ini tidak memuat nomor rekening, kredensial, nomor telepon, token, atau dokumen identitas. Saldo pada daftar dihitung dari seluruh riwayat, bukan hanya baris yang difilter. Periksa penerima sebelum membagikan.',
            ),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
  return document.save();
}
