import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wargakas_mobile/l10n/l10n.dart';
import 'package:wargakas_mobile/pdf_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => L10n.code = 'id');

  test(
    'PDF theme embeds Noto fonts with Thai, Arabic and Devanagari fallback',
    () async {
      L10n.code = 'th';
      final theme = await loadPdfTheme();
      expect(
        theme.defaultTextStyle.fontFallback,
        hasLength(3),
        reason: 'bundled fallback fonts loaded',
      );
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.Page(
          build: (_) => pw.Column(
            children: [pw.Text('José Nguyễn • สมชาย • محمد • राम')],
          ),
        ),
      );
      final bytes = await doc.save();
      final raw = String.fromCharCodes(bytes);
      expect(
        'FontFile2'.allMatches(raw).length,
        greaterThanOrEqualTo(4),
        reason: 'Latin, Thai, Arabic and Devanagari TrueType fonts embedded',
      );
    },
  );

  test('Arabic pages are right-to-left', () {
    L10n.code = 'ar';
    expect(pdfTextDirection, pw.TextDirection.rtl);
    L10n.code = 'en';
    expect(pdfTextDirection, pw.TextDirection.ltr);
  });
}
