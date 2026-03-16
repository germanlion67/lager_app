// lib/screens/settings_screen.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/artikel_db_service.dart';
import '../services/pocketbase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _artikelNummerController = TextEditingController();
  final _pocketBaseUrlController = TextEditingController();

  // FIX: Einmalige Instanzerstellung — nicht bei jedem Aufruf neu
  late final PocketBaseService _pbService;
  late final ArtikelDbService _db;

  bool _isDatabaseEmpty = true;
  bool _isCheckingConnection = false;
  bool? _pbConnectionOk;

  @override
  void initState() {
    super.initState();
    _pbService = PocketBaseService();
    _db = ArtikelDbService();

    _loadSettings();
    if (!kIsWeb) {
      _checkDatabaseStatus();
    }
  }

  @override
  void dispose() {
    _artikelNummerController.dispose();
    _pocketBaseUrlController.dispose();
    super.dispose();
  }

  // ==================== LADEN ====================

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_pbService.isInitialized) {
        await _pbService.initialize();
      }
      if (!mounted) return;
      setState(() {
        _artikelNummerController.text =
            (prefs.getInt('artikel_start_nummer') ?? 1000).toString();
        _pocketBaseUrlController.text = _pbService.url;
      });
    } catch (e, st) {
      debugPrint('[Settings] Laden fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Einstellungen konnten nicht geladen werden: $e'),
        ),
      );
    }
  }

  Future<void> _checkDatabaseStatus() async {
    if (kIsWeb) return;
    try {
      final isEmpty = await _db.isDatabaseEmpty();
      if (!mounted) return;
      setState(() => _isDatabaseEmpty = isEmpty);
    } catch (e, st) {
      debugPrint('[Settings] DB-Status prüfen fehlgeschlagen: $e\n$st');
    }
  }

  // ==================== POCKETBASE ====================

  Future<void> _testPocketBaseConnection() async {
    setState(() {
      _isCheckingConnection = true;
      _pbConnectionOk = null;
    });

    try {
      final testUrl = _pocketBaseUrlController.text.trim();

      if (testUrl.isNotEmpty && testUrl != _pbService.url) {
        // FIX: updateUrl() gibt jetzt bool zurück und führt intern bereits
        // einen Health-Check durch. Schlägt er fehl (URL ungültig oder
        // nicht erreichbar), bleibt der bestehende Client aktiv.
        // → kein separater checkHealth()-Aufruf mehr nötig (war doppelter
        //   Netzwerk-Request). Ergebnis direkt als Verbindungsstatus nutzen.
        final ok = await _pbService.updateUrl(testUrl);

        if (!mounted) return;
        setState(() => _pbConnectionOk = ok);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? '✅ Verbindung zu PocketBase erfolgreich!'
                  : '❌ PocketBase nicht erreichbar – '
                    'bestehende URL bleibt aktiv',
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      } else {
        // URL unverändert — nur Health-Check auf bestehendem Client
        final ok = await _pbService.checkHealth();

        if (!mounted) return;
        setState(() => _pbConnectionOk = ok);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? '✅ Verbindung zu PocketBase erfolgreich!'
                  : '❌ PocketBase nicht erreichbar',
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[Settings] PocketBase-Test fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      setState(() => _pbConnectionOk = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungsfehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCheckingConnection = false);
    }
  }

  Future<void> _resetPocketBaseUrl() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('URL zurücksetzen?'),
        content: Text(
          'Die PocketBase-URL wird auf den Standard zurückgesetzt:\n\n'
          '${PocketBaseService.defaultUrl}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Zurücksetzen'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _pbService.resetToDefault();
        if (!mounted) return;
        setState(() {
          _pocketBaseUrlController.text = PocketBaseService.defaultUrl;
          _pbConnectionOk = null;
        });
      } catch (e, st) {
        debugPrint('[Settings] URL-Reset fehlgeschlagen: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Zurücksetzen: $e')),
        );
      }
    }
  }

  // ==================== DATENBANK ====================

  Future<void> _deleteDatabase() async {
    if (kIsWeb) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank löschen'),
        content: const Text(
          'Möchten Sie die komplette lokale Datenbank löschen? '
          'Alle lokal gespeicherten Artikel gehen verloren!\n\n'
          'Daten in PocketBase bleiben erhalten und können neu '
          'synchronisiert werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await _db.resetDatabase();
        await _checkDatabaseStatus();
        await _loadSettings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lokale Datenbank gelöscht – '
              'Sie können jetzt eine neue Start-Artikelnummer festlegen',
            ),
          ),
        );
      } catch (e, st) {
        debugPrint('[Settings] DB-Löschen fehlgeschlagen: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    }
  }

  // ==================== SPEICHERN ====================

  Future<void> _saveSettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final newUrl = _pocketBaseUrlController.text.trim();
      if (newUrl.isNotEmpty) {
        // FIX: updateUrl() bool-Rückgabe auswerten —
        // schlägt der Health-Check fehl, bleibt der bestehende Client
        // aktiv und der User bekommt eine klare Fehlermeldung.
        // Einstellungen werden trotzdem gespeichert (Artikelnummer etc.)
        // — nur die URL wird nicht übernommen wenn sie nicht erreichbar ist.
        final urlUpdated = await _pbService.updateUrl(newUrl);
        if (!urlUpdated) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ PocketBase URL konnte nicht gesetzt werden – '
                'Server nicht erreichbar oder URL ungültig. '
                'Bestehende URL bleibt aktiv.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          // Frühzeitig abbrechen — URL-Feld zurücksetzen auf aktive URL
          setState(() {
            _pocketBaseUrlController.text = _pbService.url;
          });
          return;
        }
      }

      // Artikelnummer nur bei leerer DB (und nur auf Mobile)
      if (!kIsWeb && _isDatabaseEmpty) {
        final artikelNummer =
            int.tryParse(_artikelNummerController.text.trim()) ?? 1000;
        await prefs.setInt('artikel_start_nummer', artikelNummer);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Einstellungen gespeichert')),
      );
    } catch (e, st) {
      debugPrint('[Settings] Speichern fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Einstellungen speichern',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPocketBaseCard(),
              const SizedBox(height: 16),
              if (!kIsWeb) _buildArtikelNummerCard(),
              const SizedBox(height: 16),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== POCKETBASE CARD ====================

  Widget _buildPocketBaseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'PocketBase Server',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_pbConnectionOk != null)
                  Icon(
                    _pbConnectionOk! ? Icons.check_circle : Icons.error,
                    color: _pbConnectionOk! ? Colors.green : Colors.red,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pocketBaseUrlController,
              decoration: InputDecoration(
                labelText: 'PocketBase URL',
                hintText: 'http://192.168.1.100:8080',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                helperText: 'Standard: ${PocketBaseService.defaultUrl}',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Auf Standard zurücksetzen',
                  onPressed: _resetPocketBaseUrl,
                ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte eine URL eingeben';
                }
                final url = value.trim();
                if (!url.startsWith('http://') &&
                    !url.startsWith('https://')) {
                  return 'URL muss mit http:// oder https:// beginnen';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isCheckingConnection ? null : _testPocketBaseConnection,
                icon: _isCheckingConnection
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(
                  _isCheckingConnection
                      ? 'Prüfe Verbindung...'
                      : 'Verbindung testen',
                ),
              ),
            ),
            if (_pbConnectionOk != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _pbConnectionOk!
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _pbConnectionOk!
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _pbConnectionOk! ? Icons.check_circle : Icons.error,
                      color: _pbConnectionOk! ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pbConnectionOk!
                            ? 'Verbindung erfolgreich! Server ist erreichbar.'
                            : 'Server nicht erreichbar. Bitte URL und Netzwerk prüfen.',
                        style: TextStyle(
                          color: _pbConnectionOk!
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Im Web-Modus wird die API über den Reverse Proxy '
                        'bereitgestellt. Die Standard-URL (/api) sollte '
                        'normalerweise nicht geändert werden.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== ARTIKELNUMMER CARD ====================

  Widget _buildArtikelNummerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Artikelnummer-Einstellungen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _artikelNummerController,
              enabled: _isDatabaseEmpty,
              decoration: InputDecoration(
                labelText: 'Start-Artikelnummer',
                hintText: 'z.B. 1000',
                prefixIcon: const Icon(Icons.tag),
                helperText: _isDatabaseEmpty
                    ? 'Neue Artikel erhalten eine ID ab dieser Nummer'
                    : 'Kann nur bei leerer Datenbank geändert werden',
                border: const OutlineInputBorder(),
                suffixIcon: _isDatabaseEmpty
                    ? null
                    : const Icon(Icons.lock, color: Colors.grey),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte eine Artikelnummer eingeben';
                }
                final nummer = int.tryParse(value.trim());
                if (nummer == null) return 'Bitte eine gültige Zahl eingeben';
                if (nummer < 1) return 'Mindestens 1';
                if (nummer > 999999) return 'Maximal 999999';
                return null;
              },
            ),
            if (!_isDatabaseEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Die Start-Artikelnummer kann nur geändert werden, '
                        'wenn die lokale Datenbank leer ist. '
                        'Daten in PocketBase bleiben erhalten.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _deleteDatabase,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Lokale Datenbank löschen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== INFO CARD ====================

  Widget _buildInfoCard() {
    final pbUrl = _pbService.url;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App-Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('Version', '1.5.0'),
            _infoRow('Plattform', kIsWeb ? 'Web' : 'Mobile/Desktop'),
            _infoRow(
              'Datenbank',
              kIsWeb
                  ? 'PocketBase (direkt)'
                  : 'SQLite (lokal) + PocketBase Sync',
            ),
            _infoRow('PocketBase URL', pbUrl),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}