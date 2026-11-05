part of '../main.dart';

Future<void> showConflictDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final conflict = controller.syncConflict;
  if (conflict == null) return;
  final local = CashbookSnapshot.fromJson(conflict.localSnapshot);
  final remote = CashbookSnapshot.fromJson(conflict.remoteSnapshot);
  final choice = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('Bandingkan perubahan')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  'Tidak ada penggabungan otomatis. Pilih satu versi untuk seluruh kas acara.',
                ),
              ),
              const SizedBox(height: 12),
              _ConflictVersionCard(
                title: tr('Perangkat ini'),
                snapshot: local,
                detail: tr('Perubahan lokal {date}', {
                  'date': formatDateTime(conflict.operation.createdAt),
                }),
              ),
              _ConflictVersionCard(
                title: tr('Data online'),
                snapshot: remote,
                detail: _remoteConflictDetail(conflict),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('Tutup')),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, 'remote'),
          child: Text(tr('Gunakan data online')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'local'),
          child: Text(tr('Gunakan perangkat ini')),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (confirmContext) => AlertDialog(
      scrollable: true,
      title: Text(tr('Konfirmasi pilihan')),
      content: Text(
        choice == 'remote'
            ? tr(
                'Perubahan lokal yang bertentangan akan dibuang dan data online dipakai.',
              )
            : tr(
                'Seluruh data perangkat ini akan dikirim sebagai versi baru dan dicatat dalam audit.',
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(confirmContext, false),
          child: Text(tr('Batal')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(confirmContext, true),
          child: Text(tr('Ya, lanjutkan')),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (choice == 'remote') {
    await controller.resolveConflictWithRemote();
  } else {
    await controller.resolveConflictWithLocal();
  }
}

class _ConflictVersionCard extends StatelessWidget {
  const _ConflictVersionCard({
    required this.title,
    required this.snapshot,
    required this.detail,
  });

  final String title;
  final CashbookSnapshot snapshot;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final active = snapshot.participants
        .where((item) => item.state == ParticipantState.active)
        .length;
    final income = incomeTotal(snapshot.transactions);
    final expenses = expenseTotal(snapshot.transactions);
    final openReminders = snapshot.reminders
        .where((item) => !item.isDone)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(detail),
            const SizedBox(height: 6),
            Text(tr('{count} peserta aktif', {'count': active})),
            Text(
              tr('Pemasukan tercatat {amount}', {
                'amount': formatMoney(income),
              }),
            ),
            Text(
              tr('Refund dan pengeluaran {amount}', {
                'amount': formatMoney(expenses),
              }),
            ),
            Text(
              tr('Saldo {amount}', {
                'amount': formatMoney(
                  currentBalance(snapshot.event, snapshot.transactions),
                ),
              }),
            ),
            Text(tr('{count} pengingat terbuka', {'count': openReminders})),
          ],
        ),
      ),
    );
  }
}

String _remoteConflictDetail(SyncConflict conflict) {
  final actor = conflict.remoteUpdatedBy;
  final shortActor = actor == null || actor.isEmpty
      ? tr('akun lain')
      : tr('akun {id}', {
          'id': actor.substring(0, actor.length < 8 ? actor.length : 8),
        });
  final time = conflict.remoteUpdatedAt == null
      ? tr('waktu tidak tersedia')
      : formatDateTime(conflict.remoteUpdatedAt!.toLocal());
  return tr('Versi {version} oleh {actor} - {time}', {
    'version': conflict.remoteVersion,
    'actor': shortActor,
    'time': time,
  });
}

int? _parseWholeNumber(String value) {
  final normalized = value.replaceAll(RegExp(r'[^0-9-]'), '');
  return int.tryParse(normalized);
}

List<String> _eventChangeSummary(EventRecord before, EventRecord after) {
  final changes = <String>[];
  if (before.name != after.name.trim()) {
    changes.add(
      tr('Nama: {before} -> {after}', {
        'before': before.name,
        'after': after.name.trim(),
      }),
    );
  }
  if (before.startDate != after.startDate) {
    changes.add(
      tr('Mulai: {before} -> {after}', {
        'before': formatDate(before.startDate),
        'after': formatDate(after.startDate),
      }),
    );
  }
  if (before.endDate != after.endDate) {
    changes.add(
      tr('Selesai: {before} -> {after}', {
        'before': formatDate(before.endDate),
        'after': formatDate(after.endDate),
      }),
    );
  }
  if (before.participantCapacity != after.participantCapacity) {
    changes.add(
      tr('Kapasitas: {before} -> {after}', {
        'before': before.participantCapacity,
        'after': after.participantCapacity,
      }),
    );
  }
  if (before.finalBudget != after.finalBudget) {
    changes.add(
      tr('Anggaran: {before} -> {after}', {
        'before': formatMoney(before.finalBudget),
        'after': formatMoney(after.finalBudget),
      }),
    );
  }
  if (before.sponsorName != after.sponsorName ||
      before.sponsorContribution != after.sponsorContribution) {
    changes.add(
      tr('Sponsor: {before} -> {after}', {
        'before':
            '${before.sponsorName} ${formatMoney(before.sponsorContribution)}',
        'after':
            '${after.sponsorName} ${formatMoney(after.sponsorContribution)}',
      }),
    );
  }
  if (before.openingBalance != after.openingBalance) {
    changes.add(
      tr('Saldo awal: {before} -> {after}', {
        'before': formatMoney(before.openingBalance),
        'after': formatMoney(after.openingBalance),
      }),
    );
  }
  return changes;
}
