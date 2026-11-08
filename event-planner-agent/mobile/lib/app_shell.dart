import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_lock.dart';
import 'app_settings.dart';
import 'l10n/l10n.dart';
import 'main.dart' show wargakasTheme;
import 'onboarding_page.dart';

/// The single MaterialApp configuration every entry point uses, so language,
/// theme, accent, contrast and text size apply the same way everywhere.
class WargakasMaterialApp extends StatefulWidget {
  const WargakasMaterialApp({
    required this.home,
    this.settings,
    this.navigatorKey,
    this.enableOnboarding = false,
    super.key,
  });

  /// Shows the first-run welcome until it is completed once. Off in tests
  /// and embedded screens.
  final bool enableOnboarding;
  final Widget home;
  final AppSettings? settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<WargakasMaterialApp> createState() => _WargakasMaterialAppState();
}

class _WargakasMaterialAppState extends State<WargakasMaterialApp>
    with WidgetsBindingObserver {
  String? _language;
  bool _locked = false;
  DateTime? _backgroundedAt;

  AppSettings get _settings => widget.settings ?? AppSettings.instance;

  @override
  void initState() {
    super.initState();
    _locked = _settings.appLock;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null &&
          _settings.appLock &&
          !_locked &&
          DateTime.now().difference(since) > AppLock.gracePeriod) {
        setState(() => _locked = true);
      }
    }
  }

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
            final locked = _locked && settings.appLock;
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(
                  (systemScale * settings.textScale).clamp(0.8, 3.0),
                ),
                disableAnimations:
                    media.disableAnimations || settings.reduceMotion,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ExcludeSemantics(
                    excluding: locked,
                    child: IgnorePointer(
                      ignoring: locked,
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                  if (locked)
                    Positioned.fill(
                      child: AppLockScreen(
                        onUnlocked: () => setState(() => _locked = false),
                      ),
                    ),
                ],
              ),
            );
          },
          home: widget.enableOnboarding && !settings.onboardingDone
              ? OnboardingPage(settings: settings, onDone: () {})
              : widget.home,
        );
      },
    );
  }
}
