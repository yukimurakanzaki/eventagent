import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_settings.dart';
import 'l10n/l10n.dart';
import 'main.dart' show wargakasTheme;

/// The single MaterialApp configuration every entry point uses, so language,
/// theme, accent, contrast and text size apply the same way everywhere.
class WargakasMaterialApp extends StatelessWidget {
  const WargakasMaterialApp({
    required this.home,
    this.settings,
    this.navigatorKey,
    super.key,
  });

  final Widget home;
  final AppSettings? settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  static const _materialLocales = <Locale>[
    Locale('en'),
    Locale('id'),
    Locale('ms'),
    Locale('es'),
    Locale('pt'),
    Locale('fr'),
    Locale('de'),
    Locale('vi'),
    Locale('th'),
    Locale('hi'),
    Locale('ar'),
    Locale('zh'),
    Locale('ja'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = this.settings ?? AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final language = settings.effectiveLanguage(deviceLocale);
        L10n.code = language;
        return MaterialApp(
          // Rebuild the whole tree when the language changes so const
          // widgets pick up new strings.
          key: ValueKey('app-$language'),
          navigatorKey: navigatorKey,
          title: 'Wargakas',
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          supportedLocales: _materialLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          themeMode: settings.themeMode,
          themeAnimationDuration: settings.reduceMotion
              ? Duration.zero
              : kThemeAnimationDuration,
          theme: wargakasTheme(
            seedColor: settings.accentColor,
            highContrast: settings.highContrast,
          ),
          darkTheme: wargakasTheme(
            brightness: Brightness.dark,
            seedColor: settings.accentColor,
            highContrast: settings.highContrast,
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final systemScale = media.textScaler.scale(16) / 16;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  (systemScale * settings.textScale).clamp(0.8, 3.0),
                ),
                disableAnimations:
                    media.disableAnimations || settings.reduceMotion,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: home,
        );
      },
    );
  }
}
