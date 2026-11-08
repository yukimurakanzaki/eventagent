import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'cashbook_models.dart';
import 'l10n/l10n.dart';

const backupFormat = 'wargakas-backup';
const backupVersion = 1;

/// Serialises the cashbook into a pretty JSON backup. Sync queue and conflict
/// state are device-specific, so they are left out.
String buildBackupJson(CashbookSnapshot snapshot, {DateTime? now}) {
  final data = Map<String, dynamic>.from(snapshot.toJson())
    ..remove('pendingOperations')
    ..remove('syncConflict');
  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'snapshot': data,
  });
}

/// Parses a backup file. Throws [FormatException] with a readable message.
CashbookSnapshot parseBackupJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    throw FormatException(tr('Berkas ini bukan cadangan Wargakas yang valid.'));
  }
  if (decoded is! Map || decoded['format'] != backupFormat) {
    throw FormatException(tr('Berkas ini bukan cadangan Wargakas yang valid.'));
  }
  if (decoded['version'] != backupVersion) {
    throw FormatException(
      tr('Versi cadangan tidak didukung. Perbarui aplikasi lalu coba lagi.'),
    );
  }
  final raw = decoded['snapshot'];
  if (raw is! Map) {
    throw FormatException(tr('Isi cadangan rusak atau tidak lengkap.'));
  }
  try {
    final data = Map<String, dynamic>.from(raw)
      ..['pendingOperations'] = const []
      ..remove('syncConflict');
    return CashbookSnapshot.fromJson(data);
  } catch (_) {
    throw FormatException(tr('Isi cadangan rusak atau tidak lengkap.'));
  }
}

String backupFileName(CashbookSnapshot snapshot, DateTime date) {
  final slug = snapshot.event.name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final stamp =
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  return 'wargakas-backup-${slug.isEmpty ? 'acara' : slug}-$stamp.json';
}

/// Writes the backup to a temp file (or memory on web) and opens the share sheet.
Future<void> shareBackup(CashbookSnapshot snapshot) async {
  final name = backupFileName(snapshot, DateTime.now());
  final json = buildBackupJson(snapshot);
  final XFile shared;
  if (kIsWeb) {
    shared = XFile.fromData(
      Uint8List.fromList(utf8.encode(json)),
      name: name,
      mimeType: 'application/json',
    );
  } else {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$name');
    await file.writeAsString(json, flush: true);
    shared = XFile(file.path, mimeType: 'application/json');
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [shared],
      subject: tr('Cadangan Wargakas - {name}', {'name': snapshot.event.name}),
    ),
  );
}
