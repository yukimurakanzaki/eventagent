import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:wargakas_mobile/app_settings.dart';
import 'package:wargakas_mobile/l10n/l10n.dart';

/// The original widget tests assert Indonesian copy, so "follow the phone"
/// resolves to Indonesian here. Tests for other languages set it explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppSettings.debugSystemLanguageOverride = 'id';
  L10n.code = 'id';
  await initializeDateFormatting();
  await testMain();
}
