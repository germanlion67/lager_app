// lib/screens/artikel_erfassen_screen.dart
//
// Screen zum Erfassen neuer Artikel.
// Web: Speichert direkt in PocketBase.
// Mobile/Desktop: Speichert lokal in SQLite + Upload zu PocketBase im Hintergrund.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/artikel_model.dart';
import '../services/pocketbase_service.dart';
import '../services/artikel_db_service.dart';
import '../services/image_picker.dart';
import '../widgets/article_icons.dart';

// Conditional imports für dart:io (nur Mobile/Desktop)
import 'artikel_erfassen_io.dart'
    if (dart.library.html) 'artikel_erfassen_stub.dart' as platform;

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

  // ==================== BILD AUSWAHL ====================

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile(context);
    if (!picked.hasImage) return;
    setState(() {
      _bildPfad = picked.pfad; // null im Web – das ist OK
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) return;
    final picked = await ImagePickerService.pickImageCamera(context);
    if (!picked.hasImage) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  // ==================== ABBRECHEN ====================

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

  // ==================== SPEICHERN ====================

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final menge = int.tryParse(_mengeCtrl.text.trim()) ?? 0;
    setState(() => _isSaving = true);

    try {
      final artikel = Artikel(
        name: _nameCtrl.text.trim(),
        beschreibung: _beschreibungCtrl.text.trim(),
        ort: _ortCtrl.text.trim(),
        fach: _fachCtrl.text.trim(),
        menge: menge,
        bildPfad: '',
        remoteBildPfad: '',
        erstelltAm: DateTime.now(),
        aktualisiertAm: DateTime.now(),
      );

      if (kIsWeb) {
        await _saveWeb(artikel);
      } else {
        await _saveMobile(artikel);
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

  /// Web: Artikel + Bild direkt in PocketBase speichern.
  Future<void> _saveWeb(Artikel artikel) async {
    final pb = PocketBaseService().client;

    // Nur PocketBase-relevante Felder senden
    final body = artikel.toPocketBaseMap();

    final List<http.MultipartFile> files = [];
    if (_bildBytes != null && _bildDateiname != null) {
      files.add(http.MultipartFile.fromBytes(
        'bild',       //PocketBase Feldname
        _bildBytes!,
        filename: _bildDateiname!,
      ));   
    }

    final record = await pb.collection('artikel').create(
      body: body,
      files: files,
    );

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(artikel.copyWith(
        uuid: record.data['uuid'] ?? artikel.uuid,
      ));
    }
  }

  /// Mobile/Desktop: Lokal speichern + Bild lokal ablegen.
  Future<void> _saveMobile(Artikel artikel) async {
    final dbService = ArtikelDbService();
    final artikelId = await dbService.insertArtikel(artikel);

    // Bild lokal speichern
    String? localImagePath;
    if (_bildBytes != null || _bildPfad != null) {
      localImagePath = await platform.copyImageToLocalDirectory(
        bildBytes: _bildBytes,
        bildPfad: _bildPfad,
        artikelId: artikelId,
        artikelName: _nameCtrl.text.trim(),
      );

      if (localImagePath != null) {
        await dbService.updateBildPfad(artikelId, localImagePath);
      }
    }

    // Bild zu PocketBase hochladen (im Hintergrund, non-blocking)
    if (localImagePath != null || _bildBytes != null) {
      _uploadImageToPocketBase(
        artikel: artikel,
        bildBytes: _bildBytes,
        bildDateiname: _bildDateiname,
        localImagePath: localImagePath,
      );
    }

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(artikel.copyWith(
        id: artikelId,
        bildPfad: localImagePath ?? '',
      ));
    }
  }

  /// Bild im Hintergrund zu PocketBase hochladen (fire-and-forget).
  /// Fehler werden nur geloggt, nicht dem User angezeigt.
  Future<void> _uploadImageToPocketBase({
    required Artikel artikel,
    Uint8List? bildBytes,
    String? bildDateiname,
    String? localImagePath,
  }) async {
    try {
      final pb = PocketBaseService().client;

      // Artikel in PocketBase finden (per UUID)
      final filter = 'uuid = "${artikel.uuid}"';
      final list = await pb.collection('artikel').getList(filter: filter);

      if (list.items.isEmpty) return;

      final recordId = list.items.first.id;

      // Bild-Bytes vorbereiten
      Uint8List bytes;
      String filename;

      if (bildBytes != null) {
        bytes = bildBytes;
        filename = bildDateiname ?? 'bild.jpg';
      } else if (localImagePath != null) {
        bytes = await platform.readFileBytes(localImagePath);
        filename = platform.getBasename(localImagePath);
      } else {
        return;
      }

      // Upload als Multipart
      await pb.collection('artikel').update(
        recordId,
        files: [
          http.MultipartFile.fromBytes(
            'bild',
             bytes,
             filename: filename),
        ],
      );

      debugPrint('[Upload] Bild zu PocketBase hochgeladen: $filename');
    } catch (e) {
      debugPrint('[Upload] PocketBase Bild-Upload fehlgeschlagen: $e');
    }
  }

  // ==================== UI ====================

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
              const SizedBox(height: spacing),
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

              // Bild-Auswahl Buttons
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _pickImageFile,
                    icon: const ImageFileIcon(),
                    label: const Text('Bilddatei wählen'),
                  ),
                  // Kamera-Button nur auf Mobile/Desktop
                  if (ImagePickerService.isCameraAvailable) ...[
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _pickImageCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bildDateiname ?? 'Keine Datei ausgewählt',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Bild-Vorschau
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

              // Buttons
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
                              width: 18,
                              height: 18,
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
