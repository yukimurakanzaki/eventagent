import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cashbook_calculations.dart';
import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'event_directory.dart';
import 'event_picker.dart';
import 'report_service.dart';
import 'status_chip.dart';
import 'status_colors.dart';
import 'supabase_app.dart';
import 'supabase_backend.dart';
import 'transaction_log_page.dart';

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
      darkTheme: wargakasTheme(brightness: Brightness.dark),
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
    this.eventDirectory,
    this.reportShareGateway = const PlatformReportShareGateway(),
    super.key,
  });

  final EventDirectory? eventDirectory;
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
      darkTheme: wargakasTheme(brightness: Brightness.dark),
      home: EventHomePage(
        controller: controller,
        onSignOut: onSignOut,
        onInviteChairperson: onInviteChairperson,
        accountEmail: accountEmail,
        accountRole: accountRole,
        eventDirectory: eventDirectory,
        reportShareGateway: reportShareGateway,
      ),
    );
  }
}

/// Lexend for headings/amounts, Source Sans 3 for body (bundled fonts, offline
/// safe). Body is 16sp+ for the 50+ treasurer; see design-system/wargakas.
TextTheme _wargakasTextTheme(TextTheme base) {
  const body = 'SourceSans3';
  const display = 'Lexend';
  TextStyle? b(TextStyle? s, {double? size}) =>
      s?.copyWith(fontFamily: body, fontSize: size, height: 1.5);
  TextStyle? d(TextStyle? s, {double? size, FontWeight? weight}) => s?.copyWith(
    fontFamily: display,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return base.copyWith(
    displayLarge: d(base.displayLarge),
    displayMedium: d(base.displayMedium),
    displaySmall: d(base.displaySmall),
    headlineLarge: d(base.headlineLarge),
    headlineMedium: d(base.headlineMedium),
    headlineSmall: d(base.headlineSmall, size: 28),
    titleLarge: d(base.titleLarge, size: 20),
    titleMedium: d(base.titleMedium, size: 17),
    titleSmall: d(base.titleSmall, size: 15),
    bodyLarge: b(base.bodyLarge, size: 18),
    bodyMedium: b(base.bodyMedium, size: 16),
    bodySmall: b(base.bodySmall, size: 14),
    labelLarge: b(
      base.labelLarge,
      size: 16,
    )?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: b(base.labelMedium, size: 14),
    labelSmall: b(base.labelSmall, size: 13),
  );
}

ThemeData wargakasTheme({Brightness brightness = Brightness.light}) {
  const primary = Color(0xff006b5b);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: _wargakasTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    ),
    extensions: [dark ? StatusColors.dark : StatusColors.light],
    scaffoldBackgroundColor: dark
        ? const Color(0xff0f1715)
        : const Color(0xfff8faf8),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: dark ? const Color(0xff16211e) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
    this.eventDirectory,
    this.reportShareGateway = const PlatformReportShareGateway(),
    super.key,
  });

  final EventDirectory? eventDirectory;
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
  PayState? _participantFilter;

  void _showParticipants([PayState? filter]) => setState(() {
    _participantFilter = filter;
    _selectedIndex = 1;
  });

  static const _destinations = [
    ('Ringkasan', Icons.dashboard_outlined),
    ('Peserta', Icons.groups_outlined),
    ('Uang', Icons.account_balance_wallet_outlined),
    ('Laporan', Icons.description_outlined),
  ];

  /// Material "expanded" width: side rail instead of bottom bar.
  static const _railBreakpoint = 840.0;

  /// Reading width for content on wide screens (tablet / web).
  static const _contentMaxWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final useRail = MediaQuery.sizeOf(context).width >= _railBreakpoint;
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
            child: Row(
              children: [
                if (useRail)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (index) => setState(() {
                      _selectedIndex = index;
                      if (index != 1) _participantFilter = null;
                    }),
                    destinations: [
                      for (final destination in _destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.$2),
                          label: Text(destination.$1),
                        ),
                    ],
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _contentMaxWidth,
                      ),
                      child: Column(
                        children: [
                          _EventHeader(
                            event: widget.controller.event,
                            activeCount: widget.controller.participants
                                .where(
                                  (participant) =>
                                      participant.state ==
                                      ParticipantState.active,
                                )
                                .length,
                            onSwitch: widget.eventDirectory == null
                                ? null
                                : () => showEventPicker(
                                    context,
                                    widget.eventDirectory!,
                                  ),
                            onEdit: widget.controller.isReadOnly
                                ? null
                                : () => showEventDialog(
                                    context,
                                    widget.controller,
                                  ),
                          ),
                          if (widget.controller.syncConflict != null)
                            _ConflictNotice(controller: widget.controller),
                          Expanded(child: _buildPage()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: _TransactionShortcut(
            hasConflict: widget.controller.syncConflict != null,
            onPressed: () => _openTransactionEntry(context),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                      if (index != 1) _participantFilter = null;
                    });
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
        return ParticipantsPage(
          controller: widget.controller,
          filter: _participantFilter,
          onFilterChanged: (filter) =>
              setState(() => _participantFilter = filter),
        );
      case 2:
        return MoneyPage(
          controller: widget.controller,
          onShowUnpaid: () => _showParticipants(PayState.unpaid),
          creatorRole: widget.accountRole ?? 'treasurer',
          shareGateway: widget.reportShareGateway,
        );
      case 3:
        return ReportPage(
          controller: widget.controller,
          creatorRole: widget.accountRole ?? 'treasurer',
          shareGateway: widget.reportShareGateway,
        );
      default:
        return SummaryPage(
          controller: widget.controller,
          onShowParticipants: _showParticipants,
          onShowMoney: () => setState(() => _selectedIndex = 2),
        );
    }
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Bantuan singkat'),
        content: const SingleChildScrollView(
          child: Text(
            'Gunakan empat menu di bawah untuk mengelola peserta, uang, dan laporan. '
            'Perubahan disimpan di perangkat dan masuk antrean sinkronisasi saat offline.',
          ),
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
    this.onSwitch,
    this.onEdit,
  });

  final VoidCallback? onSwitch;
  final EventRecord event;
  final int activeCount;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: onSwitch != null,
                  hint: onSwitch == null ? null : 'Ganti acara',
                  child: InkWell(
                    onTap: onSwitch,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge,
                                ),
                                Text(
                                  '${formatDateRange(event.startDate, event.endDate)}'
                                  ' • $activeCount/${event.participantCapacity} peserta',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onSwitch != null)
                            const ExcludeSemantics(
                              child: Icon(Icons.unfold_more),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: onEdit == null
                    ? 'Selesaikan konflik sebelum mengedit acara'
                    : 'Edit acara',
                // Icon-only at large text so the event name keeps its width.
                child: MediaQuery.textScalerOf(context).scale(1) > 1.3
                    ? IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined),
                      )
                    : TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Edit'),
                      ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ConflictNotice extends StatelessWidget {
  const _ConflictNotice({required this.controller});

  final CashbookController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
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
    return FloatingActionButton.extended(
      key: const Key('global-transaction-shortcut'),
      tooltip: label,
      onPressed: onPressed,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      icon: Icon(
        hasConflict ? Icons.compare_arrows_outlined : Icons.add_card_outlined,
      ),
      label: Text(label),
    );
  }
}

class SummaryPage extends StatelessWidget {
  const SummaryPage({
    required this.controller,
    this.onShowParticipants,
    this.onShowMoney,
    super.key,
  });

  final CashbookController controller;
  final void Function(PayState? filter)? onShowParticipants;
  final VoidCallback? onShowMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    );
    final activeCount = progress.paid + progress.partial + progress.unpaid;
    final reminders = [...controller.reminders]
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final recent = controller.transactions.reversed.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _SyncStatusBanner(pendingCount: controller.pendingOperations.length),
        if (controller.syncError != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.sync_problem_outlined),
                title: const Text('Sinkronisasi perlu diperiksa'),
                subtitle: Text(controller.syncError!),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _BalanceHero(
          balance: rupiah(controller.balance),
          contribution: rupiah(controller.contributionTarget),
          helper:
              '(Anggaran − sponsor − saldo awal) ÷ $activeCount peserta aktif',
          progress: progress,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final state in PayState.values) ...[
                if (state != PayState.paid) const SizedBox(width: 8),
                Expanded(
                  child: _CountTile(
                    state: state,
                    count: switch (state) {
                      PayState.paid => progress.paid,
                      PayState.partial => progress.partial,
                      PayState.unpaid => progress.unpaid,
                    },
                    onTap: onShowParticipants == null
                        ? null
                        : () => onShowParticipants!(state),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Aktivitas terakhir',
          actionLabel: recent.isEmpty ? null : 'Lihat semua',
          onAction: onShowMoney,
        ),
        if (recent.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            message:
                'Ketuk Catat transaksi untuk mencatat uang masuk atau keluar.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _TransactionTile(
                      controller: controller,
                      transaction: recent[i],
                      correctable: false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'Pengingat',
          actionLabel: 'Tambah',
          actionIcon: Icons.add_alert_outlined,
          onAction: controller.isReadOnly
              ? null
              : () => showReminderDialog(context, controller),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (actionLabel != null)
            actionIcon == null
                ? TextButton(onPressed: onAction, child: Text(actionLabel!))
                : TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel!),
                  ),
        ],
      ),
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final synced = pendingCount == 0;
    final onTone = synced ? theme.colorScheme.onSurfaceVariant : colors.onInfo;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: synced ? theme.colorScheme.surfaceContainerLow : colors.info,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  synced
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  color: onTone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  synced
                      ? 'Tersimpan di perangkat • tidak ada perubahan menunggu sinkronisasi.'
                      : '$pendingCount perubahan tersimpan dan menunggu sinkronisasi.',
                  style: TextStyle(color: onTone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-glance answer for a treasurer: how much cash is in hand, and how
/// much of what the group owes has actually been collected.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balance,
    required this.contribution,
    required this.helper,
    required this.progress,
  });

  final String balance;
  final String contribution;
  final String helper;
  final CollectionProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress.fraction * 100).floor();
    final summary =
        'Iuran terkumpul ${rupiah(progress.collected)} dari ${rupiah(progress.expected)} ($percent%)';
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
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
              const SizedBox(height: 16),
              Semantics(
                label: summary,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: 12,
                        backgroundColor: theme.colorScheme.surface.withValues(
                          alpha: 0.5,
                        ),
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(summary),
                  ],
                ),
              ),
              const Divider(height: 32),
              _SummaryAmount(
                icon: Icons.calculate_outlined,
                label: 'Iuran per peserta',
                value: contribution,
              ),
              const SizedBox(height: 6),
              Text(helper, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.state, required this.count, this.onTap});

  final PayState state;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final (tone, onTone) = switch (state) {
      PayState.paid => (colors.success, colors.onSuccess),
      PayState.partial => (colors.warning, colors.onWarning),
      PayState.unpaid => (colors.danger, colors.onDanger),
    };
    final label = PayStateChip.textFor(state);
    return Semantics(
      button: onTap != null,
      label: '$label: $count peserta',
      hint: onTap == null ? null : 'Ketuk untuk melihat daftar',
      excludeSemantics: true,
      child: Material(
        color: tone,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              children: [
                Icon(PayStateChip.iconFor(state), color: onTone),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(color: onTone),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: onTone),
                ),
              ],
            ),
          ),
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
    return MergeSemantics(
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 28)),
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
      ),
    );
  }
}

class ParticipantsPage extends StatelessWidget {
  const ParticipantsPage({
    required this.controller,
    this.filter,
    this.onFilterChanged,
    super.key,
  });

  final CashbookController controller;

  /// Pay-state filter for the active list; null shows everyone.
  final PayState? filter;
  final ValueChanged<PayState?>? onFilterChanged;

  PayState _stateOf(ParticipantRecord participant) => payState(
    participantNetPaid(controller.transactions, participant.id),
    controller.contributionTarget,
  );

  @override
  Widget build(BuildContext context) {
    final active = controller.participants
        .where((item) => item.state == ParticipantState.active)
        .toList();
    final cancelled = controller.participants
        .where((item) => item.state == ParticipantState.cancelled)
        .toList();
    final progress = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    );
    final shown = filter == null
        ? active
        : active.where((item) => _stateOf(item) == filter).toList();
    int countOf(PayState? state) => switch (state) {
      null => active.length,
      PayState.paid => progress.paid,
      PayState.partial => progress.partial,
      PayState.unpaid => progress.unpaid,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: controller.isReadOnly
              ? null
              : () => showParticipantDialog(context, controller),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Tambah peserta'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final state in <PayState?>[null, ...PayState.values])
              ChoiceChip(
                avatar: Icon(
                  filter == state
                      ? Icons.check
                      : state == null
                      ? Icons.groups_outlined
                      : PayStateChip.iconFor(state),
                ),
                label: Text(
                  '${state == null ? 'Semua' : PayStateChip.textFor(state)} (${countOf(state)})',
                ),
                selected: filter == state,
                showCheckmark: false,
                onSelected: onFilterChanged == null
                    ? null
                    : (_) => onFilterChanged!(state),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${active.length} peserta aktif • kapasitas ${controller.event.participantCapacity}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (controller.participants.isEmpty)
          const _EmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada peserta',
            message: 'Tambahkan nama peserta untuk mulai mencatat pembayaran.',
          )
        else ...[
          if (shown.isEmpty && filter != null)
            _EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title:
                  'Tidak ada peserta ${PayStateChip.textFor(filter!).toLowerCase()}',
              message: 'Ubah filter untuk melihat peserta lain.',
              actionLabel: 'Tampilkan semua',
              onAction: onFilterChanged == null
                  ? null
                  : () => onFilterChanged!(null),
            )
          else
            _ParticipantSection(
              title: filter == null
                  ? 'Peserta aktif'
                  : 'Peserta ${PayStateChip.textFor(filter!).toLowerCase()}',
              participants: shown,
              controller: controller,
            ),
          if (cancelled.isNotEmpty && filter == null) ...[
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
  const MoneyPage({
    required this.controller,
    required this.creatorRole,
    required this.shareGateway,
    this.onShowUnpaid,
    super.key,
  });

  final CashbookController controller;
  final String creatorRole;
  final ReportShareGateway shareGateway;
  final VoidCallback? onShowUnpaid;

  /// Inline history stays short; the log page owns the full, filterable list.
  static const _inlineLimit = 15;

  void _openLog(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TransactionLogPage(
        controller: controller,
        creatorRole: creatorRole,
        shareGateway: shareGateway,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<StatusColors>()!;
    final counted = effectiveTransactions(controller.transactions);
    final participantIncome = counted
        .where((item) => item.type == TransactionType.participantPayment)
        .fold(0, (sum, item) => sum + item.amount);
    final additionalIncome = counted
        .where((item) => item.type == TransactionType.additionalContribution)
        .fold(0, (sum, item) => sum + item.amount);
    final expense = expenseTotal(controller.transactions);
    final unpaid = collectionProgress(
      controller.participants,
      controller.transactions,
      controller.contributionTarget,
    ).unpaid;
    final history = controller.transactions.reversed.toList();
    final shown = history.take(_inlineLimit).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryAmount(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Saldo saat ini',
                    value: rupiah(controller.balance),
                  ),
                  const Divider(height: 28),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: 'Pembayaran peserta',
                    value: '+${rupiah(participantIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_downward,
                    label: 'Kontribusi tambahan',
                    value: '+${rupiah(additionalIncome)}',
                  ),
                  _FlowRow(
                    icon: Icons.arrow_upward,
                    label: 'Pengeluaran bersih',
                    value: '−${rupiah(expense)}',
                  ),
                ],
              ),
            ),
          ),
        ),
        if (unpaid > 0 && onShowUnpaid != null) ...[
          const SizedBox(height: 8),
          Card(
            color: colors.info,
            child: ListTile(
              onTap: onShowUnpaid,
              leading: Icon(Icons.groups_outlined, color: colors.onInfo),
              title: Text(
                '$unpaid peserta belum bayar',
                style: TextStyle(color: colors.onInfo),
              ),
              subtitle: Text(
                'Lihat daftar sebelum mengirim pengingat.',
                style: TextStyle(color: colors.onInfo),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.onInfo),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text('Anggaran dan dana awal'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Riwayat transaksi',
          actionLabel: 'Filter & laporan rinci',
          actionIcon: Icons.filter_list,
          onAction: () => _openLog(context),
        ),
        Text(
          'Salah catat? Ketuk transaksinya untuk koreksi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi',
            message:
                'Ketuk Catat transaksi untuk mencatat uang masuk atau keluar.',
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i == 0 || !_sameDay(shown[i - 1].createdAt, shown[i].createdAt))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 4),
              child: Semantics(
                header: true,
                child: Text(
                  formatDateLong(shown[i].createdAt),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Card(
            margin: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TransactionTile(
                controller: controller,
                transaction: shown[i],
                showDate: false,
              ),
            ),
          ),
        ],
        if (history.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => _openLog(context),
              child: Text('Lihat semua ${history.length} transaksi'),
            ),
          ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Label on the left, amount on the right; stacked at large text so neither
/// gets squeezed on a narrow phone.
class _LabelValueRow extends StatelessWidget {
  const _LabelValueRow({
    required this.label,
    required this.value,
    this.icon,
    this.labelStyle,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final text = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: labelStyle),
              Text(value, style: valueStyle),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text(label, style: labelStyle)),
              const SizedBox(width: 8),
              Text(value, style: valueStyle),
            ],
          );
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 20)),
            const SizedBox(width: 8),
          ],
          Expanded(child: text),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _LabelValueRow(
        icon: icon,
        label: label,
        value: value,
        labelStyle: theme.textTheme.bodyLarge,
        valueStyle: theme.textTheme.titleMedium,
      ),
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

  CashbookReport _report([ReportKind kind = ReportKind.summary]) =>
      CashbookReport(
        snapshot: widget.controller.snapshot,
        creatorRole: widget.creatorRole,
        generatedAt: DateTime.now(),
        kind: kind,
      );

  Future<void> _share({
    required bool pdf,
    ReportKind kind = ReportKind.summary,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final report = _report(kind);
      String? note;
      if (pdf) {
        final saved = await widget.shareGateway.sharePdf(report);
        if (saved != null) note = 'Salinan PDF tersimpan di: $saved';
      } else {
        await widget.shareGateway.shareWhatsAppText(report);
        note =
            'Teks laporan disalin. Jika WhatsApp tidak muncul, tempel manual.';
      }
      if (note != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(note)));
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
    final theme = Theme.of(context);
    final report = _report();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Semantics(
          header: true,
          child: Text('Preview laporan', style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 4),
        Text(
          'Periksa nama, status, transaksi, dan saldo sebelum membagikan laporan.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : () => _share(pdf: true),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_busy ? 'Menyiapkan...' : 'Buat dan bagikan PDF'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _share(pdf: false),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Bagikan pesan WhatsApp'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _share(pdf: true, kind: ReportKind.portfolio),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('Portofolio acara lengkap (PDF)'),
        ),
        const SizedBox(height: 8),
        Text(
          'Periksa penerima sebelum mengirim.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.event.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Periode ${formatDateRange(controller.event.startDate, controller.event.endDate)}',
                ),
                Text('Dibuat oleh: ${reportRoleLabel(widget.creatorRole)}'),
                Text(
                  'Disusun ${formatDateTime(report.generatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                _ReportRow(
                  'Saldo awal',
                  rupiah(controller.event.openingBalance),
                ),
                _ReportRow(
                  'Pemasukan peserta',
                  rupiah(report.participantIncome),
                ),
                _ReportRow('Iuran tambahan', rupiah(report.additionalIncome)),
                _ReportRow('Refund dan pengeluaran', rupiah(report.expenses)),
                const Divider(height: 16),
                _ReportRow(
                  'Saldo akhir',
                  rupiah(controller.balance),
                  bold: true,
                ),
                const Divider(height: 24),
                Text('Status peserta', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final participant in controller.participants)
                  _ReportParticipantRow(
                    participant: participant,
                    netPaid: participantNetPaid(
                      controller.transactions,
                      participant.id,
                    ),
                    target: controller.contributionTarget,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _LabelValueRow(
        label: label,
        value: value,
        labelStyle: style,
        valueStyle: style?.copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ReportParticipantRow extends StatelessWidget {
  const _ReportParticipantRow({
    required this.participant,
    required this.netPaid,
    required this.target,
  });

  final ParticipantRecord participant;
  final int netPaid;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = participant.state == ParticipantState.cancelled;
    final state = payState(netPaid, target);
    final remaining = target - netPaid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MergeSemantics(
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Text(participant.name, style: theme.textTheme.bodyLarge),
            ),
            if (cancelled)
              StatusPill(
                label:
                    'Dibatalkan - ${refundPolicyLabelForReport(participant.refundPolicy)}',
                icon: Icons.history,
                tone: theme.colorScheme.surfaceContainerHighest,
                onTone: theme.colorScheme.onSurfaceVariant,
              )
            else ...[
              PayStateChip(state),
              if (state != PayState.paid)
                Text(
                  'kurang ${rupiah(remaining)}',
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ],
        ),
      ),
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

  Future<void> _quickPay(
    BuildContext context,
    ParticipantRecord participant,
    int remaining,
  ) async {
    final saved = await showTransactionDialog(
      context,
      controller,
      initialType: TransactionType.participantPayment,
      initialParticipantId: participant.id,
      initialAmount: remaining,
      initialDescription: 'Iuran peserta',
    );
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Semantics(
          liveRegion: true,
          child: Text('Pembayaran ${participant.name} disimpan.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            '$title (${participants.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                  onPay: controller.isReadOnly
                      ? null
                      : (remaining) =>
                            _quickPay(context, participants[index], remaining),
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
    required this.onPay,
  });

  final ParticipantRecord participant;
  final int grossPaidAmount;
  final int refundAmount;
  final int target;
  final VoidCallback? onTap;
  final void Function(int remaining)? onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cancelled = participant.state == ParticipantState.cancelled;
    final netPaidAmount = grossPaidAmount - refundAmount;
    final state = payState(netPaidAmount, target);
    final remaining = target - netPaidAmount;
    final initial = participant.name.trim().isEmpty
        ? '?'
        : participant.name.trim().characters.first.toUpperCase();
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                backgroundColor: cancelled
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.primaryContainer,
                foregroundColor: cancelled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
                child: cancelled ? const Icon(Icons.history) : Text(initial),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(participant.name, style: theme.textTheme.bodyLarge),
                  if (cancelled)
                    Text(
                      refundAmount == 0
                          ? 'Dibayar ${rupiah(grossPaidAmount)}'
                          : 'Bayar ${rupiah(grossPaidAmount)} • Refund ${rupiah(refundAmount)}',
                      style: muted,
                    )
                  else ...[
                    Text(
                      '${refundAmount == 0 ? 'Dibayar' : 'Bersih'} ${rupiah(netPaidAmount)} dari ${rupiah(target)}',
                      style: muted,
                    ),
                    if (refundAmount > 0)
                      Text(
                        'Bayar ${rupiah(grossPaidAmount)} • Refund ${rupiah(refundAmount)}',
                        style: muted,
                      ),
                    if (remaining > 0)
                      Text(
                        'Kurang ${rupiah(remaining)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (cancelled)
                        StatusPill(
                          label:
                              'Dibatalkan • ${refundPolicyLabel(participant.refundPolicy)}',
                          icon: Icons.history,
                          tone: theme.colorScheme.surfaceContainerHighest,
                          onTone: theme.colorScheme.onSurfaceVariant,
                        )
                      else
                        PayStateChip(state),
                      if (!cancelled && remaining > 0 && onPay != null)
                        TextButton.icon(
                          onPressed: () => onPay!(remaining),
                          icon: const Icon(Icons.add_card_outlined),
                          label: const Text('Catat bayar'),
                        ),
                    ],
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.controller,
    required this.transaction,
    this.correctable = true,
    this.showDate = true,
  });

  final CashbookController controller;
  final TransactionRecord transaction;

  /// Tap-to-correct is only offered where the full history is shown.
  final bool correctable;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final isCorrection = transaction.type == TransactionType.correction;
    final corrected = correctedTransactionIds(controller.transactions)
        .contains(transaction.id);
    final participant = controller.participants
        .where((item) => item.id == transaction.participantId)
        .firstOrNull;
    final original = controller.transactions
        .where((item) => item.id == transaction.relatedTransactionId)
        .firstOrNull;
    final title = isCorrection
        ? 'Koreksi: ${original?.description ?? 'transaksi'}'
        : transaction.description;
    final detail = [
      transactionTypeLabel(transaction.type),
      if (participant != null) participant.name,
      if (showDate) formatDate(transaction.createdAt),
      if (isCorrection) 'Alasan: ${transaction.description}',
      if (corrected) 'Dikoreksi, tidak dihitung',
    ].join(' • ');
    final struck = corrected
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    final colors = Theme.of(context).extension<StatusColors>()!;
    final outflow =
        transaction.type == TransactionType.expense ||
        transaction.type == TransactionType.refund;
    // Direction is carried by the sign and icon, color only reinforces it.
    final amountColor = corrected || isCorrection
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : outflow
        ? colors.onDanger
        : colors.onSuccess;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(
        child: Icon(
          isCorrection || corrected
              ? Icons.undo
              : outflow
              ? Icons.arrow_upward
              : Icons.arrow_downward,
          color: amountColor,
        ),
      ),
      title: Text(title, style: struck),
      subtitle: Text(detail),
      trailing: Text(
        isCorrection
            ? '-'
            : '${outflow ? '−' : '+'}${rupiah(transaction.amount)}',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: amountColor)
            .merge(struck),
      ),
      onTap: !correctable || isCorrection || corrected || controller.isReadOnly
          ? null
          : () =>
                showCorrectTransactionDialog(context, controller, transaction),
    );
  }
}

Future<void> showCorrectTransactionDialog(
  BuildContext context,
  CashbookController controller,
  TransactionRecord transaction,
) async {
  // ponytail: no TextEditingController, so nothing is disposed while the
  // dialog is still animating out over a rebuilding list.
  var reason = '';
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Koreksi transaksi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${transaction.description} • ${rupiah(transaction.amount)}'),
          const SizedBox(height: 8),
          const Text(
            'Transaksi ini tidak dihapus. Ia tetap terlihat dicoret di riwayat '
            'dan laporan, dan tidak dihitung lagi. Setelah itu catat ulang '
            'transaksi yang benar.',
          ),
          TextField(
            onChanged: (value) => reason = value,
            decoration: const InputDecoration(
              labelText: 'Alasan koreksi',
              hintText: 'Contoh: salah ketik nominal',
            ),
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
            final error = await controller.correctTransaction(
              transaction.id,
              reason,
            );
            if (error != null) {
              if (context.mounted) {
                await showInfo(context, 'Koreksi belum disimpan', error);
              }
              return;
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Simpan koreksi'),
        ),
      ],
    ),
  );
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: MergeSemantics(
          child: Column(
            children: [
              ExcludeSemantics(child: Icon(icon, size: 40)),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
            ],
          ),
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
  final sponsorLocked = !sponsorEditable(controller.transactions);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        scrollable: true,
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
                  scrollable: true,
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
        scrollable: true,
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
        scrollable: true,
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
      scrollable: true,
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
        scrollable: true,
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
      scrollable: true,
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

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "12 Sep 2026": month names read faster than 12/09/2026 for older users.
String formatDateLong(DateTime date) =>
    '${date.day} ${_monthShort[date.month - 1]} ${date.year}';

String formatDateRange(DateTime start, DateTime end) {
  if (start.year != end.year) {
    return '${formatDateLong(start)} – ${formatDateLong(end)}';
  }
  if (start.month != end.month) {
    return '${start.day} ${_monthShort[start.month - 1]} – ${formatDateLong(end)}';
  }
  if (start.day == end.day) return formatDateLong(start);
  return '${start.day}–${end.day} ${_monthShort[end.month - 1]} ${end.year}';
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
