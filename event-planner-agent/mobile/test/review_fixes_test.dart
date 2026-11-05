import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/money.dart';
import 'package:wargakas_mobile/report_service.dart';

void main() {
  group('parseMoneyInput decimals', () {
    int p(String t, {String lang = 'id'}) =>
        parseMoneyInput(t, currency: 'USD', languageCode: lang);

    test('last separator with 1-2 digits is the decimal in any locale', () {
      expect(p('12.50'), 1250);
      expect(p('12,5'), 1250);
      expect(p('12,50', lang: 'en'), 1250);
      expect(p('12.5', lang: 'en'), 1250);
    });

    test('three digits after a separator is grouping', () {
      expect(p('1.250'), 125000);
      expect(p('1,250', lang: 'en'), 125000);
      expect(p('1.250,50'), 125050);
      expect(p('1,250.50', lang: 'en'), 125050);
    });

    test('non-ASCII digits are normalised', () {
      expect(p('١٢٫٥'.replaceAll('٫', ',')), 1250);
      expect(p('१२.५०'), 1250);
      expect(p('๑๒.๕๐'), 1250);
      expect(p('１２.５０'), 1250);
      expect(p('۱۲,۵'), 1250);
      expect(parseMoneyInput('١٢٣', currency: 'IDR'), 123);
    });

    test('whole-unit currencies ignore separators', () {
      expect(parseMoneyInput('1.250', currency: 'IDR'), 1250);
    });
  });

  group('MoneyTextInputFormatter', () {
    String f(String text, {String lang = 'id'}) =>
        MoneyTextInputFormatter(currency: 'USD', languageCode: lang)
            .formatEditUpdate(
              TextEditingValue.empty,
              TextEditingValue(text: text),
            )
            .text;

    test('renders with the locale separators', () {
      expect(f('12.50'), '12,50');
      expect(f('12,5'), '12,5');
      expect(f('1.250'), '1.250');
      expect(f('12,5', lang: 'en'), '12.5');
      expect(f('１２.５０', lang: 'en'), '12.50');
    });

    test('output parses back to the same amount', () {
      for (final t in ['12.50', '1.250', '12,5', '1.250,5']) {
        expect(
          parseMoneyInput(f(t), currency: 'USD', languageCode: 'id'),
          parseMoneyInput(t, currency: 'USD', languageCode: 'id'),
        );
      }
    });
  });

  group('sanitizeReportText', () {
    test('keeps ISO dates', () {
      expect(
        sanitizeReportText('Dibayar 2026-12-01 pukul 10:30'),
        'Dibayar 2026-12-01 pukul 10:30',
      );
    });

    test('still redacts long digit runs', () {
      expect(
        sanitizeReportText('transfer ke 1234567890123'),
        isNot(contains('1234567890123')),
      );
      expect(
        sanitizeReportText('hubungi 0812-3456-7890'),
        isNot(contains('3456')),
      );
    });
  });

  group('whatsAppNumber', () {
    test('plus keeps digits', () {
      expect(whatsAppNumber('+62 812-3456', countryCode: 'US'), '628123456');
    });
    test('double zero is dropped', () {
      expect(whatsAppNumber('0044 7700 900123'), '447700900123');
    });
    test('leading zero uses region calling code', () {
      expect(whatsAppNumber('0812345', countryCode: 'MY'), '60812345');
      expect(whatsAppNumber('07700 900123', countryCode: 'GB'), '447700900123');
      expect(whatsAppNumber('0555', countryCode: 'US'), '1555');
    });
    test('defaults to Indonesia', () {
      expect(whatsAppNumber('0812345'), '62812345');
      expect(whatsAppNumber('0812345', countryCode: 'ZZ'), '62812345');
    });
    test('empty stays empty', () {
      expect(whatsAppNumber(' '), '');
    });
  });

  test('committee role label', () {
    expect(reportRoleLabel('committee'), 'Panitia');
  });
}
