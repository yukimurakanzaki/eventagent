import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_settings.dart';
import 'l10n/l10n.dart';
import 'main.dart' show wargakasTheme;

/// The single MaterialApp configuration every entry point uses, so language,
/// theme, accent, contrast and text size apply the same way everywhere.
class WargakasMaterialApp extends StatefulWidget {
  const WargakasMaterialApp({
    required this.home,
    this.settings,
    this.navigatorKey,
    super.key,
  });

  final Widget home;
  final AppSettings? settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<WargakasMaterialApp> createState() => _WargakasMaterialAppState();
}

class _WargakasMaterialAppState extends State<WargakasMaterialApp> {
  String? _language;

  /// tr() strings are not inherited-widget dependents, so a language switch
  /// marks every element dirty once. Unlike re-keying the app this keeps the
  /// open screen (e.g. Settings) and its navigation stack.
  void _rebuildEverything() {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
  }

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
    final settings = widget.settings ?? AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final language = settings.effectiveLanguage(deviceLocale);
        L10n.code = language;
        if (_language != null && _language != language) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _rebuildEverything(),
          );
        }
        _language = language;
        return MaterialApp(
          navigatorKey: widget.navigatorKey,
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
          home: widget.home,
        );
      },
    );
  }
}
