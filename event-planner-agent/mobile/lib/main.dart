import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cashbook_calculations.dart';
import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'report_service.dart';
import 'supabase_app.dart';
import 'supabase_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseBackend.isDemoMode) {
    final controller = await CashbookController.bootstrap();
    runApp(WargakasApp(controller: controller));
    return;
  }
  final configurationError = SupabaseBackend.configurationError;
  if (configurationError != null) {
    runApp(ConfigurationErrorApp(message: configurationError));
    return;
  }
  try {
    final backend = await SupabaseBackend.initializeFromEnvironment();
    if (backend != null) {
      runApp(SupabaseApp(backend: backend));
      return;
    }
  } catch (_) {
    runApp(
      const ConfigurationErrorApp(
        message: 'Tidak dapat memulai koneksi Supabase. Periksa build hosted.',
      ),
    );
    return;
  }
  runApp(
    const ConfigurationErrorApp(
      message: 'Supabase belum siap. Periksa konfigurasi build.',
    ),
  );
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wargakas',
      debugShowCheckedModeBanner: false,
      theme: wargakasTheme(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Wargakas')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.settings_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi belum dikonfigurasi untuk login.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class WargakasApp extends StatelessWidget {
  const WargakasApp({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    this.accountEmail,
    this.accountRole,
    this.reportShareGateway = const PlatformReportShareGateway(),
    super.key,
  });

  final CashbookController controller;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String email)? onInviteChairperson;
  final String? accountEmail;
  final String? accountRole;
  final ReportShareGateway reportShareGateway;

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
        accountEmail: accountEmail,
        accountRole: accountRole,
        reportShareGateway: reportShareGateway,
      ),
    );
  }
}

ThemeData wargakasTheme() {
  const primary = Color(0xff006b5b);
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xfff8faf8),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
  );
}

class EventHomePage extends StatefulWidget {
  const EventHomePage({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    this.accountEmail,
    this.accountRole,
    this.reportShareGateway = const PlatformReportShareGateway(),
    super.key,
  });

  final CashbookController controller;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String email)? onInviteChairperson;
  final String? accountEmail;
  final String? accountRole;
  final ReportShareGateway reportShareGateway;

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
                  tooltip: 'Tambah ketua acara',
                  icon: const Icon(Icons.person_add_outlined),
                ),
              IconButton(
                onPressed: () => _showHelp(context),
                tooltip: 'Bantuan',
                icon: const Icon(Icons.help_outline),
              ),
              if (widget.onSignOut != null)
                IconButton(
                  onPressed: () => showAccountDialog(
                    context,
                    widget.controller,
                    widget.onSignOut!,
                    email: widget.accountEmail,
                    role: widget.accountRole,
                  ),
                  tooltip: 'Akun',
                  icon: const Icon(Icons.account_circle_outlined),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _EventHeader(
                  event: widget.controller.event,
                  activeCount: widget.controller.participants
                      .where(
                        (participant) =>
                            participant.state == ParticipantState.active,
                      )
                      .length,
                  onEdit: widget.controller.isReadOnly
                      ? null
                      : () => showEventDialog(context, widget.controller),
                ),
                if (widget.controller.syncConflict != null)
                  _ConflictNotice(controller: widget.controller),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
          floatingActionButton: _TransactionShortcut(
            hasConflict: widget.controller.syncConflict != null,
            onPressed: () => _openTransactionEntry(context),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  Future<void> _openTransactionEntry(BuildContext context) async {
    if (widget.controller.syncConflict != null) {
      await showConflictDialog(context, widget.controller);
      return;
    }
    final saved = await showTransactionDialog(context, widget.controller);
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Text('Transaksi berhasil disimpan.'),
        ),
        action: SnackBarAction(
          label: 'Lihat di Uang',
          onPressed: () => setState(() => _selectedIndex = 2),
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 1:
        return ParticipantsPage(controller: widget.controller);
      case 2:
        return MoneyPage(controller: widget.controller);
      case 3:
        return ReportPage(
          controller: widget.controller,
          creatorRole: widget.accountRole ?? 'treasurer',
          shareGateway: widget.reportShareGateway,
        );
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
    required this.activeCount,
    this.onEdit,
  });

  final EventRecord event;
  final int activeCount;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(event.startDate)}–${formatDate(event.endDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$activeCount/${event.participantCapacity} peserta aktif',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ),
          Tooltip(
            message: onEdit == null
                ? 'Selesaikan konflik sebelum mengedit acara'
                : 'Edit acara',
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Edit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictNotice extends StatelessWidget {
  const _ConflictNotice({required this.controller});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        leading: const Icon(Icons.compare_arrows_outlined),
        title: const Text('Pilih versi data sebelum melanjutkan'),
        subtitle: const Text(
          'Pengeditan dihentikan agar perubahan dari dua perangkat tidak saling menimpa.',
        ),
        trailing: FilledButton(
          onPressed: () => showConflictDialog(context, controller),
          child: const Text('Bandingkan'),
        ),
      ),
    );
  }
}

class _TransactionShortcut extends StatelessWidget {
  const _TransactionShortcut({
    required this.hasConflict,
    required this.onPressed,
  });

  final bool hasConflict;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = hasConflict ? 'Selesaikan konflik' : 'Catat transaksi';
    return Semantics(
      button: true,
      label: label,
      child: FloatingActionButton.extended(
        key: const Key('global-transaction-shortcut'),
        tooltip: label,
        onPressed: onPressed,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: Icon(
          hasConflict ? Icons.compare_arrows_outlined : Icons.add_card_outlined,
        ),
        label: Text(label),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _SyncStatusBanner(pendingCount: controller.pendingOperations.length),
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
        _FinancialSummary(
          balance: rupiah(controller.balance),
          contribution: rupiah(controller.contributionTarget),
          helper:
              '(Anggaran − sponsor − saldo awal) ÷ kapasitas ${controller.event.participantCapacity} • $activeCount aktif',
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pengingat', style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: controller.isReadOnly
                  ? null
                  : () => showReminderDialog(context, controller),
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
              margin: const EdgeInsets.only(bottom: 8),
              child: CheckboxListTile(
                value: reminder.isDone,
                onChanged: controller.isReadOnly
                    ? null
                    : (_) => controller.toggleReminder(reminder),
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

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pendingCount == 0
                    ? 'Tersimpan di perangkat • tidak ada perubahan menunggu sinkronisasi.'
                    : '$pendingCount perubahan tersimpan dan menunggu sinkronisasi.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({
    required this.balance,
    required this.contribution,
    required this.helper,
  });

  final String balance;
  final String contribution;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryAmount(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Saldo saat ini',
              value: balance,
            ),
            const Divider(height: 28),
            _SummaryAmount(
              icon: Icons.calculate_outlined,
              label: 'Iuran per peserta',
              value: contribution,
            ),
            const SizedBox(height: 6),
            Text(helper),
          ],
        ),
      ),
    );
  }
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
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
    final active = controller.participants
        .where((item) => item.state == ParticipantState.active)
        .toList();
    final cancelled = controller.participants
        .where((item) => item.state == ParticipantState.cancelled)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: controller.isReadOnly
              ? null
              : () => showParticipantDialog(context, controller),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tambah peserta'),
        ),
        const SizedBox(height: 8),
        Text(
          '${active.length} peserta aktif • kapasitas tetap ${controller.event.participantCapacity}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        if (controller.participants.isEmpty)
          const _EmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada peserta',
            message: 'Tambahkan nama peserta untuk mulai mencatat pembayaran.',
          )
        else ...[
          _ParticipantSection(
            title: 'Peserta aktif',
            participants: active,
            controller: controller,
          ),
          if (cancelled.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ParticipantSection(
              title: 'Dibatalkan',
              participants: cancelled,
              controller: controller,
            ),
          ],
        ],
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
    final additionalIncome = controller.transactions
        .where((item) => item.type == TransactionType.additionalContribution)
        .fold(0, (sum, item) => sum + item.amount);
    final expense = expenseTotal(controller.transactions);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Saldo saat ini'),
            subtitle: Text(
              rupiah(controller.balance),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
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
        _MoneyRow(
          label: 'Kontribusi tambahan',
          value: rupiah(additionalIncome),
        ),
        const Divider(height: 24),
        _MoneyRow(label: 'Pengeluaran bersih', value: rupiah(expense)),
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

class ReportPage extends StatefulWidget {
  const ReportPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _busy = false;
  String? _error;

  CashbookReport _report() => CashbookReport(
    snapshot: widget.controller.snapshot,
    creatorRole: widget.creatorRole,
    generatedAt: DateTime.now(),
  );

  Future<void> _share({required bool pdf}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = _report();
      if (pdf) {
        await widget.shareGateway.sharePdf(report);
      } else {
        await widget.shareGateway.shareWhatsAppText(report);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = pdf
              ? 'PDF belum dapat dibuat atau dibagikan. Coba lagi.'
              : 'Pesan belum dapat dibagikan. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final report = _report();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const Text(
          'Preview laporan',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Periksa nama, status, transaksi, dan saldo sebelum membagikan laporan.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _share(pdf: true),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_busy ? 'Menyiapkan...' : 'Buat dan bagikan PDF'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _share(pdf: false),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Bagikan pesan WhatsApp'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Periksa penerima sebelum mengirim.',
          textAlign: TextAlign.center,
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
                  'Periode ${formatDate(controller.event.startDate)}-${formatDate(controller.event.endDate)}',
                ),
                Text('Dibuat oleh: ${reportRoleLabel(widget.creatorRole)}'),
                const Divider(height: 24),
                Text('Saldo awal: ${rupiah(controller.event.openingBalance)}'),
                Text('Pemasukan peserta: ${rupiah(report.participantIncome)}'),
                Text('Iuran tambahan: ${rupiah(report.additionalIncome)}'),
                Text('Refund dan pengeluaran: ${rupiah(report.expenses)}'),
                Text(
                  'Saldo akhir: ${rupiah(controller.balance)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),
                for (final participant in controller.participants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${participant.name}: ${participant.state == ParticipantState.cancelled ? 'Dibatalkan - ${refundPolicyLabelForReport(participant.refundPolicy)}' : paymentStatus(participantNetPaid(controller.transactions, participant.id), controller.contributionTarget)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticipantSection extends StatelessWidget {
  const _ParticipantSection({
    required this.title,
    required this.participants,
    required this.controller,
  });

  final String title;
  final List<ParticipantRecord> participants;
  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${participants.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < participants.length; index++) ...[
                _ParticipantTile(
                  participant: participants[index],
                  grossPaidAmount: participantPaid(
                    controller.transactions,
                    participants[index].id,
                  ),
                  refundAmount: refundTotalForParticipant(
                    controller.transactions,
                    participants[index].id,
                  ),
                  target: controller.contributionTarget,
                  onTap: controller.isReadOnly
                      ? null
                      : () => showParticipantActions(
                          context,
                          controller,
                          participants[index],
                        ),
                ),
                if (index < participants.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.grossPaidAmount,
    required this.refundAmount,
    required this.target,
    required this.onTap,
  });

  final ParticipantRecord participant;
  final int grossPaidAmount;
  final int refundAmount;
  final int target;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = participant.state == ParticipantState.cancelled;
    final netPaidAmount = grossPaidAmount - refundAmount;
    final status = cancelled
        ? 'Dibatalkan • ${refundPolicyLabel(participant.refundPolicy)}'
        : paymentStatus(netPaidAmount, target);
    final tone = cancelled
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : netPaidAmount >= target
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;
    return ListTile(
      minVerticalPadding: 10,
      leading: CircleAvatar(
        child: Icon(cancelled ? Icons.history : Icons.person_outline),
      ),
      title: Text(participant.name),
      subtitle: Text(
        refundAmount == 0
            ? rupiah(grossPaidAmount)
            : 'Bayar ${rupiah(grossPaidAmount)} • Refund ${rupiah(refundAmount)}\nBersih ${rupiah(netPaidAmount)}',
      ),
      trailing: Container(
        constraints: const BoxConstraints(maxWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: tone,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      onTap: onTap,
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
  String? replacementForId;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tambah peserta'),
      content: StatefulBuilder(
        builder: (dialogContext, setState) => Column(
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
                onChanged: (value) => setState(() => replacementForId = value),
              ),
            ],
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
  nameController.dispose();
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
        final partialAmount = parseRupiahInput(partialRefundController.text);
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
                Text('Maksimum refund: ${rupiah(refundable)}.'),
                if (selectedPolicy == RefundPolicy.full)
                  Text(
                    refundable == 0
                        ? 'Tidak ada pembayaran bersih yang dapat direfund.'
                        : '${rupiah(refundable)} akan dicatat sebagai refund penuh.',
                  ),
                if (selectedPolicy == RefundPolicy.partial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('cancellation-refund-amount'),
                    controller: partialRefundController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [RupiahTextInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nominal refund sebagian (rupiah)',
                      errorText: partialRefundController.text.isEmpty
                          ? null
                          : partialValid
                          ? null
                          : 'Masukkan nominal dari Rp 1 sampai ${rupiah(refundable)}.',
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
  partialRefundController.dispose();
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

Future<bool> showTransactionDialog(
  BuildContext context,
  CashbookController controller,
) async {
  TransactionType? type;
  String? participantId;
  final amountController = TextEditingController();
  final descriptionController = TextEditingController();
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
          title: const Text('Catat transaksi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              onPressed: () => Navigator.pop(dialogContext, false),
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
    text: current.finalBudget.toString(),
  );
  final sponsorNameController = TextEditingController(
    text: current.sponsorName,
  );
  final sponsorAmountController = TextEditingController(
    text: current.sponsorContribution.toString(),
  );
  final openingController = TextEditingController(
    text: current.openingBalance.toString(),
  );
  var startDate = current.startDate;
  var endDate = current.endDate;
  var error = '';
  final sponsorLocked = controller.transactions.any(
    (item) => item.type == TransactionType.participantPayment,
  );

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Edit acara'),
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
                  decoration: const InputDecoration(labelText: 'Nama acara'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tanggal acara',
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _EventDateButton(
                  label: 'Mulai',
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
                  label: 'Selesai',
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
                  decoration: const InputDecoration(
                    labelText: 'Kapasitas peserta',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Anggaran final (Rp)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sponsorNameController,
                  enabled: !sponsorLocked,
                  decoration: const InputDecoration(labelText: 'Nama sponsor'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sponsorAmountController,
                  enabled: !sponsorLocked,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Kontribusi sponsor (Rp)',
                    helperText: sponsorLocked
                        ? 'Dikunci karena pembayaran peserta sudah dimulai.'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openingController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saldo awal (Rp)',
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
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final capacity = _parseWholeNumber(capacityController.text);
              final budget = _parseWholeNumber(budgetController.text);
              final sponsor = _parseWholeNumber(sponsorAmountController.text);
              final opening = _parseWholeNumber(openingController.text);
              if ([capacity, budget, sponsor, opening].contains(null)) {
                setState(() => error = 'Gunakan angka bulat pada semua nilai.');
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
                  title: const Text('Simpan perubahan acara?'),
                  content: Text(
                    '${changes.join('\n')}\n\nPerubahan akan dicatat dalam riwayat audit.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(confirmContext, false),
                      child: const Text('Periksa lagi'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(confirmContext, true),
                      child: const Text('Simpan'),
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
            child: const Text('Tinjau perubahan'),
          ),
        ],
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    nameController.dispose();
    capacityController.dispose();
    budgetController.dispose();
    sponsorNameController.dispose();
    sponsorAmountController.dispose();
    openingController.dispose();
  });
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
      label: 'Pilih tanggal $label, $date',
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
    final income = snapshot.transactions
        .where(
          (item) =>
              item.type == TransactionType.participantPayment ||
              item.type == TransactionType.additionalContribution,
        )
        .fold(0, (sum, item) => sum + item.amount);
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
                  firstDate: DateTime.now(),
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
              final error = await controller.addReminder(
                title: titleController.text,
                dueAt: dueAt,
                note: noteController.text,
              );
              if (error != null) {
                if (context.mounted) {
                  await showInfo(context, 'Pengingat belum disimpan', error);
                }
                return;
              }
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
        title: const Text('Tambah ketua acara'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan email akun yang sudah dibuat di Wargakas.'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email ketua acara'),
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
                        'Masukkan email akun ketua acara.',
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
                        '$email sekarang dapat membuka acara ini sebagai ketua acara.',
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

Future<void> showAccountDialog(
  BuildContext context,
  CashbookController controller,
  Future<void> Function() onSignOut, {
  String? email,
  String? role,
}) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Akun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Email akun'),
                    Text(
                      email ?? 'Akun Wargakas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(roleLabel(role)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Data acara tetap tersimpan di Supabase dan di perangkat ini untuk digunakan saat sinyal lemah.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, 'signOut'),
          icon: const Icon(Icons.logout),
          label: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (action != 'signOut' || !context.mounted) return;

  if (controller.pendingOperations.isNotEmpty) {
    final pendingCount = controller.pendingOperations.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Perubahan belum tersinkron'),
        content: Text(
          '$pendingCount perubahan masih menunggu dikirim. Jika keluar sekarang, perubahan tetap disimpan dan akan dicoba saat akun ini masuk kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tetap di sini'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  try {
    await onSignOut();
  } catch (error) {
    if (context.mounted) {
      await showInfo(context, 'Belum berhasil keluar', authErrorMessage(error));
    }
  }
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

String roleLabel(String? role) {
  switch (role) {
    case 'treasurer':
      return 'Bendahara';
    case 'chairperson':
      return 'Ketua acara';
    default:
      return 'Anggota acara';
  }
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
