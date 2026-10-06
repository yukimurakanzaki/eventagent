import 'package:flutter/material.dart';

import 'cashbook_calculations.dart';
import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'report_service.dart';
import 'transaction_log.dart';

class TransactionLogPage extends StatefulWidget {
  const TransactionLogPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;

  @override
  State<TransactionLogPage> createState() => _TransactionLogPageState();
}

class _TransactionLogPageState extends State<TransactionLogPage> {
  TransactionFilter _filter = const TransactionFilter();
  bool _busy = false;

  Future<void> _pickRange() async {
    final event = widget.controller.event;
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _filter.from == null || _filter.to == null
          ? DateTimeRange(start: event.startDate, end: event.endDate)
          : DateTimeRange(start: _filter.from!, end: _filter.to!),
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked != null) {
      setState(
        () => _filter = _filter.copyWith(from: picked.start, to: picked.end),
      );
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await widget.shareGateway.sharePdf(
        CashbookReport(
          snapshot: widget.controller.snapshot,
          creatorRole: widget.creatorRole,
          generatedAt: DateTime.now(),
          kind: ReportKind.log,
          filter: _filter,
        ),
      );
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Salinan PDF tersimpan di: $saved')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF belum dapat dibuat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final ledger = buildLedger(controller.event, controller.transactions);
    final rows = filterLedger(ledger, _filter).reversed.toList();
    final summary = summarize(rows);
    final presentTypes = TransactionType.values.where(
      (type) => ledger.any((entry) => entry.transaction.type == type),
    );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat transaksi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Kategori', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final type in presentTypes)
                FilterChip(
                  label: Text(transactionTypeLabel(type)),
                  selected: _filter.types.contains(type),
                  onSelected: (on) => setState(
                    () => _filter = _filter.copyWith(
                      types: {
                        for (final t in _filter.types)
                          if (t != type) t,
                        if (on) type,
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    _filter.from == null || _filter.to == null
                        ? 'Semua tanggal'
                        : '${formatReportDate(_filter.from!)} - ${formatReportDate(_filter.to!)}',
                  ),
                ),
              ),
              if (!_filter.isEmpty)
                TextButton(
                  onPressed: () =>
                      setState(() => _filter = const TransactionFilter()),
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${summary.count} transaksi',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text('Pemasukan: ${formatReportRupiah(summary.inflow)}'),
                  Text('Pengeluaran: ${formatReportRupiah(summary.outflow)}'),
                  Text(
                    'Selisih: ${formatReportRupiah(summary.net)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_busy ? 'Menyiapkan...' : 'Ekspor hasil filter (PDF)'),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const ListTile(title: Text('Tidak ada transaksi pada filter ini.')),
          for (final entry in rows)
            _LogTile(
              entry: entry,
              participant: _participantOf(entry.transaction),
              onTap: () => _showDetail(entry),
            ),
        ],
      ),
    );
  }

  ParticipantRecord? _participantOf(TransactionRecord transaction) => widget
      .controller
      .participants
      .where((p) => p.id == transaction.participantId)
      .firstOrNull;

  void _showDetail(LedgerEntry entry) {
    final controller = widget.controller;
    final all = controller.transactions;
    final transaction = entry.transaction;
    final participant = _participantOf(transaction);
    final related = all
        .where((t) => t.id == transaction.relatedTransactionId)
        .firstOrNull;
    final correction = all
        .where(
          (t) =>
              t.type == TransactionType.correction &&
              t.relatedTransactionId == transaction.id,
        )
        .firstOrNull;
    final status = transaction.type == TransactionType.correction
        ? 'Koreksi: membatalkan transaksi lain'
        : correction != null
        ? 'Dikoreksi, tidak dihitung'
        : 'Dihitung dalam saldo';
    final lines = <(String, String)>[
      ('Kategori', transactionTypeLabel(transaction.type)),
      ('Nominal', formatReportRupiah(transaction.amount)),
      ('Tanggal', formatReportDateTime(transaction.createdAt)),
      ('Status', status),
      ('Saldo setelah', formatReportRupiah(entry.balanceAfter)),
      if (participant != null) ...[
        ('Peserta', participant.name),
        (
          'Total bayar peserta',
          formatReportRupiah(participantPaid(all, participant.id)),
        ),
        (
          'Total refund peserta',
          formatReportRupiah(refundTotalForParticipant(all, participant.id)),
        ),
        (
          'Status peserta',
          participant.state == ParticipantState.cancelled
              ? 'Dibatalkan - ${refundPolicyLabelForReport(participant.refundPolicy)}'
              : paymentStatus(
                  participantNetPaid(all, participant.id),
                  controller.contributionTarget,
                ),
        ),
      ],
      if (related != null)
        (
          'Membatalkan',
          '${related.description} (${formatReportRupiah(related.amount)}, ${formatReportDate(related.createdAt)})',
        ),
      if (correction != null)
        (
          'Dikoreksi pada',
          '${formatReportDate(correction.createdAt)}. Alasan: ${correction.description}',
        ),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final (label, value) in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(value),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.entry,
    required this.participant,
    required this.onTap,
  });

  final LedgerEntry entry;
  final ParticipantRecord? participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final transaction = entry.transaction;
    final outflow = isOutflow(transaction.type);
    final struck = entry.counted
        ? null
        : const TextStyle(decoration: TextDecoration.lineThrough);
    final subtitle = [
      transactionTypeLabel(transaction.type),
      if (participant != null) participant!.name,
      formatReportDate(transaction.createdAt),
      if (!entry.counted) 'tidak dihitung',
    ].join(' • ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(
        child: Icon(
          !entry.counted
              ? Icons.undo
              : outflow
              ? Icons.arrow_upward
              : Icons.arrow_downward,
        ),
      ),
      title: Text(transaction.description, style: struck),
      subtitle: Text(subtitle),
      trailing: Text(
        transaction.type == TransactionType.correction
            ? '-'
            : '${outflow ? '−' : '+'}${formatReportRupiah(transaction.amount)}',
        style: Theme.of(context).textTheme.titleSmall?.merge(struck),
      ),
      onTap: onTap,
    );
  }
}
