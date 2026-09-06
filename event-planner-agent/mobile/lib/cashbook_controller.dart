import 'package:flutter/foundation.dart';

import 'cashbook_calculations.dart';
import 'cashbook_models.dart';
import 'cashbook_store.dart';
import 'cashbook_sync.dart';
import 'reminder_notifier.dart';

class CashbookController extends ChangeNotifier {
  CashbookController._(
    this._store,
    this._snapshot,
    this._reminderNotifier,
    this._syncAdapter,
  );

  final CashbookStore _store;
  final ReminderNotifier _reminderNotifier;
  final CashbookSyncAdapter? _syncAdapter;
  CashbookSnapshot _snapshot;
  String? _syncError;

  CashbookSnapshot get snapshot => _snapshot;
  EventRecord get event => _snapshot.event;
  List<ParticipantRecord> get participants => _snapshot.participants;
  List<TransactionRecord> get transactions => _snapshot.transactions;
  List<ReminderRecord> get reminders => _snapshot.reminders;
  List<SyncOperation> get pendingOperations => _snapshot.pendingOperations;
  SyncConflict? get syncConflict => _snapshot.syncConflict;
  bool get isReadOnly => syncConflict != null;
  String? get syncError => _syncError;

  int get contributionTarget => participantTarget(event);
  int get balance => currentBalance(event, transactions);

  static Future<CashbookController> bootstrap({
    CashbookSyncAdapter? syncAdapter,
    String storageNamespace = 'demo',
  }) async {
    final store = LocalCashbookStore(namespace: storageNamespace);
    final saved = await store.load();
    final remote = await syncAdapter?.load();
    final notifier = LocalReminderNotifier();
    await notifier.initialize();
    final initial = saved != null &&
            (saved.pendingOperations.isNotEmpty || saved.syncConflict != null)
        ? saved
        : remote ?? saved ?? CashbookSnapshot.demo();
    final controller = CashbookController._(
      store,
      initial,
      notifier,
      syncAdapter,
    );
    if (saved == null || remote != null) await store.save(controller.snapshot);
    await controller._schedulePendingReminders();
    await controller._flushPending();
    return controller;
  }

  factory CashbookController.forTesting({
    CashbookSnapshot? initial,
    ReminderNotifier? reminderNotifier,
    CashbookSyncAdapter? syncAdapter,
  }) {
    return CashbookController._(
      MemoryCashbookStore(initial),
      initial ?? CashbookSnapshot.demo(),
      reminderNotifier ?? const NoopReminderNotifier(),
      syncAdapter,
    );
  }

  Future<void> addParticipant(String name, {String? replacementForId}) async {
    if (isReadOnly) return;
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    final participant = ParticipantRecord(
      id: _newId('participant'),
      name: trimmedName,
      replacementForId: replacementForId,
    );
    await _commit(
      _snapshot.copyWith(participants: [...participants, participant]),
      entity: 'participant',
      entityId: participant.id,
      action: 'upsert',
      payload: participant.toJson(),
    );
  }

  Future<void> editParticipant(ParticipantRecord participant) async {
    if (isReadOnly) return;
    final updated = participants
        .map((item) => item.id == participant.id ? participant : item)
        .toList();
    await _commit(
      _snapshot.copyWith(participants: updated),
      entity: 'participant',
      entityId: participant.id,
      action: 'upsert',
      payload: participant.toJson(),
    );
  }

  Future<void> cancelParticipant(
    ParticipantRecord participant,
    RefundPolicy policy,
  ) async {
    if (isReadOnly) return;
    await editParticipant(
      participant.copyWith(
        state: ParticipantState.cancelled,
        refundPolicy: policy,
        cancelledAt: DateTime.now(),
      ),
    );
  }

  Future<void> recordTransaction({
    required TransactionType type,
    required int amount,
    required String description,
    String? participantId,
    String? relatedTransactionId,
  }) async {
    if (isReadOnly) return;
    if (amount <= 0 || description.trim().isEmpty) return;
    if (type == TransactionType.sponsor && !canAddSponsor(transactions)) return;
    final transaction = TransactionRecord(
      id: _newId('transaction'),
      type: type,
      amount: amount,
      description: description.trim(),
      createdAt: DateTime.now(),
      participantId: participantId,
      relatedTransactionId: relatedTransactionId,
    );
    await _commit(
      _snapshot.copyWith(transactions: [...transactions, transaction]),
      entity: 'transaction',
      entityId: transaction.id,
      action: 'create',
      payload: transaction.toJson(),
    );
  }

  Future<void> addReminder({
    required String title,
    required DateTime dueAt,
    String note = '',
  }) async {
    if (isReadOnly) return;
    if (title.trim().isEmpty) return;
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

  String? validateEventUpdate(EventRecord next) {
    if (next.name.trim().isEmpty) return 'Nama acara wajib diisi.';
    if (next.endDate.isBefore(next.startDate)) {
      return 'Tanggal selesai tidak boleh sebelum tanggal mulai.';
    }
    final activeCount = participants
        .where((item) => item.state == ParticipantState.active)
        .length;
    if (next.participantCapacity <= 0) return 'Kapasitas harus lebih dari 0.';
    if (next.participantCapacity < activeCount) {
      return 'Kapasitas tidak boleh kurang dari $activeCount peserta aktif.';
    }
    if (next.finalBudget < 0 ||
        next.sponsorContribution < 0 ||
        next.openingBalance < 0) {
      return 'Nilai uang tidak boleh negatif.';
    }
    final paymentsStarted = transactions.any(
      (item) => item.type == TransactionType.participantPayment,
    );
    if (paymentsStarted &&
        (next.sponsorName != event.sponsorName ||
            next.sponsorContribution != event.sponsorContribution)) {
      return 'Sponsor dikunci setelah pembayaran peserta dimulai.';
    }
    return null;
  }

  Future<String?> updateEvent(EventRecord next) async {
    if (isReadOnly) return 'Selesaikan konflik data sebelum mengedit acara.';
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
    final operation = SyncOperation(
      id: _newId('sync'),
      entity: entity,
      entityId: entityId,
      action: action,
      createdAt: DateTime.now(),
      payload: payload,
    );
    final withQueue = next.copyWith(
      pendingOperations: [...next.pendingOperations, operation],
    );
    await _store.save(withQueue);
    _snapshot = withQueue;
    notifyListeners();
    await _flushPending();
  }

  Future<void> _flushPending() async {
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
            _syncError = 'Konflik ditemukan, tetapi data online tidak dapat dibaca.';
            notifyListeners();
            return;
          }
          final local = _snapshot.copyWith(clearSyncConflict: true);
          _snapshot = _snapshot.copyWith(
            syncConflict: SyncConflict(
              localSnapshot: local.toJson(),
              remoteSnapshot: remote
                  .copyWith(clearSyncConflict: true)
                  .toJson(),
              operation: operation,
              remoteVersion: result.version,
              remoteUpdatedBy: result.remoteUpdatedBy,
              remoteUpdatedAt: result.remoteUpdatedAt,
              createdAt: DateTime.now(),
            ),
          );
          await _store.save(_snapshot);
          _syncError = 'Pilih data online atau data perangkat ini.';
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
        _syncError =
            'Belum tersambung. Perubahan tetap tersimpan di perangkat.';
        notifyListeners();
        return;
      }
    }
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
