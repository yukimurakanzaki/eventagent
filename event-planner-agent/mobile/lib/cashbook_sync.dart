import 'cashbook_models.dart';

enum SyncResultStatus { synced, conflict }

class SyncResult {
  const SyncResult.synced({required this.version})
      : status = SyncResultStatus.synced,
        remoteSnapshot = null;

  const SyncResult.conflict({required this.version, required this.remoteSnapshot})
      : status = SyncResultStatus.conflict;

  final SyncResultStatus status;
  final int version;
  final CashbookSnapshot? remoteSnapshot;
}

abstract interface class CashbookSyncAdapter {
  Future<CashbookSnapshot?> load();

  Future<SyncResult> push({required CashbookSnapshot snapshot, required SyncOperation operation});
}
