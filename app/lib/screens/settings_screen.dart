//lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/artikel_db_service.dart';
// ...existing code...

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  // Nextcloud-Konfiguration entfernt
  final _artikelNummerController = TextEditingController();
  
  bool _isDatabaseEmpty = true;
  // Nextcloud-Konfiguration entfernt

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkDatabaseStatus();
  }

  @override
  void dispose() {
  // Nextcloud-Konfiguration entfernt
    _artikelNummerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _artikelNummerController.text = (prefs.getInt('artikel_start_nummer') ?? 1000).toString();
    });
  }

  Future<void> _checkDatabaseStatus() async {
    final isEmpty = await ArtikelDbService().isDatabaseEmpty();
    setState(() {
      _isDatabaseEmpty = isEmpty;
    });
  }

  Future<void> _deleteDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datenbank löschen'),
        content: const Text(
          'Möchten Sie die komplette Datenbank löschen? '
          'Alle Artikel gehen verloren! Diese Aktion kann nicht rückgängig gemacht werden.\n\n'
          'Nach dem Löschen können Sie eine neue Start-Artikelnummer festlegen.',
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

    if (confirm == true) {
      try {
        await ArtikelDbService().deleteOldDatabase();
        await _checkDatabaseStatus(); // Status neu prüfen
        await _loadSettings(); // Einstellungen neu laden um UI zu aktualisieren
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datenbank erfolgreich gelöscht - Sie können jetzt eine neue Start-Artikelnummer festlegen')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Löschen: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    // Artikelnummer nur bei leerer Datenbank speichern
    if (_isDatabaseEmpty) {
      final artikelNummer = int.tryParse(_artikelNummerController.text.trim()) ?? 1000;
      await prefs.setInt('artikel_start_nummer', artikelNummer);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isDatabaseEmpty 
              ? 'Einstellungen gespeichert' 
              : 'Start-Artikelnummer kann bei vorhandenen Daten nicht geändert werden'),
        ),
      );
    }
  }



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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nextcloud-Konfigurationseinträge entfernt

              const SizedBox(height: 16),

              // Artikelnummer-Einstellungen
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Artikelnummer-Einstellungen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _artikelNummerController,
                        enabled: _isDatabaseEmpty,
                        decoration: InputDecoration(
                          labelText: 'Start-Artikelnummer',
                          hintText: 'z.B. 1000',
                          prefixIcon: Icon(Icons.tag),
                          helperText: _isDatabaseEmpty 
                              ? 'Neue Artikel erhalten eine ID ab dieser Nummer'
                              : 'Kann nur bei leerer Datenbank geändert werden',
                          border: OutlineInputBorder(),
                          suffixIcon: _isDatabaseEmpty 
                              ? null 
                              : Icon(Icons.lock, color: Colors.grey),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Bitte geben Sie eine Artikelnummer ein';
                          }
                          final nummer = int.tryParse(value.trim());
                          if (nummer == null) {
                            return 'Bitte geben Sie eine gültige Zahl ein';
                          }
                          if (nummer < 1) {
                            return 'Die Artikelnummer muss mindestens 1 sein';
                          }
                          if (nummer > 999999) {
                            return 'Die Artikelnummer darf maximal 999999 sein';
                          }
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
                                  'Die Start-Artikelnummer kann nur geändert werden, wenn die Datenbank leer ist. '
                                  'Löschen Sie die Datenbank, um eine neue Startnummer festzulegen.',
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
                          label: const Text('Datenbank löschen'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Hinweistext zur App-Passwort-Erstellung entfernt
              
              const SizedBox(height: 24),
              
              // Nextcloud-Sync-Status entfernt
            ],
          ),
        ),
      ),
    );
  }
}