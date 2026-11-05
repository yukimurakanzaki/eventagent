part of '../main.dart';

Future<bool> showTransactionDialog(
  BuildContext context,
  CashbookController controller, {
  TransactionType? initialType,
  String? initialParticipantId,
  int initialAmount = 0,
  String initialDescription = '',
}) async {
  TransactionType? type = initialType;
  String? participantId = initialParticipantId;
  final amountController = TextEditingController(
    text: formatMoneyInput(initialAmount),
  );
  final descriptionController = TextEditingController(text: initialDescription);
  var showValidation = false;
  var category = ExpenseCategory.other;
  String? receiptPath;
  final draft = await showDialog<_TransactionDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final amount = parseMoneyInput(amountController.text);
        final needsParticipant =
            type == TransactionType.participantPayment ||
            type == TransactionType.refund;
        final refundLimit = participantId == null
            ? 0
            : refundableAmountForParticipant(
                controller.transactions,
                participantId!,
              );
        final valid =
            type != null &&
            amount > 0 &&
            descriptionController.text.trim().isNotEmpty &&
            (!needsParticipant || participantId != null) &&
            (type != TransactionType.refund || amount <= refundLimit);
        return AlertDialog(
          title: Text(
            initialType == TransactionType.participantPayment
                ? tr('Catat pembayaran')
                : tr('Catat transaksi'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A preset type (quick "Catat bayar") needs no type picker.
                if (initialType == null) ...[
                  Text(
                    tr('Pilih jenis transaksi'),
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  RadioGroup<TransactionType>(
                    groupValue: type,
                    onChanged: (value) => setState(() {
                      type = value;
                      // Filters differ per type; keep the dropdown value valid.
                      participantId = null;
                      showValidation = true;
                    }),
                    child: Column(
                      children: [
                        _TransactionTypeChoice(
                          value: TransactionType.participantPayment,
                          icon: Icons.person_add_alt_1_outlined,
                          label: tr('Pembayaran peserta'),
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.expense,
                          icon: Icons.receipt_long_outlined,
                          label: tr('Pengeluaran'),
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.additionalContribution,
                          icon: Icons.volunteer_activism_outlined,
                          label: tr('Kontribusi tambahan'),
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.refund,
                          icon: Icons.reply_all_outlined,
                          label: tr('Refund peserta'),
                        ),
                      ],
                    ),
                  ),
                  if (showValidation && type == null)
                    _FieldError(tr('Pilih jenis transaksi terlebih dahulu.')),
                ],
                if (needsParticipant) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('transaction-participant'),
                    initialValue: participantId,
                    decoration: InputDecoration(
                      labelText: tr('Peserta'),
                      errorText: showValidation && participantId == null
                          ? tr('Pilih peserta untuk transaksi ini.')
                          : null,
                    ),
                    hint: Text(tr('Pilih peserta')),
                    items: controller.participants
                        .where(
                          (item) =>
                              (type != TransactionType.participantPayment ||
                                  item.state == ParticipantState.active) &&
                              (type != TransactionType.refund ||
                                  refundableAmountForParticipant(
                                        controller.transactions,
                                        item.id,
                                      ) >
                                      0),
                        )
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              type == TransactionType.refund
                                  ? tr('{name} • tersedia {amount}', {
                                      'name': item.name,
                                      'amount': formatMoney(
                                        refundableAmountForParticipant(
                                          controller.transactions,
                                          item.id,
                                        ),
                                      ),
                                    })
                                  : item.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      participantId = value;
                      showValidation = true;
                    }),
                  ),
                  if (type == TransactionType.participantPayment)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        tr(
                          'Nominal ini akan menambah total pembayaran peserta.',
                        ),
                      ),
                    ),
                  if (type == TransactionType.refund && participantId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        tr('Maksimum refund peserta ini: {amount}.', {
                          'amount': formatMoney(refundLimit),
                        }),
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('transaction-amount'),
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyTextInputFormatter()],
                  onChanged: (_) => setState(() => showValidation = true),
                  decoration: InputDecoration(
                    labelText: tr('Jumlah ({currency})', {
                      'currency': Money.currency,
                    }),
                    helperText: tr('Contoh: 125.000'),
                    errorText: showValidation && amount <= 0
                        ? tr('Masukkan jumlah lebih dari {zero}.', {
                            'zero': formatMoney(0),
                          })
                        : type == TransactionType.refund &&
                              participantId != null &&
                              amount > refundLimit
                        ? tr('Refund tidak boleh melebihi {amount}.', {
                            'amount': formatMoney(refundLimit),
                          })
                        : null,
                  ),
                ),
                if (type == TransactionType.participantPayment &&
                    participantId != null)
                  Builder(
                    builder: (context) {
                      final remaining =
                          controller.contributionTarget -
                          participantNetPaid(
                            controller.transactions,
                            participantId!,
                          );
                      if (remaining <= 0 || amount == remaining) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.check_circle_outline),
                            label: Text(
                              tr('Lunasi {amount}', {
                                'amount': formatMoney(remaining),
                              }),
                            ),
                            onPressed: () => setState(() {
                              amountController.text = formatMoneyInput(
                                remaining,
                              );
                            }),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('transaction-description'),
                  controller: descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => showValidation = true),
                  decoration: InputDecoration(
                    labelText: tr('Keterangan'),
                    helperText: tr('Contoh: Uang muka bus'),
                    errorText:
                        showValidation &&
                            descriptionController.text.trim().isEmpty
                        ? tr('Isi keterangan transaksi.')
                        : null,
                  ),
                ),
                if (type == TransactionType.expense) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ExpenseCategory>(
                    key: const Key('transaction-category'),
                    isExpanded: true,
                    initialValue: category,
                    decoration: InputDecoration(labelText: tr('Kategori')),
                    items: [
                      for (final item in ExpenseCategory.values)
                        DropdownMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              Icon(expenseCategoryIcon(item), size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  expenseCategoryLabel(item),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => category = value ?? category),
                  ),
                  if (Receipts.supported) ...[
                    const SizedBox(height: 12),
                    if (receiptPath != null)
                      Row(
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ReceiptImage(
                                transaction: TransactionRecord(
                                  id: 'draft',
                                  type: TransactionType.expense,
                                  amount: 0,
                                  description: '',
                                  createdAt: DateTime.now(),
                                  receiptPath: receiptPath,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tr('Foto nota terlampir'))),
                          IconButton(
                            key: const Key('transaction-receipt-remove'),
                            tooltip: tr('Hapus foto nota'),
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => receiptPath = null),
                          ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('transaction-receipt-attach'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(
                          receiptPath == null
                              ? tr('Lampirkan foto nota')
                              : tr('Ganti foto nota'),
                        ),
                        onPressed: () async {
                          final path = await pickReceiptPhoto(dialogContext);
                          if (path != null) setState(() => receiptPath = path);
                        },
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(tr('Batal')),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(
                      dialogContext,
                      _TransactionDraft(
                        type: type!,
                        amount: amount,
                        description: descriptionController.text,
                        participantId: participantId,
                        category: type == TransactionType.expense
                            ? category
                            : null,
                        receiptPath: type == TransactionType.expense
                            ? receiptPath
                            : null,
                      ),
                    )
                  : null,
              child: Text(tr('Simpan transaksi')),
            ),
          ],
        );
      },
    ),
  );
  if (draft == null || !context.mounted) return false;

  // As with cancellation, commit after the dialog route has been removed so
  // a refund's participant dropdown is never rebuilt while it is deactivating.
  await controller.recordTransaction(
    type: draft.type,
    amount: draft.amount,
    description: draft.description,
    participantId: draft.participantId,
    category: draft.category,
    receiptPath: draft.receiptPath,
  );
  return true;
}

class _TransactionDraft {
  const _TransactionDraft({
    required this.type,
    required this.amount,
    required this.description,
    required this.participantId,
    this.category,
    this.receiptPath,
  });

  final TransactionType type;
  final int amount;
  final String description;
  final String? participantId;
  final ExpenseCategory? category;
  final String? receiptPath;
}

class _CancellationDraft {
  const _CancellationDraft({
    required this.policy,
    required this.partialRefundAmount,
  });

  final RefundPolicy policy;
  final int partialRefundAmount;
}

class _TransactionTypeChoice extends StatelessWidget {
  const _TransactionTypeChoice({
    required this.value,
    required this.icon,
    required this.label,
  });

  final TransactionType value;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<TransactionType>(
      value: value,
      contentPadding: EdgeInsets.zero,
      dense: false,
      secondary: Icon(icon),
      title: Text(label),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
