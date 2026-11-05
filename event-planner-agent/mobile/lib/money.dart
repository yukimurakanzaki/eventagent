import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'l10n/l10n.dart';

/// A currency an event can be kept in. Amounts are stored as integers in the
/// currency's minor unit ([decimals] digits), so IDR and JPY store whole
/// units and USD stores cents. Existing rupiah data needs no migration.
class CurrencySpec {
  const CurrencySpec(this.code, this.symbol, this.decimals, this.name);

  final String code;
  final String symbol;
  final int decimals;
  final String name;

  int get minorFactor {
    var factor = 1;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    return factor;
  }
}

const defaultCurrencyCode = 'IDR';

/// Practical decimals: currencies whose coins are not used for everyday
/// group spending (IDR, VND, KRW, JPY, ...) are kept as whole units.
const supportedCurrencies = <CurrencySpec>[
  CurrencySpec('IDR', 'Rp', 0, 'Indonesian Rupiah'),
  CurrencySpec('USD', r'$', 2, 'US Dollar'),
  CurrencySpec('EUR', '€', 2, 'Euro'),
  CurrencySpec('GBP', '£', 2, 'British Pound'),
  CurrencySpec('MYR', 'RM', 2, 'Malaysian Ringgit'),
  CurrencySpec('SGD', r'S$', 2, 'Singapore Dollar'),
  CurrencySpec('THB', '฿', 2, 'Thai Baht'),
  CurrencySpec('PHP', '₱', 2, 'Philippine Peso'),
  CurrencySpec('VND', '₫', 0, 'Vietnamese Dong'),
  CurrencySpec('INR', '₹', 2, 'Indian Rupee'),
  CurrencySpec('PKR', 'Rs', 0, 'Pakistani Rupee'),
  CurrencySpec('BDT', '৳', 0, 'Bangladeshi Taka'),
  CurrencySpec('CNY', '¥', 2, 'Chinese Yuan'),
  CurrencySpec('JPY', '¥', 0, 'Japanese Yen'),
  CurrencySpec('KRW', '₩', 0, 'South Korean Won'),
  CurrencySpec('HKD', r'HK$', 2, 'Hong Kong Dollar'),
  CurrencySpec('TWD', r'NT$', 0, 'New Taiwan Dollar'),
  CurrencySpec('AUD', r'A$', 2, 'Australian Dollar'),
  CurrencySpec('NZD', r'NZ$', 2, 'New Zealand Dollar'),
  CurrencySpec('CAD', r'C$', 2, 'Canadian Dollar'),
  CurrencySpec('MXN', r'MX$', 2, 'Mexican Peso'),
  CurrencySpec('BRL', r'R$', 2, 'Brazilian Real'),
  CurrencySpec('ARS', r'AR$', 0, 'Argentine Peso'),
  CurrencySpec('COP', r'COL$', 0, 'Colombian Peso'),
  CurrencySpec('CLP', r'CLP$', 0, 'Chilean Peso'),
  CurrencySpec('PEN', 'S/', 2, 'Peruvian Sol'),
  CurrencySpec('CHF', 'CHF', 2, 'Swiss Franc'),
  CurrencySpec('SEK', 'kr', 2, 'Swedish Krona'),
  CurrencySpec('NOK', 'kr', 2, 'Norwegian Krone'),
  CurrencySpec('DKK', 'kr', 2, 'Danish Krone'),
  CurrencySpec('PLN', 'zł', 2, 'Polish Złoty'),
  CurrencySpec('TRY', '₺', 2, 'Turkish Lira'),
  CurrencySpec('RUB', '₽', 0, 'Russian Ruble'),
  CurrencySpec('UAH', '₴', 2, 'Ukrainian Hryvnia'),
  CurrencySpec('SAR', 'SAR', 2, 'Saudi Riyal'),
  CurrencySpec('AED', 'AED', 2, 'UAE Dirham'),
  CurrencySpec('QAR', 'QAR', 2, 'Qatari Riyal'),
  CurrencySpec('EGP', 'E£', 2, 'Egyptian Pound'),
  CurrencySpec('NGN', '₦', 0, 'Nigerian Naira'),
  CurrencySpec('KES', 'KSh', 0, 'Kenyan Shilling'),
  CurrencySpec('ZAR', 'R', 2, 'South African Rand'),
  CurrencySpec('GHS', 'GH₵', 2, 'Ghanaian Cedi'),
];

CurrencySpec currencySpec(String? code) => supportedCurrencies.firstWhere(
  (spec) => spec.code == code,
  orElse: () => supportedCurrencies.first,
);

/// The currency of the open event. The event screens set it whenever the
/// event changes, so every amount on screen uses one currency.
class Money {
  Money._();

  static String currency = defaultCurrencyCode;

  static CurrencySpec get spec => currencySpec(currency);
}

String _intlLocale(String languageCode) => switch (languageCode) {
  'zh' => 'zh_CN',
  'pt' => 'pt_BR',
  _ => languageCode,
};

String _groupSeparator(String languageCode) {
  if (languageCode == 'id') return '.';
  try {
    return NumberFormat.decimalPattern(_intlLocale(languageCode))
        .symbols
        .GROUP_SEP;
  } catch (_) {
    return ',';
  }
}

String _decimalSeparator(String languageCode) {
  if (languageCode == 'id') return ',';
  try {
    return NumberFormat.decimalPattern(_intlLocale(languageCode))
        .symbols
        .DECIMAL_SEP;
  } catch (_) {
    return '.';
  }
}

String _groupDigits(String digits, String separator) {
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    groups.insert(0, digits.substring(end - 3 < 0 ? 0 : end - 3, end));
  }
  return groups.join(separator);
}

/// Formats [minorUnits] for display, e.g. `Rp 1.250.000`, `$12.50`.
String formatMoney(int minorUnits, {String? currency, String? languageCode}) {
  final spec = currencySpec(currency ?? Money.currency);
  final language = languageCode ?? L10n.code;
  final sign = minorUnits < 0 ? '-' : '';
  final absolute = minorUnits.abs();
  final whole = absolute ~/ spec.minorFactor;
  final fraction = absolute % spec.minorFactor;
  var number = _groupDigits('$whole', _groupSeparator(language));
  if (spec.decimals > 0) {
    number +=
        _decimalSeparator(language) +
        fraction.toString().padLeft(spec.decimals, '0');
  }
  // A space after letter symbols ("Rp 10", "CHF 10") keeps them readable;
  // sign symbols ("$10", "€10") sit tight like printed prices.
  final letterSymbol = RegExp(r'[A-Za-z]$').hasMatch(spec.symbol);
  return '$sign${spec.symbol}${letterSymbol ? ' ' : ''}$number';
}

/// The text a money input field shows for a stored amount.
String formatMoneyInput(
  int minorUnits, {
  String? currency,
  String? languageCode,
}) {
  if (minorUnits == 0) return '';
  final spec = currencySpec(currency ?? Money.currency);
  final language = languageCode ?? L10n.code;
  final whole = minorUnits.abs() ~/ spec.minorFactor;
  final fraction = minorUnits.abs() % spec.minorFactor;
  var text = _groupDigits('$whole', _groupSeparator(language));
  if (spec.decimals > 0 && fraction > 0) {
    text +=
        _decimalSeparator(language) +
        fraction.toString().padLeft(spec.decimals, '0');
  }
  return text;
}

/// Parses what a person typed into minor units. Accepts the locale's decimal
/// separator; for whole-unit currencies every non-digit is ignored.
int parseMoneyInput(String value, {String? currency, String? languageCode}) {
  final spec = currencySpec(currency ?? Money.currency);
  if (spec.decimals == 0) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
  final decimal = _decimalSeparator(languageCode ?? L10n.code);
  final cleaned = value.replaceAll(
    RegExp('[^0-9${RegExp.escape(decimal)}]'),
    '',
  );
  final parts = cleaned.split(decimal);
  final whole = int.tryParse(parts.first.isEmpty ? '0' : parts.first) ?? 0;
  var fractionText = parts.length > 1 ? parts[1] : '';
  if (fractionText.length > spec.decimals) {
    fractionText = fractionText.substring(0, spec.decimals);
  }
  final fraction = int.tryParse(fractionText.padRight(spec.decimals, '0')) ?? 0;
  return whole * spec.minorFactor + fraction;
}

/// Groups thousands while typing and allows the currency's decimals.
class MoneyTextInputFormatter extends TextInputFormatter {
  MoneyTextInputFormatter({this.currency, this.languageCode});

  final String? currency;
  final String? languageCode;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final spec = currencySpec(currency ?? Money.currency);
    final language = languageCode ?? L10n.code;
    final group = _groupSeparator(language);
    final decimal = _decimalSeparator(language);
    var raw = newValue.text;
    String fraction = '';
    var hasDecimal = false;
    if (spec.decimals > 0) {
      // Accept "." typed on a keyboard whose locale uses ",".
      if (decimal != '.' && group != '.' && raw.contains('.')) {
        raw = raw.replaceAll('.', decimal);
      }
      final index = raw.indexOf(decimal);
      if (index >= 0) {
        hasDecimal = true;
        fraction = raw.substring(index + 1).replaceAll(RegExp(r'[^0-9]'), '');
        if (fraction.length > spec.decimals) {
          fraction = fraction.substring(0, spec.decimals);
        }
        raw = raw.substring(0, index);
      }
    }
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty && !hasDecimal) return const TextEditingValue();
    final trimmed = digits.replaceFirst(RegExp(r'^0+'), '');
    var text = _groupDigits(trimmed.isEmpty ? '0' : trimmed, group);
    if (hasDecimal) text += '$decimal$fraction';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
