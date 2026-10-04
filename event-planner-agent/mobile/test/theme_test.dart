import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/status_colors.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'light': StatusColors.light,
    'dark': StatusColors.dark,
  }.entries) {
    test('${entry.key} status colors meet 4.5:1 text contrast', () {
      final c = entry.value;
      for (final pair in [
        (c.success, c.onSuccess),
        (c.warning, c.onWarning),
        (c.danger, c.onDanger),
        (c.info, c.onInfo),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });
  }

  testWidgets('app renders in dark theme with status colors available', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );
    await tester.tap(find.text('Peserta').last);
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, Brightness.dark);
    expect(theme.extension<StatusColors>(), StatusColors.dark);
    expect(tester.takeException(), isNull);
  });
}
