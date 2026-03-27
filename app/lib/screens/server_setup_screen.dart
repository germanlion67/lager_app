// lib/screens/server_setup_screen.dart
//
// Ersteinrichtungs-Screen für die PocketBase-Server-URL.
//
// Wird angezeigt wenn beim App-Start keine gültige URL konfiguriert ist.
// Nutzt den bestehenden PocketBaseService für Validierung und Healthcheck.

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class ServerSetupScreen extends StatefulWidget {
  /// Callback, der nach erfolgreicher Konfiguration aufgerufen wird.
  /// Wird von main.dart genutzt, um zur normalen App zu wechseln.
  final VoidCallback onConfigured;

  const ServerSetupScreen({
    super.key,
    required this.onConfigured,
  });

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isTesting = false;
  bool _isSaving = false;
  bool? _connectionOk;
  String? _connectionError;

  @override
  void initState() {
    super.initState();

    // Falls ein Build-Default vorhanden ist, als Startwert eintragen
    final defaultUrl = PocketBaseService.defaultUrl;
    if (defaultUrl.isNotEmpty &&
        !defaultUrl.contains('your-production-server.com') &&
        !defaultUrl.contains('192.168.178.XX')) {
      _urlController.text = defaultUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // ==================== VALIDIERUNG ====================

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

    // Localhost-Warnung auf Android
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

    // Falls noch nicht getestet, zuerst testen
    if (_connectionOk != true) {
      await _testConnection();
      if (_connectionOk != true) {
        // Benutzer fragen ob trotzdem gespeichert werden soll
        final shouldSave = await _showSaveWithoutTestDialog();
        if (shouldSave != true) return;

        // Ohne Healthcheck speichern: URL direkt in SharedPreferences
        // und Client erstellen (updateUrl macht Healthcheck, daher
        // hier manuell)
        setState(() => _isSaving = true);
        try {
          final url = _urlController.text.trim();
          // Direkt über updateUrl versuchen — falls es fehlschlägt,
          // trotzdem die URL speichern
          await PocketBaseService().updateUrl(url);
        } catch (_) {
          // Ignorieren — Benutzer hat bewusst ohne Test gespeichert
        }

        if (mounted) {
          setState(() => _isSaving = false);
          // Prüfen ob der Service jetzt einen Client hat
          if (PocketBaseService().hasClient) {
            widget.onConfigured();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'URL konnte nicht gespeichert werden. '
                  'Bitte eine erreichbare URL eingeben.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        return;
      }
    }

    // Verbindung war erfolgreich — URL ist bereits gespeichert
    // (updateUrl speichert automatisch bei Erfolg)
    setState(() => _isSaving = true);

    if (mounted) {
      setState(() => _isSaving = false);
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
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    Icon(
                      Icons.dns_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Server-Einrichtung',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gib die URL deines PocketBase-Servers ein, '
                      'damit die App sich verbinden kann.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

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
                        // Bei Änderung vorherigen Test zurücksetzen
                        if (_connectionOk != null) {
                          setState(() {
                            _connectionOk = null;
                            _connectionError = null;
                          });
                        }
                      },
                      onFieldSubmitted: (_) => _testConnection(),
                    ),
                    const SizedBox(height: 16),

                    // --- Beispiel-URLs ---
                    _buildExamplesCard(theme),
                    const SizedBox(height: 24),

                    // --- Verbindungsstatus ---
                    if (_isTesting) _buildLoadingIndicator(),
                    if (_connectionOk != null && !_isTesting)
                      _buildConnectionResult(theme),
                    if (_connectionOk != null || _isTesting)
                      const SizedBox(height: 24),

                    // --- Buttons ---
                    OutlinedButton.icon(
                      onPressed:
                          _isTesting || _isSaving ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: Text(
                        _isTesting
                            ? 'Prüfe Verbindung...'
                            : 'Verbindung testen',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _isTesting || _isSaving ? null : _saveAndContinue,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
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
    );
  }

  Widget _buildExamplesCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beispiele:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          _buildExampleRow(
            'Produktion:',
            'https://api.deine-domain.de',
          ),
          _buildExampleRow(
            'LAN-Test:',
            'http://192.168.x.x:8080',
          ),
          if (!kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android)
            _buildExampleRow(
              'Emulator:',
              'http://10.0.2.2:8080',
            ),
        ],
      ),
    );
  }

  Widget _buildExampleRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Verbindung wird getestet...'),
        ],
      ),
    );
  }

  Widget _buildConnectionResult(ThemeData theme) {
    final isOk = _connectionOk!;
    final color = isOk ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOk
                  ? 'Verbindung erfolgreich! Server ist erreichbar.'
                  : _connectionError ??
                      'Server nicht erreichbar.',
              style: TextStyle(color: color.shade800),
            ),
          ),
        ],
      ),
    );
  }
}