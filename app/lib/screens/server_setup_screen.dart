// lib/screens/server_setup_screen.dart
//
// Ersteinrichtungs-Screen für die PocketBase-Server-URL.
//
// Wird angezeigt wenn beim App-Start keine gültige URL konfiguriert ist.
// Nutzt den bestehenden PocketBaseService für Validierung und Healthcheck.
//
// v0.7.10: Lade-Overlay nach erfolgreicher Konfiguration, während der
//          initiale Sync in main.dart läuft.

import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/pocketbase_service.dart';

class ServerSetupScreen extends StatefulWidget {
  final VoidCallback onConfigured;

  const ServerSetupScreen({
    super.key,
    required this.onConfigured,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  static const String _prefsPocketBaseUrlKey = 'pocketbase_url';

  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isTesting = false;
  bool _isSaving = false;
  bool? _connectionOk;
  String? _connectionError;
  bool _isSyncingAfterSetup = false; // ← NEU

  @override
  void initState() {
    super.initState();

    final defaultUrl = PocketBaseService.defaultUrl;
    if (_isPreFillableDefaultUrl(defaultUrl)) {
      _urlController.text = defaultUrl;
    }

    unawaited(_prefillSavedUrl());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ==================== VALIDIERUNG ====================

  bool _isPreFillableDefaultUrl(String url) {
    return url.isNotEmpty &&
        !url.contains('your-production-server.com') &&
        !url.contains('192.168.178.XX');
  }

  Future<void> _prefillSavedUrl() async {
    final initialText = _urlController.text;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_prefsPocketBaseUrlKey)?.trim() ?? '';

      if (savedUrl.isEmpty || !mounted) return;

      // Nicht überschreiben falls der Nutzer bereits angefangen hat zu tippen.
      if (_urlController.text != initialText) return;

      setState(() {
        _urlController.text = savedUrl;
      });
    } catch (_) {
      // Fallback bleibt die Default-URL (falls vorhanden).
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bitte eine Server-URL eingeben';
    }

    final url = value.trim();

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'Die URL muss mit http:// oder https:// beginnen';
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return 'Ungültiges URL-Format';
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return 'Auf Android zeigt "localhost" auf das Gerät selbst.\n'
          'Verwende stattdessen:\n'
          '• Emulator: http://10.0.2.2:8080\n'
          '• Echtes Gerät: http://<PC-IP>:8080';
    }

    return null;
  }

  // ==================== VERBINDUNGSTEST ====================

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isTesting = true;
      _connectionOk = null;
      _connectionError = null;
    });

    try {
      final url = _urlController.text.trim();
      final ok = await PocketBaseService().updateUrl(url);

      if (!mounted) return;

      if (ok) {
        setState(() {
          _connectionOk = true;
          _connectionError = null;
        });
      } else {
        setState(() {
          _connectionOk = false;
          _connectionError =
              'Server nicht erreichbar oder URL ungültig.\n'
              'Bitte URL und Netzwerkverbindung prüfen.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connectionOk = false;
        _connectionError = 'Verbindungsfehler: $e';
      });
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  // ==================== SPEICHERN ====================

  Future<void> _saveAndContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_connectionOk != true) {
      await _testConnection();
      if (_connectionOk != true) {
        final shouldSave = await _showSaveWithoutTestDialog();
        if (shouldSave != true) return;

        setState(() => _isSaving = true);
        try {
          final url = _urlController.text.trim();
          await PocketBaseService().updateUrl(url);
        } catch (_) {}

        if (mounted) {
          setState(() => _isSaving = false);
          if (PocketBaseService().hasClient) {
            // ← NEU: Lade-Overlay anzeigen bevor Callback aufgerufen wird
            setState(() => _isSyncingAfterSetup = true);
            widget.onConfigured();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'URL konnte nicht gespeichert werden. '
                  'Bitte eine erreichbare URL eingeben.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
        return;
      }
    }

    // Verbindung war erfolgreich — URL ist bereits gespeichert
    setState(() => _isSaving = true);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _isSyncingAfterSetup = true; // ← NEU
      });
      widget.onConfigured();
    }
  }

  Future<bool?> _showSaveWithoutTestDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verbindung nicht bestätigt'),
        content: const Text(
          'Die Verbindung zum Server konnte nicht bestätigt werden.\n\n'
          'Möchtest du die URL trotzdem speichern? '
          'Die App benötigt eine erreichbare URL, um zu funktionieren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Trotzdem speichern'),
          ),
        ],
      ),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(                                          // ← GEÄNDERT: Stack
      children: [
        // ── Bestehender Scaffold (unverändert) ──────────────────────
        Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConfig.spacingXLarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppConfig.setupFormMaxWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Header ---
                        Icon(
                          Icons.dns_outlined,
                          size: AppConfig.iconSizeXXLarge,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: AppConfig.spacingLarge),
                        Text(
                          'Server-Einrichtung',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConfig.spacingSmall),
                        Text(
                          'Gib die URL deines PocketBase-Servers ein, '
                          'damit die App sich verbinden kann.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConfig.spacingXXLarge),

                        // --- URL-Eingabefeld ---
                        TextFormField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            labelText: 'Server-URL',
                            hintText: 'https://api.deine-domain.de',
                            prefixIcon: const Icon(Icons.link),
                            border: const OutlineInputBorder(),
                            suffixIcon: _urlController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _urlController.clear();
                                      setState(() {
                                        _connectionOk = null;
                                        _connectionError = null;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          validator: _validateUrl,
                          onChanged: (_) {
                            if (_connectionOk != null) {
                              setState(() {
                                _connectionOk = null;
                                _connectionError = null;
                              });
                            }
                          },
                          onFieldSubmitted: (_) => _testConnection(),
                        ),
                        const SizedBox(height: AppConfig.spacingLarge),

                        // --- Beispiel-URLs ---
                        _buildExamplesCard(colorScheme, textTheme),
                        const SizedBox(height: AppConfig.spacingXLarge),

                        // --- Verbindungsstatus ---
                        if (_isTesting)
                          _buildLoadingIndicator(colorScheme, textTheme),
                        if (_connectionOk != null && !_isTesting)
                          _buildConnectionResult(colorScheme, textTheme),
                        if (_connectionOk != null || _isTesting)
                          const SizedBox(height: AppConfig.spacingXLarge),

                        // --- Buttons ---
                        OutlinedButton.icon(
                          onPressed: _isTesting || _isSaving || _isSyncingAfterSetup
                              ? null
                              : _testConnection,                // ← GEÄNDERT
                          icon: _isTesting
                              ? const SizedBox(
                                  width: AppConfig.iconSizeSmall,
                                  height: AppConfig.iconSizeSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppConfig.strokeWidthMedium,
                                  ),
                                )
                              : const Icon(Icons.wifi_find),
                          label: Text(
                            _isTesting
                                ? 'Prüfe Verbindung...'
                                : 'Verbindung testen',
                          ),
                        ),
                        const SizedBox(height: AppConfig.spacingMedium),
                        FilledButton.icon(
                          onPressed: _isTesting || _isSaving || _isSyncingAfterSetup
                              ? null
                              : _saveAndContinue,               // ← GEÄNDERT
                          icon: _isSaving
                              ? SizedBox(
                                  width: AppConfig.iconSizeSmall,
                                  height: AppConfig.iconSizeSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: AppConfig.strokeWidthMedium,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(
                            _isSaving ? 'Wird gespeichert...' : 'Weiter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── NEU: Lade-Overlay während initialem Sync ────────────────
        if (_isSyncingAfterSetup)
          Positioned.fill(
            child: Container(
              color: colorScheme.scrim.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(AppConfig.spacingXLarge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppConfig.spacingMedium),
                        Text(
                          'Erstmalige Synchronisation…',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppConfig.spacingSmall),
                        Text(
                          'Artikel und Bilder werden geladen',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Bestehende Helper-Widgets (UNVERÄNDERT) ───────────────────────

  Widget _buildExamplesCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest
            .withValues(
                alpha: AppConfig.opacityMedium + AppConfig.opacityLight,),
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beispiele:',
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConfig.spacingXSmall),
          _buildExampleRow(
            'Produktion:',
            'https://api.deine-domain.de',
            colorScheme,
            textTheme,
          ),
          _buildExampleRow(
            'LAN-Test:',
            'http://192.168.x.x:8080',
            colorScheme,
            textTheme,
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
            _buildExampleRow(
              'Emulator:',
              'http://10.0.2.2:8080',
              colorScheme,
              textTheme,
            ),
        ],
      ),
    );
  }

  Widget _buildExampleRow(
    String label,
    String url,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppConfig.borderRadiusXXSmall),
      child: Row(
        children: [
          SizedBox(
            width: AppConfig.exampleLabelWidth,
            child: Text(
              label,
              style: textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _urlController.text = url;
                setState(() {
                  _connectionOk = null;
                  _connectionError = null;
                });
              },
              child: Text(
                url,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        border: Border.all(
          color:
              colorScheme.primary.withValues(alpha: AppConfig.opacityMedium),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppConfig.progressIndicatorSizeSmall,
            height: AppConfig.progressIndicatorSizeSmall,
            child: CircularProgressIndicator(
              strokeWidth: AppConfig.strokeWidthMedium,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppConfig.spacingMedium),
          Text(
            'Verbindung wird getestet...',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionResult(
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isOk = _connectionOk!;

    return Container(
      padding: const EdgeInsets.all(AppConfig.spacingMedium),
      decoration: BoxDecoration(
        color: isOk
            ? colorScheme.tertiaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
        border: Border.all(
          color: isOk
              ? colorScheme.tertiary
                  .withValues(alpha: AppConfig.opacityMedium)
              : colorScheme.error
                  .withValues(alpha: AppConfig.opacityMedium),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk
                ? colorScheme.onTertiaryContainer
                : colorScheme.onErrorContainer,
            size: AppConfig.iconSizeMedium,
          ),
          const SizedBox(width: AppConfig.spacingMedium),
          Expanded(
            child: Text(
              isOk
                  ? 'Verbindung erfolgreich! Server ist erreichbar.'
                  : _connectionError ?? 'Server nicht erreichbar.',
              style: textTheme.bodyMedium?.copyWith(
                color: isOk
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
