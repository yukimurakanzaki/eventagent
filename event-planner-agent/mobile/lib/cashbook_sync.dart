import 'cashbook_models.dart';

enum SyncResultStatus { synced, conflict }

class SyncResult {
  const SyncResult.synced({required this.version})
    : status = SyncResultStatus.synced,
      remoteSnapshot = null,
      remoteUpdatedBy = null,
      remoteUpdatedAt = null;

  const SyncResult.conflict({
    required this.version,
    required this.remoteSnapshot,
    this.remoteUpdatedBy,
    this.remoteUpdatedAt,
  }) : status = SyncResultStatus.conflict;

  final SyncResultStatus status;
  final int version;
  final CashbookSnapshot? remoteSnapshot;
  final String? remoteUpdatedBy;
  final DateTime? remoteUpdatedAt;
}

abstract interface class CashbookSyncAdapter {
  Future<CashbookSnapshot?> load();

  Future<SyncResult> push({
    required CashbookSnapshot snapshot,
    required SyncOperation operation,
  });
}
