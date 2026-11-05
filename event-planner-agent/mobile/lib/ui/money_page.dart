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
                    label: tr('Saldo saat ini'),
                    value: formatMoney(controller.balance),
                  ),
                  const Divider(height: 28),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: tr('Pembayaran peserta'),
                    value: '+${formatMoney(participantIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: tr('Kontribusi tambahan'),
                    value: '+${formatMoney(additionalIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_upward,
                    label: tr('Pengeluaran bersih'),
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
                tr('{count} peserta belum bayar', {'count': unpaid}),
                style: TextStyle(color: colors.onInfo),
              ),
              subtitle: Text(
                tr('Lihat daftar sebelum mengirim pengingat.'),
                style: TextStyle(color: colors.onInfo),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.onInfo),
            ),
          ),
        ],
        if (expenseTotalsByCategory(
          controller.transactions,
          correctedTransactionIds(controller.transactions),
        ).isNotEmpty) ...[
          const SizedBox(height: 8),
          _CategoryTotalsCard(
            totals: expenseTotalsByCategory(
              controller.transactions,
              correctedTransactionIds(controller.transactions),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(tr('Anggaran dan dana awal')),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _MoneyRow(
                label: tr('Anggaran final'),
                value: formatMoney(controller.event.finalBudget),
              ),
              _MoneyRow(
                label: tr('Sponsor'),
                value: formatMoney(controller.event.sponsorContribution),
              ),
              _MoneyRow(
                label: tr('Saldo awal'),
                value: formatMoney(controller.event.openingBalance),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: tr('Riwayat transaksi'),
          actionLabel: tr('Filter & laporan rinci'),
          actionIcon: Icons.filter_list,
          onAction: () => _openLog(context),
        ),
        Text(
          tr('Salah catat? Ketuk transaksinya untuk koreksi.'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: tr('Belum ada transaksi'),
            message: tr(
              'Ketuk Catat transaksi untuk mencatat uang masuk atau keluar.',
            ),
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
              child: Text(
                tr('Lihat semua {count} transaksi', {'count': history.length}),
              ),
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
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.25;
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
              Flexible(
                child: Text(value, style: valueStyle, textAlign: TextAlign.end),
              ),
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

  Widget _receiptRow(BuildContext context) {
    final theme = Theme.of(context);
    final category = transaction.category ?? ExpenseCategory.other;
    final canPhoto = Receipts.supported && !controller.isReadOnly;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(expenseCategoryIcon(category), size: 16),
            ),
            const SizedBox(width: 4),
            Text(expenseCategoryLabel(category), style: muted),
          ],
        ),
        if (transaction.hasReceipt)
          TextButton.icon(
            key: Key('receipt-view-${transaction.id}'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.receipt_long, size: 18),
            label: Text(tr('Lihat nota')),
            onPressed: () => showReceiptViewer(context, transaction),
          )
        else
          Text(tr('Tanpa nota'), style: muted),
        if (canPhoto)
          TextButton(
            key: Key('receipt-attach-${transaction.id}'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => _attach(context),
            child: Text(
              transaction.hasReceipt ? tr('Ganti nota') : tr('Lampirkan nota'),
            ),
          ),
      ],
    );
  }

  Future<void> _attach(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await pickReceiptPhoto(context);
    if (path == null) return;
    final error = await controller.attachReceipt(
      transaction.id,
      localPath: path,
    );
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

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
        ? tr('Koreksi: {name}', {
            'name': original?.description ?? tr('transaksi'),
          })
        : transaction.description;
    final detail = [
      transactionTypeLabel(transaction.type),
      if (participant != null) participant.name,
      if (showDate) formatDate(transaction.createdAt),
      if (isCorrection)
        tr('Alasan: {reason}', {'reason': transaction.description}),
      if (corrected) tr('Dikoreksi, tidak dihitung'),
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
    final isExpense = transaction.type == TransactionType.expense;
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail),
          if (isExpense && !corrected) _receiptRow(context),
        ],
      ),
      trailing: Text(
        isCorrection
            ? '-'
            : formatSignedMoney(transaction.amount, outflow: outflow),
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
      title: Text(tr('Koreksi transaksi')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${transaction.description} • ${formatMoney(transaction.amount)}',
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Transaksi ini tidak dihapus. Ia tetap terlihat dicoret di riwayat dan laporan, dan tidak dihitung lagi. Setelah itu catat ulang transaksi yang benar.',
            ),
          ),
          TextField(
            onChanged: (value) => reason = value,
            decoration: InputDecoration(
              labelText: tr('Alasan koreksi'),
              hintText: tr('Contoh: salah ketik nominal'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Batal')),
        ),
        FilledButton(
          onPressed: () async {
            final error = await controller.correctTransaction(
              transaction.id,
              reason,
            );
            if (error != null) {
              if (context.mounted) {
                await showInfo(context, tr('Koreksi belum disimpan'), error);
              }
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(tr('Simpan koreksi')),
        ),
      ],
    ),
  );
}

class _CategoryTotalsCard extends StatelessWidget {
  const _CategoryTotalsCard({required this.totals});

  final List<(ExpenseCategory, int)> totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = totals.fold(0, (sum, item) => sum + item.$2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                tr('Pengeluaran per kategori'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            for (final (category, amount) in totals) ...[
              const SizedBox(height: 12),
              _LabelValueRow(
                icon: expenseCategoryIcon(category),
                label: expenseCategoryLabel(category),
                value: formatMoney(amount),
                valueStyle: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: total <= 0 ? 0 : amount / total,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
