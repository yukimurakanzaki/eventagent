import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:wargakas_mobile/cashbook_calculations.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/cashbook_sync.dart';
import 'package:wargakas_mobile/reminder_notifier.dart';

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
          dueAt: DateTime(2026, 8, 30, 10),
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

  test('schedules a reminder locally and cancels it when completed', () async {
    final notifier = RecordingReminderNotifier();
    final controller = CashbookController.forTesting(
      reminderNotifier: notifier,
    );

    await controller.addReminder(
      title: 'Kumpulkan tahap 2',
      dueAt: DateTime(2026, 9, 1, 9),
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

  test('rebases an explicit local conflict choice and synchronizes it', () async {
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
  });
}
