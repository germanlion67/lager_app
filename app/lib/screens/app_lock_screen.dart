// lib/screens/app_lock_screen.dart
// ── F-001: App-Lock Screen ──────────────────────────────────────────────────
// Vollbild-Sperrbildschirm mit biometrischer/PIN Authentifizierung.

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _auth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    // Automatisch biometrische Authentifizierung starten
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateWithBiometrics());
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (mounted) {
        setState(() => _isBiometricAvailable = canCheck && isSupported);
      }
    } on PlatformException {
      if (mounted) {
        setState(() => _isBiometricAvailable = false);
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Bitte entsperren Sie die App',
        biometricOnly: false, // Erlaubt auch PIN/Pattern des Geräts
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        widget.onUnlocked();
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'App gesperrt',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bitte entsperren Sie die App,\num fortzufahren.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(
                      _isBiometricAvailable
                          ? Icons.fingerprint
                          : Icons.lock_open_rounded,
                    ),
                    label: Text(
                      _isBiometricAvailable
                          ? 'Mit Biometrie entsperren'
                          : 'Entsperren',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
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
