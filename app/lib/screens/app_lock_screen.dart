// lib/screens/app_lock_screen.dart
// ── B-002: App-Lock Screen — korrigiert ─────────────────────────────────────
// Vollbild-Sperrbildschirm mit biometrischer/PIN Authentifizierung.
// Nutzt nativen System-Dialog (BiometricPrompt / FaceID).

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/app_lock_service.dart';
import 'dart:async';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometricsAndAutoStart();
  }

  /// Prüft Biometrie-Verfügbarkeit und startet automatisch den System-Dialog.
  Future<void> _checkBiometricsAndAutoStart() async {
    await _checkBiometrics();
    if (mounted && AppLockService().isBiometricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _authenticateWithBiometrics(),
      );
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (mounted) {
        setState(() => _isBiometricAvailable = canCheck || isSupported);
      }
    } on LocalAuthException {
      if (mounted) {
        setState(() => _isBiometricAvailable = false);
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final useBiometricOnly =
          _isBiometricAvailable && AppLockService().isBiometricsEnabled;

      final authenticated = await _auth.authenticate(
        localizedReason: 'Bitte entsperren Sie die Lager-App',
        biometricOnly: useBiometricOnly,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        widget.onUnlocked();
      }
    } on LocalAuthException catch (e) {
      if (mounted) {
        String message;
        switch (e.code) {
          case LocalAuthExceptionCode.noBiometricsEnrolled:
            message =
                'Keine Biometrie eingerichtet. Bitte in den '
                'Geräte-Einstellungen konfigurieren.';
          case LocalAuthExceptionCode.noCredentialsSet:
            message =
                'Keine Anmeldedaten konfiguriert. Bitte '
                'Geräte-PIN oder Biometrie einrichten.';
          case LocalAuthExceptionCode.temporaryLockout:
            message =
                'Zu viele Versuche. Bitte warten Sie einen Moment.';
          case LocalAuthExceptionCode.biometricLockout:
            message =
                'Biometrie gesperrt. Bitte zuerst '
                'Geräte-PIN verwenden.';
          case LocalAuthExceptionCode.noBiometricHardware:
            message = 'Keine Biometrie-Hardware auf diesem Gerät.';
          case LocalAuthExceptionCode.userCanceled:
            message = 'Authentifizierung abgebrochen.';
          case LocalAuthExceptionCode.userRequestedFallback:
            // Benutzer will PIN statt Biometrie — Fallback starten
            unawaited(_authenticateWithDevicePin());
            return;
          default:
            message =
                'Authentifizierung fehlgeschlagen: '
                '${e.description ?? e.code.name}';
        }
        setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  /// Fallback: Erzwingt Geräte-PIN statt Biometrie.
  Future<void> _authenticateWithDevicePin() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Bitte Geräte-PIN eingeben',
        biometricOnly: false,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated && mounted) {
        widget.onUnlocked();
      }
    } on LocalAuthException catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'PIN-Authentifizierung fehlgeschlagen: '
              '${e.description ?? e.code.name}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useBiometrics =
        _isBiometricAvailable && AppLockService().isBiometricsEnabled;

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
                  color: colorScheme.primary,
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
                  useBiometrics
                      ? 'Bitte verwenden Sie Ihren Fingerabdruck\n'
                          'oder die Geräte-PIN zum Entsperren.'
                      : 'Bitte entsperren Sie die App\n'
                          'mit Ihrer Geräte-PIN.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),

                // Fehlermeldung
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Authentifizierungs-Button
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(
                      useBiometrics
                          ? Icons.fingerprint
                          : Icons.lock_open_rounded,
                    ),
                    label: Text(
                      useBiometrics
                          ? 'Mit Biometrie entsperren'
                          : 'Mit Geräte-PIN entsperren',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),

                // Fallback-Button: PIN wenn Biometrie fehlschlägt
                if (useBiometrics && _errorMessage != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _authenticateWithDevicePin,
                    icon: const Icon(Icons.dialpad),
                    label: const Text(
                      'Stattdessen Geräte-PIN verwenden',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}