import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_forms.dart';
import 'auth_support.dart';
import 'cashbook_controller.dart';
import 'main.dart' show EventHomePage, wargakasTheme;
import 'supabase_backend.dart';

export 'auth_support.dart' show authErrorMessage;
export 'auth_forms.dart' show LoginPage, PasswordRecoveryPage;

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
  String? _role;
  String? _authError;
  bool _passwordRecovery = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.backend.currentSession;
    _authSubscription = widget.backend.authChanges.listen(
      (state) {
        if (!mounted) return;
        setState(() {
          final userChanged = _session?.user.id != state.session?.user.id;
          _session = state.session;
          _authError = null;
          if (_session == null) {
            if (state.signOutReason != null &&
                state.signOutReason != SignOutReason.userInitiated) {
              _authError =
                  'Sesi sudah berakhir. Masuk kembali untuk melanjutkan.';
            }
            _passwordRecovery = false;
            _clearController();
          } else if (state.event == AuthChangeEvent.passwordRecovery) {
            _passwordRecovery = true;
            _clearController();
          } else if (userChanged) {
            _passwordRecovery = false;
            _clearController();
            _controllerFuture = _loadController();
          } else if (!_passwordRecovery && _controllerFuture == null) {
            _controllerFuture = _loadController();
          }
          // A refresh or userUpdated event for this user must not leave the
          // recovery form, reload local state, or discard pending edits.
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() {
          if (isExpiredAuthSession(error)) {
            _session = null;
            _passwordRecovery = false;
            _clearController();
          }
          _authError = authErrorMessage(error);
        });
      },
    );
    if (_session != null) _controllerFuture = _loadController();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<CashbookController> _loadController() {
    final generation = ++_loadGeneration;
    final userId = _session?.user.id;
    Future<CashbookController> load() async {
      final opened = await widget.backend.loadCashbook();
      if (!mounted ||
          generation != _loadGeneration ||
          _session?.user.id != userId) {
        opened.controller.dispose();
        throw StateError('Pemuatan akun sebelumnya dibatalkan.');
      }
      _workspaceId = opened.workspaceId;
      _role = opened.role;
      return opened.controller;
    }

    return load().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (generation == _loadGeneration) _loadGeneration++;
        throw TimeoutException('Pemuatan acara terlalu lama.');
      },
    );
  }

  void _clearController() {
    _loadGeneration++;
    _workspaceId = null;
    _role = null;
    _controllerFuture = null;
  }

  void _finishRecovery() {
    setState(() {
      _passwordRecovery = false;
      _authError = null;
      _controllerFuture = _session == null ? null : _loadController();
    });
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
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (_authError != null && _session != null)
                MaterialBanner(
                  content: Text(_authError!),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _authError = null),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              Expanded(child: _buildHome()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHome() {
    if (_passwordRecovery) {
      return PasswordRecoveryPage(
        backend: widget.backend,
        onCompleted: _finishRecovery,
      );
    }
    if (_session == null) {
      return LoginPage(backend: widget.backend, initialError: _authError);
    }

    final controllerFuture = _controllerFuture;
    if (controllerFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return FutureBuilder<CashbookController>(
      future: controllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SetupErrorPage(
            message: 'Periksa koneksi internet lalu coba lagi. Jika tetap gagal, hubungi pengelola Wargakas.',
            onSignOut: widget.backend.signOut,
            onRetry: () => setState(() {
              _controllerFuture = _loadController();
            }),
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return EventHomePage(
          key: ValueKey(_session!.user.id),
          controller: snapshot.data!,
          onSignOut: widget.backend.signOut,
          onInviteChairperson: _role == 'treasurer' ? _inviteChairperson : null,
          accountEmail: widget.backend.user?.email,
          accountRole: _role,
        );
      },
    );
  }
}

class SetupErrorPage extends StatefulWidget {
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
  State<SetupErrorPage> createState() => _SetupErrorPageState();
}

class _SetupErrorPageState extends State<SetupErrorPage> {
  bool _busy = false;
  String? _error;

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSignOut().timeout(const Duration(seconds: 30));
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wargakas')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
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
                  _error ?? widget.message,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : widget.onRetry,
                  child: const Text('Coba lagi'),
                ),
                TextButton(
                  onPressed: _busy ? null : _signOut,
                  child: Text(_busy ? 'Memproses…' : 'Keluar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
