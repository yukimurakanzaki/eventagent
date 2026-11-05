import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/app_settings.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/l10n/l10n.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/money.dart';

/// Opens every main screen in every shipped language on a small phone with
/// large text. Overflows and missing localisations throw in tests, so this
/// catches layouts that break for longer languages or right-to-left text.
void main() {
  tearDown(() {
    L10n.code = 'id';
    Money.currency = 'IDR';
  });

  for (final language in L10n.languages) {
    testWidgets('${language.code}: all tabs and settings render', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final settings = AppSettings();
      await settings.setLanguage(language.code);
      await settings.setTextScale(1.3);
      await tester.pumpWidget(
        WargakasApp(
          controller: CashbookController.forTesting(),
          settings: settings,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(NavigationBar))),
        language.rtl ? TextDirection.rtl : TextDirection.ltr,
      );
      final bar = find.byType(NavigationBar);
      for (final icon in [
        Icons.groups_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.description_outlined,
        Icons.dashboard_outlined,
      ]) {
        await tester.tap(find.descendant(of: bar, matching: find.byIcon(icon)));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      // Overflow and other framework errors fail the test with full details.
    });
  }
}
