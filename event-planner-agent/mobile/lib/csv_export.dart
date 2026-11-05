import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'l10n/l10n.dart';
import 'labels.dart';
import 'money.dart';
import 'report_service.dart';
import 'transaction_log.dart';

const _csvBom = '﻿';

/// Quotes a cell per RFC 4180 and neutralises spreadsheet formulas.
String csvCell(String value, {bool numeric = false}) {
  var text = value;
  if (!numeric && text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(RegExp(r'[",\r\n]'))) {
    text = '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// Plain decimal in currency units with '.' separator, e.g. 12.50.
String csvAmount(int minorUnits, CurrencySpec spec) {
  final sign = minorUnits < 0 ? '-' : '';
  final absolute = minorUnits.abs();
  final whole = absolute ~/ spec.minorFactor;
  if (spec.decimals == 0) return '$sign$whole';
  final fraction = (absolute % spec.minorFactor).toString().padLeft(
    spec.decimals,
    '0',
  );
  return '$sign$whole.$fraction';
}

/// The whole ledger as CSV for Excel: UTF-8 BOM, CRLF rows.
String buildLedgerCsv(CashbookSnapshot snapshot) {
  final spec = currencySpec(snapshot.event.currency);
  final names = {for (final p in snapshot.participants) p.id: p.name};
  final ledger = buildLedger(snapshot.event, snapshot.transactions);
  final corrected = correctedTransactionIds(snapshot.transactions);
  final yes = tr('ya');
  final no = tr('tidak');
  final rows = <String>[
    [
      tr('Tanggal'),
      tr('Jenis'),
      tr('Kategori'),
      tr('Keterangan'),
      tr('Peserta'),
      tr('Nominal'),
      tr('Mata uang'),
      tr('Dibatalkan'),
      tr('Nota'),
      tr('Saldo'),
    ].map(csvCell).join(','),
  ];
  for (final entry in ledger) {
    final t = entry.transaction;
    final isExpense = t.type == TransactionType.expense;
    rows.add(
      [
        csvCell(formatCsvDate(t.createdAt)),
        csvCell(transactionTypeLabel(t.type)),
        csvCell(
          isExpense
              ? expenseCategoryLabel(t.category ?? ExpenseCategory.other)
              : '',
        ),
        csvCell(t.description),
        csvCell(names[t.participantId] ?? ''),
        csvCell(csvAmount(t.amount, spec), numeric: true),
        csvCell(spec.code),
        csvCell(corrected.contains(t.id) ? yes : no),
        csvCell(isExpense ? (t.hasReceipt ? yes : no) : ''),
        csvCell(csvAmount(entry.balanceAfter, spec), numeric: true),
      ].join(','),
    );
  }
  return '$_csvBom${rows.join('\r\n')}\r\n';
}

String formatCsvDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// Writes the ledger CSV to the temp folder and opens the share sheet.
Future<void> shareLedgerCsv(CashbookSnapshot snapshot) async {
  final directory = await getTemporaryDirectory();
  final slug = snapshot.event.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final file = File(
    '${directory.path}/wargakas-${slug.isEmpty ? 'laporan' : slug}.csv',
  );
  await file.writeAsString(buildLedgerCsv(snapshot), flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: tr('Laporan Wargakas - {name}', {'name': snapshot.event.name}),
    ),
  );
}

Future<void> copyTextToClipboard(String text) =>
    Clipboard.setData(ClipboardData(text: text));
