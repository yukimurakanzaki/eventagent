import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/supabase_app.dart';

import 'auth_test.dart' show FakeBackend, tap;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('AUTH_SCREENSHOTS')) return;
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final fonts = '${artifacts.path}/material_fonts';
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(
        File('$fonts/${font.value}')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)),
      );
      await loader.load();
    }
  });
  testWidgets('auth forms remain scrollable on a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final backend = FakeBackend();
    addTearDown(backend.events.close);
    final captureKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wargakasTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: LoginPage(backend: backend),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (!const bool.fromEnvironment('AUTH_SCREENSHOTS')) return;
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = await Directory('build/auth-review')
            .create(recursive: true);
        await File('${directory.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('login');
    await tap(tester, 'auth-register');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 1000),
    );
    await capture('register');
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'secret123');
    await tester.enterText(
      find.byKey(const Key('auth-confirmation')),
      'secret123',
    );
    await tap(tester, 'auth-submit');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 1000),
    );
    await capture('registration-result');
    await tap(tester, 'auth-forgot');
    await tester.pump(const Duration(seconds: 61));
    await tap(tester, 'auth-submit');
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, 1000),
    );
    await capture('forgot-password-result');
    await tap(tester, 'auth-login');
    expect(find.text('Masuk ke Wargakas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
