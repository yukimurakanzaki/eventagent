part of '../main.dart';

class MoneyPage extends StatelessWidget {
  const MoneyPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    this.onShowUnpaid,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;
  final VoidCallback? onShowUnpaid;

  /// Inline history stays short; the log page owns the full, filterable list.
  static const _inlineLimit = 15;

  void _openLog(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionLogPage(
        controller: controller,
        creatorRole: creatorRole,
        shareGateway: shareGateway,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final counted = effectiveTransactions(controller.transactions);
    final participantIncome = counted
        .where((item) => item.type == TransactionType.participantPayment)
        .fold(0, (sum, item) => sum + item.amount);
    final additionalIncome = counted
        .where((item) => item.type == TransactionType.additionalContribution)
        .fold(0, (sum, item) => sum + item.amount);
    final expense = expenseTotal(controller.transactions);
    final unpaid = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    ).unpaid;
    final history = controller.transactions.reversed.toList();
    final shown = history.take(_inlineLimit).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
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
                    value: formatMoney(controller.balance),
                  ),
                  const Divider(height: 28),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: 'Pembayaran peserta',
                    value: '+${formatMoney(participantIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: 'Kontribusi tambahan',
                    value: '+${formatMoney(additionalIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_upward,
                    label: 'Pengeluaran bersih',
                    value: '−${formatMoney(expense)}',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (unpaid > 0 && onShowUnpaid != null) ...[
          const SizedBox(height: 8),
          Card(
            color: colors.info,
            child: ListTile(
              onTap: onShowUnpaid,
              leading: Icon(Icons.groups_outlined, color: colors.onInfo),
              title: Text(
                '$unpaid peserta belum bayar',
                style: TextStyle(color: colors.onInfo),
              ),
              subtitle: Text(
                'Lihat daftar sebelum mengirim pengingat.',
                style: TextStyle(color: colors.onInfo),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.onInfo),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('Anggaran dan dana awal'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _MoneyRow(
                label: 'Anggaran final',
                value: formatMoney(controller.event.finalBudget),
              ),
              _MoneyRow(
                label: 'Sponsor',
                value: formatMoney(controller.event.sponsorContribution),
              ),
              _MoneyRow(
                label: 'Saldo awal',
                value: formatMoney(controller.event.openingBalance),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Riwayat transaksi',
          actionLabel: 'Filter & laporan rinci',
          actionIcon: Icons.filter_list,
          onAction: () => _openLog(context),
        ),
        Text(
          'Salah catat? Ketuk transaksinya untuk koreksi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            message:
                'Ketuk Catat transaksi untuk mencatat uang masuk atau keluar.',
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i == 0 || !_sameDay(shown[i - 1].createdAt, shown[i].createdAt))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 4),
              child: Semantics(
                header: true,
                child: Text(
                  formatDateLong(shown[i].createdAt),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TransactionTile(
                controller: controller,
                transaction: shown[i],
                showDate: false,
              ),
            ),
          ),
        ],
        if (history.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => _openLog(context),
              child: Text('Lihat semua ${history.length} transaksi'),
            ),
          ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Label on the left, amount on the right; stacked at large text so neither
/// gets squeezed on a narrow phone.
class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({
    required this.label,
    required this.value,
    this.icon,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final text = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              Text(value, style: valueStyle),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: 8),
              Text(value, style: valueStyle),
            ],
          );
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 20)),
            const SizedBox(width: 8),
          ],
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _LabelValueRow(
        icon: icon,
        label: label,
        value: value,
        labelStyle: theme.textTheme.bodyLarge,
        valueStyle: theme.textTheme.titleMedium,
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.controller,
    required this.transaction,
    this.correctable = true,
    this.showDate = true,
  });

  final CashbookController controller;
  final TransactionRecord transaction;

  /// Tap-to-correct is only offered where the full history is shown.
  final bool correctable;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final isCorrection = transaction.type == TransactionType.correction;
    final corrected = correctedTransactionIds(controller.transactions)
        .contains(transaction.id);
    final participant = controller.participants
        .where((item) => item.id == transaction.participantId)
        .firstOrNull;
    final original = controller.transactions
        .where((item) => item.id == transaction.relatedTransactionId)
        .firstOrNull;
    final title = isCorrection
        ? 'Koreksi: ${original?.description ?? 'transaksi'}'
        : transaction.description;
    final detail = [
      transactionTypeLabel(transaction.type),
      if (participant != null) participant.name,
      if (showDate) formatDate(transaction.createdAt),
      if (isCorrection) 'Alasan: ${transaction.description}',
      if (corrected) 'Dikoreksi, tidak dihitung',
    ].join(' • ');
    final struck = corrected
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final outflow =
        transaction.type == TransactionType.expense ||
        transaction.type == TransactionType.refund;
    // Direction is carried by the sign and icon, color only reinforces it.
    final amountColor = corrected || isCorrection
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : outflow
        ? colors.onDanger
        : colors.onSuccess;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(
        child: Icon(
          isCorrection || corrected
              ? Icons.undo
              : outflow
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          color: amountColor,
        ),
      ),
      title: Text(title, style: struck),
      subtitle: Text(detail),
      trailing: Text(
        isCorrection
            ? '-'
            : '${outflow ? '−' : '+'}${formatMoney(transaction.amount)}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: amountColor)
            .merge(struck),
      ),
      onTap: !correctable || isCorrection || corrected || controller.isReadOnly
          ? null
          : () =>
                showCorrectTransactionDialog(context, controller, transaction),
    );
  }
}

Future<void> showCorrectTransactionDialog(
  BuildContext context,
  CashbookController controller,
  TransactionRecord transaction,
) async {
  // ponytail: no TextEditingController, so nothing is disposed while the
  // dialog is still animating out over a rebuilding list.
  var reason = '';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Koreksi transaksi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${transaction.description} • ${formatMoney(transaction.amount)}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Transaksi ini tidak dihapus. Ia tetap terlihat dicoret di riwayat '
            'dan laporan, dan tidak dihitung lagi. Setelah itu catat ulang '
            'transaksi yang benar.',
          ),
          TextField(
            onChanged: (value) => reason = value,
            decoration: const InputDecoration(
              labelText: 'Alasan koreksi',
              hintText: 'Contoh: salah ketik nominal',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            final error = await controller.correctTransaction(
              transaction.id,
              reason,
            );
            if (error != null) {
              if (context.mounted) {
                await showInfo(context, 'Koreksi belum disimpan', error);
              }
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan koreksi'),
        ),
      ],
    ),
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MergeSemantics(
          child: Column(
            children: [
              ExcludeSemantics(child: Icon(icon, size: 40)),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
