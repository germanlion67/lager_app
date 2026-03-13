// lib/screens/nextcloud_settings_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/nextcloud_connection_service.dart';
import '../services/nextcloud_credentials.dart';

class NextcloudSettingsScreen extends StatefulWidget {
  // FIX: Service von außen übergeben — kein neues Objekt intern erstellen
  final NextcloudConnectionService connectionService;

  const NextcloudSettingsScreen({
    super.key,
    required this.connectionService,
  });

  @override
  State<NextcloudSettingsScreen> createState() =>
      _NextcloudSettingsScreenState();
}

class _NextcloudSettingsScreenState extends State<NextcloudSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _appPwCtrl = TextEditingController();
  final _folderCtrl = TextEditingController(text: 'Apps/Artikel');
  final _intervalCtrl = TextEditingController(text: '10');

  bool _isSaving = false;
  bool _isTesting = false;
  bool _appPwVisible = false;

  @override
  void initState() {
    super.initState();
    _ladeGespeicherteDaten();
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _appPwCtrl.dispose();
    _folderCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  // ==================== DATEN LADEN ====================

  Future<void> _ladeGespeicherteDaten() async {
    // FIX: try/catch ergänzt — Exception crasht sonst die App
    try {
      final creds = await NextcloudCredentialsStore().read();
      // FIX: mounted-Guard nach await
      if (!mounted) return;
      if (creds != null) {
        setState(() {
          _serverCtrl.text = creds.server.toString();
          _userCtrl.text = creds.user;
          _appPwCtrl.text = creds.appPw;
          _folderCtrl.text = creds.baseFolder;
          _intervalCtrl.text = creds.checkIntervalMinutes.toString();
        });
      }
    } catch (e, st) {
      debugPrint('[NextcloudSettings] Laden fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Einstellungen konnten nicht geladen werden: $e')),
      );
    }
  }

  // ==================== SPEICHERN ====================

  Future<void> _speichern() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      // FIX: Bounds-gesicherter Parse — konsistent mit Validator
      final intervalMinutes =
          (int.tryParse(_intervalCtrl.text.trim()) ?? 10).clamp(1, 1440);

      await NextcloudCredentialsStore().save(
        serverBaseUrl: _serverCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        appPassword: _appPwCtrl.text.trim(),
        baseRemoteFolder: _folderCtrl.text.trim(),
        checkIntervalMinutes: intervalMinutes,
      );

      // FIX: Übergebenen Service verwenden — nicht neue Instanz erstellen
      await widget.connectionService.restartMonitoring();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    } catch (e, st) {
      // FIX: StackTrace mitloggen
      debugPrint('[NextcloudSettings] Speichern fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==================== VERBINDUNGSTEST ====================

  Future<void> _testVerbindung() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isTesting = true);
    try {
      // FIX: Uri.tryParse ohne Force-Unwrap — sicherer Null-Check
      final serverUri = Uri.tryParse(_serverCtrl.text.trim());
      if (serverUri == null || !serverUri.isAbsolute) {
        throw Exception('Ungültige Server-URL');
      }

      final encodedUser = Uri.encodeComponent(_userCtrl.text.trim());
      final uri = serverUri.resolve('remote.php/dav/files/$encodedUser/');

      final basicAuth = base64Encode(
        utf8.encode('${_userCtrl.text.trim()}:${_appPwCtrl.text.trim()}'),
      );

      final res = await http
          .head(uri, headers: {'Authorization': 'Basic $basicAuth'}).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Verbindungstest-Timeout (15s)'),
      );

      if (!mounted) return;

      // FIX: ScaffoldMessenger vor dem switch cachen — kein async-Gap danach
      final messenger = ScaffoldMessenger.of(context);

      switch (res.statusCode) {
        case 200 || 207:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✅ Verbindung erfolgreich!'),
              backgroundColor: Colors.green,
            ),
          );
        case 401:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ Fehler: Benutzername oder Passwort falsch (401)'),
              backgroundColor: Colors.red,
            ),
          );
        case 404:
          messenger.showSnackBar(
            const SnackBar(
              content: Text('❌ Fehler: Benutzer nicht gefunden (404)'),
              backgroundColor: Colors.red,
            ),
          );
        default:
          messenger.showSnackBar(
            SnackBar(
              content: Text('⚠️ Unerwarteter Status: ${res.statusCode}'),
              backgroundColor: Colors.orange,
            ),
          );
      }
    } catch (e, st) {
      // FIX: StackTrace mitloggen
      debugPrint('[NextcloudSettings] Verbindungstest fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungsfehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nextcloud-Einstellungen'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _speichern,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Einstellungen speichern',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ==================== VERBINDUNGSDATEN ====================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verbindungsdaten',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),

                      // Server-URL
                      TextFormField(
                        controller: _serverCtrl,
                        decoration: const InputDecoration(
                          labelText:
                              'Server-URL (z. B. https://cloud.example.com)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cloud),
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Bitte Server-URL eingeben';
                          }
                          // FIX: tryParse ohne Force-Unwrap
                          final uri = Uri.tryParse(v.trim());
                          if (uri == null || !uri.isAbsolute) {
                            return 'Ungültige URL';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Benutzername
                      TextFormField(
                        controller: _userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Benutzername',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        autocorrect: false,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Bitte Benutzername eingeben'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      // App-Passwort
                      TextFormField(
                        controller: _appPwCtrl,
                        decoration: InputDecoration(
                          labelText: 'App-Passwort',
                          hintText: 'Nicht Ihr normales Passwort!',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.key),
                          // FIX: Sichtbarkeits-Toggle für App-Passwort
                          suffixIcon: IconButton(
                            icon: Icon(
                              _appPwVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                                () => _appPwVisible = !_appPwVisible,),
                            tooltip: _appPwVisible
                                ? 'Passwort verbergen'
                                : 'Passwort anzeigen',
                          ),
                        ),
                        obscureText: !_appPwVisible,
                        autocorrect: false,
                        enableSuggestions: false,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Bitte App-Passwort eingeben'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      // Basisordner
                      TextFormField(
                        controller: _folderCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Basisordner (z. B. Apps/Artikel)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder),
                        ),
                        autocorrect: false,
                      ),
                      const SizedBox(height: 16),

                      // Prüfintervall
                      TextFormField(
                        controller: _intervalCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Prüfintervall (Minuten)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Wie oft soll die Verbindung geprüft werden? (Standard: 10 Min.)',
                          prefixIcon: Icon(Icons.timer),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Bitte Intervall eingeben';
                          }
                          final interval = int.tryParse(v.trim());
                          if (interval == null) {
                            return 'Bitte eine gültige Zahl eingeben';
                          }
                          if (interval < 1) {
                            return 'Intervall muss mindestens 1 Minute betragen';
                          }
                          if (interval > 1440) {
                            return 'Intervall darf maximal 1440 Minuten (24h) betragen';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ==================== ANLEITUNG ====================
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App-Passwort erstellen',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Gehen Sie in Ihre Nextcloud-Einstellungen\n'
                        '2. Wählen Sie "Sicherheit"\n'
                        '3. Erstellen Sie ein neues App-Passwort\n'
                        '4. Kopieren Sie das generierte Passwort hier hinein',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ==================== VERBINDUNGSTEST ====================
              ElevatedButton.icon(
                onPressed: _isTesting ? null : _testVerbindung,
                icon: _isTesting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi),
                label: Text(_isTesting ? 'Teste...' : 'Verbindung testen'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}