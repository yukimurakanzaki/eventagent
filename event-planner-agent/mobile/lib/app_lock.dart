import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'l10n/l10n.dart';

/// Asks the phone to prove the person holding it is its owner.
abstract class AppLockAuthenticator {
  /// Whether the phone has a screen lock or biometrics that can be used.
  Future<bool> isSupported();

  /// Shows the system prompt. Returns true only when it succeeded.
  Future<bool> authenticate(String reason);
}

/// Uses the phone's fingerprint, face, or PIN/pattern via `local_auth`.
class LocalAuthAppLockAuthenticator implements AppLockAuthenticator {
  LocalAuthAppLockAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() || await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // PlatformException / LocalAuthException: cancelled, locked out, etc.
      return false;
    }
  }
}

class AppLock {
  AppLock._();

  /// Replaced by tests with a fake.
  static AppLockAuthenticator authenticator = LocalAuthAppLockAuthenticator();

  /// How long the app may stay in the background before it locks again.
  static const gracePeriod = Duration(seconds: 60);
}

/// Full-screen cover shown while the app is locked.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _busy = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Prompt once as soon as the cover appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _disposed) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      // Fail open when the phone has no screen lock any more.
      ok =
          !await AppLock.authenticator.isSupported() ||
          await AppLock.authenticator.authenticate(tr('Buka Wargakas'));
    } catch (_) {
      ok = false;
    }
    if (_disposed) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      key: const Key('app-lock-screen'),
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr('Wargakas terkunci'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('Buka kunci untuk melihat catatan kas.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      key: const Key('app-lock-unlock'),
                      onPressed: _busy ? null : _unlock,
                      icon: const Icon(Icons.lock_open),
                      label: Text(tr('Buka kunci')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
