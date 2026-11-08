import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wargakas_mobile/backup_service.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/cashbook_models.dart';
import 'package:wargakas_mobile/cashbook_sync.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/report_service.dart';
import 'package:wargakas_mobile/share_link.dart';

class _Gateway implements ReportShareGateway {
  @override
  Future<String?> sharePdf(CashbookReport report) async => null;
  @override
  Future<void> shareWhatsAppText(CashbookReport report) async {}
}

class _Links implements ShareLinkService {
  @override
  bool get canRevoke => true;
  @override
  Future<String> createLink() async => 'https://example.test/?share=qr1';
  @override
  Future<void> revokeLinks() async {}
}

class _Sync implements CashbookSyncAdapter {
  @override
  dynamic noSuchMethod(Invocation invocation) async => null;
}

void main() {
  test('backup round-trip keeps data and drops sync state', () {
    final demo = CashbookSnapshot.demo();
    final parsed = parseBackupJson(buildBackupJson(demo));
    expect(parsed.event.name, demo.event.name);
    expect(parsed.participants.length, demo.participants.length);
    expect(parsed.transactions.length, demo.transactions.length);
    expect(parsed.pendingOperations, isEmpty);
    expect(parsed.syncConflict, isNull);
    expect(buildBackupJson(demo), contains('"format": "wargakas-backup"'));
  });

  test('invalid backups are rejected', () {
    expect(() => parseBackupJson('not json'), throwsFormatException);
    expect(() => parseBackupJson('{"format":"other"}'), throwsFormatException);
    expect(
      () => parseBackupJson('{"format":"wargakas-backup","version":99}'),
      throwsFormatException,
    );
    expect(
      () => parseBackupJson(
        '{"format":"wargakas-backup","version":1,"snapshot":{}}',
      ),
      throwsFormatException,
    );
  });

  test('file name uses slug and date', () {
    final name = backupFileName(CashbookSnapshot.demo(), DateTime(2026, 3, 7));
    expect(name, 'wargakas-backup-wisata-dieng-20260307.json');
  });

  test('restore works offline and is refused with a sync adapter', () async {
    final backup = CashbookSnapshot.demo().copyWith(
      participants: const [ParticipantRecord(id: 'x', name: 'Solo')],
      transactions: const [],
    );
    final offline = CashbookController.forTesting();
    expect(offline.canRestoreBackup, isTrue);
    expect(await offline.restoreFromBackup(backup), isNull);
    expect(offline.participants.length, 1);
    expect(offline.transactions, isEmpty);

    final online = CashbookController.forTesting(syncAdapter: _Sync());
    expect(online.canRestoreBackup, isFalse);
    expect(await online.restoreFromBackup(backup), isNotNull);
    expect(online.participants.length, isNot(1));
  });

  testWidgets('QR appears after creating a link', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: wargakasTheme(),
        home: Scaffold(
          body: ReportPage(
            controller: CashbookController.forTesting(),
            creatorRole: 'treasurer',
            shareGateway: _Gateway(),
            shareLinkService: _Links(),
          ),
        ),
      ),
    );
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Simpan cadangan (JSON)'), findsOneWidget);
    expect(find.text('Pulihkan dari cadangan'), findsOneWidget);
    await tester.tap(find.text('Buat / salin tautan'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      find.text('Peserta dapat memindai kode ini dengan kamera ponsel.'),
      findsOneWidget,
    );
  });
}
