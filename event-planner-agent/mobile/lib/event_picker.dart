import 'package:flutter/material.dart';

import 'event_directory.dart';
import 'app_settings.dart';
import 'formatting.dart';
import 'l10n/l10n.dart';
import 'main.dart' show showInfo;
import 'money.dart';
import 'settings_page.dart' show pickCurrency;

/// Bottom sheet listing the account's events: switch, add, archive, restore.
Future<void> showEventPicker(BuildContext context, EventDirectory directory) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _EventPickerSheet(directory: directory),
  );
}

class _EventPickerSheet extends StatefulWidget {
  const _EventPickerSheet({required this.directory});

  final EventDirectory directory;

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
  late Future<List<EventSummary>> _events = widget.directory.list();
  bool _busy = false;

  void _reload() {
    setState(() {
      _events = widget.directory.list();
    });
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        await showInfo(
          context,
          failure,
          tr('Periksa koneksi internet lalu coba lagi.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(EventSummary event) async {
    if (event.id == widget.directory.currentEventId) {
      Navigator.pop(context);
      return;
    }
    await _run(() async {
      await widget.directory.select(event.id);
      if (mounted) Navigator.pop(context);
    }, tr('Acara belum dapat dibuka'));
  }

  Future<void> _create() async {
    final draft = await showNewEventDialog(context);
    if (draft == null || !mounted) return;
    await _run(() async {
      await widget.directory.create(draft);
      if (mounted) Navigator.pop(context);
    }, tr('Acara belum dapat dibuat'));
  }

  Future<void> _archive(EventSummary event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Arsipkan acara?')),
        content: Text(
          tr(
            '{name} disembunyikan dari daftar acara aktif. Data dan riwayat tetap tersimpan dan bisa dipulihkan kapan saja.',
            {'name': event.name},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr('Arsipkan')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final wasCurrent = event.id == widget.directory.currentEventId;
      await widget.directory.setArchived(event.id, true);
      // Archiving the open event moves to another one, so leave the sheet.
      if (wasCurrent && widget.directory.currentEventId != event.id) {
        if (mounted) Navigator.pop(context);
      } else {
        _reload();
      }
    }, tr('Acara belum dapat diarsipkan'));
  }

  Future<void> _restore(EventSummary event) => _run(() async {
    await widget.directory.setArchived(event.id, false);
    _reload();
  }, tr('Acara belum dapat dipulihkan'));

  @override
  Widget build(BuildContext context) {
    final canManage = widget.directory.canManage;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: FutureBuilder<List<EventSummary>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('Daftar acara belum dapat dimuat.')),
                  TextButton(onPressed: _reload, child: Text(tr('Coba lagi'))),
                ],
              ),
            );
          }
          final events = snapshot.data;
          if (events == null) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final active = events.where((item) => !item.archived).toList();
          final archived = events.where((item) => item.archived).toList();
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(tr('Acara'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (canManage)
                FilledButton.icon(
                  onPressed: _busy ? null : _create,
                  icon: const Icon(Icons.add),
                  label: Text(tr('Buat acara baru')),
                ),
              const SizedBox(height: 8),
              for (final event in active)
                _EventTile(
                  event: event,
                  current: event.id == widget.directory.currentEventId,
                  onTap: _busy ? null : () => _select(event),
                  menuLabel: canManage ? tr('Arsipkan') : null,
                  onMenu: _busy ? null : () => _archive(event),
                ),
              if (archived.isNotEmpty)
                ExpansionTile(
                  title: Text(
                    tr('Diarsipkan ({count})', {'count': archived.length}),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    for (final event in archived)
                      _EventTile(
                        event: event,
                        current: event.id == widget.directory.currentEventId,
                        onTap: _busy ? null : () => _select(event),
                        menuLabel: canManage ? tr('Pulihkan') : null,
                        onMenu: _busy ? null : () => _restore(event),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.current,
    required this.onTap,
    required this.menuLabel,
    required this.onMenu,
  });

  final EventSummary event;
  final bool current;
  final VoidCallback? onTap;
  final String? menuLabel;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: current,
      leading: Icon(
        current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(event.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatDate(event.startDate)}–${formatDate(event.endDate)}',
      ),
      onTap: onTap,
      trailing: menuLabel == null
          ? null
          : TextButton(onPressed: onMenu, child: Text(menuLabel!)),
    );
  }
}

Future<NewEventDraft?> showNewEventDialog(BuildContext context) {
  // ponytail: controllers are not disposed; the route is still animating out
  // when showDialog returns and disposing then throws.
  final nameController = TextEditingController();
  final capacityController = TextEditingController(text: '20');
  final budgetController = TextEditingController(text: '0');
  final today = DateTime.now();
  var startDate = DateTime(today.year, today.month, today.day);
  var endDate = startDate;
  var error = '';
  var currency = AppSettings.instance.defaultCurrency;

  Future<DateTime?> pick(BuildContext dialogContext, DateTime initial) =>
      showDatePicker(
        context: dialogContext,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDate: initial,
      );

  return showDialog<NewEventDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(tr('Acara baru')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tr('Nama acara')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  tr('Mulai {date}', {'date': formatDate(startDate)}),
                ),
                onPressed: () async {
                  final picked = await pick(dialogContext, startDate);
                  if (picked == null) return;
                  setState(() {
                    startDate = picked;
                    if (endDate.isBefore(startDate)) endDate = startDate;
                  });
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  tr('Selesai {date}', {'date': formatDate(endDate)}),
                ),
                onPressed: () async {
                  final picked = await pick(dialogContext, endDate);
                  if (picked != null) setState(() => endDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: tr('Kapasitas peserta')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('new-event-currency'),
                icon: const Icon(Icons.payments_outlined),
                label: Text(
                  tr('Mata uang: {currency}', {
                    'currency': '$currency · ${currencySpec(currency).name}',
                  }),
                ),
                onPressed: () async {
                  final code = await pickCurrency(
                    dialogContext,
                    selected: currency,
                  );
                  if (code == null) return;
                  setState(() {
                    final budget = parseMoneyInput(
                      budgetController.text,
                      currency: currency,
                    );
                    final from = currencySpec(currency).minorFactor;
                    currency = code;
                    final value =
                        budget * currencySpec(code).minorFactor ~/ from;
                    budgetController.text = value == 0
                        ? '0'
                        : formatMoneyInput(value, currency: code);
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetController,
                keyboardType: currencySpec(currency).decimals > 0
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.number,
                inputFormatters: [MoneyTextInputFormatter(currency: currency)],
                decoration: InputDecoration(
                  labelText: tr('Anggaran final ({currency})', {
                    'currency': currencySpec(currency).symbol,
                  }),
                  helperText: tr(
                    'Sponsor dan saldo awal diatur lewat Edit acara.',
                  ),
                  helperMaxLines: 2,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () {
              final draft = NewEventDraft(
                name: nameController.text,
                startDate: startDate,
                endDate: endDate,
                capacity:
                    int.tryParse(
                      capacityController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0,
                budget: parseMoneyInput(
                  budgetController.text,
                  currency: currency,
                ),
                currency: currency,
              );
              final problem = draft.validate();
              if (problem != null) {
                setState(() => error = problem);
                return;
              }
              Navigator.pop(dialogContext, draft);
            },
            child: Text(tr('Buat acara')),
          ),
        ],
      ),
    ),
  );
}
