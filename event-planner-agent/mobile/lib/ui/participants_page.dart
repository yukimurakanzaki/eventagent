part of '../main.dart';

class ParticipantsPage extends StatelessWidget {
  const ParticipantsPage({
    required this.controller,
    this.filter,
    this.onFilterChanged,
    super.key,
  });

  final CashbookController controller;

  /// Pay-state filter for the active list; null shows everyone.
  final PayState? filter;
  final ValueChanged<PayState?>? onFilterChanged;

  PayState _stateOf(ParticipantRecord participant) => payState(
    participantNetPaid(controller.transactions, participant.id),
    controller.contributionTarget,
  );

  @override
  Widget build(BuildContext context) {
    final active = controller.participants
        .where((item) => item.state == ParticipantState.active)
        .toList();
    final cancelled = controller.participants
        .where((item) => item.state == ParticipantState.cancelled)
        .toList();
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    );
    final shown = filter == null
        ? active
        : active.where((item) => _stateOf(item) == filter).toList();
    int countOf(PayState? state) => switch (state) {
      null => active.length,
      PayState.paid => progress.paid,
      PayState.partial => progress.partial,
      PayState.unpaid => progress.unpaid,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: controller.isReadOnly
              ? null
              : () => showParticipantDialog(context, controller),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tambah peserta'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final state in <PayState?>[null, ...PayState.values])
              ChoiceChip(
                avatar: Icon(
                  filter == state
                      ? Icons.check
                      : state == null
                      ? Icons.groups_outlined
                      : PayStateChip.iconFor(state),
                ),
                label: Text(
                  '${state == null ? 'Semua' : PayStateChip.textFor(state)} (${countOf(state)})',
                ),
                selected: filter == state,
                showCheckmark: false,
                onSelected: onFilterChanged == null
                    ? null
                    : (_) => onFilterChanged!(state),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${active.length} peserta aktif • kapasitas ${controller.event.participantCapacity}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (controller.participants.isEmpty)
          const _EmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada peserta',
            message: 'Tambahkan nama peserta untuk mulai mencatat pembayaran.',
          )
        else ...[
          if (shown.isEmpty && filter != null)
            _EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title:
                  'Tidak ada peserta ${PayStateChip.textFor(filter!).toLowerCase()}',
              message: 'Ubah filter untuk melihat peserta lain.',
              actionLabel: 'Tampilkan semua',
              onAction: onFilterChanged == null
                  ? null
                  : () => onFilterChanged!(null),
            )
          else
            _ParticipantSection(
              title: filter == null
                  ? 'Peserta aktif'
                  : 'Peserta ${PayStateChip.textFor(filter!).toLowerCase()}',
              participants: shown,
              controller: controller,
            ),
          if (cancelled.isNotEmpty && filter == null) ...[
            const SizedBox(height: 16),
            _ParticipantSection(
              title: 'Dibatalkan',
              participants: cancelled,
              controller: controller,
            ),
          ],
        ],
      ],
    );
  }
}

class _ParticipantSection extends StatelessWidget {
  const _ParticipantSection({
    required this.title,
    required this.participants,
    required this.controller,
  });

  final String title;
  final List<ParticipantRecord> participants;
  final CashbookController controller;

  Future<void> _quickPay(
    BuildContext context,
    ParticipantRecord participant,
    int remaining,
  ) async {
    final saved = await showTransactionDialog(
      context,
      controller,
      initialType: TransactionType.participantPayment,
      initialParticipantId: participant.id,
      initialAmount: remaining,
      initialDescription: 'Iuran peserta',
    );
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Text('Pembayaran ${participant.name} disimpan.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            '$title (${participants.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < participants.length; index++) ...[
                _ParticipantTile(
                  participant: participants[index],
                  grossPaidAmount: participantPaid(
                    controller.transactions,
                    participants[index].id,
                  ),
                  refundAmount: refundTotalForParticipant(
                    controller.transactions,
                    participants[index].id,
                  ),
                  target: controller.contributionTarget,
                  onTap: controller.isReadOnly
                      ? null
                      : () => showParticipantActions(
                          context,
                          controller,
                          participants[index],
                        ),
                  onPay: controller.isReadOnly
                      ? null
                      : (remaining) =>
                            _quickPay(context, participants[index], remaining),
                ),
                if (index < participants.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.grossPaidAmount,
    required this.refundAmount,
    required this.target,
    required this.onTap,
    required this.onPay,
  });

  final ParticipantRecord participant;
  final int grossPaidAmount;
  final int refundAmount;
  final int target;
  final VoidCallback? onTap;
  final void Function(int remaining)? onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = participant.state == ParticipantState.cancelled;
    final netPaidAmount = grossPaidAmount - refundAmount;
    final state = payState(netPaidAmount, target);
    final remaining = target - netPaidAmount;
    final initial = participant.name.trim().isEmpty
        ? '?'
        : participant.name.trim().characters.first.toUpperCase();
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                backgroundColor: cancelled
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primaryContainer,
                foregroundColor: cancelled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
                child: cancelled ? const Icon(Icons.history) : Text(initial),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(participant.name, style: theme.textTheme.bodyLarge),
                  if (cancelled)
                    Text(
                      refundAmount == 0
                          ? 'Dibayar ${rupiah(grossPaidAmount)}'
                          : 'Bayar ${rupiah(grossPaidAmount)} • Refund ${rupiah(refundAmount)}',
                      style: muted,
                    )
                  else ...[
                    Text(
                      '${refundAmount == 0 ? 'Dibayar' : 'Bersih'} ${rupiah(netPaidAmount)} dari ${rupiah(target)}',
                      style: muted,
                    ),
                    if (refundAmount > 0)
                      Text(
                        'Bayar ${rupiah(grossPaidAmount)} • Refund ${rupiah(refundAmount)}',
                        style: muted,
                      ),
                    if (remaining > 0)
                      Text(
                        'Kurang ${rupiah(remaining)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (cancelled)
                        StatusPill(
                          label:
                              'Dibatalkan • ${refundPolicyLabel(participant.refundPolicy)}',
                          icon: Icons.history,
                          tone: theme.colorScheme.surfaceContainerHighest,
                          onTone: theme.colorScheme.onSurfaceVariant,
                        )
                      else
                        PayStateChip(state),
                      if (!cancelled && remaining > 0 && onPay != null)
                        TextButton.icon(
                          onPressed: () => onPay!(remaining),
                          icon: const Icon(Icons.add_card_outlined),
                          label: const Text('Catat bayar'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
