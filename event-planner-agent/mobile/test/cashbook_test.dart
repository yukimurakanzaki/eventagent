import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:wargakas_mobile/cashbook_calculations.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/cashbook_sync.dart';
import 'package:wargakas_mobile/reminder_notifier.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class RecordingReminderNotifier implements ReminderNotifier {
  final scheduled = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dueAt,
    String note = '',
  }) async {
    scheduled.add(id);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}

class RecordingSyncAdapter implements CashbookSyncAdapter {
  final pushed = <String>[];

  @override
  Future<CashbookSnapshot?> load() async => null;

  @override
  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  }) async {
    pushed.add(operation.id);
    return SyncResult.synced(version: snapshot.syncVersion + 1);
  }
}

class ConflictThenSyncAdapter implements CashbookSyncAdapter {
  ConflictThenSyncAdapter(this.remote);

  final CashbookSnapshot remote;
  var pushes = 0;

  @override
  Future<CashbookSnapshot?> load() async => null;

  @override
  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  }) async {
    pushes += 1;
    if (pushes == 1) {
      return SyncResult.conflict(
        version: 4,
        remoteSnapshot: remote.copyWith(syncVersion: 4),
        remoteUpdatedBy: 'account-remote',
        remoteUpdatedAt: DateTime(2026, 9, 6, 10),
      );
    }
    return SyncResult.synced(version: 5);
  }
}

void main() {
  test('keeps the Dieng contribution rule visible and fixed to capacity', () {
    final event = CashbookSnapshot.demo().event;

    expect(participantTarget(event), 1850000);
    expect(event.participantCapacity, 18);
  });

  test('calculates balance with refunds and refund reversals exactly once', () {
    final snapshot = CashbookSnapshot.demo();
    final transactions = [
      ...snapshot.transactions,
      TransactionRecord(
        id: 'refund-1',
        type: TransactionType.refund,
        amount: 300000,
        description: 'Refund sebagian',
        createdAt: DateTime(2026, 1, 1),
      ),
      TransactionRecord(
        id: 'refund-reversal-1',
        type: TransactionType.refundReversal,
        amount: 200000,
        description: 'Koreksi refund',
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    expect(expenseTotal(transactions), 10050000);
    expect(currentBalance(snapshot.event, transactions), 1650000);
  });

  test('serializes the local snapshot without losing queued operations', () {
    final controller = CashbookController.forTesting();

    return controller
        .addReminder(
          title: 'Bayar uang muka penginapan',
          dueAt: DateTime.now().add(const Duration(days: 7)),
          note: 'Konfirmasi ke ketua.',
        )
        .then((_) {
          final encoded = jsonEncode(controller.snapshot.toJson());
          final restored = CashbookSnapshot.fromJson(
            jsonDecode(encoded) as Map<String, dynamic>,
          );

          expect(restored.reminders.last.title, 'Bayar uang muka penginapan');
          expect(restored.pendingOperations, hasLength(1));
          expect(restored.pendingOperations.single.entity, 'reminder');
        });
  });

  test(
    'records local changes in the sync queue and can acknowledge them',
    () async {
      final controller = CashbookController.forTesting();
      final initialCount = controller.participants.length;

      await controller.addParticipant('Pak Joko');

      expect(controller.participants, hasLength(initialCount + 1));
      expect(controller.pendingOperations, hasLength(1));
      expect(controller.pendingOperations.single.action, 'upsert');

      await controller.markSyncOperationSynced(
        controller.pendingOperations.single.id,
      );

      expect(controller.pendingOperations, isEmpty);
    },
  );

  test(
    'rejects participants over capacity before queuing an offline change',
    () async {
      final demo = CashbookSnapshot.demo();
      final activeCount = demo.participants
          .where((item) => item.state == ParticipantState.active)
          .length;
      final controller = CashbookController.forTesting(
        initial: demo.copyWith(
          event: demo.event.copyWith(participantCapacity: activeCount),
        ),
      );

      final error = await controller.addParticipant('Peserta kelebihan');

      expect(error, contains('Kapasitas'));
      expect(controller.pendingOperations, isEmpty);
    },
  );

  test('links a replacement only to a cancelled participant', () async {
    final controller = CashbookController.forTesting();
    final cancelled = controller.participants.first;
    await controller.cancelParticipant(cancelled, RefundPolicy.none);

    final error = await controller.addParticipant(
      'Peserta Pengganti',
      replacementForId: cancelled.id,
    );

    expect(error, isNull);
    expect(controller.participants.last.replacementForId, cancelled.id);
  });

  test('does not add a sponsor after participant payments start', () async {
    final controller = CashbookController.forTesting();
    final before = controller.transactions.length;

    await controller.recordTransaction(
      type: TransactionType.sponsor,
      amount: 100000,
      description: 'Sponsor tambahan',
    );

    expect(controller.transactions, hasLength(before));
    expect(controller.pendingOperations, isEmpty);
  });

  test(
    'counts a selected participant payment in that participant total',
    () async {
      final controller = CashbookController.forTesting();
      final participant = controller.participants.first;
      final before = participantPaid(controller.transactions, participant.id);

      await controller.recordTransaction(
        type: TransactionType.participantPayment,
        amount: 125000,
        description: 'Cicilan pertama',
        participantId: participant.id,
      );

      expect(
        participantPaid(controller.transactions, participant.id),
        before + 125000,
      );
    },
  );

  test(
    'cancelling with a full refund records the paid amount explicitly',
    () async {
      final controller = CashbookController.forTesting();
      final participant = controller.participants.first;
      final balanceBefore = controller.balance;

      final saved = await controller.cancelParticipant(
        participant,
        RefundPolicy.full,
      );

      expect(saved, isTrue);
      expect(
        controller.participants
            .singleWhere((item) => item.id == participant.id)
            .state,
        ParticipantState.cancelled,
      );
      final refund = controller.transactions.last;
      expect(refund.type, TransactionType.refund);
      expect(refund.participantId, participant.id);
      expect(refund.amount, 1850000);
      expect(controller.balance, balanceBefore - refund.amount);
    },
  );

  test('partial refunds are capped by the participant net payment', () async {
    final controller = CashbookController.forTesting();
    final participant = controller.participants.first;
    final transactionCount = controller.transactions.length;

    final rejected = await controller.cancelParticipant(
      participant,
      RefundPolicy.partial,
      partialRefundAmount: 1850001,
    );
    expect(rejected, isFalse);
    expect(controller.transactions, hasLength(transactionCount));
    expect(
      controller.participants
          .singleWhere((item) => item.id == participant.id)
          .state,
      ParticipantState.active,
    );

    final saved = await controller.cancelParticipant(
      participant,
      RefundPolicy.partial,
      partialRefundAmount: 250000,
    );
    expect(saved, isTrue);
    expect(controller.transactions.last.type, TransactionType.refund);
    expect(controller.transactions.last.amount, 250000);
  });

  test(
    'keeps cancellation and refund together in a sync conflict snapshot',
    () async {
      final remote = CashbookSnapshot.demo().copyWith(syncVersion: 4);
      final controller = CashbookController.forTesting(
        syncAdapter: ConflictThenSyncAdapter(remote),
      );
      final participant = controller.participants.first;

      expect(
        await controller.cancelParticipant(participant, RefundPolicy.full),
        isTrue,
      );

      final conflict = controller.syncConflict;
      expect(conflict, isNotNull);
      final local = CashbookSnapshot.fromJson(conflict!.localSnapshot);
      expect(
        local.participants
            .singleWhere((item) => item.id == participant.id)
            .state,
        ParticipantState.cancelled,
      );
      expect(
        local.transactions.any(
          (item) =>
              item.type == TransactionType.refund &&
              item.participantId == participant.id,
        ),
        isTrue,
      );
    },
  );

  test('rejects a manual refund above a participant net payment', () async {
    final controller = CashbookController.forTesting();
    final paidParticipant = controller.participants.first;
    final unpaidParticipant = controller.participants.last;
    final transactionCount = controller.transactions.length;

    final overRefunded = await controller.recordTransaction(
      type: TransactionType.refund,
      amount: 1850001,
      description: 'Terlalu besar',
      participantId: paidParticipant.id,
    );
    final refundWithoutPayment = await controller.recordTransaction(
      type: TransactionType.refund,
      amount: 1,
      description: 'Tidak ada pembayaran',
      participantId: unpaidParticipant.id,
    );

    expect(overRefunded, isFalse);
    expect(refundWithoutPayment, isFalse);
    expect(controller.transactions, hasLength(transactionCount));
  });

  test('a participant payment status uses the net amount after a refund', () {
    final snapshot = CashbookSnapshot.demo();
    const participantId = 'p-sari';
    final transactions = [
      ...snapshot.transactions,
      TransactionRecord(
        id: 'refund-sari',
        type: TransactionType.refund,
        amount: 10000,
        description: 'Pengembalian kelebihan bayar',
        participantId: participantId,
        createdAt: DateTime(2026, 9, 8),
      ),
    ];

    expect(participantPaid(transactions, participantId), 1850000);
    expect(refundTotalForParticipant(transactions, participantId), 10000);
    expect(participantNetPaid(transactions, participantId), 1840000);
    expect(
      paymentStatus(participantNetPaid(transactions, participantId), 1850000),
      'Sebagian',
    );
  });

  test(
    'does not record a participant payment without a valid participant',
    () async {
      final controller = CashbookController.forTesting();
      final before = controller.transactions.length;

      await controller.recordTransaction(
        type: TransactionType.participantPayment,
        amount: 125000,
        description: 'Tidak terhubung',
      );

      expect(controller.transactions, hasLength(before));
    },
  );

  test('schedules a reminder locally and cancels it when completed', () async {
    final notifier = RecordingReminderNotifier();
    final controller = CashbookController.forTesting(
      reminderNotifier: notifier,
    );

    await controller.addReminder(
      title: 'Kumpulkan tahap 2',
      dueAt: DateTime.now().add(const Duration(days: 7)),
    );
    final reminder = controller.reminders.last;

    expect(notifier.scheduled, contains(reminder.id));

    await controller.toggleReminder(reminder);

    expect(notifier.cancelled, contains(reminder.id));
  });

  test(
    'flushes queued local changes through the hosted sync adapter',
    () async {
      final adapter = RecordingSyncAdapter();
      final controller = CashbookController.forTesting(syncAdapter: adapter);

      await controller.addParticipant('Ibu Joko');

      expect(adapter.pushed, hasLength(1));
      expect(controller.pendingOperations, isEmpty);
      expect(controller.snapshot.syncVersion, 1);
    },
  );

  test('validates configurable event fields and sponsor lock', () async {
    final controller = CashbookController.forTesting();
    final changedSponsor = controller.event.copyWith(
      sponsorContribution: controller.event.sponsorContribution + 1,
    );

    expect(
      controller.validateEventUpdate(changedSponsor),
      'Sponsor dikunci setelah pembayaran peserta dimulai.',
    );
    expect(
      controller.validateEventUpdate(
        controller.event.copyWith(participantCapacity: 1),
      ),
      contains('peserta aktif'),
    );

    final updated = controller.event.copyWith(
      name: 'Wisata Bandung',
      finalBudget: 41000000,
      openingBalance: 2500000,
    );
    expect(await controller.updateEvent(updated), isNull);
    expect(controller.event.name, 'Wisata Bandung');
    expect(controller.pendingOperations.single.entity, 'event');
    expect(controller.pendingOperations.single.payload, contains('before'));
    expect(controller.pendingOperations.single.payload, contains('after'));
  });

  test('persists conflict and can choose the online version', () async {
    final remote = CashbookSnapshot.demo().copyWith(
      event: CashbookSnapshot.demo().event.copyWith(name: 'Versi Online'),
      syncVersion: 4,
    );
    final adapter = ConflictThenSyncAdapter(remote);
    final controller = CashbookController.forTesting(syncAdapter: adapter);

    await controller.addParticipant('Perubahan Lokal');

    expect(controller.isReadOnly, isTrue);
    expect(controller.syncConflict?.remoteUpdatedBy, 'account-remote');
    final restored = CashbookSnapshot.fromJson(
      jsonDecode(jsonEncode(controller.snapshot.toJson()))
          as Map<String, dynamic>,
    );
    expect(restored.syncConflict, isNotNull);

    final beforeBlockedEdit = controller.participants.length;
    await controller.addParticipant('Tidak boleh masuk');
    expect(controller.participants, hasLength(beforeBlockedEdit));

    await controller.resolveConflictWithRemote();
    expect(controller.isReadOnly, isFalse);
    expect(controller.event.name, 'Versi Online');
    expect(
      controller.participants.any((item) => item.name == 'Perubahan Lokal'),
      isFalse,
    );
  });

  test(
    'rebases an explicit local conflict choice and synchronizes it',
    () async {
      final remote = CashbookSnapshot.demo().copyWith(syncVersion: 4);
      final adapter = ConflictThenSyncAdapter(remote);
      final controller = CashbookController.forTesting(syncAdapter: adapter);

      await controller.addParticipant('Tetap Lokal');
      expect(controller.isReadOnly, isTrue);

      await controller.resolveConflictWithLocal();

      expect(controller.isReadOnly, isFalse);
      expect(adapter.pushes, 2);
      expect(controller.snapshot.syncVersion, 5);
      expect(controller.pendingOperations, isEmpty);
      expect(
        controller.participants.any((item) => item.name == 'Tetap Lokal'),
        isTrue,
      );
    },
  );

  test('retries queued changes after a transient sync failure', () async {
    final adapter = _FailOnceSyncAdapter();
    final controller = CashbookController.forTesting(syncAdapter: adapter);

    await controller.addParticipant('Tetap Tersimpan');
    expect(controller.pendingOperations, hasLength(1));

    await controller.retryPendingSync();
    expect(controller.pendingOperations, isEmpty);
    expect(adapter.pushes, 2);
  });

  test('delays quiet-hour reminders until 07:00 in the device time zone', () {
    tz_data.initializeTimeZones();
    final jakarta = tz.getLocation('Asia/Jakarta');

    final late = scheduleAfterQuietHours(
      tz.TZDateTime(jakarta, 2026, 9, 8, 20),
    );
    final early = scheduleAfterQuietHours(
      tz.TZDateTime(jakarta, 2026, 9, 8, 6, 30),
    );
    final daytime = scheduleAfterQuietHours(
      tz.TZDateTime(jakarta, 2026, 9, 8, 9),
    );

    expect(late, tz.TZDateTime(jakarta, 2026, 9, 9, 7));
    expect(early, tz.TZDateTime(jakarta, 2026, 9, 8, 7));
    expect(daytime, tz.TZDateTime(jakarta, 2026, 9, 8, 9));
  });
}

class _FailOnceSyncAdapter implements CashbookSyncAdapter {
  var pushes = 0;

  @override
  Future<CashbookSnapshot?> load() async => null;

  @override
  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  }) async {
    pushes += 1;
    if (pushes == 1) throw StateError('temporary offline');
    return SyncResult.synced(version: snapshot.syncVersion + 1);
  }
}
