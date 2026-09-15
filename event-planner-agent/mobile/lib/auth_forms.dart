import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_support.dart';
import 'supabase_backend.dart';

enum _Mode { signIn, signUp, reset, confirmation }

class LoginPage extends StatefulWidget {
  const LoginPage({required this.backend, this.initialError, super.key});
  final SupabaseBackend backend;
  final String? initialError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _obscure = true;
  bool _throttled = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void didUpdateWidget(covariant LoginPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialError != oldWidget.initialError) {
      _error = widget.initialError;
      _message = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = 60;
    var previousTick = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _cooldown = (_cooldown - (timer.tick - previousTick)).clamp(0, 60);
        previousTick = timer.tick;
        if (_cooldown == 0) {
          _throttled = false;
          timer.cancel();
        }
      });
    });
  }

  void _switchMode(_Mode mode, {String? message}) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _password.clear();
      _confirmation.clear();
      _obscure = true;
      _error = null;
      _message = message;
    });
  }

  bool get _mailBlocked => _busy || _cooldown > 0;
  bool get _submitBlocked =>
      _busy ||
      _throttled ||
      ((_mode == _Mode.signUp || _mode == _Mode.reset) && _cooldown > 0);

  Future<void> _submit() async {
    if (_submitBlocked) return;
    final email = _email.text.trim();
    final password = _password.text;
    final validation =
        validateAuthEmail(email) ??
        (_mode == _Mode.signUp
            ? validateNewPassword(password, _confirmation.text)
            : _mode == _Mode.signIn && password.isEmpty
            ? 'Masukkan kata sandi Anda.'
            : null);
    if (validation != null) {
      setState(() {
        _error = validation;
        _message = null;
      });
      return;
    }
    final mode = _mode;
    final operation = mode == _Mode.reset
        ? AuthOperation.reset
        : mode == _Mode.signUp
        ? AuthOperation.signUp
        : AuthOperation.signIn;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      if (mode != _Mode.signIn) _startCooldown();
    });
    FocusScope.of(context).unfocus();
    try {
      if (mode == _Mode.reset) {
        await widget.backend
            .sendPasswordReset(email)
            .timeout(const Duration(seconds: 30));
        if (mounted) setState(() => _message = resetAcceptedMessage);
      } else if (mode == _Mode.signUp) {
        final response = await widget.backend
            .signUp(email, password)
            .timeout(const Duration(seconds: 30));
        if (!mounted) return;
        if (response.session == null) {
          setState(() {
            _mode = _Mode.confirmation;
            // An obfuscated result is not proof that a new account was created.
            _message = signupAcceptedMessage;
            _password.clear();
            _confirmation.clear();
          });
        }
      } else {
        await widget.backend
            .signIn(email, password)
            .timeout(const Duration(seconds: 30));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error, operation: operation);
        if (error is AuthException &&
            (error.code == 'email_not_confirmed' ||
                error.message == 'Email not confirmed')) {
          _mode = _Mode.confirmation;
          _password.clear();
          _confirmation.clear();
        }
        if (error is AuthException &&
            (const {
                  'user_already_exists',
                  'email_exists',
                }.contains(error.code) ||
                error.message == 'User already registered')) {
          _mode = _Mode.signIn;
          _password.clear();
          _confirmation.clear();
        }
        if (isAuthRateLimit(error)) {
          _throttled = true;
          _startCooldown();
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_mailBlocked) return;
    final email = _email.text.trim();
    final validation = validateAuthEmail(email);
    if (validation != null) {
      setState(() {
        _error = validation;
        _message = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _startCooldown();
    });
    try {
      await widget.backend
          .resendSignupConfirmation(email)
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _mode = _Mode.confirmation;
          _message = resendAcceptedMessage;
          _password.clear();
          _confirmation.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = authErrorMessage(error, operation: AuthOperation.resend);
          if (isAuthRateLimit(error)) {
            _throttled = true;
            _startCooldown();
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _mode == _Mode.confirmation;
    final register = _mode == _Mode.signUp;
    final reset = _mode == _Mode.reset;
    final canResendConfirmation =
        pending || (_error?.contains('Email belum dikonfirmasi') ?? false);
    final title = pending
        ? 'Periksa email atau masuk'
        : register
        ? 'Buat akun Wargakas'
        : reset
        ? 'Lupa kata sandi'
        : 'Masuk ke Wargakas';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      pending
                          ? Icons.mark_email_read_outlined
                          : Icons.account_balance_wallet_outlined,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pending
                          ? 'Sudah pernah mendaftar? Anda bisa langsung mencoba Masuk.'
                          : reset
                          ? 'Masukkan email akun Anda untuk meminta link pemulihan.'
                          : register
                          ? 'Gunakan email aktif. Sudah punya akun? Pilih Masuk.'
                          : 'Masuk untuk melihat acara bersama.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('auth-email'),
                      controller: _email,
                      enabled: !_busy && !pending,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: reset
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onSubmitted: reset ? (_) => _submit() : null,
                      onChanged: (_) => setState(() {
                        _error = null;
                        _message = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (!pending && !reset) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('auth-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onSubmitted: register ? null : (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Kata sandi',
                          border: const OutlineInputBorder(),
                          helperText: register
                              ? 'Minimal 6 karakter; gunakan kata sandi yang kuat.'
                              : null,
                          helperMaxLines: 2,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Tampilkan kata sandi'
                                : 'Sembunyikan kata sandi',
                            onPressed: _busy
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (register) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('auth-confirmation'),
                        controller: _confirmation,
                        enabled: !_busy,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Ulangi kata sandi',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (_error != null) _AuthNotice(_error!, error: true),
                    if (_message != null) _AuthNotice(_message!),
                    if (pending || reset)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(authEmailHelp),
                      ),
                    if (_cooldown > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Tunggu $_cooldown detik sebelum meminta email lagi.',
                        ),
                      ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('auth-submit'),
                      onPressed: pending
                          ? (_busy ? null : () => _switchMode(_Mode.signIn))
                          : (_submitBlocked ? null : _submit),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _busy
                              ? 'Memproses…'
                              : pending
                              ? 'Masuk sekarang'
                              : register
                              ? 'Buat akun'
                              : reset
                              ? 'Kirim link pemulihan'
                              : 'Masuk',
                        ),
                      ),
                    ),
                    if (canResendConfirmation)
                      TextButton(
                        key: const Key('auth-resend'),
                        onPressed: _mailBlocked ? null : _resend,
                        child: const Text('Kirim ulang email konfirmasi'),
                      ),
                    if (!reset)
                      TextButton(
                        key: const Key('auth-forgot'),
                        onPressed: _busy
                            ? null
                            : () => _switchMode(_Mode.reset),
                        child: const Text('Lupa kata sandi?'),
                      ),
                    if (pending)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _switchMode(_Mode.signUp),
                        child: const Text('Perbaiki email pendaftaran'),
                      ),
                    if (register || reset || pending)
                      TextButton(
                        key: const Key('auth-login'),
                        onPressed: _busy
                            ? null
                            : () => _switchMode(_Mode.signIn),
                        child: const Text('Sudah punya akun? Masuk'),
                      ),
                    if (!register && !pending)
                      TextButton(
                        key: const Key('auth-register'),
                        onPressed: _busy
                            ? null
                            : () => _switchMode(_Mode.signUp),
                        child: const Text('Belum punya akun? Buat akun'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice(this.message, {this.error = false});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: TextStyle(
          color: error
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    required this.backend,
    required this.onCompleted,
    super.key,
  });
  final SupabaseBackend backend;
  final VoidCallback onCompleted;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _saved) return;
    final validation = validateNewPassword(_password.text, _confirmation.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend
          .updatePassword(_password.text)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      setState(() {
        _saved = true;
        _password.clear();
        _confirmation.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = authErrorMessage(
            error,
            operation: AuthOperation.updatePassword,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.backend.signOut().timeout(const Duration(seconds: 30));
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Buat ulang kata sandi')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset_outlined, size: 56),
                  const SizedBox(height: 16),
                  if (_saved) ...[
                    const _AuthNotice(
                      'Kata sandi berhasil diperbarui. Gunakan kata sandi baru saat masuk berikutnya.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.onCompleted,
                      child: const Text('Lanjut ke acara'),
                    ),
                  ] else ...[
                    const Text(
                      'Buat kata sandi baru',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.backend.user?.email != null)
                      Text(widget.backend.user!.email!),
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('recovery-password'),
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi baru',
                        border: const OutlineInputBorder(),
                        helperText:
                            'Minimal 6 karakter; gunakan kata sandi yang kuat.',
                        helperMaxLines: 2,
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: _busy
                              ? null
                              : () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('recovery-confirmation'),
                      controller: _confirmation,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Ulangi kata sandi baru',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) _AuthNotice(_error!, error: true),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('recovery-save'),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Menyimpan…' : 'Simpan kata sandi'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _cancel,
                      child: const Text('Batal dan kembali ke masuk'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
