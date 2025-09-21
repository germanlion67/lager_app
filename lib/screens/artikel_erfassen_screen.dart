//lib/screens/artikel_erfassen_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
//import 'package/file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../widgets/article_icons.dart';
import '../services/nextcloud_webdav_client.dart';
import '../services/nextcloud_credentials.dart';
import '../services/image_picker.dart';

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

  String? _bildPfad;         
  Uint8List? _bildBytes;     
  String? _bildDateiname;

  bool _isSaving = false;
  bool _hasUnsavedChanges = false;   

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_markDirty);
    _beschreibungCtrl.addListener(_markDirty);
    _ortCtrl.addListener(_markDirty);
    _fachCtrl.addListener(_markDirty);
    _mengeCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _beschreibungCtrl.dispose();
    _ortCtrl.dispose();
    _fachCtrl.dispose();
    _mengeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile();
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickImageCamera() async {
    final picked = await ImagePickerService.pickImageCamera();
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  // --- Hilfsfunktionen für Remote-Pfad-Namen (ohne DB-ID-Abhängigkeit) ---
  String _slug(String input) {
    final s = input.toLowerCase();
    final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  // Bilddateiname = Artikelnr-Slug.jpg
  String _buildRemotePath({
    required String baseFolder,
    required int artikelId,
    required String artikelName,
  }) {
    final nameSlug = _slug(artikelName.isEmpty ? 'artikel' : artikelName);
    final fileName = '$artikelId-$nameSlug.jpg';
    return p.posix.join(baseFolder, fileName);
  }

  // ---------- Abbrechen mit Bestätigung ----------
  Future<void> _handleCancel() async {
    if (!_hasUnsavedChanges) {
      Navigator.pop(context);
      return;
    }

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Änderungen verwerfen?'),
        content: const Text(
          'Du hast bereits Daten eingegeben, die noch nicht gespeichert sind. '
          'Möchtest du das Formular wirklich verlassen und alle Eingaben verlieren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Weiter bearbeiten'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Verwerfen'),
          ),
        ],
      ),
    );

    if (discard == true && mounted) {
      Navigator.pop(context);
    }
  }
  // ---------- Speichern mit Upload ----------
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

        // Bildname immer nach Schema: Artikelnr-Slug.jpg
        final remoteRelPath = _buildRemotePath(
          baseFolder: client.config.baseRemoteFolder,
          artikelId: artikelId,
          artikelName: _nameCtrl.text.trim(),
        );

        try {
          if (_bildBytes != null) {
            await client.uploadBytes(
              bytes: _bildBytes!,
              remoteRelativePath: remoteRelPath,
            );
          } else if (_bildPfad != null) {
            await client.uploadFileNew(
              localPath: _bildPfad!,
              remoteRelativePath: remoteRelPath,
            );
          }

          // DB mit Remote-Pfad aktualisieren
          if (!mounted) return; 
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

    // ---Screen schließen ---
    if (mounted) {
      setState(() => _hasUnsavedChanges = false); 
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
                  if (v == null || v.trim().isEmpty) return null;
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
                    onPressed: _pickImageFile,
                    icon: const ImageFileIcon(),
                    label: const Text('Bilddatei wählen'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _pickImageCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
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
                      onPressed: _isSaving ? null : _handleCancel,
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

// Der Bildname in Nextcloud wird jetzt wie folgt erzeugt:
// Beispiel: 1234-artikelname-datei.jpg
// Dabei:
//   1234         = Artikelnummer (ID)
//   artikelname  = Slug des Artikelnamens (nur Kleinbuchstaben und Bindestriche)
//   datei.jpg    = Originaldateiname des Bildes
        // Beispiel für einen Originaldateinamen:
        // - "foto123.jpg"
        // - "scan_2024.png"
        // - "bild.jpg" (Fallback)
