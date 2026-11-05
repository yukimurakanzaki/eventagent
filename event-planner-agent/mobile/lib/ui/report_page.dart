part of '../main.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    this.shareLinkService,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;

  /// Hosted builds only: creates the participant read-only link.
  final ShareLinkService? shareLinkService;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _busy = false;
  String? _error;
  bool _linkBusy = false;
  String? _link;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await shareLedgerCsv(widget.controller.snapshot);
    } catch (_) {
      _snack(tr('File CSV belum dapat dibuat atau dibagikan. Coba lagi.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ensureLink() async {
    final service = widget.shareLinkService;
    if (service == null) return null;
    try {
      final link = await service.createLink();
      if (mounted) setState(() => _link = link);
      return link;
    } catch (_) {
      _snack(tr('Tautan belum dapat dibuat. Periksa koneksi lalu coba lagi.'));
      return null;
    }
  }

  Future<void> _createAndCopyLink() async {
    if (_linkBusy) return;
    setState(() => _linkBusy = true);
    try {
      final link = await _ensureLink();
      if (link != null) {
        await copyTextToClipboard(link);
        _snack(tr('Tautan disalin.'));
      }
    } catch (_) {
      _snack(tr('Tautan belum dapat disalin. Coba lagi.'));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _shareLink() async {
    if (_linkBusy) return;
    setState(() => _linkBusy = true);
    try {
      final link = _link ?? await _ensureLink();
      if (link != null) {
        await SharePlus.instance.share(
          ShareParams(
            text: tr('Lihat laporan kas {name} di sini: {link}', {
              'name': widget.controller.event.name,
              'link': link,
            }),
          ),
        );
      }
    } catch (_) {
      _snack(tr('Tautan belum dapat dibagikan. Coba lagi.'));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _revokeLink() async {
    final service = widget.shareLinkService;
    if (service == null || _linkBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Matikan tautan?')),
        content: Text(
          tr(
            'Semua tautan yang sudah dibagikan tidak akan bisa dibuka lagi. Anda bisa membuat tautan baru kapan saja.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Matikan tautan')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _linkBusy = true);
    try {
      await service.revokeLinks();
      if (mounted) setState(() => _link = null);
      _snack(tr('Tautan dimatikan.'));
    } catch (_) {
      _snack(tr('Tautan belum dapat dimatikan. Coba lagi.'));
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Widget _shareLinkCard(ThemeData theme) {
    final service = widget.shareLinkService!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                tr('Tautan baca-saja untuk peserta'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Peserta bisa membuka tautan ini di browser tanpa akun. Selalu menampilkan data terbaru. Nomor telepon dan foto nota tidak ditampilkan.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_link != null) ...[
              const SizedBox(height: 8),
              SelectableText(_link!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _linkBusy ? null : _createAndCopyLink,
              icon: const Icon(Icons.link),
              label: Text(
                _linkBusy ? tr('Menyiapkan...') : tr('Buat / salin tautan'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _linkBusy ? null : _shareLink,
              icon: const Icon(Icons.share_outlined),
              label: Text(tr('Bagikan tautan')),
            ),
            if (service.canRevoke) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _linkBusy ? null : _revokeLink,
                icon: const Icon(Icons.link_off),
                label: Text(tr('Matikan tautan')),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
        OutlinedButton.icon(
          onPressed: _busy ? null : _exportCsv,
          icon: const Icon(Icons.table_chart_outlined),
          label: Text(tr('Ekspor CSV (Excel)')),
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
        if (widget.shareLinkService != null) ...[
          _shareLinkCard(theme),
          const SizedBox(height: 16),
        ],
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
              child: Text(
                participant.role == ParticipantRole.committee
                    ? '${participant.name} (${participantRoleLabel(ParticipantRole.committee)})'
                    : participant.name,
                style: theme.textTheme.bodyLarge,
              ),
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
