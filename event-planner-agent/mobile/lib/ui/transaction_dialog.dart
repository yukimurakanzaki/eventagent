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
    text: initialAmount > 0 ? rupiah(initialAmount).substring(3) : '',
  );
  final descriptionController = TextEditingController(text: initialDescription);
  var showValidation = false;
  final draft = await showDialog<_TransactionDraft>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final amount = parseRupiahInput(amountController.text);
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
                ? 'Catat pembayaran'
                : 'Catat transaksi',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // A preset type (quick "Catat bayar") needs no type picker.
                if (initialType == null) ...[
                  Text(
                    'Pilih jenis transaksi',
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
                    child: const Column(
                      children: [
                        _TransactionTypeChoice(
                          value: TransactionType.participantPayment,
                          icon: Icons.person_add_alt_1_outlined,
                          label: 'Pembayaran peserta',
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.expense,
                          icon: Icons.receipt_long_outlined,
                          label: 'Pengeluaran',
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.additionalContribution,
                          icon: Icons.volunteer_activism_outlined,
                          label: 'Kontribusi tambahan',
                        ),
                        _TransactionTypeChoice(
                          value: TransactionType.refund,
                          icon: Icons.reply_all_outlined,
                          label: 'Refund peserta',
                        ),
                      ],
                    ),
                  ),
                  if (showValidation && type == null)
                    const _FieldError('Pilih jenis transaksi terlebih dahulu.'),
                ],
                if (needsParticipant) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('transaction-participant'),
                    initialValue: participantId,
                    decoration: InputDecoration(
                      labelText: 'Peserta',
                      errorText: showValidation && participantId == null
                          ? 'Pilih peserta untuk transaksi ini.'
                          : null,
                    ),
                    hint: const Text('Pilih peserta'),
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
                                  ? '${item.name} • tersedia ${rupiah(refundableAmountForParticipant(controller.transactions, item.id))}'
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
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Nominal ini akan menambah total pembayaran peserta.',
                      ),
                    ),
                  if (type == TransactionType.refund && participantId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Maksimum refund peserta ini: ${rupiah(refundLimit)}.',
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('transaction-amount'),
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [RupiahTextInputFormatter()],
                  onChanged: (_) => setState(() => showValidation = true),
                  decoration: InputDecoration(
                    labelText: 'Jumlah (rupiah)',
                    helperText: 'Contoh: 125.000',
                    errorText: showValidation && amount <= 0
                        ? 'Masukkan jumlah lebih dari Rp 0.'
                        : type == TransactionType.refund &&
                              participantId != null &&
                              amount > refundLimit
                        ? 'Refund tidak boleh melebihi ${rupiah(refundLimit)}.'
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
                            label: Text('Lunasi ${rupiah(remaining)}'),
                            onPressed: () => setState(() {
                              amountController.text = rupiah(remaining)
                                  .substring(3);
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
                    labelText: 'Keterangan',
                    helperText: 'Contoh: Uang muka bus',
                    errorText:
                        showValidation &&
                            descriptionController.text.trim().isEmpty
                        ? 'Isi keterangan transaksi.'
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
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
                      ),
                    )
                  : null,
              child: const Text('Simpan transaksi'),
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
  );
  return true;
}

class _TransactionDraft {
  const _TransactionDraft({
    required this.type,
    required this.amount,
    required this.description,
    required this.participantId,
  });

  final TransactionType type;
  final int amount;
  final String description;
  final String? participantId;
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

int parseRupiahInput(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

class RupiahTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = digits.replaceFirst(RegExp(r'^0+'), '');
    final value = formatted.isEmpty ? '0' : formatted;
    final groups = <String>[];
    for (var end = value.length; end > 0; end -= 3) {
      groups.add(value.substring(end - 3 < 0 ? 0 : end - 3, end));
    }
    final text = groups.reversed.join('.');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
