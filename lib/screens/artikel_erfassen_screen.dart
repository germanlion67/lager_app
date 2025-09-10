//lib/screens/artikel_erfassen_screen.dart

// Änderungen gegenüber vorherigem Stand:
//Imports für WebDAV‑Client & Credentials sowie path
//Erweiterte _save()‑Methode: Upload nach dem Insert
//Robuste Remote‑Pfaderzeugung (Zeitstempel + Slug aus Artikelname)


// Felder: Name, Beschreibung, Ort, Menge, Bilddatei.
// Bildauswahl: über file_picker (Filter: übliche Bildformate).
// Speichern: erstellt Artikel und ruft ArtikelDbService().insertArtikel(...).
// Hinweis: Dein Artikel‑Modell im vorhandenen Code hat (Name, Beschreibung,
// Ort, Menge). Für die Bilddatei zeige ich zwei Varianten:
//
// Ohne Schema‑Änderung: Bild wird nur ausgewählt/angezeigt, aber
// nicht ins Modell geschrieben (kompiliert sofort).
// Mit Schema‑Erweiterung (optional): Wenn du bildPfad in Artikel ergänzt,
// kannst du die markierte Stelle freischalten.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../widgets/article_icons.dart';

// ⬇️ WebDAV / Nextcloud (Option B)
import '../services/nextcloud_webdav_client.dart';
import '../services/nextcloud_credentials.dart';

class ArtikelErfassenScreen extends StatefulWidget {
  const ArtikelErfassenScreen({super.key});

  @override
  State<ArtikelErfassenScreen> createState() => _ArtikelErfassenScreenState();
}

class _ArtikelErfassenScreenState extends State<ArtikelErfassenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _beschreibungCtrl = TextEditingController();
  final _ortCtrl = TextEditingController();
  final _fachCtrl = TextEditingController();
  final _mengeCtrl = TextEditingController(text: '0');

  String? _bildPfad;         // Pfad der ausgewählten Datei (Desktop/Mobile)
  Uint8List? _bildBytes;     // Bytes für Preview (Web/Allgemein)
  String? _bildDateiname;

  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _beschreibungCtrl.dispose();
    _ortCtrl.dispose();
    _fachCtrl.dispose();
    _mengeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['png','jpg','jpeg','gif','bmp','webp'],
      withData: true, // ermöglicht Preview über bytes
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    setState(() {
      _bildPfad = file.path;
      _bildBytes = file.bytes; // kann null sein, je nach Plattform/Größe
      _bildDateiname = file.name;
    });
  }

  // --- Hilfsfunktionen für Remote-Pfad-Namen (ohne DB-ID-Abhängigkeit) ---

  String _slug(String input) {
    final s = input.toLowerCase();
    final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Erzeugt z. B.: Apps/Artikel/2025-09-01T12-34-56.789Z-artikelname/datei.jpg
  String _buildRemotePath({
    required String baseFolder,
    required String dateiname,
    required String artikelName,
  }) {
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    return p.posix.join(baseFolder, '$ts-$nameSlug', dateiname);
  }

Future<void> _save() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  final menge = int.tryParse(_mengeCtrl.text.trim()) ?? 0;

  final artikel = Artikel(
    name: _nameCtrl.text.trim(),
    beschreibung: _beschreibungCtrl.text.trim(),
    ort: _ortCtrl.text.trim(),
    fach: _fachCtrl.text.trim(),
    menge: menge,
    bildPfad: _bildPfad ?? '',
    remoteBildPfad: '', // Initialwert
    erstelltAm: DateTime.now(),
    aktualisiertAm: DateTime.now(),
  );

  setState(() => _isSaving = true);

  try {
    // --- 1) Artikel in DB speichern ---
    final artikelId = await ArtikelDbService().insertArtikel(artikel);

    // --- 2) Bild hochladen, falls vorhanden ---
    if (_bildBytes != null || _bildPfad != null) {
      final creds = await NextcloudCredentialsStore().read();

      if (creds == null) {
        if (!mounted) return; // 👈
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Hinweis: Nextcloud nicht konfiguriert – Bild nicht hochgeladen')),
        );
      } else {
        final client = NextcloudWebDavClient(
          NextcloudConfig(
            serverBase: creds.server,
            username: creds.user,
            appPassword: creds.appPw,
            baseRemoteFolder: creds.baseFolder,
          ),
        );

        final baseName =
            _bildDateiname ?? (_bildPfad != null ? p.basename(_bildPfad!) : 'bild.jpg');

        final remoteRelPath = _buildRemotePath(
          baseFolder: client.config.baseRemoteFolder,
          dateiname: baseName,
          artikelName: _nameCtrl.text.trim(),
        );

        try {
          if (_bildBytes != null) {
            await client.uploadBytes(
              bytes: _bildBytes!,
              remoteRelativePath: remoteRelPath,
            );
          } else if (_bildPfad != null) {
            await client.uploadFile(
              localPath: _bildPfad!,
              remoteRelativePath: remoteRelPath,
            );
          }

          // DB mit Remote-Pfad aktualisieren
          if (!mounted) return; // 👈 neu
          await ArtikelDbService().updateRemoteBildPfad(artikelId, remoteRelPath);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bild erfolgreich zu Nextcloud hochgeladen')),
          );
        } on WebDavException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload fehlgeschlagen: ${e.message}')),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload-Fehler: $e')),
          );
        }
      }
    }

    // --- 3) Screen schließen, nur einmal ---
    if (mounted) {
      Navigator.of(context).pop(artikel.copyWith(id: artikelId));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Neuen Artikel erfassen')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bitte Name eingeben' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _beschreibungCtrl,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: spacing),
              TextFormField(
                controller: _ortCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ort',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bitte Ort eingeben' : null,
                textInputAction: TextInputAction.next,
              ),

              TextFormField(
                controller: _fachCtrl,
                decoration: const InputDecoration(
                  labelText: 'Fach',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bitte Fach eingeben' : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: spacing),
              TextFormField(
                controller: _mengeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Menge',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 0) return 'Ungültige Menge';
                  return null;
                },
              ),
              const SizedBox(height: spacing),
              // Bilddatei-Auswahl
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickImage,
                    icon: const ImageFileIcon(),
                    label: const Text('Bilddatei wählen'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bildDateiname ?? 'Keine Datei ausgewählt',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_bildBytes != null) ...[
                const SizedBox(height: spacing),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_bildBytes!, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: spacing * 1.5),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                      child: const Text('Abbrechen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Speichern'),
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
