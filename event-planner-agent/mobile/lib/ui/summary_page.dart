part of '../main.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({
    required this.controller,
    this.onShowParticipants,
    this.onShowMoney,
    super.key,
  });

  final CashbookController controller;
  final void Function(PayState? filter)? onShowParticipants;
  final VoidCallback? onShowMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    );
    final activeCount = progress.paid + progress.partial + progress.unpaid;
    final reminders = [...controller.reminders]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final recent = controller.transactions.reversed.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _SyncStatusBanner(pendingCount: controller.pendingOperations.length),
        if (controller.syncError != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.sync_problem_outlined),
                title: const Text('Sinkronisasi perlu diperiksa'),
                subtitle: Text(controller.syncError!),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _BalanceHero(
          balance: rupiah(controller.balance),
          contribution: rupiah(controller.contributionTarget),
          helper:
              '(Anggaran − sponsor − saldo awal) ÷ $activeCount peserta aktif',
          progress: progress,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final state in PayState.values) ...[
                if (state != PayState.paid) const SizedBox(width: 8),
                Expanded(
                  child: _CountTile(
                    state: state,
                    count: switch (state) {
                      PayState.paid => progress.paid,
                      PayState.partial => progress.partial,
                      PayState.unpaid => progress.unpaid,
                    },
                    onTap: onShowParticipants == null
                        ? null
                        : () => onShowParticipants!(state),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Aktivitas terakhir',
          actionLabel: recent.isEmpty ? null : 'Lihat semua',
          onAction: onShowMoney,
        ),
        if (recent.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            message:
                'Ketuk Catat transaksi untuk mencatat uang masuk atau keluar.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _TransactionTile(
                      controller: controller,
                      transaction: recent[i],
                      correctable: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Pengingat',
          actionLabel: 'Tambah',
          actionIcon: Icons.add_alert_outlined,
          onAction: controller.isReadOnly
              ? null
              : () => showReminderDialog(context, controller),
        ),
        if (reminders.isEmpty)
          const _EmptyState(
            icon: Icons.notifications_none,
            title: 'Belum ada pengingat',
            message: 'Tambahkan tenggat pembayaran atau rencana perjalanan.',
          )
        else
          for (final reminder in reminders.take(3))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: reminder.isDone,
                onChanged: controller.isReadOnly
                    ? null
                    : (_) => controller.toggleReminder(reminder),
                title: Text(reminder.title),
                subtitle: Text(
                  '${formatDateTime(reminder.dueAt)}${reminder.note.isEmpty ? '' : ' • ${reminder.note}'}',
                ),
                secondary: Icon(
                  reminder.dueAt.isBefore(DateTime.now()) && !reminder.isDone
                      ? Icons.warning_amber_outlined
                      : Icons.notifications_active_outlined,
                ),
              ),
            ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (actionLabel != null)
            actionIcon == null
                ? TextButton(onPressed: onAction, child: Text(actionLabel!))
                : TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel!),
                  ),
        ],
      ),
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final synced = pendingCount == 0;
    final onTone = synced ? theme.colorScheme.onSurfaceVariant : colors.onInfo;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: synced ? theme.colorScheme.surfaceContainerLow : colors.info,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  synced
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  color: onTone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  synced
                      ? 'Tersimpan di perangkat • tidak ada perubahan menunggu sinkronisasi.'
                      : '$pendingCount perubahan tersimpan dan menunggu sinkronisasi.',
                  style: TextStyle(color: onTone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-glance answer for a treasurer: how much cash is in hand, and how
/// much of what the group owes has actually been collected.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.contribution,
    required this.helper,
    required this.progress,
  });

  final String balance;
  final String contribution;
  final String helper;
  final CollectionProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.fraction * 100).floor();
    final summary =
        'Iuran terkumpul ${rupiah(progress.collected)} dari ${rupiah(progress.expected)} ($percent%)';
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryAmount(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Saldo saat ini',
                value: balance,
              ),
              const SizedBox(height: 16),
              Semantics(
                label: summary,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 12,
                        backgroundColor: theme.colorScheme.surface.withValues(
                          alpha: 0.5,
                        ),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(summary),
                  ],
                ),
              ),
              const Divider(height: 32),
              _SummaryAmount(
                icon: Icons.calculate_outlined,
                label: 'Iuran per peserta',
                value: contribution,
              ),
              const SizedBox(height: 6),
              Text(helper, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.state, required this.count, this.onTap});

  final PayState state;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final (tone, onTone) = switch (state) {
      PayState.paid => (colors.success, colors.onSuccess),
      PayState.partial => (colors.warning, colors.onWarning),
      PayState.unpaid => (colors.danger, colors.onDanger),
    };
    final label = PayStateChip.textFor(state);
    return Semantics(
      button: onTap != null,
      label: '$label: $count peserta',
      hint: onTap == null ? null : 'Ketuk untuk melihat daftar',
      excludeSemantics: true,
      child: Material(
        color: tone,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: [
                Icon(PayStateChip.iconFor(state), color: onTone),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(color: onTone),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: onTone),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
