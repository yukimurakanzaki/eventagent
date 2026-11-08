import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'money.dart';
import 'l10n/l10n.dart';
import 'cashbook_store.dart';
import 'cashbook_sync.dart';
import 'reminder_notifier.dart';

typedef ReceiptUploader = Future<String?> Function(
  String eventId,
  String transactionId,
  String localPath,
);

class CashbookController extends ChangeNotifier {
  CashbookController._(
    this._store,
    this._snapshot,
    this._reminderNotifier,
    this._syncAdapter, [
    this._receiptUploader,
  ]);

  /// Uploads a local receipt photo and returns its storage path, or null when
  /// uploads are not available (demo mode).
  final ReceiptUploader? _receiptUploader;

  final CashbookStore _store;
  final ReminderNotifier _reminderNotifier;
  final CashbookSyncAdapter? _syncAdapter;
  CashbookSnapshot _snapshot;
  String? _syncError;
  Timer? _retryTimer;
  bool _disposed = false;

  CashbookSnapshot get snapshot => _snapshot;
  EventRecord get event => _snapshot.event;
  List<ParticipantRecord> get participants => _snapshot.participants;
  List<TransactionRecord> get transactions => _snapshot.transactions;
  List<ReminderRecord> get reminders => _snapshot.reminders;
  List<SyncOperation> get pendingOperations => _snapshot.pendingOperations;
  SyncConflict? get syncConflict => _snapshot.syncConflict;
  bool get isReadOnly => syncConflict != null;
  String? get syncError => _syncError;

  int get contributionTarget =>
      participantTarget(event, activeParticipantCount(participants));
  int get balance => currentBalance(event, transactions);

  static Future<CashbookController> bootstrap({
    CashbookSyncAdapter? syncAdapter,
    ReceiptUploader? receiptUploader,
    String storageNamespace = 'demo',
  }) async {
    final store = LocalCashbookStore(namespace: storageNamespace);
    final saved = await store.load();
    final remote = await syncAdapter?.load();
    final notifier = LocalReminderNotifier();
    await notifier.initialize();
    final initial =
        saved != null &&
            (saved.pendingOperations.isNotEmpty || saved.syncConflict != null)
        ? saved
        : remote ?? saved ?? CashbookSnapshot.demo();
    final controller = CashbookController._(
      store,
      initial,
      notifier,
      syncAdapter,
      receiptUploader,
    );
    if (saved == null || remote != null) await store.save(controller.snapshot);
    await controller._schedulePendingReminders();
    await controller._flushPending();
    controller._retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      controller._flushPending();
      controller._uploadPendingReceipts();
    });
    unawaited(controller._uploadPendingReceipts());
    return controller;
  }

  factory CashbookController.forTesting({
    CashbookSnapshot? initial,
    ReminderNotifier? reminderNotifier,
    CashbookSyncAdapter? syncAdapter,
    ReceiptUploader? receiptUploader,
  }) {
    return CashbookController._(
      MemoryCashbookStore(initial),
      initial ?? CashbookSnapshot.demo(),
      reminderNotifier ?? const NoopReminderNotifier(),
      syncAdapter,
      receiptUploader,
    );
  }

  Future<String?> addParticipant(
    String name, {
    String? replacementForId,
    ParticipantRole role = ParticipantRole.participant,
    String phone = '',
  }) async {
    if (isReadOnly) {
      return tr('Selesaikan konflik data sebelum menambah peserta.');
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return tr('Nama peserta wajib diisi.');
    final activeCount = participants
        .where((item) => item.state == ParticipantState.active)
        .length;
    if (activeCount >= event.participantCapacity) {
      return tr('Kapasitas {count} peserta aktif sudah penuh.', {
        'count': event.participantCapacity,
      });
    }
    if (replacementForId != null &&
        !participants.any(
          (item) =>
              item.id == replacementForId &&
              item.state == ParticipantState.cancelled,
        )) {
      return tr(
        'Peserta pengganti harus menggantikan peserta yang dibatalkan.',
      );
    }
    final participant = ParticipantRecord(
      id: _newId('participant'),
      name: trimmedName,
      replacementForId: replacementForId,
      role: role,
      phone: phone.trim(),
    );
    await _commit(
      _snapshot.copyWith(participants: [...participants, participant]),
      entity: 'participant',
      entityId: participant.id,
      action: 'upsert',
      payload: participant.toJson(),
    );
    return null;
  }

  Future<String?> editParticipant(ParticipantRecord participant) async {
    if (isReadOnly) {
      return tr('Selesaikan konflik data sebelum mengedit peserta.');
    }
    final trimmedName = participant.name.trim();
    if (trimmedName.isEmpty) return tr('Nama peserta wajib diisi.');
    final edited = participant.copyWith(
      name: trimmedName,
      phone: participant.phone.trim(),
    );
    final updated = participants
        .map((item) => item.id == edited.id ? edited : item)
        .toList();
    await _commit(
      _snapshot.copyWith(participants: updated),
      entity: 'participant',
      entityId: edited.id,
      action: 'upsert',
      payload: edited.toJson(),
    );
    return null;
  }

  Future<bool> cancelParticipant(
    ParticipantRecord participant,
    RefundPolicy policy, {
    int partialRefundAmount = 0,
  }) async {
    if (isReadOnly) return false;
    final refundable = refundableAmountForParticipant(
      transactions,
      participant.id,
    );
    final amount = switch (policy) {
      RefundPolicy.full => refundable,
      RefundPolicy.partial => partialRefundAmount,
      RefundPolicy.none || RefundPolicy.undecided => 0,
    };
    if (policy == RefundPolicy.partial &&
        (amount <= 0 || amount > refundable)) {
      return false;
    }
    final cancelled = participant.copyWith(
      state: ParticipantState.cancelled,
      refundPolicy: policy,
      cancelledAt: DateTime.now(),
    );
    final updatedParticipants = participants
        .map((item) => item.id == participant.id ? cancelled : item)
        .toList();
    final operations = <SyncOperation>[
      _operation(
        entity: 'participant',
        entityId: participant.id,
        action: 'upsert',
        payload: cancelled.toJson(),
      ),
    ];
    var nextTransactions = transactions;
    if (amount > 0) {
      final refund = TransactionRecord(
        id: _newId('transaction'),
        type: TransactionType.refund,
        amount: amount,
        description: policy == RefundPolicy.full
            ? tr('Refund penuh untuk {name}', {'name': participant.name})
            : tr('Refund sebagian untuk {name}', {'name': participant.name}),
        createdAt: DateTime.now(),
        participantId: participant.id,
      );
      nextTransactions = [...transactions, refund];
      operations.add(
        _operation(
          entity: 'transaction',
          entityId: refund.id,
          action: 'create',
          payload: refund.toJson(),
        ),
      );
    }
    await _commitBatch(
      _snapshot.copyWith(
        participants: updatedParticipants,
        transactions: nextTransactions,
      ),
      operations,
    );
    return true;
  }

  Future<bool> recordTransaction({
    required TransactionType type,
    required int amount,
    required String description,
    String? participantId,
    String? relatedTransactionId,
    ExpenseCategory? category,
    String? receiptPath,
  }) async {
    if (isReadOnly) return false;
    if (amount <= 0 || description.trim().isEmpty) return false;
    // Sponsor money is held on event.sponsorContribution, not in the ledger.
    if (type == TransactionType.sponsor) return false;
    // Corrections carry a reason and a target; only correctTransaction makes them.
    if (type == TransactionType.correction) return false;
    if (type == TransactionType.participantPayment ||
        type == TransactionType.refund) {
      final hasParticipant =
          participantId != null &&
          participants.any((participant) => participant.id == participantId);
      if (!hasParticipant) return false;
    }
    if (type == TransactionType.participantPayment &&
        !participants.any(
          (participant) =>
              participant.id == participantId &&
              participant.state == ParticipantState.active,
        )) {
      return false;
    }
    if (type == TransactionType.refund &&
        amount > refundableAmountForParticipant(transactions, participantId!)) {
      return false;
    }
    final transaction = TransactionRecord(
      id: _newId('transaction'),
      type: type,
      amount: amount,
      description: description.trim(),
      createdAt: DateTime.now(),
      participantId: participantId,
      relatedTransactionId: relatedTransactionId,
      category: type == TransactionType.expense
          ? category ?? ExpenseCategory.other
          : null,
      receiptPath: receiptPath,
    );
    await _commit(
      _snapshot.copyWith(transactions: [...transactions, transaction]),
      entity: 'transaction',
      entityId: transaction.id,
      action: 'create',
      payload: transaction.toJson(),
    );
    if (receiptPath != null) unawaited(_uploadPendingReceipts());
    return true;
  }

  /// Voids a mistaken entry without deleting it. The original stays visible,
  /// marked as corrected, and the correction row records why.
  Future<String?> correctTransaction(
    String transactionId,
    String reason,
  ) async {
    if (isReadOnly) return tr('Selesaikan konflik data sebelum koreksi.');
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) return tr('Alasan koreksi wajib diisi.');
    final original = transactions
        .where((item) => item.id == transactionId)
        .firstOrNull;
    if (original == null) return tr('Transaksi tidak ditemukan.');
    if (original.type == TransactionType.correction) {
      return tr('Koreksi tidak bisa dikoreksi lagi.');
    }
    if (correctedTransactionIds(transactions).contains(original.id)) {
      return tr('Transaksi ini sudah dikoreksi.');
    }
    if (original.type == TransactionType.participantPayment &&
        original.participantId != null &&
        participantNetPaid(transactions, original.participantId!) <
            original.amount) {
      return tr('Pembayaran ini sudah direfund. Koreksi refund-nya dulu.');
    }
    final correction = TransactionRecord(
      id: _newId('transaction'),
      type: TransactionType.correction,
      amount: original.amount,
      description: trimmedReason,
      createdAt: DateTime.now(),
      participantId: original.participantId,
      relatedTransactionId: original.id,
    );
    await _commit(
      _snapshot.copyWith(transactions: [...transactions, correction]),
      entity: 'transaction',
      entityId: correction.id,
      action: 'create',
      payload: correction.toJson(),
    );
    return null;
  }

  Future<String?> addReminder({
    required String title,
    required DateTime dueAt,
    String note = '',
  }) async {
    if (isReadOnly) {
      return tr('Selesaikan konflik data sebelum menambah pengingat.');
    }
    if (title.trim().isEmpty) return tr('Judul pengingat wajib diisi.');
    if (dueAt.isBefore(DateTime.now())) {
      return tr(
        'Jatuh tempo sudah lewat. Pilih tanggal dan jam yang belum lewat.',
      );
    }
    final reminder = ReminderRecord(
      id: _newId('reminder'),
      title: title.trim(),
      dueAt: dueAt,
      note: note.trim(),
    );
    await _commit(
      _snapshot.copyWith(reminders: [...reminders, reminder]),
      entity: 'reminder',
      entityId: reminder.id,
      action: 'upsert',
      payload: reminder.toJson(),
    );
    await _reminderNotifier.schedule(
      id: reminder.id,
      title: reminder.title,
      dueAt: reminder.dueAt,
      note: reminder.note,
    );
    return null;
  }

  Future<void> toggleReminder(ReminderRecord reminder) async {
    if (isReadOnly) return;
    final updated = reminder.copyWith(isDone: !reminder.isDone);
    await _commit(
      _snapshot.copyWith(
        reminders: reminders
            .map((item) => item.id == reminder.id ? updated : item)
            .toList(),
      ),
      entity: 'reminder',
      entityId: reminder.id,
      action: 'upsert',
      payload: updated.toJson(),
    );
    if (updated.isDone) {
      await _reminderNotifier.cancel(updated.id);
    } else {
      await _reminderNotifier.schedule(
        id: updated.id,
        title: updated.title,
        dueAt: updated.dueAt,
        note: updated.note,
      );
    }
  }

  Future<void> _schedulePendingReminders() async {
    for (final reminder in reminders.where((item) => !item.isDone)) {
      await _reminderNotifier.schedule(
        id: reminder.id,
        title: reminder.title,
        dueAt: reminder.dueAt,
        note: reminder.note,
      );
    }
  }

  Future<void> markSyncOperationSynced(String operationId) async {
    await _store.save(
      _snapshot.copyWith(
        pendingOperations: pendingOperations
            .where((item) => item.id != operationId)
            .toList(),
      ),
    );
    _snapshot = _snapshot.copyWith(
      pendingOperations: pendingOperations
          .where((item) => item.id != operationId)
          .toList(),
    );
    notifyListeners();
  }

  /// Lets the app retry queued offline changes as soon as connectivity returns.
  Future<void> retryPendingSync() => _flushPending();

  String? validateEventUpdate(EventRecord next) {
    if (next.name.trim().isEmpty) return tr('Nama acara wajib diisi.');
    if (next.endDate.isBefore(next.startDate)) {
      return tr('Tanggal selesai tidak boleh sebelum tanggal mulai.');
    }
    final activeCount = participants
        .where((item) => item.state == ParticipantState.active)
        .length;
    if (next.participantCapacity <= 0) {
      return tr('Kapasitas harus lebih dari 0.');
    }
    if (next.participantCapacity < activeCount) {
      return tr('Kapasitas tidak boleh kurang dari {count} peserta aktif.', {
        'count': activeCount,
      });
    }
    if (next.finalBudget < 0 ||
        next.sponsorContribution < 0 ||
        next.openingBalance < 0) {
      return tr('Nilai uang tidak boleh negatif.');
    }
    if (next.sponsorContribution + next.openingBalance > next.finalBudget) {
      return tr('Sponsor dan saldo awal tidak boleh melebihi anggaran final.');
    }
    // Sponsor money often arrives or shrinks after collection starts (both
    // interviewed treasurers); the change stays visible in the audit trail.
    if (next.currency != event.currency &&
        currencySpec(next.currency).decimals !=
            currencySpec(event.currency).decimals &&
        (transactions.isNotEmpty ||
            event.finalBudget != 0 ||
            event.sponsorContribution != 0 ||
            event.openingBalance != 0)) {
      return tr(
        'Mata uang hanya bisa diganti ke mata uang dengan jumlah desimal yang sama setelah ada nominal tercatat.',
      );
    }
    return null;
  }

  /// Attaches (or replaces) the receipt photo of an existing transaction.
  /// The ledger amount is untouched, so this is allowed on any entry.
  Future<String?> attachReceipt(
    String transactionId, {
    String? localPath,
    String? storagePath,
  }) async {
    if (isReadOnly) {
      return tr('Selesaikan konflik data sebelum melampirkan nota.');
    }
    final original = transactions
        .where((item) => item.id == transactionId)
        .firstOrNull;
    if (original == null) return tr('Transaksi tidak ditemukan.');
    // A new local photo replaces any uploaded one; it re-uploads below.
    final updated = original.copyWith(
      receiptPath: localPath,
      receiptStoragePath: storagePath,
      clearStoragePath: localPath != null && storagePath == null,
    );
    await _commit(
      _snapshot.copyWith(
        transactions: transactions
            .map((item) => item.id == transactionId ? updated : item)
            .toList(),
      ),
      entity: 'transaction',
      entityId: transactionId,
      action: 'attach_receipt',
      payload: {
        'transactionId': transactionId,
        'receiptStoragePath': ?updated.receiptStoragePath,
        'hasLocalReceipt': updated.receiptPath != null,
      },
    );
    await _uploadPendingReceipts();
    return null;
  }

  /// Uploads receipts that exist only on this device. Safe to call often.
  Future<void> _uploadPendingReceipts() async {
    final uploader = _receiptUploader;
    if (uploader == null || isReadOnly || _disposed) return;
    for (final transaction in [...transactions]) {
      final local = transaction.receiptPath;
      if (local == null || local.isEmpty) continue;
      if (transaction.receiptStoragePath?.isNotEmpty ?? false) continue;
      try {
        final storagePath = await uploader(event.id, transaction.id, local);
        if (storagePath == null) continue;
        final updated = transaction.copyWith(receiptStoragePath: storagePath);
        await _commit(
          _snapshot.copyWith(
            transactions: transactions
                .map((item) => item.id == transaction.id ? updated : item)
                .toList(),
          ),
          entity: 'transaction',
          entityId: transaction.id,
          action: 'receipt_uploaded',
          payload: {'receiptStoragePath': storagePath},
        );
      } catch (_) {
        // Offline or storage unavailable: the photo stays on the device and
        // is retried with the next sync.
        return;
      }
    }
  }

  Future<String?> updateEvent(EventRecord next) async {
    if (isReadOnly) {
      return tr('Selesaikan konflik data sebelum mengedit acara.');
    }
    final normalized = next.copyWith(name: next.name.trim());
    final error = validateEventUpdate(normalized);
    if (error != null) return error;
    if (mapEquals(normalized.toJson(), event.toJson())) return null;
    await _commit(
      _snapshot.copyWith(event: normalized),
      entity: 'event',
      entityId: event.id,
      action: 'update',
      payload: {'before': event.toJson(), 'after': normalized.toJson()},
    );
    return null;
  }

  bool get canRestoreBackup => _syncAdapter == null;

  /// Replaces all local data with a backup. Offline/demo mode only.
  Future<String?> restoreFromBackup(CashbookSnapshot backup) async {
    if (!canRestoreBackup) {
      return tr(
        'Pemulihan cadangan hanya tersedia di mode offline. Data online dipulihkan oleh bendahara melalui cadangan server.',
      );
    }
    final restored = backup.copyWith(
      pendingOperations: const [],
      clearSyncConflict: true,
    );
    _snapshot = restored;
    _syncError = null;
    await _store.save(restored);
    notifyListeners();
    return null;
  }

  Future<void> resolveConflictWithRemote() async {
    final conflict = syncConflict;
    if (conflict == null) return;
    final remote = CashbookSnapshot.fromJson(conflict.remoteSnapshot).copyWith(
      pendingOperations: const [],
      syncVersion: conflict.remoteVersion,
      clearSyncConflict: true,
    );
    _snapshot = remote;
    _syncError = null;
    await _store.save(remote);
    notifyListeners();
  }

  Future<void> resolveConflictWithLocal() async {
    final conflict = syncConflict;
    if (conflict == null) return;
    final local = CashbookSnapshot.fromJson(conflict.localSnapshot);
    final operation = SyncOperation(
      id: _newId('sync'),
      entity: 'cashbook',
      entityId: event.id,
      action: 'conflict_resolution_local',
      createdAt: DateTime.now(),
      payload: {'replacedRemoteVersion': conflict.remoteVersion},
    );
    _snapshot = local.copyWith(
      syncVersion: conflict.remoteVersion,
      pendingOperations: [operation],
      clearSyncConflict: true,
    );
    _syncError = null;
    await _store.save(_snapshot);
    notifyListeners();
    await _flushPending();
  }

  Future<void> _commit(
    CashbookSnapshot next, {
    required String entity,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    if (isReadOnly) return;
    final operation = _operation(
      entity: entity,
      entityId: entityId,
      action: action,
      payload: payload,
    );
    await _commitBatch(next, [operation]);
  }

  SyncOperation _operation({
    required String entity,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) => SyncOperation(
    id: _newId('sync'),
    entity: entity,
    entityId: entityId,
    action: action,
    createdAt: DateTime.now(),
    payload: payload,
  );

  Future<void> _commitBatch(
    CashbookSnapshot next,
    List<SyncOperation> operations,
  ) async {
    if (isReadOnly) return;
    final withQueue = next.copyWith(
      pendingOperations: [...next.pendingOperations, ...operations],
    );
    await _store.save(withQueue);
    _snapshot = withQueue;
    notifyListeners();
    await _flushPending();
  }

  @override
  @override
  void notifyListeners() {
    // Async sync work can finish after the screen let go of this controller.
    if (!_disposed) super.notifyListeners();
  }

  /// Tries once to send queued changes, then releases the controller. Used
  /// when switching events so offline edits are not left waiting until the
  /// event is reopened.
  Future<void> flushThenDispose() async {
    try {
      await _flushPending().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Still queued on the device; retried when the event opens again.
    }
    dispose();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _flushPending() async {
    if (_disposed) return;
    final syncAdapter = _syncAdapter;
    if (syncAdapter == null || pendingOperations.isEmpty) return;
    _syncError = null;
    for (final operation in [...pendingOperations]) {
      try {
        final result = await syncAdapter.push(
          snapshot: _snapshot.copyWith(pendingOperations: const []),
          operation: operation,
        );
        if (result.status == SyncResultStatus.conflict) {
          final remote = result.remoteSnapshot;
          if (remote == null) {
            _syncError = tr(
              'Konflik ditemukan, tetapi data online tidak dapat dibaca.',
            );
            notifyListeners();
            return;
          }
          final local = _snapshot.copyWith(clearSyncConflict: true);
          _snapshot = _snapshot.copyWith(
            syncConflict: SyncConflict(
              localSnapshot: local.toJson(),
              remoteSnapshot: remote.copyWith(clearSyncConflict: true).toJson(),
              operation: operation,
              remoteVersion: result.version,
              remoteUpdatedBy: result.remoteUpdatedBy,
              remoteUpdatedAt: result.remoteUpdatedAt,
              createdAt: DateTime.now(),
            ),
          );
          await _store.save(_snapshot);
          _syncError = tr('Pilih data online atau data perangkat ini.');
          notifyListeners();
          return;
        }
        _snapshot = _snapshot.copyWith(
          syncVersion: result.version,
          pendingOperations: _snapshot.pendingOperations
              .where((item) => item.id != operation.id)
              .toList(),
        );
        await _store.save(_snapshot);
        notifyListeners();
      } catch (_) {
        _syncError = tr(
          'Belum tersambung. Perubahan tetap tersimpan di perangkat.',
        );
        notifyListeners();
        return;
      }
    }
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
