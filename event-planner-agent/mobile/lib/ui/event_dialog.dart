part of '../main.dart';

Future<void> showEventDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final current = controller.event;
  final nameController = TextEditingController(text: current.name);
  final capacityController = TextEditingController(
    text: current.participantCapacity.toString(),
  );
  final budgetController = TextEditingController(
    text: _moneyText(current.finalBudget, current.currency),
  );
  final sponsorNameController = TextEditingController(
    text: current.sponsorName,
  );
  final sponsorAmountController = TextEditingController(
    text: _moneyText(current.sponsorContribution, current.currency),
  );
  final openingController = TextEditingController(
    text: _moneyText(current.openingBalance, current.currency),
  );
  var startDate = current.startDate;
  var endDate = current.endDate;
  var error = '';
  var currency = current.currency;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        scrollable: true,
        title: Text(tr('Edit acara')),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: tr('Nama acara')),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Tanggal acara'),
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _EventDateButton(
                  label: tr('Mulai'),
                  value: startDate,
                  icon: Icons.event_outlined,
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: startDate,
                    );
                    if (picked != null) setState(() => startDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                _EventDateButton(
                  label: tr('Selesai'),
                  value: endDate,
                  icon: Icons.event_available_outlined,
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: endDate,
                    );
                    if (picked != null) setState(() => endDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr('Kapasitas peserta'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('event-currency'),
                  onPressed: () async {
                    final code = await pickCurrency(
                      dialogContext,
                      selected: currency,
                    );
                    if (code == null || code == currency) return;
                    final values = [
                      budgetController,
                      sponsorAmountController,
                      openingController,
                    ].map((c) => parseMoneyInput(c.text, currency: currency));
                    final list = values.toList();
                    setState(() {
                      // Same face value in the new currency's minor units.
                      final from = currencySpec(currency).minorFactor;
                      final to = currencySpec(code).minorFactor;
                      currency = code;
                      budgetController.text = _moneyText(
                        list[0] * to ~/ from,
                        code,
                      );
                      sponsorAmountController.text = _moneyText(
                        list[1] * to ~/ from,
                        code,
                      );
                      openingController.text = _moneyText(
                        list[2] * to ~/ from,
                        code,
                      );
                    });
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(
                    tr('Mata uang: {currency}', {
                      'currency': '$currency · ${currencySpec(currency).name}',
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetController,
                  keyboardType: _moneyKeyboard(currency),
                  inputFormatters: [
                    MoneyTextInputFormatter(currency: currency),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('Anggaran final ({currency})', {
                      'currency': currencySpec(currency).symbol,
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sponsorNameController,
                  decoration: InputDecoration(labelText: tr('Nama sponsor')),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sponsorAmountController,
                  keyboardType: _moneyKeyboard(currency),
                  inputFormatters: [
                    MoneyTextInputFormatter(currency: currency),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('Kontribusi sponsor ({currency})', {
                      'currency': currencySpec(currency).symbol,
                    }),
                    helperText: tr(
                      'Boleh diubah kapan saja; perubahan tercatat di riwayat dan target per peserta dihitung ulang.',
                    ),
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingController,
                  keyboardType: _moneyKeyboard(currency),
                  inputFormatters: [
                    MoneyTextInputFormatter(currency: currency),
                  ],
                  decoration: InputDecoration(
                    labelText: tr('Saldo awal ({currency})', {
                      'currency': currencySpec(currency).symbol,
                    }),
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () async {
              final capacity = _parseWholeNumber(capacityController.text);
              final budget = parseMoneyInput(
                budgetController.text,
                currency: currency,
              );
              final sponsor = parseMoneyInput(
                sponsorAmountController.text,
                currency: currency,
              );
              final opening = parseMoneyInput(
                openingController.text,
                currency: currency,
              );
              if ([capacity, budget, sponsor, opening].contains(null)) {
                setState(
                  () => error = tr('Gunakan angka bulat pada semua nilai.'),
                );
                return;
              }
              final next = current.copyWith(
                name: nameController.text,
                startDate: startDate,
                endDate: endDate,
                participantCapacity: capacity,
                finalBudget: budget,
                sponsorName: sponsorNameController.text.trim(),
                sponsorContribution: sponsor,
                openingBalance: opening,
                currency: currency,
              );
              final validation = controller.validateEventUpdate(next);
              if (validation != null) {
                setState(() => error = validation);
                return;
              }
              final changes = _eventChangeSummary(current, next);
              if (changes.isEmpty) {
                Navigator.pop(dialogContext);
                return;
              }
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) => AlertDialog(
                  scrollable: true,
                  title: Text(tr('Simpan perubahan acara?')),
                  content: Text(
                    tr(
                      '{changes}\n\nPerubahan akan dicatat dalam riwayat audit.',
                      {'changes': changes.join('\n')},
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: Text(tr('Periksa lagi')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: Text(tr('Simpan')),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final saveError = await controller.updateEvent(next);
              if (!dialogContext.mounted) return;
              if (saveError != null) {
                setState(() => error = saveError);
                return;
              }
              Navigator.pop(dialogContext);
            },
            child: Text(tr('Tinjau perubahan')),
          ),
        ],
      ),
    ),
  );
}

class _EventDateButton extends StatelessWidget {
  const _EventDateButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(value);
    return Semantics(
      button: true,
      label: tr('Pilih tanggal {label}, {date}', {
        'label': label,
        'date': date,
      }),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$label\n'),
                    TextSpan(
                      text: date,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _moneyText(int minorUnits, String currency) =>
    minorUnits == 0 ? '0' : formatMoneyInput(minorUnits, currency: currency);

TextInputType _moneyKeyboard(String currency) =>
    currencySpec(currency).decimals > 0
    ? const TextInputType.numberWithOptions(decimal: true)
    : TextInputType.number;
