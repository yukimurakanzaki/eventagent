import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/app_lock.dart';
import 'package:wargakas_mobile/app_settings.dart';
import 'package:wargakas_mobile/app_shell.dart';
import 'package:wargakas_mobile/settings_page.dart';

class _FakeAuth implements AppLockAuthenticator {
  _FakeAuth({this.supported = true, this.succeed = true});
  bool supported;
  bool succeed;
  int calls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return succeed;
  }
}

void main() {
  late AppLockAuthenticator original;
  setUp(() => original = AppLock.authenticator);
  tearDown(() => AppLock.authenticator = original);

  Widget app(AppSettings settings) => WargakasMaterialApp(
    settings: settings,
    home: const Scaffold(body: Text('isi catatan')),
  );

  testWidgets('no lock when appLock is off', (tester) async {
    final auth = _FakeAuth();
    AppLock.authenticator = auth;
    await tester.pumpWidget(app(AppSettings()));
    await tester.pumpAndSettle();
    expect(find.text('Wargakas terkunci'), findsNothing);
    expect(auth.calls, 0);
  });

  testWidgets('lock shows and disappears after successful unlock', (
    tester,
  ) async {
    final auth = _FakeAuth();
    AppLock.authenticator = auth;
    final settings = AppSettings();
    await settings.setAppLock(true);
    await tester.pumpWidget(app(settings));
    await tester.pump();
    await tester.pumpAndSettle();
    // Auto-prompt succeeded once.
    expect(auth.calls, 1);
    expect(find.text('Wargakas terkunci'), findsNothing);
    expect(find.text('isi catatan'), findsOneWidget);
  });

  testWidgets('lock stays when authentication fails', (tester) async {
    final auth = _FakeAuth(succeed: false);
    AppLock.authenticator = auth;
    final settings = AppSettings();
    await settings.setAppLock(true);
    await tester.pumpWidget(app(settings));
    await tester.pumpAndSettle();
    expect(find.text('Wargakas terkunci'), findsOneWidget);
    expect(find.text('Buka kunci untuk melihat catatan kas.'), findsOneWidget);
    expect(auth.calls, 1);

    auth.succeed = true;
    await tester.tap(find.text('Buka kunci'));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect(find.text('Wargakas terkunci'), findsNothing);
  });

  testWidgets('fails open when unsupported at runtime', (tester) async {
    AppLock.authenticator = _FakeAuth(supported: false, succeed: false);
    final settings = AppSettings();
    await settings.setAppLock(true);
    await tester.pumpWidget(app(settings));
    await tester.pumpAndSettle();
    expect(find.text('Wargakas terkunci'), findsNothing);
  });

  testWidgets('locks again after more than 60 seconds in background', (
    tester,
  ) async {
    final auth = _FakeAuth();
    AppLock.authenticator = auth;
    final settings = AppSettings();
    await settings.setAppLock(true);
    await tester.pumpWidget(app(settings));
    await tester.pumpAndSettle();
    auth.succeed = false;

    // Short trip: no lock.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Wargakas terkunci'), findsNothing);
  });

  group('settings switch', () {
    Future<AppSettings> open(WidgetTester tester) async {
      final settings = AppSettings();
      await tester.pumpWidget(
        WargakasMaterialApp(
          settings: settings,
          home: SettingsPage(settings: settings),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kunci aplikasi'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      return settings;
    }

    testWidgets('enabling requires a successful authentication', (
      tester,
    ) async {
      final auth = _FakeAuth(succeed: false);
      AppLock.authenticator = auth;
      final settings = await open(tester);
      await tester.tap(find.text('Kunci aplikasi'));
      await tester.pumpAndSettle();
      expect(auth.calls, 1);
      expect(settings.appLock, isFalse);

      auth.succeed = true;
      await tester.tap(find.text('Kunci aplikasi'));
      await tester.pumpAndSettle();
      expect(settings.appLock, isTrue);
    });

    testWidgets('unsupported phone shows a message and stays off', (
      tester,
    ) async {
      AppLock.authenticator = _FakeAuth(supported: false);
      final settings = await open(tester);
      await tester.tap(find.text('Kunci aplikasi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ponsel ini belum mengatur kunci layar atau sidik jari.'),
        findsOneWidget,
      );
      expect(settings.appLock, isFalse);
    });
  });
}
