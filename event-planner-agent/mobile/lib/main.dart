import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app_settings.dart';
import 'app_shell.dart';
import 'formatting.dart';
import 'l10n/l10n.dart';
import 'money.dart';

import 'cashbook_calculations.dart';
import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'event_directory.dart';
import 'event_picker.dart';
import 'report_service.dart';
import 'status_chip.dart';
import 'status_colors.dart';
import 'supabase_app.dart';
import 'supabase_backend.dart';
import 'transaction_log_page.dart';

part 'ui/conflict_dialog.dart';
part 'ui/event_dialog.dart';
part 'ui/formatters.dart';
part 'ui/home_page.dart';
part 'ui/misc_dialogs.dart';
part 'ui/money_page.dart';
part 'ui/participant_dialogs.dart';
part 'ui/participants_page.dart';
part 'ui/report_page.dart';
part 'ui/summary_page.dart';
part 'ui/transaction_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final settings = await AppSettings.load();
  settings.suggestCurrencyFromLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  if (SupabaseBackend.isDemoMode) {
    final controller = await CashbookController.bootstrap();
    runApp(WargakasApp(controller: controller));
    return;
  }
  final configurationError = SupabaseBackend.configurationError;
  if (configurationError != null) {
    runApp(ConfigurationErrorApp(message: configurationError));
    return;
  }
  try {
    final backend = await SupabaseBackend.initializeFromEnvironment();
    if (backend != null) {
      runApp(SupabaseApp(backend: backend));
      return;
    }
  } catch (_) {
    runApp(
      const ConfigurationErrorApp(
        message: 'Tidak dapat memulai koneksi Supabase. Periksa build hosted.',
      ),
    );
    return;
  }
  runApp(
    const ConfigurationErrorApp(
      message: 'Supabase belum siap. Periksa konfigurasi build.',
    ),
  );
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return WargakasMaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Wargakas')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.settings_outlined, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi belum dikonfigurasi untuk login.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class WargakasApp extends StatelessWidget {
  const WargakasApp({
    required this.controller,
    this.onSignOut,
    this.onInviteChairperson,
    this.accountEmail,
    this.accountRole,
    this.eventDirectory,
    this.reportShareGateway = const PlatformReportShareGateway(),
    this.settings,
    super.key,
  });

  /// Personal preferences; defaults to [AppSettings.instance].
  final AppSettings? settings;
  final EventDirectory? eventDirectory;
  final CashbookController controller;
  final Future<void> Function()? onSignOut;
  final Future<void> Function(String email)? onInviteChairperson;
  final String? accountEmail;
  final String? accountRole;
  final ReportShareGateway reportShareGateway;

  @override
  Widget build(BuildContext context) {
    return WargakasMaterialApp(
      settings: settings,
      home: EventHomePage(
        controller: controller,
        onSignOut: onSignOut,
        onInviteChairperson: onInviteChairperson,
        accountEmail: accountEmail,
        accountRole: accountRole,
        eventDirectory: eventDirectory,
        reportShareGateway: reportShareGateway,
      ),
    );
  }
}

/// Lexend for headings/amounts, Source Sans 3 for body (bundled fonts, offline
/// safe). Body is 16sp+ for the 50+ treasurer; see design-system/wargakas.
TextTheme _wargakasTextTheme(TextTheme base) {
  const body = 'SourceSans3';
  const display = 'Lexend';
  TextStyle? b(TextStyle? s, {double? size}) =>
      s?.copyWith(fontFamily: body, fontSize: size, height: 1.5);
  TextStyle? d(TextStyle? s, {double? size, FontWeight? weight}) => s?.copyWith(
    fontFamily: display,
    fontSize: size,
    fontWeight: weight ?? FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return base.copyWith(
    displayLarge: d(base.displayLarge),
    displayMedium: d(base.displayMedium),
    displaySmall: d(base.displaySmall),
    headlineLarge: d(base.headlineLarge),
    headlineMedium: d(base.headlineMedium),
    headlineSmall: d(base.headlineSmall, size: 28),
    titleLarge: d(base.titleLarge, size: 20),
    titleMedium: d(base.titleMedium, size: 17),
    titleSmall: d(base.titleSmall, size: 15),
    bodyLarge: b(base.bodyLarge, size: 18),
    bodyMedium: b(base.bodyMedium, size: 16),
    bodySmall: b(base.bodySmall, size: 14),
    labelLarge: b(
      base.labelLarge,
      size: 16,
    )?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: b(base.labelMedium, size: 14),
    labelSmall: b(base.labelSmall, size: 13),
  );
}

ThemeData wargakasTheme({
  Brightness brightness = Brightness.light,
  Color seedColor = const Color(0xff006b5b),
  bool highContrast = false,
}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    contrastLevel: highContrast ? 1.0 : 0.0,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: _wargakasTextTheme(
      ThemeData(brightness: brightness, useMaterial3: true).textTheme,
    ),
    extensions: [dark ? StatusColors.dark : StatusColors.light],
    scaffoldBackgroundColor: dark
        ? const Color(0xff0f1715)
        : const Color(0xfff8faf8),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: dark ? const Color(0xff16211e) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highContrast ? scheme.outline : scheme.outlineVariant,
          width: highContrast ? 1.5 : 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
  );
}
