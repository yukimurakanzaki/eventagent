import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'l10n/l10n.dart';

const _fontDir = 'assets/fonts/pdf/';

pw.ThemeData? _cachedTheme;
String? _cachedThemeLanguage;

/// Text direction for generated PDF pages (right-to-left for Arabic).
pw.TextDirection get pdfTextDirection =>
    L10n.code == 'ar' ? pw.TextDirection.rtl : pw.TextDirection.ltr;

Future<pw.Font> _asset(String name) async =>
    pw.Font.ttf(await rootBundle.load('$_fontDir$name'));

/// A PDF theme whose fonts cover Latin, Vietnamese, Thai, Arabic, Devanagari
/// and (best effort, downloaded once) Chinese/Japanese. Falls back to the
/// default theme if the bundled fonts cannot be loaded.
Future<pw.ThemeData> loadPdfTheme() async {
  final language = L10n.code;
  final cached = _cachedTheme;
  if (cached != null && _cachedThemeLanguage == language) return cached;
  try {
    final base = await _asset('NotoSans-Regular.ttf');
    final bold = await _asset('NotoSans-Bold.ttf');
    final fallback = <pw.Font>[
      await _asset('NotoSansThai-Regular.ttf'),
      await _asset('NotoSansArabic-Regular.ttf'),
      await _asset('NotoSansDevanagari-Regular.ttf'),
    ];
    if (language == 'zh' || language == 'ja') {
      final cjk = await _loadCjkFont(language);
      if (cjk != null) fallback.add(cjk);
    }
    final theme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: base,
      boldItalic: bold,
      fontFallback: fallback,
    );
    _cachedTheme = theme;
    _cachedThemeLanguage = language;
    return theme;
  } catch (_) {
    return pw.ThemeData.base();
  }
}

Future<pw.Font?> _loadCjkFont(String language) async {
  try {
    final family = language == 'ja' ? 'Noto+Sans+JP' : 'Noto+Sans+SC';
    Directory? cacheDir;
    try {
      final support = await getApplicationSupportDirectory();
      cacheDir = Directory('${support.path}/pdf-fonts');
    } catch (_) {}
    final cacheFile = cacheDir == null
        ? null
        : File('${cacheDir.path}/$family.ttf');
    if (cacheFile != null && await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      if (bytes.isNotEmpty) {
        return pw.Font.ttf(ByteData.sublistView(bytes));
      }
    }
    final bytes = await _download(
      Uri.parse('https://fonts.googleapis.com/css2?family=$family'),
    );
    if (bytes == null) return null;
    if (cacheFile != null) {
      try {
        await cacheDir!.create(recursive: true);
        await cacheFile.writeAsBytes(bytes, flush: true);
      } catch (_) {}
    }
    return pw.Font.ttf(ByteData.sublistView(bytes));
  } catch (e) {
    debugPrint('CJK PDF font unavailable: $e');
    return null;
  }
}

Future<Uint8List?> _download(Uri cssUri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    // Without a browser user agent Google Fonts serves plain TTF files.
    final cssRequest = await client.getUrl(cssUri);
    cssRequest.headers.set('User-Agent', 'Mozilla/4.0');
    final cssResponse = await cssRequest.close().timeout(
      const Duration(seconds: 10),
    );
    if (cssResponse.statusCode != 200) return null;
    final css = await utf8.decodeStream(cssResponse);
    final match = RegExp(r'url\((https?://[^)]+?\.ttf)\)').firstMatch(css);
    if (match == null) return null;
    final fontRequest = await client.getUrl(Uri.parse(match.group(1)!));
    final fontResponse = await fontRequest.close().timeout(
      const Duration(seconds: 60),
    );
    if (fontResponse.statusCode != 200) return null;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in fontResponse) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    return bytes.length > 1000 ? bytes : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
