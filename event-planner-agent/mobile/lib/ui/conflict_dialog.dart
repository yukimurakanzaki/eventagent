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
      title: const Text('Bandingkan perubahan'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tidak ada penggabungan otomatis. Pilih satu versi untuk seluruh kas acara.',
              ),
              const SizedBox(height: 12),
              _ConflictVersionCard(
                title: 'Perangkat ini',
                snapshot: local,
                detail:
                    'Perubahan lokal ${formatDateTime(conflict.operation.createdAt)}',
              ),
              _ConflictVersionCard(
                title: 'Data online',
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
          child: const Text('Tutup'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, 'remote'),
          child: const Text('Gunakan data online'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'local'),
          child: const Text('Gunakan perangkat ini'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (confirmContext) => AlertDialog(
      scrollable: true,
      title: const Text('Konfirmasi pilihan'),
      content: Text(
        choice == 'remote'
            ? 'Perubahan lokal yang bertentangan akan dibuang dan data online dipakai.'
            : 'Seluruh data perangkat ini akan dikirim sebagai versi baru dan dicatat dalam audit.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(confirmContext, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(confirmContext, true),
          child: const Text('Ya, lanjutkan'),
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
            Text('$active peserta aktif'),
            Text('Pemasukan tercatat ${rupiah(income)}'),
            Text('Refund dan pengeluaran ${rupiah(expenses)}'),
            Text(
              'Saldo ${rupiah(currentBalance(snapshot.event, snapshot.transactions))}',
            ),
            Text('$openReminders pengingat terbuka'),
          ],
        ),
      ),
    );
  }
}

String _remoteConflictDetail(SyncConflict conflict) {
  final actor = conflict.remoteUpdatedBy;
  final shortActor = actor == null || actor.isEmpty
      ? 'akun lain'
      : 'akun ${actor.substring(0, actor.length < 8 ? actor.length : 8)}';
  final time = conflict.remoteUpdatedAt == null
      ? 'waktu tidak tersedia'
      : formatDateTime(conflict.remoteUpdatedAt!.toLocal());
  return 'Versi ${conflict.remoteVersion} oleh $shortActor - $time';
}

int? _parseWholeNumber(String value) {
  final normalized = value.replaceAll(RegExp(r'[^0-9-]'), '');
  return int.tryParse(normalized);
}

List<String> _eventChangeSummary(EventRecord before, EventRecord after) {
  final changes = <String>[];
  if (before.name != after.name.trim()) {
    changes.add('Nama: ${before.name} -> ${after.name.trim()}');
  }
  if (before.startDate != after.startDate) {
    changes.add(
      'Mulai: ${formatDate(before.startDate)} -> ${formatDate(after.startDate)}',
    );
  }
  if (before.endDate != after.endDate) {
    changes.add(
      'Selesai: ${formatDate(before.endDate)} -> ${formatDate(after.endDate)}',
    );
  }
  if (before.participantCapacity != after.participantCapacity) {
    changes.add(
      'Kapasitas: ${before.participantCapacity} -> ${after.participantCapacity}',
    );
  }
  if (before.finalBudget != after.finalBudget) {
    changes.add(
      'Anggaran: ${rupiah(before.finalBudget)} -> ${rupiah(after.finalBudget)}',
    );
  }
  if (before.sponsorName != after.sponsorName ||
      before.sponsorContribution != after.sponsorContribution) {
    changes.add(
      'Sponsor: ${before.sponsorName} ${rupiah(before.sponsorContribution)} -> '
      '${after.sponsorName} ${rupiah(after.sponsorContribution)}',
    );
  }
  if (before.openingBalance != after.openingBalance) {
    changes.add(
      'Saldo awal: ${rupiah(before.openingBalance)} -> ${rupiah(after.openingBalance)}',
    );
  }
  return changes;
}
