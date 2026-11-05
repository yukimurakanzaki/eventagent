part of '../main.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _busy = false;
  String? _error;

  CashbookReport _report([ReportKind kind = ReportKind.summary]) =>
      CashbookReport(
        snapshot: widget.controller.snapshot,
        creatorRole: widget.creatorRole,
        generatedAt: DateTime.now(),
        kind: kind,
      );

  Future<void> _share({
    required bool pdf,
    ReportKind kind = ReportKind.summary,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = _report(kind);
      String? note;
      if (pdf) {
        final saved = await widget.shareGateway.sharePdf(report);
        if (saved != null) {
          note = tr('Salinan PDF tersimpan di: {path}', {'path': saved});
        }
      } else {
        await widget.shareGateway.shareWhatsAppText(report);
        note = tr(
          'Teks laporan disalin. Jika WhatsApp tidak muncul, tempel manual.',
        );
      }
      if (note != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(note)));
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = pdf
              ? tr('PDF belum dapat dibuat atau dibagikan. Coba lagi.')
              : tr('Pesan belum dapat dibagikan. Coba lagi.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final report = _report();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Semantics(
          header: true,
          child: Text(tr('Preview laporan'), style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'Periksa nama, status, transaksi, dan saldo sebelum membagikan laporan.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _share(pdf: true),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_busy ? tr('Menyiapkan...') : tr('Buat dan bagikan PDF')),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _share(pdf: false),
          icon: const Icon(Icons.chat_outlined),
          label: Text(tr('Bagikan pesan WhatsApp')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _share(pdf: true, kind: ReportKind.portfolio),
          icon: const Icon(Icons.auto_stories_outlined),
          label: Text(tr('Portofolio acara lengkap (PDF)')),
        ),
        const SizedBox(height: 8),
        Text(
          tr('Periksa penerima sebelum mengirim.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.event.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  tr('Periode {range}', {
                    'range': formatDateRange(
                      controller.event.startDate,
                      controller.event.endDate,
                    ),
                  }),
                ),
                Text(
                  tr('Dibuat oleh: {role}', {
                    'role': reportRoleLabel(widget.creatorRole),
                  }),
                ),
                Text(
                  tr('Disusun {date}', {
                    'date': formatDateTime(report.generatedAt),
                  }),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                _ReportRow(
                  tr('Saldo awal'),
                  formatMoney(controller.event.openingBalance),
                ),
                _ReportRow(
                  tr('Pemasukan peserta'),
                  formatMoney(report.participantIncome),
                ),
                _ReportRow(
                  tr('Iuran tambahan'),
                  formatMoney(report.additionalIncome),
                ),
                _ReportRow(
                  tr('Refund dan pengeluaran'),
                  formatMoney(report.expenses),
                ),
                const Divider(height: 16),
                _ReportRow(
                  tr('Saldo akhir'),
                  formatMoney(controller.balance),
                  bold: true,
                ),
                const Divider(height: 24),
                Text(tr('Status peserta'), style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final participant in controller.participants)
                  _ReportParticipantRow(
                    participant: participant,
                    netPaid: participantNetPaid(
                      controller.transactions,
                      participant.id,
                    ),
                    target: controller.contributionTarget,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _LabelValueRow(
        label: label,
        value: value,
        labelStyle: style,
        valueStyle: style?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ReportParticipantRow extends StatelessWidget {
  const _ReportParticipantRow({
    required this.participant,
    required this.netPaid,
    required this.target,
  });

  final ParticipantRecord participant;
  final int netPaid;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = participant.state == ParticipantState.cancelled;
    final state = payState(netPaid, target);
    final remaining = target - netPaid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Text(participant.name, style: theme.textTheme.bodyLarge),
            ),
            if (cancelled)
              StatusPill(
                label: tr('Dibatalkan - {policy}', {
                  'policy': refundPolicyLabelForReport(
                    participant.refundPolicy,
                  ),
                }),
                icon: Icons.history,
                tone: theme.colorScheme.surfaceContainerHighest,
                onTone: theme.colorScheme.onSurfaceVariant,
              )
            else ...[
              PayStateChip(state),
              if (state != PayState.paid)
                Text(
                  tr('kurang {amount}', {'amount': formatMoney(remaining)}),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
