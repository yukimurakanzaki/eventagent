import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'cashbook_models.dart';
import 'l10n/l10n.dart';

/// Resolves a hosted receipt (storage path) to a short-lived download URL.
/// Set by the hosted app; null in demo mode.
typedef ReceiptUrlResolver = Future<String?> Function(String storagePath);

class Receipts {
  Receipts._();

  static ReceiptUrlResolver? urlResolver;

  /// Receipt photos need a camera or file system; not offered on the web.
  static bool get supported => !kIsWeb;
}

/// Lets the person take or choose a receipt photo and keeps a compressed
/// copy in the app's own storage. Returns the saved path, or null.
Future<String?> pickReceiptPhoto(BuildContext context) async {
  if (!Receipts.supported) return null;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(tr('Ambil foto nota')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(tr('Pilih dari galeri')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 72,
    );
    if (picked == null) return null;
    final directory = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/receipts',
    );
    await directory.create(recursive: true);
    final extension = picked.path.toLowerCase().endsWith('.png')
        ? 'png'
        : 'jpg';
    final target =
        '${directory.path}/receipt-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await File(picked.path).copy(target);
    return target;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'Foto nota belum bisa diambil. Periksa izin kamera atau galeri.',
            ),
          ),
        ),
      );
    }
    return null;
  }
}

/// Shows the receipt of [transaction]: the local copy when this phone has
/// it, otherwise the hosted copy.
class ReceiptImage extends StatelessWidget {
  const ReceiptImage({
    required this.transaction,
    this.fit = BoxFit.contain,
    super.key,
  });

  final TransactionRecord transaction;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final local = transaction.receiptPath;
    if (!kIsWeb &&
        local != null &&
        local.isNotEmpty &&
        File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: fit,
        semanticLabel: tr('Foto nota'),
        errorBuilder: (_, _, _) => const _ReceiptUnavailable(),
      );
    }
    final remote = transaction.receiptStoragePath;
    final resolver = Receipts.urlResolver;
    if (remote == null || remote.isEmpty || resolver == null) {
      return const _ReceiptUnavailable();
    }
    return FutureBuilder<String?>(
      future: resolver(remote),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final url = snapshot.data;
        if (url == null) return const _ReceiptUnavailable();
        return Image.network(
          url,
          fit: fit,
          semanticLabel: tr('Foto nota'),
          errorBuilder: (_, _, _) => const _ReceiptUnavailable(),
        );
      },
    );
  }
}

class _ReceiptUnavailable extends StatelessWidget {
  const _ReceiptUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 48),
            const SizedBox(height: 8),
            Text(
              tr(
                'Foto nota belum tersedia di perangkat ini. Sambungkan internet untuk mengunduhnya.',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen, zoomable receipt viewer.
Future<void> showReceiptViewer(
  BuildContext context,
  TransactionRecord transaction,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(tr('Foto nota'))),
        body: SafeArea(
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(child: ReceiptImage(transaction: transaction)),
          ),
        ),
      ),
    ),
  );
}
