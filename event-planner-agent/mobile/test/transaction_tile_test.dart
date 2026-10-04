import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';

void main() {
  testWidgets('history shows direction by sign and icon, not color alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );
    await tester.tap(find.text('Uang').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Uang muka bus'), 200);

    // 'Uang muka bus' is an expense: outflow sign + upward arrow.
    expect(find.textContaining('−Rp'), findsWidgets);
    expect(find.byIcon(Icons.arrow_upward), findsWidgets);
  });
}
