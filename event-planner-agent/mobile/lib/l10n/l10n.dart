import 'translations/ar.dart';
import 'translations/de.dart';
import 'translations/en.dart';
import 'translations/es.dart';
import 'translations/fr.dart';
import 'translations/hi.dart';
import 'translations/ja.dart';
import 'translations/ms.dart';
import 'translations/pt.dart';
import 'translations/th.dart';
import 'translations/vi.dart';
import 'translations/zh.dart';

/// A language the app ships with. [nativeName] is shown in the picker so a
/// person who cannot read the current language can still find their own.
class AppLanguage {
  const AppLanguage(
    this.code,
    this.nativeName,
    this.englishName, {
    this.rtl = false,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final bool rtl;
}

/// Gettext-style localisation.
///
/// Source strings are written in Indonesian (the pilot language) and double
/// as lookup keys, so `tr('Peserta')` reads naturally in code and a missing
/// translation degrades to English, then to the Indonesian source, never to a
/// blank label. Placeholders use `{name}` and are filled from [args].
class L10n {
  L10n._();

  static const source = 'id';

  static const languages = <AppLanguage>[
    AppLanguage('en', 'English', 'English'),
    AppLanguage('id', 'Bahasa Indonesia', 'Indonesian'),
    AppLanguage('ms', 'Bahasa Melayu', 'Malay'),
    AppLanguage('es', 'Español', 'Spanish'),
    AppLanguage('pt', 'Português', 'Portuguese'),
    AppLanguage('fr', 'Français', 'French'),
    AppLanguage('de', 'Deutsch', 'German'),
    AppLanguage('vi', 'Tiếng Việt', 'Vietnamese'),
    AppLanguage('th', 'ไทย', 'Thai'),
    AppLanguage('hi', 'हिन्दी', 'Hindi'),
    AppLanguage('ar', 'العربية', 'Arabic', rtl: true),
    AppLanguage('zh', '中文', 'Chinese'),
    AppLanguage('ja', '日本語', 'Japanese'),
  ];

  static const Map<String, Map<String, String>> catalogs = {
    'en': en,
    'ms': ms,
    'es': es,
    'pt': pt,
    'fr': fr,
    'de': de,
    'vi': vi,
    'th': th,
    'hi': hi,
    'ar': ar,
    'zh': zh,
    'ja': ja,
  };

  static String _code = source;

  /// The active language code. Set by the app shell before each build.
  static String get code => _code;

  static set code(String value) {
    _code = isSupported(value) ? value : 'en';
  }

  static bool isSupported(String code) =>
      languages.any((language) => language.code == code);

  static AppLanguage languageFor(String code) => languages.firstWhere(
    (language) => language.code == code,
    orElse: () => languages.first,
  );

  /// Picks the best shipped language for a device locale, English otherwise.
  static String resolve(String? deviceLanguageCode) {
    if (deviceLanguageCode != null && isSupported(deviceLanguageCode)) {
      return deviceLanguageCode;
    }
    return 'en';
  }

  static String lookup(String key, String code) {
    if (code == source) return key;
    return catalogs[code]?[key] ?? catalogs['en']?[key] ?? key;
  }
}

/// Translates an Indonesian source string into the active language.
String tr(String key, [Map<String, Object?> args = const {}]) {
  var text = L10n.lookup(key, L10n.code);
  if (args.isEmpty) return text;
  args.forEach((name, value) {
    text = text.replaceAll('{$name}', '${value ?? ''}');
  });
  return text;
}
