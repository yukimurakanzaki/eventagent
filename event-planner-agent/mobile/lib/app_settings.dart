// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/l10n.dart';
import 'money.dart';

/// Accent colours a person can pick. The first is the Wargakas brand teal.
const accentColors = <Color>[
  Color(0xff006b5b), // teal (brand)
  Color(0xff1b5fc1), // blue
  Color(0xff6a4fb3), // violet
  Color(0xffb3261e), // red
  Color(0xffb35c00), // orange
  Color(0xff3c7a1e), // green
  Color(0xff8a4f7d), // plum
  Color(0xff455a64), // slate
];

/// Text sizes offered in Settings, on top of the phone's own text size.
const textScaleOptions = <double>[0.9, 1.0, 1.15, 1.3, 1.5];

/// Per-device personal preferences. Kept on the phone (not synced) because
/// two committee members sharing an event can read it in different languages.
class AppSettings extends ChangeNotifier {
  AppSettings({SharedPreferences? preferences}) : _preferences = preferences;

  static const _prefix = 'wargakas.settings.';

  /// The app-wide instance. Replaced by [load] at startup.
  static AppSettings instance = AppSettings();

  /// Tests pin the language that "follow the phone" resolves to, so the
  /// existing Indonesian widget tests stay deterministic.
  static String? debugSystemLanguageOverride;

  final SharedPreferences? _preferences;

  String? _languageCode;
  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0;
  int _accentIndex = 0;
  bool _highContrast = false;
  bool _reduceMotion = false;
  String _defaultCurrency = defaultCurrencyCode;
  bool _onboardingDone = false;
  bool _currencyChosen = false;
  bool _appLock = false;

  /// `null` follows the phone language.
  String? get languageCode => _languageCode;
  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  int get accentIndex => _accentIndex;
  Color get accentColor => accentColors[_accentIndex];
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  String get defaultCurrency => _defaultCurrency;
  bool get onboardingDone => _onboardingDone;
  bool get currencyChosen => _currencyChosen;

  /// Ask for fingerprint, face, or phone PIN when opening the app.
  bool get appLock => _appLock;

  /// The language actually shown, resolving "follow the phone".
  String effectiveLanguage(Locale deviceLocale) {
    final chosen = _languageCode;
    if (chosen != null && L10n.isSupported(chosen)) return chosen;
    return debugSystemLanguageOverride ??
        L10n.resolve(deviceLocale.languageCode);
  }

  static Future<AppSettings> load() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final settings = AppSettings(preferences: preferences);
    if (preferences != null) {
      final p = preferences;
      settings._languageCode = p.getString('${_prefix}language');
      settings._themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == p.getString('${_prefix}theme'),
        orElse: () => ThemeMode.system,
      );
      final scale = p.getDouble('${_prefix}textScale') ?? 1.0;
      settings._textScale = textScaleOptions.contains(scale) ? scale : 1.0;
      final accent = p.getInt('${_prefix}accent') ?? 0;
      settings._accentIndex = accent >= 0 && accent < accentColors.length
          ? accent
          : 0;
      settings._highContrast = p.getBool('${_prefix}highContrast') ?? false;
      settings._reduceMotion = p.getBool('${_prefix}reduceMotion') ?? false;
      settings._defaultCurrency = currencySpec(
        p.getString('${_prefix}currency'),
      ).code;
      settings._currencyChosen = p.getString('${_prefix}currency') != null;
      settings._onboardingDone = p.getBool('${_prefix}onboarded') ?? false;
      settings._appLock = p.getBool('${_prefix}appLock') ?? false;
    }
    instance = settings;
    return settings;
  }

  /// Suggests a currency from the phone's region the first time the app runs.
  void suggestCurrencyFromLocale(Locale locale) {
    if (_currencyChosen) return;
    _defaultCurrency =
        currencyForCountry(locale.countryCode) ??
        currencyForLanguage(locale.languageCode);
  }

  Future<void> setLanguage(String? code) async {
    _languageCode = code;
    if (code == null) {
      await _preferences?.remove('${_prefix}language');
    } else {
      await _preferences?.setString('${_prefix}language', code);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences?.setString('${_prefix}theme', mode.name);
    notifyListeners();
  }

  Future<void> setTextScale(double scale) async {
    _textScale = scale;
    await _preferences?.setDouble('${_prefix}textScale', scale);
    notifyListeners();
  }

  Future<void> setAccentIndex(int index) async {
    _accentIndex = index.clamp(0, accentColors.length - 1);
    await _preferences?.setInt('${_prefix}accent', _accentIndex);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await _preferences?.setBool('${_prefix}highContrast', value);
    notifyListeners();
  }

  Future<void> setReduceMotion(bool value) async {
    _reduceMotion = value;
    await _preferences?.setBool('${_prefix}reduceMotion', value);
    notifyListeners();
  }

  Future<void> setDefaultCurrency(String code) async {
    _defaultCurrency = currencySpec(code).code;
    _currencyChosen = true;
    await _preferences?.setString('${_prefix}currency', _defaultCurrency);
    notifyListeners();
  }

  Future<void> setAppLock(bool value) async {
    _appLock = value;
    await _preferences?.setBool('${_prefix}appLock', value);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingDone = true;
    await _preferences?.setBool('${_prefix}onboarded', true);
    notifyListeners();
  }
}

/// Best-guess currency for an ISO 3166 country code.
String? currencyForCountry(String? country) {
  if (country == null) return null;
  const euro = {
    'AT',
    'BE',
    'CY',
    'DE',
    'EE',
    'ES',
    'FI',
    'FR',
    'GR',
    'HR',
    'IE',
    'IT',
    'LT',
    'LU',
    'LV',
    'MT',
    'NL',
    'PT',
    'SI',
    'SK',
  };
  if (euro.contains(country)) return 'EUR';
  const map = {
    'ID': 'IDR',
    'US': 'USD',
    'GB': 'GBP',
    'MY': 'MYR',
    'SG': 'SGD',
    'TH': 'THB',
    'PH': 'PHP',
    'VN': 'VND',
    'IN': 'INR',
    'PK': 'PKR',
    'BD': 'BDT',
    'CN': 'CNY',
    'JP': 'JPY',
    'KR': 'KRW',
    'HK': 'HKD',
    'TW': 'TWD',
    'AU': 'AUD',
    'NZ': 'NZD',
    'CA': 'CAD',
    'MX': 'MXN',
    'BR': 'BRL',
    'AR': 'ARS',
    'CO': 'COP',
    'CL': 'CLP',
    'PE': 'PEN',
    'CH': 'CHF',
    'SE': 'SEK',
    'NO': 'NOK',
    'DK': 'DKK',
    'PL': 'PLN',
    'TR': 'TRY',
    'RU': 'RUB',
    'UA': 'UAH',
    'SA': 'SAR',
    'AE': 'AED',
    'QA': 'QAR',
    'EG': 'EGP',
    'NG': 'NGN',
    'KE': 'KES',
    'ZA': 'ZAR',
    'GH': 'GHS',
  };
  return map[country];
}

/// Fallback when the phone reports a language but no region.
String currencyForLanguage(String languageCode) => switch (languageCode) {
  'id' => 'IDR',
  'ms' => 'MYR',
  'th' => 'THB',
  'vi' => 'VND',
  'hi' => 'INR',
  'zh' => 'CNY',
  'ja' => 'JPY',
  'de' || 'fr' => 'EUR',
  'ar' => 'SAR',
  'pt' => 'BRL',
  _ => 'USD',
};
