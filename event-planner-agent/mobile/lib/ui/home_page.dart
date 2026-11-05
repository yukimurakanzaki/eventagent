part of '../main.dart';

class EventHomePage extends StatefulWidget {
  const EventHomePage({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    this.accountEmail,
    this.accountRole,
    this.eventDirectory,
    this.reportShareGateway = const PlatformReportShareGateway(),
    this.shareLinkService,
    this.onDeleteAccount,
    this.onInviteMember,
    super.key,
  });

  final ShareLinkService? shareLinkService;

  /// Hosted builds: invite with an explicit role (chairperson or committee).
  final Future<void> Function(String email, String role)? onInviteMember;

  /// Hosted builds only: permanently deletes the signed-in account.
  final Future<void> Function()? onDeleteAccount;
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

  static List<(String, IconData)> get _destinations => [
    (tr('Ringkasan'), Icons.dashboard_outlined),
    (tr('Peserta'), Icons.groups_outlined),
    (tr('Uang'), Icons.account_balance_wallet_outlined),
    (tr('Laporan'), Icons.description_outlined),
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
        Money.currency = widget.controller.event.currency;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Acara Saya')),
            actions: [
              if (widget.onInviteChairperson != null)
                IconButton(
                  onPressed: () => showInviteChairpersonDialog(
                    context,
                    widget.onInviteChairperson!,
                    onInviteMember: widget.onInviteMember,
                  ),
                  tooltip: tr('Tambah ketua acara'),
                  icon: const Icon(Icons.person_add_outlined),
                ),
              IconButton(
                onPressed: () => _showHelp(context),
                tooltip: tr('Bantuan'),
                icon: const Icon(Icons.help_outline),
              ),
              IconButton(
                key: const Key('open-settings'),
                onPressed: () => openSettings(context),
                tooltip: tr('Pengaturan'),
                icon: const Icon(Icons.settings_outlined),
              ),
              if (widget.onSignOut != null)
                IconButton(
                  onPressed: () => showAccountDialog(
                    context,
                    widget.controller,
                    widget.onSignOut!,
                    email: widget.accountEmail,
                    role: widget.accountRole,
                    onDeleteAccount: widget.onDeleteAccount,
                  ),
                  tooltip: tr('Akun'),
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
          child: Text(tr('Transaksi berhasil disimpan.')),
        ),
        action: SnackBarAction(
          label: tr('Lihat di Uang'),
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
          shareLinkService: widget.shareLinkService,
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
        title: Text(tr('Bantuan singkat')),
        content: SingleChildScrollView(
          child: Text(
            tr(
              'Gunakan empat menu di bawah untuk mengelola peserta, uang, dan laporan. Perubahan disimpan di perangkat dan masuk antrean sinkronisasi saat offline.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Mengerti')),
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
                  hint: onSwitch == null ? null : tr('Ganti acara'),
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
                                  tr('{range} • {active}/{capacity} peserta', {
                                    'range': formatDateRange(
                                      event.startDate,
                                      event.endDate,
                                    ),
                                    'active': activeCount,
                                    'capacity': event.participantCapacity,
                                  }),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                    ? tr('Selesaikan konflik sebelum mengedit acara')
                    : tr('Edit acara'),
                // Icon-only at large text so the event name keeps its width.
                child: MediaQuery.textScalerOf(context).scale(1) >= 1.25
                    ? IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined),
                      )
                    : TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: Text(tr('Edit')),
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
          title: Text(tr('Pilih versi data sebelum melanjutkan')),
          subtitle: Text(
            tr(
              'Pengeditan dihentikan agar perubahan dari dua perangkat tidak saling menimpa.',
            ),
          ),
          trailing: FilledButton(
            onPressed: () => showConflictDialog(context, controller),
            child: Text(tr('Bandingkan')),
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
    final label = hasConflict
        ? tr('Selesaikan konflik')
        : tr('Catat transaksi');
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
