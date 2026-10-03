import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_forms.dart';
import 'auth_support.dart';
import 'cashbook_controller.dart';
import 'event_directory.dart';
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

class _SupabaseAppState extends State<SupabaseApp> implements EventDirectory {
  Session? _session;
  Future<CashbookController>? _controllerFuture;
  StreamSubscription<AuthState>? _authSubscription;
  String? _workspaceId;
  String? _role;
  String? _eventId;
  CashbookController? _controller;
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

  String _selectionKey(String? userId) => 'wargakas.selectedEvent.$userId';

  Future<String?> _savedEventId(String? userId) async {
    try {
      return (await SharedPreferences.getInstance()).getString(
        _selectionKey(userId),
      );
    } catch (_) {
      return null;
    }
  }

  Future<CashbookController> _loadController({String? eventId}) {
    final generation = ++_loadGeneration;
    final userId = _session?.user.id;
    Future<CashbookController> load() async {
      final opened = await widget.backend.loadCashbook(
        preferredEventId: eventId ?? await _savedEventId(userId),
      );
      if (!mounted ||
          generation != _loadGeneration ||
          _session?.user.id != userId) {
        opened.controller.dispose();
        throw StateError('Pemuatan akun sebelumnya dibatalkan.');
      }
      _workspaceId = opened.workspaceId;
      _role = opened.role;
      _eventId = opened.eventId;
      _controller = opened.controller;
      try {
        await (await SharedPreferences.getInstance()).setString(
          _selectionKey(userId),
          opened.eventId,
        );
      } catch (_) {}
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
    _eventId = null;
    _controller = null;
    _controllerFuture = null;
  }

  @override
  String get currentEventId => _eventId ?? '';

  @override
  bool get canManage => _role == 'treasurer';

  @override
  Future<List<EventSummary>> list() {
    final workspaceId = _workspaceId;
    if (workspaceId == null) throw StateError('workspace belum siap');
    return widget.backend.listEvents(workspaceId);
  }

  @override
  Future<void> select(String eventId) async {
    if (eventId == _eventId) return;
    // Unsynced edits stay in the local store and resume when the event reopens.
    final previous = _controller;
    setState(() => _controllerFuture = _loadController(eventId: eventId));
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  @override
  Future<void> create(NewEventDraft draft) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) throw StateError('workspace belum siap');
    final eventId = await widget.backend.createEvent(workspaceId, draft);
    await select(eventId);
  }

  @override
  Future<void> setArchived(String eventId, bool archived) async {
    await widget.backend.setEventArchived(eventId, archived);
    if (!archived || eventId != _eventId) return;
    final active = (await list()).where((item) => !item.archived);
    if (active.isNotEmpty) await select(active.last.id);
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
            message: loadErrorMessage(snapshot.error!),
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
          key: ValueKey('${_session!.user.id}-$_eventId'),
          controller: snapshot.data!,
          onSignOut: widget.backend.signOut,
          onInviteChairperson: _role == 'treasurer' ? _inviteChairperson : null,
          eventDirectory: this,
          accountEmail: widget.backend.user?.email,
          accountRole: _role,
        );
      },
    );
  }
}

/// Says "check your internet" only for real connectivity failures. Anything
/// else (missing column, denied access) shows what went wrong so it can be
/// reported; the pilot treasurer is the audience, not the public.
String loadErrorMessage(Object error) {
  if (error is TimeoutException || error is SocketException) {
    return 'Periksa koneksi internet lalu coba lagi. Jika tetap gagal, hubungi pengelola Wargakas.';
  }
  final detail = switch (error) {
    PostgrestException(:final code, :final message) =>
      '${code == null ? '' : '$code: '}$message',
    _ => error.toString(),
  };
  final shortened = detail.length > 160
      ? '${detail.substring(0, 160)}…'
      : detail;
  return 'Terjadi kesalahan saat membuka acara. Hubungi pengelola Wargakas dan kirim pesan ini:\n$shortened';
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
