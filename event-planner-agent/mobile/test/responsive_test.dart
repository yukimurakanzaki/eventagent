import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';

void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      WargakasApp(controller: CashbookController.forTesting()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone width keeps the bottom bar', (tester) async {
    await pump(tester, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('wide screen uses a rail and a centred reading column', (
    tester,
  ) async {
    await pump(tester, const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.getSize(find.byType(SummaryPage)).width,
      lessThanOrEqualTo(720),
    );

    await tester.tap(find.text('Peserta').last);
    await tester.pumpAndSettle();
    expect(find.byType(ParticipantsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
