import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wargakas_mobile/auth_support.dart';
import 'package:wargakas_mobile/cashbook_controller.dart';
import 'package:wargakas_mobile/main.dart';
import 'package:wargakas_mobile/supabase_app.dart';
import 'package:wargakas_mobile/supabase_backend.dart';

Session session(String id) => Session(
  accessToken: 'test-token',
  tokenType: 'bearer',
  user: User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-09-05',
    email: '$id@example.com',
  ),
);

class FakeBackend implements SupabaseBackend {
  final events = StreamController<AuthState>.broadcast(sync: true);
  Session? activeSession;
  Object? failure;
  Completer<void>? pending;
  AuthResponse signupResponse = AuthResponse();
  final calls = <String>[];
  String? lastEmail;
  String? lastPassword;
  int loads = 0;
  Future<OpenedCashbook> Function()? onLoad;
  bool updateEmitsEvent = false;

  @override
  User? get user => activeSession?.user;
  @override
  Session? get currentSession => activeSession;
  @override
  Stream<AuthState> get authChanges => events.stream;

  void emit(AuthChangeEvent event, Session? value) {
    activeSession = value;
    events.add(AuthState(event, value));
  }

  Future<void> request(String action, [String? email, String? password]) async {
    calls.add(action);
    lastEmail = email;
    lastPassword = password;
    if (failure != null) throw failure!;
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> signIn(String email, String password) =>
      request('login', email, password);
  @override
  Future<AuthResponse> signUp(String email, String password) async {
    await request('signup', email, password);
    return signupResponse;
  }

  @override
  Future<void> sendPasswordReset(String email) => request('reset', email);
  @override
  Future<void> resendSignupConfirmation(String email) =>
      request('resend', email);
  @override
  Future<void> updatePassword(String password) async {
    await request('update', null, password);
    if (updateEmitsEvent) emit(AuthChangeEvent.userUpdated, activeSession);
  }

  @override
  Future<void> signOut() async {
    await request('logout');
    emit(AuthChangeEvent.signedOut, null);
  }

  @override
  Future<OpenedCashbook> loadCashbook() async {
    loads++;
    return onLoad != null
        ? onLoad!()
        : OpenedCashbook(
            CashbookController.forTesting(),
            'workspace-${user?.id}',
            'treasurer',
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> form(WidgetTester tester, FakeBackend backend) async {
  tester.view.resetPhysicalSize();
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(backend.events.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: wargakasTheme(),
      home: LoginPage(backend: backend),
    ),
  );
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> credentials(
  WidgetTester tester, {
  String password = 'secret123',
}) async {
  await tester.enterText(
    find.byKey(const Key('auth-email')),
    ' person@example.com ',
  );
  await tester.enterText(find.byKey(const Key('auth-password')), password);
}

void main() {
  testWidgets('recovery input survives a network banner and dismiss', (
    tester,
  ) async {
    final backend = FakeBackend();
    addTearDown(backend.events.close);
    await tester.pumpWidget(SupabaseApp(backend: backend));
    backend.emit(AuthChangeEvent.passwordRecovery, session('recovery'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recovery-password')),
      'not-lost',
    );
    backend.events.addError(AuthRetryableFetchException());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('recovery-password')))
          .controller!
          .text,
      'not-lost',
    );
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('recovery-password')))
          .controller!
          .text,
      'not-lost',
    );
  });

  testWidgets('automatic signout explains expiry and removes recovery form', (
    tester,
  ) async {
    final backend = FakeBackend();
    addTearDown(backend.events.close);
    await tester.pumpWidget(SupabaseApp(backend: backend));
    backend.emit(AuthChangeEvent.passwordRecovery, session('recovery'));
    await tester.pumpAndSettle();
    backend.activeSession = null;
    backend.events.add(
      const AuthState(
        AuthChangeEvent.signedOut,
        null,
        signOutReason: SignOutReason.sessionExpired,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sesi sudah berakhir'), findsOneWidget);
    expect(find.byType(PasswordRecoveryPage), findsNothing);
    expect(find.text('Masuk ke Wargakas'), findsOneWidget);
  });

  testWidgets('recovery cancel failure is handled and can be retried', (
    tester,
  ) async {
    final backend = FakeBackend()..failure = AuthRetryableFetchException();
    addTearDown(backend.events.close);
    await tester.pumpWidget(SupabaseApp(backend: backend));
    backend.emit(AuthChangeEvent.passwordRecovery, session('recovery'));
    await tester.pumpAndSettle();
    final cancel = find.text('Batal dan kembali ke masuk');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak dapat terhubung'), findsOneWidget);
    backend.failure = null;
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke Wargakas'), findsOneWidget);
  });

  testWidgets('workspace timeout offers retry and handles signout failure', (
    tester,
  ) async {
    final delayed = Completer<OpenedCashbook>();
    final backend = FakeBackend()
      ..activeSession = session('one')
      ..onLoad = () => delayed.future;
    addTearDown(backend.events.close);
    await tester.pumpWidget(SupabaseApp(backend: backend));
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(find.text('Acara bersama belum dapat dibuka.'), findsOneWidget);
    backend.failure = AuthRetryableFetchException();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tidak dapat terhubung'), findsOneWidget);
    backend.onLoad = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Acara Saya'), findsOneWidget);
    delayed.complete(
      OpenedCashbook(CashbookController.forTesting(), 'stale', 'chairperson'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final action in ['reset']) {
    testWidgets(
      '$action delivery failure never shows success and allows retry',
      (tester) async {
        final backend = FakeBackend()
          ..failure = const AuthException(
            'raw',
            code: 'email_address_not_authorized',
          );
        await form(tester, backend);
        await tester.enterText(
          find.byKey(const Key('auth-email')),
          'person@example.com',
        );
        if (action == 'reset') await tap(tester, 'auth-forgot');
        await tap(tester, action == 'reset' ? 'auth-submit' : 'auth-resend');
        expect(
          find.textContaining('Layanan email belum dapat'),
          findsOneWidget,
        );
        expect(find.text(resetAcceptedMessage), findsNothing);
        expect(find.text(resendAcceptedMessage), findsNothing);
        await tester.pump(const Duration(seconds: 61));
        backend.failure = null;
        await tap(tester, action == 'reset' ? 'auth-submit' : 'auth-resend');
        expect(backend.calls, [action, action]);
      },
    );
  }

  testWidgets('resend is shown only for a confirmation state', (tester) async {
    final backend = FakeBackend();
    await form(tester, backend);

    expect(find.byKey(const Key('auth-resend')), findsNothing);
    await tap(tester, 'auth-register');
    await credentials(tester);
    await tester.enterText(
      find.byKey(const Key('auth-confirmation')),
      'secret123',
    );
    await tap(tester, 'auth-submit');

    expect(find.byKey(const Key('auth-resend')), findsOneWidget);
  });
  group('Validation and errors', () {
    for (final email in [
      '',
      'a@',
      '@example.com',
      'a@b',
      'a b@c.com',
      'a@@b.com',
      '.a@b.com',
      'a..b@c.com',
    ]) {
      test(
        'rejects malformed email "$email"',
        () => expect(validateAuthEmail(email), isNotNull),
      );
    }
    test(
      'accepts trimmed plus addressing',
      () => expect(validateAuthEmail(' person+trip@example.co.id '), isNull),
    );
    test('new password rules preserve intentional whitespace', () {
      expect(validateNewPassword('      ', '      '), isNotNull);
      expect(validateNewPassword('abcdef', 'abcdeg'), contains('belum sama'));
      expect(validateNewPassword(' pass word ', ' pass word '), isNull);
    });
    final errors = <String, String>{
      'invalid_credentials': 'Email atau kata sandi tidak cocok',
      'email_not_confirmed': 'Email belum dikonfirmasi',
      'user_already_exists': 'sudah terdaftar',
      'email_exists': 'sudah terdaftar',
      'otp_expired': 'kedaluwarsa',
      'flow_state_not_found': 'perangkat',
      'bad_code_verifier': 'perangkat',
      'session_expired': 'Sesi sudah berakhir',
      'refresh_token_not_found': 'Sesi sudah berakhir',
      'over_email_send_rate_limit': 'Terlalu banyak',
      'email_address_not_authorized': 'Layanan email',
      'weak_password': 'aturan keamanan',
      'same_password': 'harus berbeda',
      'signup_disabled': 'dinonaktifkan',
      'captcha_failed': 'Verifikasi keamanan',
      'reauthentication_needed': 'Verifikasi ulang',
    };
    for (final entry in errors.entries) {
      test('translates ${entry.key} without exposing raw errors', () {
        final message = authErrorMessage(
          AuthException('private server details', code: entry.key),
        );
        expect(message, contains(entry.value));
        expect(message, isNot(contains('private server details')));
      });
    }
    test('unknown error and timeout never claim success', () {
      expect(
        authErrorMessage(const AuthException('private payload')),
        isNot(contains('private payload')),
      );
      expect(
        authErrorMessage(TimeoutException('test')),
        contains('belum dapat dipastikan'),
      );
      expect(
        authErrorMessage(const AuthException('Invalid login credentials')),
        isNot(contains('Link email')),
      );
    });
  });

  testWidgets('invalid email and empty password never call the server', (
    tester,
  ) async {
    final backend = FakeBackend();
    await form(tester, backend);
    await tester.enterText(find.byKey(const Key('auth-email')), 'person@');
    await tap(tester, 'auth-submit');
    expect(backend.calls, isEmpty);
    expect(find.textContaining('email lengkap'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'person@example.com',
    );
    await tap(tester, 'auth-submit');
    expect(find.text('Masukkan kata sandi Anda.'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('login permits legacy short passwords and preserves whitespace', (
    tester,
  ) async {
    final backend = FakeBackend();
    await form(tester, backend);
    await credentials(tester, password: ' a ');
    await tap(tester, 'auth-submit');
    expect(backend.calls, ['login']);
    expect(backend.lastEmail, 'person@example.com');
    expect(backend.lastPassword, ' a ');
  });

  testWidgets(
    'registration checks confirmation before sending and clears passwords on mode changes',
    (tester) async {
      final backend = FakeBackend();
      await form(tester, backend);
      await tap(tester, 'auth-register');
      await credentials(tester);
      await tester.enterText(
        find.byKey(const Key('auth-confirmation')),
        'wrong',
      );
      await tap(tester, 'auth-submit');
      expect(backend.calls, isEmpty);
      expect(find.textContaining('belum sama'), findsOneWidget);
      await tap(tester, 'auth-login');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('auth-password')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'obfuscated signup is conditional and offers login without a resend loop',
    (tester) async {
      final backend = FakeBackend();
      await form(tester, backend);
      await tap(tester, 'auth-register');
      await credentials(tester);
      await tester.enterText(
        find.byKey(const Key('auth-confirmation')),
        'secret123',
      );
      await tap(tester, 'auth-submit');
      expect(find.text(signupAcceptedMessage), findsOneWidget);
      expect(find.textContaining('Akun dibuat.'), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(const Key('auth-email'))).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('auth-resend')))
            .onPressed,
        isNull,
      );
      await tap(tester, 'auth-submit');
      expect(find.text('Masuk ke Wargakas'), findsOneWidget);
      expect(backend.calls, ['signup']);
    },
  );

  testWidgets(
    'explicit duplicate returns to login with actionable explanation',
    (tester) async {
      final backend = FakeBackend()
        ..failure = const AuthException(
          'User already registered',
          code: 'user_already_exists',
        );
      await form(tester, backend);
      await tap(tester, 'auth-register');
      await credentials(tester);
      await tester.enterText(
        find.byKey(const Key('auth-confirmation')),
        'secret123',
      );
      await tap(tester, 'auth-submit');
      expect(find.text('Masuk ke Wargakas'), findsOneWidget);
      expect(find.textContaining('Email ini sudah terdaftar.'), findsOneWidget);
      expect(find.byKey(const Key('auth-forgot')), findsOneWidget);
    },
  );

  testWidgets(
    'wrong credentials stay on login; unconfirmed account offers confirmation',
    (tester) async {
      final backend = FakeBackend()
        ..failure = const AuthException('raw', code: 'invalid_credentials');
      await form(tester, backend);
      await credentials(tester);
      await tap(tester, 'auth-submit');
      expect(
        find.textContaining('Email atau kata sandi tidak cocok'),
        findsOneWidget,
      );
      expect(find.textContaining('kedaluwarsa'), findsNothing);
      backend.failure = const AuthException('raw', code: 'email_not_confirmed');
      await tap(tester, 'auth-submit');
      expect(find.text('Periksa email atau masuk'), findsOneWidget);
      expect(find.textContaining('Email belum dikonfirmasi.'), findsOneWidget);
    },
  );

  testWidgets(
    'forgot password is conditional, cooldown survives switching modes',
    (tester) async {
      final backend = FakeBackend();
      await form(tester, backend);
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'unknown@example.com',
      );
      await tap(tester, 'auth-forgot');
      expect(find.byKey(const Key('auth-password')), findsNothing);
      await tap(tester, 'auth-submit');
      expect(find.text(resetAcceptedMessage), findsOneWidget);
      expect(backend.calls, ['reset']);
      await tap(tester, 'auth-login');
      expect(find.byKey(const Key('auth-resend')), findsNothing);
      await tester.pump(const Duration(seconds: 61));
      expect(find.byKey(const Key('auth-resend')), findsNothing);
      expect(backend.calls, ['reset']);
    },
  );

  testWidgets('rate limiting blocks repeated submissions then allows retry', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..failure = const AuthException('raw', statusCode: '429');
    await form(tester, backend);
    await credentials(tester);
    await tap(tester, 'auth-submit');
    expect(find.textContaining('Terlalu banyak'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 61));
    backend.failure = null;
    await tap(tester, 'auth-submit');
    expect(backend.calls, ['login', 'login']);
  });

  testWidgets(
    'pending submission locks fields and guards double calls, timeout is retryable',
    (tester) async {
      final backend = FakeBackend()..pending = Completer<void>();
      await form(tester, backend);
      await credentials(tester);
      final submit = tester
          .widget<FilledButton>(find.byKey(const Key('auth-submit')))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(backend.calls, ['login']);
      expect(
        tester.widget<TextField>(find.byKey(const Key('auth-email'))).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('auth-password')))
            .enabled,
        isFalse,
      );
      await tester.pump(const Duration(seconds: 31));
      expect(find.textContaining('belum dapat dipastikan'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('auth-submit')))
            .onPressed,
        isNotNull,
      );
      backend.pending!.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposal during a request does not call setState afterwards', (
    tester,
  ) async {
    final backend = FakeBackend()..pending = Completer<void>();
    await form(tester, backend);
    await credentials(tester);
    await tap(tester, 'auth-submit');
    await tester.pumpWidget(const SizedBox());
    backend.pending!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recovery survives refresh and userUpdated and completes into the workspace',
    (tester) async {
      final backend = FakeBackend()..updateEmitsEvent = true;
      addTearDown(backend.events.close);
      await tester.pumpWidget(SupabaseApp(backend: backend));
      backend.emit(AuthChangeEvent.passwordRecovery, session('recovery'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('recovery-password')),
        'newSecret123',
      );
      await tester.enterText(
        find.byKey(const Key('recovery-confirmation')),
        'newSecret123',
      );
      backend.emit(AuthChangeEvent.tokenRefreshed, session('recovery'));
      await tester.pump();
      expect(find.byType(PasswordRecoveryPage), findsOneWidget);
      expect(backend.loads, 0);
      await tap(tester, 'recovery-save');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Kata sandi berhasil diperbarui.'),
        findsOneWidget,
      );
      expect(backend.loads, 0);
      await tester.tap(find.text('Lanjut ke acara'));
      await tester.pumpAndSettle();
      expect(find.text('Acara Saya'), findsOneWidget);
      expect(backend.loads, 1);
      backend.emit(AuthChangeEvent.tokenRefreshed, session('recovery'));
      backend.emit(AuthChangeEvent.signedIn, session('recovery'));
      await tester.pumpAndSettle();
      expect(backend.loads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('recovery validation, duplicate save and same-password failure', (
    tester,
  ) async {
    final backend = FakeBackend()
      ..failure = const AuthException('raw', code: 'same_password');
    addTearDown(backend.events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordRecoveryPage(backend: backend, onCompleted: () {}),
      ),
    );
    await tap(tester, 'recovery-save');
    expect(backend.calls, isEmpty);
    await tester.enterText(
      find.byKey(const Key('recovery-password')),
      'newSecret123',
    );
    await tester.enterText(
      find.byKey(const Key('recovery-confirmation')),
      'newSecret123',
    );
    await tap(tester, 'recovery-save');
    expect(find.textContaining('harus berbeda'), findsOneWidget);
    backend.failure = null;
    backend.pending = Completer<void>();
    final save = tester
        .widget<FilledButton>(find.byKey(const Key('recovery-save')))
        .onPressed!;
    save();
    save();
    await tester.pump();
    expect(backend.calls, ['update', 'update']);
    backend.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('berhasil diperbarui'), findsOneWidget);
  });

  testWidgets(
    'network auth error preserves session, expired session returns to login',
    (tester) async {
      final backend = FakeBackend()..activeSession = session('one');
      addTearDown(backend.events.close);
      await tester.pumpWidget(SupabaseApp(backend: backend));
      await tester.pumpAndSettle();
      backend.events.addError(AuthRetryableFetchException());
      await tester.pumpAndSettle();
      expect(find.text('Acara Saya'), findsOneWidget);
      expect(find.textContaining('Periksa koneksi internet'), findsOneWidget);
      expect(backend.loads, 1);
      backend.events.addError(
        const AuthException('raw', code: 'refresh_token_not_found'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke Wargakas'), findsOneWidget);
      expect(find.text('Acara Saya'), findsNothing);
    },
  );

  testWidgets(
    'late workspace response from old account cannot replace new account',
    (tester) async {
      final oldLoad = Completer<OpenedCashbook>();
      final newLoad = Completer<OpenedCashbook>();
      final backend = FakeBackend()..activeSession = session('old');
      backend.onLoad = () =>
          backend.user!.id == 'old' ? oldLoad.future : newLoad.future;
      addTearDown(backend.events.close);
      await tester.pumpWidget(SupabaseApp(backend: backend));
      backend.emit(AuthChangeEvent.signedOut, null);
      await tester.pump();
      backend.emit(AuthChangeEvent.signedIn, session('new'));
      await tester.pump();
      oldLoad.complete(
        OpenedCashbook(
          CashbookController.forTesting(),
          'old-space',
          'chairperson',
        ),
      );
      await tester.pump();
      expect(find.text('Acara Saya'), findsNothing);
      newLoad.complete(
        OpenedCashbook(
          CashbookController.forTesting(),
          'new-space',
          'treasurer',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Acara Saya'), findsOneWidget);
      await tester.tap(find.byTooltip('Akun'));
      await tester.pumpAndSettle();
      expect(find.text('new@example.com'), findsOneWidget);
      expect(find.text('Bendahara'), findsOneWidget);
      expect(find.text('old@example.com'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
