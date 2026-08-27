import 'package:flutter/material.dart';

import 'cashbook_calculations.dart';
import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'supabase_app.dart';
import 'supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await SupabaseBackend.initializeFromEnvironment();
  if (backend != null) {
    runApp(SupabaseApp(backend: backend));
    return;
  }
  final controller = await CashbookController.bootstrap();
  runApp(WargakasApp(controller: controller));
}

class WargakasApp extends StatelessWidget {
  const WargakasApp({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    super.key,
  });

  final CashbookController controller;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String email)? onInviteChairperson;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wargakas',
      debugShowCheckedModeBanner: false,
      theme: wargakasTheme(),
      home: EventHomePage(
        controller: controller,
        onSignOut: onSignOut,
        onInviteChairperson: onInviteChairperson,
      ),
    );
  }
}

ThemeData wargakasTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff0b6b5c),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}

class EventHomePage extends StatefulWidget {
  const EventHomePage({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    super.key,
  });

  final CashbookController controller;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String email)? onInviteChairperson;

  @override
  State<EventHomePage> createState() => _EventHomePageState();
}

class _EventHomePageState extends State<EventHomePage> {
  int _selectedIndex = 0;

  static const _destinations = [
    ('Ringkasan', Icons.dashboard_outlined),
    ('Peserta', Icons.groups_outlined),
    ('Uang', Icons.account_balance_wallet_outlined),
    ('Laporan', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final title = _destinations[_selectedIndex].$1;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Acara Saya'),
            actions: [
              if (widget.onInviteChairperson != null)
                IconButton(
                  onPressed: () => showInviteChairpersonDialog(
                    context,
                    widget.onInviteChairperson!,
                  ),
                  tooltip: 'Tambah chairperson',
                  icon: const Icon(Icons.person_add_outlined),
                ),
              IconButton(
                onPressed: () => _showHelp(context),
                tooltip: 'Bantuan',
                icon: const Icon(Icons.help_outline),
              ),
              if (widget.onSignOut != null)
                IconButton(
                  onPressed: () => widget.onSignOut!(),
                  tooltip: 'Keluar',
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _EventHeader(
                  event: widget.controller.event,
                  title: title,
                  activeCount: widget.controller.participants
                      .where(
                        (participant) =>
                            participant.state == ParticipantState.active,
                      )
                      .length,
                ),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.$2),
                  label: destination.$1,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 1:
        return ParticipantsPage(controller: widget.controller);
      case 2:
        return MoneyPage(controller: widget.controller);
      case 3:
        return ReportPage(controller: widget.controller);
      default:
        return SummaryPage(controller: widget.controller);
    }
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bantuan singkat'),
        content: const Text(
          'Gunakan empat menu di bawah untuk mengelola peserta, uang, dan laporan. '
          'Perubahan disimpan di perangkat dan masuk antrean sinkronisasi saat offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({
    required this.event,
    required this.title,
    required this.activeCount,
  });

  final EventRecord event;
  final String title;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.landscape_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(event.startDate)}–${formatDate(event.endDate)} • '
                    '$activeCount/${event.participantCapacity} aktif',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryPage extends StatelessWidget {
  const SummaryPage({required this.controller, super.key});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    final activeCount = controller.participants
        .where((participant) => participant.state == ParticipantState.active)
        .length;
    final reminders = [...controller.reminders]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.wifi_off_outlined),
            title: const Text('Mode offline siap'),
            subtitle: Text(
              controller.pendingOperations.isEmpty
                  ? 'Tidak ada perubahan yang menunggu sinkronisasi.'
                  : '${controller.pendingOperations.length} perubahan menunggu sinkronisasi.',
            ),
          ),
        ),
        if (controller.syncError != null) ...[
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.sync_problem_outlined),
              title: const Text('Sinkronisasi perlu diperiksa'),
              subtitle: Text(controller.syncError!),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Saldo saat ini',
          value: rupiah(controller.balance),
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 12),
        _MetricCard(
          label: 'Iuran per peserta',
          value: rupiah(controller.contributionTarget),
          icon: Icons.calculate_outlined,
          helper:
              '(Anggaran − sponsor − saldo awal) ÷ kapasitas ${controller.event.participantCapacity} • $activeCount aktif',
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pengingat', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: () => showReminderDialog(context, controller),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Tambah'),
            ),
          ],
        ),
        if (reminders.isEmpty)
          const _EmptyState(
            icon: Icons.notifications_none,
            title: 'Belum ada pengingat',
            message: 'Tambahkan tenggat pembayaran atau rencana perjalanan.',
          )
        else
          for (final reminder in reminders.take(3))
            Card(
              child: CheckboxListTile(
                value: reminder.isDone,
                onChanged: (_) => controller.toggleReminder(reminder),
                title: Text(reminder.title),
                subtitle: Text(
                  '${formatDateTime(reminder.dueAt)}${reminder.note.isEmpty ? '' : ' • ${reminder.note}'}',
                ),
                secondary: Icon(
                  reminder.dueAt.isBefore(DateTime.now()) && !reminder.isDone
                      ? Icons.warning_amber_outlined
                      : Icons.notifications_active_outlined,
                ),
              ),
            ),
      ],
    );
  }
}

class ParticipantsPage extends StatelessWidget {
  const ParticipantsPage({required this.controller, super.key});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    final sorted = [...controller.participants]
      ..sort((a, b) => a.state.index.compareTo(b.state.index));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => showParticipantDialog(context, controller),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tambah peserta'),
        ),
        const SizedBox(height: 8),
        Text(
          '${sorted.where((item) => item.state == ParticipantState.active).length} peserta aktif • kapasitas tetap ${controller.event.participantCapacity}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          const _EmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada peserta',
            message: 'Tambahkan nama peserta untuk mulai mencatat pembayaran.',
          )
        else
          for (final participant in sorted)
            _ParticipantTile(
              participant: participant,
              paidAmount: participantPaid(
                controller.transactions,
                participant.id,
              ),
              target: controller.contributionTarget,
              onTap: () =>
                  showParticipantActions(context, controller, participant),
            ),
      ],
    );
  }
}

class MoneyPage extends StatelessWidget {
  const MoneyPage({required this.controller, super.key});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    final participantIncome = controller.transactions
        .where((item) => item.type == TransactionType.participantPayment)
        .fold(0, (sum, item) => sum + item.amount);
    final expense = expenseTotal(controller.transactions);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MoneyRow(
          label: 'Anggaran final',
          value: rupiah(controller.event.finalBudget),
        ),
        _MoneyRow(
          label: 'Sponsor',
          value: rupiah(controller.event.sponsorContribution),
        ),
        _MoneyRow(
          label: 'Saldo awal',
          value: rupiah(controller.event.openingBalance),
        ),
        _MoneyRow(
          label: 'Pembayaran peserta',
          value: rupiah(participantIncome),
        ),
        const Divider(height: 24),
        _MoneyRow(label: 'Pengeluaran bersih', value: rupiah(expense)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Catat pemasukan atau pengeluaran'),
            subtitle: const Text(
              'Refund dicatat sebagai transaksi terpisah dan tidak menghapus riwayat.',
            ),
            onTap: () => showTransactionDialog(context, controller),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: const ListTile(
            leading: Icon(Icons.warning_amber_outlined),
            title: Text('Periksa peserta yang belum lunas'),
            subtitle: Text(
              'Gunakan status pembayaran sebelum mengirim pengingat.',
            ),
          ),
        ),
      ],
    );
  }
}

class ReportPage extends StatelessWidget {
  const ReportPage({required this.controller, super.key});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Preview laporan',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Laporan menampilkan nama peserta, pembayaran, refund, pengeluaran, dan saldo.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.event.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Periode ${formatDate(controller.event.startDate)}–${formatDate(controller.event.endDate)}',
                ),
                Text('Saldo akhir: ${rupiah(controller.balance)}'),
                const Divider(height: 24),
                for (final participant in controller.participants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${participant.name}: ${participant.state == ParticipantState.cancelled ? 'Dibatalkan' : paymentStatus(participantPaid(controller.transactions, participant.id), controller.contributionTarget)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showInfo(
            context,
            'PDF',
            'Handoff PDF akan memakai data lokal ini setelah modul laporan produksi ditambahkan.',
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Buat PDF'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => showInfo(
            context,
            'WhatsApp',
            'Pesan WhatsApp akan dibuat dari nama, status, dan total yang terlihat di preview.',
          ),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Siapkan pesan WhatsApp'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minVerticalPadding: 16,
        leading: Icon(icon, size: 32),
        title: Text(label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            if (helper != null) Text(helper!),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.paidAmount,
    required this.target,
    required this.onTap,
  });

  final ParticipantRecord participant;
  final int paidAmount;
  final int target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = participant.state == ParticipantState.cancelled;
    final status = cancelled
        ? 'Dibatalkan • ${refundPolicyLabel(participant.refundPolicy)}'
        : paymentStatus(paidAmount, target);
    return Card(
      child: ListTile(
        minVerticalPadding: 10,
        leading: CircleAvatar(
          child: Icon(cancelled ? Icons.history : Icons.person_outline),
        ),
        title: Text(participant.name),
        subtitle: Text(
          cancelled ? 'Riwayat pembayaran tetap tersimpan' : rupiah(paidAmount),
        ),
        trailing: SizedBox(
          width: 110,
          child: Text(status, textAlign: TextAlign.end),
        ),
        onTap: onTap,
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
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

Future<void> showParticipantDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final nameController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tambah peserta'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Nama peserta'),
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
            await controller.addParticipant(nameController.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  nameController.dispose();
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
  if (action == 'edit') {
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
            if (name.isNotEmpty) {
              await controller.editParticipant(
                participant.copyWith(name: name),
              );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  nameController.dispose();
}

Future<void> showCancelParticipantDialog(
  BuildContext context,
  CashbookController controller,
  ParticipantRecord participant,
) async {
  var policy = participant.refundPolicy == RefundPolicy.undecided
      ? RefundPolicy.none
      : participant.refundPolicy;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Batalkan peserta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riwayat pembayaran tetap disimpan. Pilih kebijakan refund:',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RefundPolicy>(
              initialValue: policy,
              items: RefundPolicy.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(refundPolicyLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => policy = value ?? policy),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.cancelParticipant(participant, policy);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan pembatalan'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showTransactionDialog(
  BuildContext context,
  CashbookController controller,
) async {
  var type = TransactionType.expense;
  String? participantId;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Catat transaksi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<TransactionType>(
                initialValue: type,
                items: const [
                  DropdownMenuItem(
                    value: TransactionType.expense,
                    child: Text('Pengeluaran'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.participantPayment,
                    child: Text('Pembayaran peserta'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.additionalContribution,
                    child: Text('Kontribusi tambahan'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.refund,
                    child: Text('Refund peserta'),
                  ),
                ],
                onChanged: (value) => setState(() => type = value ?? type),
              ),
              if (type == TransactionType.participantPayment ||
                  type == TransactionType.refund)
                DropdownButtonFormField<String>(
                  initialValue: participantId,
                  hint: const Text('Pilih peserta'),
                  items: controller.participants
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => participantId = value),
                ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah (rupiah)'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Keterangan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final amount =
                  int.tryParse(
                    amountController.text
                        .replaceAll('.', '')
                        .replaceAll(',', ''),
                  ) ??
                  0;
              if (amount <= 0 || descriptionController.text.trim().isEmpty) {
                await showInfo(
                  context,
                  'Data belum lengkap',
                  'Isi jumlah dan keterangan transaksi terlebih dahulu.',
                );
                return;
              }
              if ((type == TransactionType.participantPayment ||
                      type == TransactionType.refund) &&
                  participantId == null) {
                await showInfo(
                  context,
                  'Peserta belum dipilih',
                  'Pilih nama peserta untuk transaksi ini.',
                );
                return;
              }
              await controller.recordTransaction(
                type: type,
                amount: amount,
                description: descriptionController.text,
                participantId: participantId,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan transaksi'),
          ),
        ],
      ),
    ),
  );
  amountController.dispose();
  descriptionController.dispose();
}

Future<void> showReminderDialog(
  BuildContext context,
  CashbookController controller,
) async {
  final titleController = TextEditingController();
  final noteController = TextEditingController();
  var dueAt = DateTime.now().add(const Duration(days: 7));
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Tambah pengingat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Yang perlu diingat',
              ),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(2030),
                  initialDate: dueAt,
                );
                if (picked != null) {
                  setState(
                    () => dueAt = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      dueAt.hour,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.event_outlined),
              label: Text('Jatuh tempo ${formatDateTime(dueAt)}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                await showInfo(
                  context,
                  'Judul belum diisi',
                  'Tulis hal yang perlu diingat terlebih dahulu.',
                );
                return;
              }
              await controller.addReminder(
                title: titleController.text,
                dueAt: dueAt,
                note: noteController.text,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan pengingat'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  noteController.dispose();
}

Future<void> showInviteChairpersonDialog(
  BuildContext context,
  Future<void> Function(String email) onInvite,
) async {
  final emailController = TextEditingController();
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Tambah chairperson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan email akun yang sudah dibuat di Wargakas.'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email chairperson'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final email = emailController.text.trim();
                    if (!email.contains('@')) {
                      await showInfo(
                        dialogContext,
                        'Email belum benar',
                        'Masukkan email akun chairperson.',
                      );
                      return;
                    }
                    setState(() => busy = true);
                    try {
                      await onInvite(email);
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      await showInfo(
                        context,
                        'Akses diberikan',
                        '$email sekarang dapat membuka acara ini sebagai chairperson.',
                      );
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      setState(() => busy = false);
                      await showInfo(
                        dialogContext,
                        'Belum berhasil',
                        error.toString(),
                      );
                    }
                  },
            child: Text(busy ? 'Menyimpan…' : 'Berikan akses'),
          ),
        ],
      ),
    ),
  );
  emailController.dispose();
}

Future<void> showInfo(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Mengerti'),
        ),
      ],
    ),
  );
}

String refundPolicyLabel(RefundPolicy policy) {
  switch (policy) {
    case RefundPolicy.undecided:
      return 'Belum diputuskan';
    case RefundPolicy.none:
      return 'Tidak ada refund';
    case RefundPolicy.partial:
      return 'Refund sebagian';
    case RefundPolicy.full:
      return 'Refund penuh';
  }
}

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String formatDateTime(DateTime date) {
  return '${formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String rupiah(int amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  return 'Rp $sign${groups.join('.')}';
}
