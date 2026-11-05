part of '../main.dart';

Future<void> showParticipantDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final nameController = TextEditingController();
  String? replacementForId;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tambah peserta'),
      content: StatefulBuilder(
        builder: (dialogContext, setState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama peserta'),
              ),
              if (controller.participants.any(
                (item) => item.state == ParticipantState.cancelled,
              )) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: replacementForId,
                  decoration: const InputDecoration(
                    labelText: 'Menggantikan peserta (opsional)',
                  ),
                  items: controller.participants
                      .where((item) => item.state == ParticipantState.cancelled)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => replacementForId = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              await showInfo(
                context,
                'Nama belum diisi',
                'Masukkan nama peserta terlebih dahulu.',
              );
              return;
            }
            final error = await controller.addParticipant(
              nameController.text,
              replacementForId: replacementForId,
            );
            if (error != null && context.mounted) {
              await showInfo(context, 'Peserta belum ditambahkan', error);
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  // ponytail: no dispose; route still animates out when showDialog returns,
  // and disposing now throws _dependents.isEmpty. GC reclaims the controller.
}

Future<void> showParticipantActions(
  BuildContext context,
  CashbookController controller,
  ParticipantRecord participant,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          if (participant.state == ParticipantState.active)
            ListTile(
              leading: const Icon(Icons.add_card_outlined),
              title: const Text('Catat pembayaran'),
              onTap: () => Navigator.pop(sheetContext, 'pay'),
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit nama'),
            onTap: () => Navigator.pop(sheetContext, 'edit'),
          ),
          if (participant.state == ParticipantState.active)
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Batalkan peserta'),
              onTap: () => Navigator.pop(sheetContext, 'cancel'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'pay') {
    final remaining =
        controller.contributionTarget -
        participantNetPaid(controller.transactions, participant.id);
    await showTransactionDialog(
      context,
      controller,
      initialType: TransactionType.participantPayment,
      initialParticipantId: participant.id,
      initialAmount: remaining > 0 ? remaining : 0,
      initialDescription: 'Iuran peserta',
    );
  } else if (action == 'edit') {
    await showEditParticipantDialog(context, controller, participant);
  } else if (action == 'cancel') {
    await showCancelParticipantDialog(context, controller, participant);
  }
}

Future<void> showEditParticipantDialog(
  BuildContext context,
  CashbookController controller,
  ParticipantRecord participant,
) async {
  final nameController = TextEditingController(text: participant.name);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Edit peserta'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'Nama peserta'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              await showInfo(
                context,
                'Nama belum diisi',
                'Masukkan nama peserta terlebih dahulu.',
              );
              return;
            }
            final error = await controller.editParticipant(
              participant.copyWith(name: name),
            );
            if (error != null && context.mounted) {
              await showInfo(context, 'Peserta belum diperbarui', error);
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<void> showCancelParticipantDialog(
  BuildContext context,
  CashbookController controller,
  ParticipantRecord participant,
) async {
  final refundable = refundableAmountForParticipant(
    controller.transactions,
    participant.id,
  );
  var selectedPolicy = participant.refundPolicy == RefundPolicy.undecided
      ? RefundPolicy.none
      : participant.refundPolicy;
  final partialRefundController = TextEditingController();
  final draft = await showDialog<_CancellationDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final partialAmount = parseMoneyInput(partialRefundController.text);
        final partialValid = partialAmount > 0 && partialAmount <= refundable;
        return AlertDialog(
          title: const Text('Batalkan peserta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat pembayaran tetap disimpan. Pilih kebijakan refund:',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RefundPolicy>(
                  initialValue: selectedPolicy,
                  items: RefundPolicy.values
                      .where((item) => item != RefundPolicy.undecided)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(refundPolicyLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => selectedPolicy = value ?? selectedPolicy),
                ),
                const SizedBox(height: 12),
                Text('Maksimum refund: ${formatMoney(refundable)}.'),
                if (selectedPolicy == RefundPolicy.full)
                  Text(
                    refundable == 0
                        ? 'Tidak ada pembayaran bersih yang dapat direfund.'
                        : '${formatMoney(refundable)} akan dicatat sebagai refund penuh.',
                  ),
                if (selectedPolicy == RefundPolicy.partial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('cancellation-refund-amount'),
                    controller: partialRefundController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyTextInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nominal refund sebagian (rupiah)',
                      errorText: partialRefundController.text.isEmpty
                          ? null
                          : partialValid
                          ? null
                          : 'Masukkan nominal dari Rp 1 sampai ${formatMoney(refundable)}.',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: selectedPolicy != RefundPolicy.partial || partialValid
                  ? () => Navigator.pop(
                      dialogContext,
                      _CancellationDraft(
                        policy: selectedPolicy,
                        partialRefundAmount: partialAmount,
                      ),
                    )
                  : null,
              child: const Text('Simpan pembatalan'),
            ),
          ],
        );
      },
    ),
  );
  if (draft == null || !context.mounted) return;

  // Pop the route before notifying the cashbook listeners. Updating while the
  // dialog is still mounted can deactivate an inherited dropdown with active
  // dependents, which triggers Flutter's `_dependents.isEmpty` assertion.
  await controller.cancelParticipant(
    participant,
    draft.policy,
    partialRefundAmount: draft.partialRefundAmount,
  );
}
