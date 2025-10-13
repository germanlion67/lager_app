//lib/screens/nextcloud_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_connection_service.dart';

class NextcloudSettingsScreen extends StatefulWidget {
  const NextcloudSettingsScreen({super.key});

  @override
  State<NextcloudSettingsScreen> createState() => _NextcloudSettingsScreenState();
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

  @override
  void initState() {
    super.initState();
    _ladeGespeicherteDaten();
  }

  @override
  void dispose() {
    // Dispose all TextEditingControllers to prevent memory leaks
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _appPwCtrl.dispose();
    _folderCtrl.dispose();
    _intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _ladeGespeicherteDaten() async {
    final creds = await NextcloudCredentialsStore().read();
    if (creds != null) {
      setState(() {
        _serverCtrl.text = creds.server.toString();
        _userCtrl.text = creds.user;
        _appPwCtrl.text = creds.appPw;
        _folderCtrl.text = creds.baseFolder;
        _intervalCtrl.text = creds.checkIntervalMinutes.toString();
      });
    }
  }

  Future<void> _speichern() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final intervalMinutes = int.tryParse(_intervalCtrl.text.trim()) ?? 10;
      
      await NextcloudCredentialsStore().save(
        serverBaseUrl: _serverCtrl.text.trim(),
        username: _userCtrl.text.trim(),
        appPassword: _appPwCtrl.text.trim(),
        baseRemoteFolder: _folderCtrl.text.trim(),
        checkIntervalMinutes: intervalMinutes,
      );
      
      // Restart monitoring with new settings
      await NextcloudConnectionService().restartMonitoring();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testVerbindung() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isTesting = true);
    try {
      final uri = Uri.parse(_serverCtrl.text.trim())
          .replace(path: 'remote.php/dav/files/${Uri.encodeComponent(_userCtrl.text.trim())}/');
      final basicAuth = base64Encode(utf8.encode('${_userCtrl.text.trim()}:${_appPwCtrl.text.trim()}'));
      final res = await http.head(uri, headers: {'Authorization': 'Basic $basicAuth'})
          .timeout(
            const Duration(seconds: 15), // Verbindungstest sollte schnell sein
            onTimeout: () => throw Exception('Verbindungstest-Timeout (15s)'),
          );

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 207) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verbindung erfolgreich!')),
        );
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler: Unauthorized (401)')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verbindungsfehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout Nextcloud'),
        content: const Text(
          'Gespeicherte Nextcloud-Zugangsdaten werden gelöscht. Fortfahren?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      await NextcloudCredentialsStore().clear();
      NextcloudConnectionService().stopPeriodicCheck();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nextcloud-Login gelöscht')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Nextcloud-Einstellungen')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _serverCtrl,
                decoration: const InputDecoration(
                  labelText: 'Server-URL (z. B. https://cloud.example.com)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Bitte Server-URL eingeben';
                  if (!Uri.tryParse(v.trim())!.isAbsolute) return 'Ungültige URL';
                  return null;
                },
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: 'Benutzername',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte Benutzername eingeben' : null,
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _appPwCtrl,
                decoration: const InputDecoration(
                  labelText: 'App-Passwort',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bitte App-Passwort eingeben' : null,
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _folderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Basisordner (z. B. Apps/Artikel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _intervalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prüfintervall (Minuten)',
                  border: OutlineInputBorder(),
                  helperText: 'Wie oft soll die Verbindung geprüft werden? (Standard: 10 Min.)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Bitte Intervall eingeben';
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
              const SizedBox(height: spacing * 1.5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _speichern,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testVerbindung,
                      icon: _isTesting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi),
                      label: const Text('Test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLogoutDialog,  // Verwendet die Methode
                      icon: const Icon(Icons.logout),
                      label: const Text('Lgout'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
