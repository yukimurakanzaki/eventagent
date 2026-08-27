import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cashbook_controller.dart';
import 'cashbook_models.dart';
import 'main.dart' show EventHomePage, wargakasTheme;
import 'supabase_backend.dart';

class SupabaseApp extends StatefulWidget {
  const SupabaseApp({required this.backend, super.key});

  final SupabaseBackend backend;

  @override
  State<SupabaseApp> createState() => _SupabaseAppState();
}

class _SupabaseAppState extends State<SupabaseApp> {
  Session? _session;
  Future<CashbookController>? _controllerFuture;
  StreamSubscription<AuthState>? _authSubscription;
  String? _workspaceId;

  @override
  void initState() {
    super.initState();
    _session = widget.backend.client.auth.currentSession;
    _authSubscription = widget.backend.authChanges.listen((state) {
      if (!mounted) return;
      setState(() {
        _session = state.session;
        _controllerFuture = state.session == null ? null : _loadController();
      });
    });
    if (_session != null) _controllerFuture = _loadController();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<CashbookController> _loadController() async {
    final adapter = await widget.backend.openCashbook(CashbookSnapshot.demo());
    _workspaceId = adapter.workspaceId;
    return CashbookController.bootstrap(syncAdapter: adapter);
  }

  Future<void> _inviteChairperson(String email) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) throw StateError('workspace belum siap');
    await widget.backend.inviteChairperson(
      workspaceId: workspaceId,
      email: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wargakas',
      debugShowCheckedModeBanner: false,
      theme: wargakasTheme(),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_session == null) {
      return LoginPage(backend: widget.backend);
    }

    final controllerFuture = _controllerFuture;
    if (controllerFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<CashbookController>(
      future: controllerFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SetupErrorPage(
            message: snapshot.error.toString(),
            onSignOut: widget.backend.signOut,
            onRetry: () =>
                setState(() => _controllerFuture = _loadController()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return EventHomePage(
          controller: snapshot.data!,
          onSignOut: widget.backend.signOut,
          onInviteChairperson: _inviteChairperson,
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.backend, super.key});

  final SupabaseBackend backend;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;
  bool _showResendConfirmation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@') || password.length < 6) {
      setState(
        () => _error =
            'Masukkan email yang benar dan kata sandi minimal 6 karakter.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_createAccount) {
        await widget.backend.signUp(email, password);
        if (mounted && widget.backend.user == null) {
          setState(() {
            _error = 'Akun dibuat. Periksa email untuk konfirmasi, lalu masuk.';
            _showResendConfirmation = true;
          });
        }
      } else {
        await widget.backend.signIn(email, password);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Tidak dapat terhubung. Coba lagi saat sinyal tersedia.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) return;
    setState(() => _busy = true);
    try {
      await widget.backend.resendSignupConfirmation(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permintaan diproses. Jika akun sudah dikonfirmasi, pilih Masuk.',
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak dapat mengirim ulang. Coba lagi saat sinyal tersedia.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchToSignIn() {
    setState(() {
      _createAccount = false;
      _showResendConfirmation = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Masuk ke Wargakas')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  _createAccount
                      ? 'Buat akun bersama'
                      : 'Masuk untuk melihat acara bersama',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Akun menjaga data kas tetap aman saat treasurer berganti perangkat. '
                  'Chairperson dan treasurer dapat berbagi acara melalui Supabase.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata sandi',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _busy
                          ? 'Memproses…'
                          : _createAccount
                          ? 'Buat akun'
                          : 'Masuk',
                    ),
                  ),
                ),
                if (_showResendConfirmation)
                  Column(
                    children: [
                      TextButton(
                        onPressed: _busy ? null : _resendConfirmation,
                        child: const Text('Kirim ulang email konfirmasi'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _switchToSignIn,
                        child: const Text(
                          'Akun sudah dikonfirmasi? Masuk sekarang',
                        ),
                      ),
                    ],
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _createAccount = !_createAccount;
                          _error = null;
                          _showResendConfirmation = false;
                        }),
                  child: Text(
                    _createAccount
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Buat akun',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SetupErrorPage extends StatelessWidget {
  const SetupErrorPage({
    required this.message,
    required this.onSignOut,
    required this.onRetry,
    super.key,
  });

  final String message;
  final Future<void> Function() onSignOut;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wargakas')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Acara bersama belum dapat dibuka.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
            TextButton(onPressed: onSignOut, child: const Text('Keluar')),
          ],
        ),
      ),
    );
  }
}
