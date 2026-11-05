import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'formatting.dart';
import 'l10n/l10n.dart';
import 'labels.dart';
import 'money.dart';
import 'report_service.dart' show transactionTypeLabel;
import 'settings_page.dart' show openSettings;
import 'status_chip.dart';
import 'transaction_log.dart' show isOutflow;

/// Fetches the public, read-only snapshot behind a share token.
typedef SharedCashbookLoader = Future<Map<String, dynamic>> Function(
  String token,
);

/// What participants see when they open a share link. Data comes from the
/// `get_shared_cashbook` RPC, which already removes device-only state,
/// receipt paths and phone numbers are never part of the payload we show.
class SharedCashbook {
  const SharedCashbook({
    required this.event,
    required this.participants,
    required this.transactions,
    required this.updatedAt,
  });

  final EventRecord event;
  final List<ParticipantRecord> participants;
  final List<TransactionRecord> transactions;
  final DateTime? updatedAt;

  factory SharedCashbook.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? value) => [
      for (final item in (value as List?) ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];
    return SharedCashbook(
      event: EventRecord.fromJson(
        Map<String, dynamic>.from(json['event'] as Map),
      ),
      participants: [
        for (final item in list(json['participants']))
          ParticipantRecord.fromJson(item).copyWith(phone: ''),
      ],
      transactions: [
        for (final item in list(json['transactions']))
          TransactionRecord.fromJson({
            ...item,
            if (item['hasReceipt'] == true) 'receiptStoragePath': 'shared',
          }),
      ],
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String)?.toLocal(),
    );
  }
}

class SharedViewApp extends StatelessWidget {
  const SharedViewApp({required this.token, required this.loader, super.key});

  final String token;
  final SharedCashbookLoader loader;

  @override
  Widget build(BuildContext context) {
    return WargakasMaterialApp(
      home: SharedViewPage(token: token, loader: loader),
    );
  }
}

class SharedViewPage extends StatefulWidget {
  const SharedViewPage({required this.token, required this.loader, super.key});

  final String token;
  final SharedCashbookLoader loader;

  @override
  State<SharedViewPage> createState() => _SharedViewPageState();
}

class _SharedViewPageState extends State<SharedViewPage> {
  late Future<SharedCashbook> _future = _load();

  Future<SharedCashbook> _load() async =>
      SharedCashbook.fromJson(await widget.loader(widget.token));

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next.catchError((_) => SharedCashbook.fromJson(const {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Laporan kas untuk peserta')),
        actions: [
          IconButton(
            onPressed: () => openSettings(context),
            tooltip: tr('Bahasa & tampilan'),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            onPressed: _refresh,
            tooltip: tr('Muat ulang'),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<SharedCashbook>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _SharedError(onRetry: _refresh);
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: _SharedBody(data: snapshot.data!),
            );
          },
        ),
      ),
    );
  }
}

class _SharedError extends StatelessWidget {
  const _SharedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 56),
            const SizedBox(height: 16),
            Text(
              tr('Tautan tidak dapat dibuka'),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Tautan mungkin sudah dimatikan oleh bendahara, atau internet sedang terputus. Minta tautan terbaru kepada bendahara.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(tr('Coba lagi')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedBody extends StatelessWidget {
  const _SharedBody({required this.data});

  final SharedCashbook data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final event = data.event;
    Money.currency = event.currency;
    final transactions = data.transactions;
    final voided = correctedTransactionIds(transactions);
    final target = participantTarget(
      event,
      activeParticipantCount(data.participants),
    );
    final income = incomeTotal(transactions);
    final expense = expenseTotal(transactions);
    final balance = currentBalance(event, transactions);
    final byCategory = expenseTotalsByCategory(transactions, voided);
    final sorted = [...transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final active = data.participants
        .where((p) => p.state == ParticipantState.active)
        .toList();
    final missingReceipts = transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              !voided.contains(t.id) &&
              !t.hasReceipt,
        )
        .length;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(event.name, style: theme.textTheme.headlineSmall),
            Text(
              formatDateRange(event.startDate, event.endDate),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              data.updatedAt == null
                  ? tr('Hanya-baca: data langsung dari buku kas bendahara.')
                  : tr('Hanya-baca. Diperbarui {date}.', {
                      'date': formatDateTime(data.updatedAt!),
                    }),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Saldo kas sekarang'),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      formatMoney(balance),
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    _Line(tr('Saldo awal'), formatMoney(event.openingBalance)),
                    if (event.sponsorContribution > 0)
                      _Line(
                        event.sponsorName.isEmpty
                            ? tr('Sponsor')
                            : tr('Sponsor: {name}', {
                                'name': event.sponsorName,
                              }),
                        formatMoney(event.sponsorContribution),
                      ),
                    _Line(tr('Total pemasukan'), formatMoney(income)),
                    _Line(tr('Total pengeluaran'), formatMoney(expense)),
                    _Line(tr('Target per peserta'), formatMoney(target)),
                  ],
                ),
              ),
            ),
            if (missingReceipts > 0) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    tr('{count} pengeluaran belum memiliki nota.', {
                      'count': missingReceipts,
                    }),
                  ),
                  subtitle: Text(
                    tr(
                      'Tanyakan kepada bendahara jika Anda ingin melihat buktinya.',
                    ),
                  ),
                ),
              ),
            ],
            if (byCategory.isNotEmpty) ...[
              const SizedBox(height: 20),
              _Heading(tr('Pengeluaran per kategori')),
              Card(
                child: Column(
                  children: [
                    for (final (category, total) in byCategory)
                      ListTile(
                        leading: Icon(expenseCategoryIcon(category)),
                        title: Text(expenseCategoryLabel(category)),
                        trailing: Text(formatMoney(total)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            _Heading(tr('Peserta ({count})', {'count': active.length})),
            Card(
              child: Column(
                children: [
                  for (final participant in active)
                    _ParticipantRow(
                      participant: participant,
                      netPaid: participantNetPaid(transactions, participant.id),
                      target: target,
                    ),
                  if (active.isEmpty)
                    ListTile(title: Text(tr('Belum ada peserta.'))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _Heading(tr('Semua transaksi ({count})', {'count': sorted.length})),
            Card(
              child: Column(
                children: [
                  for (final transaction in sorted)
                    _TransactionRow(
                      transaction: transaction,
                      voided: voided.contains(transaction.id),
                      participantName: data.participants
                          .where((p) => p.id == transaction.participantId)
                          .firstOrNull
                          ?.name,
                    ),
                  if (sorted.isEmpty)
                    ListTile(title: Text(tr('Belum ada transaksi.'))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                'Dibuat dengan Wargakas, buku kas bersama yang transparan. Nomor telepon dan foto nota tidak ditampilkan di halaman ini.',
              ),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.netPaid,
    required this.target,
  });

  final ParticipantRecord participant;
  final int netPaid;
  final int target;

  @override
  Widget build(BuildContext context) {
    final state = payState(netPaid, target);
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(participant.name)),
          if (participant.role == ParticipantRole.committee) ...[
            const SizedBox(width: 8),
            StatusPill(
              label: participantRoleLabel(ParticipantRole.committee),
              icon: Icons.badge_outlined,
              tone: Theme.of(context).colorScheme.secondaryContainer,
              onTone: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ],
        ],
      ),
      subtitle: Text(
        tr('Dibayar {paid} dari {target}', {
          'paid': formatMoney(netPaid),
          'target': formatMoney(target),
        }),
      ),
      trailing: PayStateChip(state),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.voided,
    required this.participantName,
  });

  final TransactionRecord transaction;
  final bool voided;
  final String? participantName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = transaction.type == TransactionType.expense;
    final details = <String>[
      transactionTypeLabel(transaction.type),
      if (isExpense && transaction.category != null)
        expenseCategoryLabel(transaction.category!),
      ?participantName,
      formatDateTime(transaction.createdAt),
      if (isExpense) transaction.hasReceipt ? tr('ada nota') : tr('tanpa nota'),
      if (voided) tr('dikoreksi, tidak dihitung'),
    ];
    final amount = transaction.type == TransactionType.correction
        ? ''
        : '${isOutflow(transaction.type) ? '−' : '+'}${formatMoney(transaction.amount)}';
    return ListTile(
      leading: Icon(
        isExpense
            ? expenseCategoryIcon(transaction.category ?? ExpenseCategory.other)
            : Icons.south_west,
      ),
      title: Text(
        transaction.description,
        style: voided
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(details.join(' · ')),
      trailing: Text(
        amount,
        style: theme.textTheme.titleSmall?.copyWith(
          color: voided ? theme.disabledColor : null,
        ),
      ),
    );
  }
}
