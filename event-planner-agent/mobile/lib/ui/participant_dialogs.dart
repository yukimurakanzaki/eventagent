part of '../main.dart';

Widget _roleAndPhoneFields({
  required ParticipantRole role,
  required ValueChanged<ParticipantRole> onRoleChanged,
  required TextEditingController phoneController,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<ParticipantRole>(
          key: const Key('participant-role'),
          showSelectedIcon: false,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
          ),
          segments: [
            for (final item in ParticipantRole.values)
              ButtonSegment(
                value: item,
                label: Text(participantRoleLabel(item)),
              ),
          ],
          selected: {role},
          onSelectionChanged: (value) => onRoleChanged(value.first),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        key: const Key('participant-phone'),
        controller: phoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: tr('Nomor WhatsApp (opsional)'),
          helperMaxLines: 4,
          helperText: tr(
            'Sertakan kode negara, misalnya +62 untuk Indonesia. Hanya dipakai untuk pengingat pribadi, tidak pernah muncul di laporan.',
          ),
        ),
      ),
    ],
  );
}

const _callingCodes = <String, String>{
  'ID': '62',
  'MY': '60',
  'SG': '65',
  'TH': '66',
  'VN': '84',
  'PH': '63',
  'IN': '91',
  'PK': '92',
  'BD': '880',
  'CN': '86',
  'JP': '81',
  'KR': '82',
  'AU': '61',
  'NZ': '64',
  'GB': '44',
  'DE': '49',
  'FR': '33',
  'ES': '34',
  'IT': '39',
  'NL': '31',
  'PT': '351',
  'BR': '55',
  'MX': '52',
  'AR': '54',
  'CO': '57',
  'CL': '56',
  'PE': '51',
  'SA': '966',
  'AE': '971',
  'EG': '20',
  'NG': '234',
  'KE': '254',
  'ZA': '27',
  'TR': '90',
  'US': '1',
  'CA': '1',
};

/// The wa.me number (E.164 digits, no '+') for a stored [phone]. A leading
/// '+' keeps its digits, '00' is dropped, a single leading '0' is replaced by
/// the calling code of [countryCode] (default Indonesia, 62).
String whatsAppNumber(String phone, {String? countryCode}) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (trimmed.startsWith('+')) return digits;
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('0')) {
    final code = _callingCodes[countryCode?.toUpperCase()] ?? '62';
    return '$code${digits.substring(1)}';
  }
  return digits;
}

/// Opens [uri] outside the app. Replaceable in tests.
Future<bool> Function(Uri uri) reminderLauncher = (uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Shares plain text through the system share sheet. Replaceable in tests.
Future<void> Function(String text) reminderSharer = (text) async {
  await SharePlus.instance.share(ShareParams(text: text));
};

Future<void> sendPaymentReminder(
  CashbookController controller,
  ParticipantRecord participant,
) async {
  final paid = participantNetPaid(controller.transactions, participant.id);
  final target = controller.contributionTarget;
  final message = tr(
    'Halo {name}, pengingat iuran {event}: sudah dibayar {paid} dari {target}, sisa {remaining}. Terima kasih!',
    {
      'name': participant.name,
      'event': controller.event.name,
      'paid': formatMoney(paid),
      'target': formatMoney(target),
      'remaining': formatMoney(target - paid),
    },
  );
  final digits = whatsAppNumber(
    participant.phone,
    countryCode: WidgetsBinding.instance.platformDispatcher.locale.countryCode,
  );
  if (digits.isNotEmpty) {
    try {
      final uri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
      );
      if (await reminderLauncher(uri)) return;
    } catch (_) {
      // Fall through to the share sheet.
    }
  }
  try {
    await reminderSharer(message);
  } catch (_) {
    // Sharing is best effort.
  }
}

Future<void> showParticipantDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  var role = ParticipantRole.participant;
  String? replacementForId;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('Tambah peserta')),
      content: StatefulBuilder(
        builder: (dialogContext, setState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('Nama peserta')),
              ),
              _roleAndPhoneFields(
                role: role,
                onRoleChanged: (value) => setState(() => role = value),
                phoneController: phoneController,
              ),
              if (controller.participants.any(
                (item) => item.state == ParticipantState.cancelled,
              )) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: replacementForId,
                  decoration: InputDecoration(
                    labelText: tr('Menggantikan peserta (opsional)'),
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
          child: Text(tr('Batal')),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              await showInfo(
                context,
                tr('Nama belum diisi'),
                tr('Masukkan nama peserta terlebih dahulu.'),
              );
              return;
            }
            final error = await controller.addParticipant(
              nameController.text,
              replacementForId: replacementForId,
              role: role,
              phone: phoneController.text.trim(),
            );
            if (error != null && context.mounted) {
              await showInfo(context, tr('Peserta belum ditambahkan'), error);
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(tr('Simpan')),
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
  final remainingToPay =
      controller.contributionTarget -
      participantNetPaid(controller.transactions, participant.id);
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          if (participant.state == ParticipantState.active)
            ListTile(
              leading: const Icon(Icons.add_card_outlined),
              title: Text(tr('Catat pembayaran')),
              onTap: () => Navigator.pop(sheetContext, 'pay'),
            ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(tr('Edit nama')),
            onTap: () => Navigator.pop(sheetContext, 'edit'),
          ),
          if (participant.state == ParticipantState.active &&
              remainingToPay > 0)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(tr('Kirim pengingat')),
              onTap: () => Navigator.pop(sheetContext, 'remind'),
            ),
          if (participant.state == ParticipantState.active)
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: Text(tr('Batalkan peserta')),
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
      initialDescription: tr('Iuran peserta'),
    );
  } else if (action == 'edit') {
    await showEditParticipantDialog(context, controller, participant);
  } else if (action == 'remind') {
    await sendPaymentReminder(controller, participant);
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
  final phoneController = TextEditingController(text: participant.phone);
  var role = participant.role;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(tr('Edit peserta')),
      content: StatefulBuilder(
        builder: (dialogContext, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: tr('Nama peserta')),
            ),
            _roleAndPhoneFields(
              role: role,
              onRoleChanged: (value) => setState(() => role = value),
              phoneController: phoneController,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Batal')),
        ),
        FilledButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              await showInfo(
                context,
                tr('Nama belum diisi'),
                tr('Masukkan nama peserta terlebih dahulu.'),
              );
              return;
            }
            final error = await controller.editParticipant(
              participant.copyWith(
                name: name,
                role: role,
                phone: phoneController.text.trim(),
              ),
            );
            if (error != null && context.mounted) {
              await showInfo(context, tr('Peserta belum diperbarui'), error);
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(tr('Simpan')),
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
          title: Text(tr('Batalkan peserta')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Riwayat pembayaran tetap disimpan. Pilih kebijakan refund:',
                  ),
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
                Text(
                  tr('Maksimum refund: {amount}.', {
                    'amount': formatMoney(refundable),
                  }),
                ),
                if (selectedPolicy == RefundPolicy.full)
                  Text(
                    refundable == 0
                        ? tr('Tidak ada pembayaran bersih yang dapat direfund.')
                        : tr('{amount} akan dicatat sebagai refund penuh.', {
                            'amount': formatMoney(refundable),
                          }),
                  ),
                if (selectedPolicy == RefundPolicy.partial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('cancellation-refund-amount'),
                    controller: partialRefundController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: Money.spec.decimals > 0,
                    ),
                    inputFormatters: [MoneyTextInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: tr('Nominal refund sebagian ({currency})', {
                        'currency': Money.currency,
                      }),
                      helperText: tr('Contoh: {example}', {
                        'example': formatMoneyInput(
                          Money.spec.decimals > 0 ? 1250 : 125000,
                        ),
                      }),
                      errorText: partialRefundController.text.isEmpty
                          ? null
                          : partialValid
                          ? null
                          : tr('Masukkan nominal dari {min} sampai {max}.', {
                              'min': formatMoney(Money.spec.minorFactor),
                              'max': formatMoney(refundable),
                            }),
                    ),
                  ),
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
              onPressed: selectedPolicy != RefundPolicy.partial || partialValid
                  ? () => Navigator.pop(
                      dialogContext,
                      _CancellationDraft(
                        policy: selectedPolicy,
                        partialRefundAmount: partialAmount,
                      ),
                    )
                  : null,
              child: Text(tr('Simpan pembatalan')),
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
