// lib/screens/artikel_erfassen_screen.dart

import 'dart:async' show unawaited;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/artikel_model.dart';
import '../services/pocketbase_service.dart';
import '../services/artikel_db_service.dart';
import '../services/app_log_service.dart';
import '../services/image_picker.dart';
import '../widgets/article_icons.dart';

import 'artikel_erfassen_io.dart'
    if (dart.library.html) 'artikel_erfassen_stub.dart' as platform;

class ArtikelErfassenScreen extends StatefulWidget {
  const ArtikelErfassenScreen({super.key});

  @override
  State<ArtikelErfassenScreen> createState() => _ArtikelErfassenScreenState();
}

class _ArtikelErfassenScreenState extends State<ArtikelErfassenScreen> {
  // M-002: Verwende AppLogService statt lokalem Logger
  final _logger = AppLogService.logger;

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

  late final ArtikelDbService _db;
  late final PocketBaseService _pbService;

  @override
  void initState() {
    super.initState();
    _db = ArtikelDbService();
    _pbService = PocketBaseService();

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

  // ==================== HILFSFUNKTIONEN ====================

  /// ✅ FIX: Prüft ob der Pfad eine externe Quelldatei ist
  /// (nicht bereits ein intern kopiertes App-Bild)
  bool _isExternalPath(String pfad) {
    return !pfad.contains('/images/');
  }

  /// ✅ FIX: State nach Speichern vollständig zurücksetzen
  void _resetBildState() {
    setState(() {
      _bildPfad = null;
      _bildBytes = null;
      _bildDateiname = null;
    });
  }

  // ==================== BILD AUSWAHL ====================

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile(context);
    if (!mounted) return;
    if (!picked.hasImage) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _bildDateiname = picked.dateiname;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickImageCamera() async {
    if (!ImagePickerService.isCameraAvailable) return;
    final picked = await ImagePickerService.pickImageCamera(context);
    if (!mounted) return;
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
      if (!mounted) return;
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
    _logger.d('_save() gestartet.');
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final menge = int.tryParse(_mengeCtrl.text.trim()) ?? 0;
    setState(() => _isSaving = true);
    _logger.d('_isSaving auf true gesetzt.');

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

      _logger.d('Artikel-Objekt erstellt. kIsWeb: $kIsWeb');
      if (kIsWeb) {
        await _saveWeb(artikel);
        _logger.d('_saveWeb() abgeschlossen.');
      } else {
        await _saveMobile(artikel);
        _logger.d('_saveMobile() abgeschlossen.');
      }
    } catch (e, st) {
      _logger.e('Fehler beim Speichern:', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      _logger.d('_isSaving auf false gesetzt. _save() beendet.');
    }
  }

  Future<void> _saveWeb(Artikel artikel) async {
    _logger.d('_saveWeb() gestartet.');
    final pb = _pbService.client;
    final body = artikel.toPocketBaseMap();

    // Prod mode: include owner field when authenticated
    if (_pbService.isAuthenticated && _pbService.currentUserId != null) {
      body['owner'] = _pbService.currentUserId;
    }

    final List<http.MultipartFile> files = [];
    if (_bildBytes != null && _bildDateiname != null) {
      files.add(http.MultipartFile.fromBytes(
        'bild',
        _bildBytes!,
        filename: _bildDateiname,
      ),);
      _logger.d('Bilddatei für Upload hinzugefügt: $_bildDateiname');
    }

    final record = await pb.collection('artikel').create(
      body: body,
      files: files,
    );
    _logger.d(
      'PocketBase create-Request abgeschlossen. Record ID: ${record.id}',
    );

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(artikel.copyWith(
        remotePath: record.id,
        remoteBildPfad: record.data['bild'] as String? ?? '',
      ),);
      _logger.d('Navigator.pop() aufgerufen.');
    }
  }

  Future<void> _saveMobile(Artikel artikel) async {
    final artikelId = await _db.insertArtikel(artikel);
    _logger.d('artikelId: $artikelId');
    _logger.d('_bildBytes null: ${_bildBytes == null}');
    _logger.d('_bildPfad (raw): $_bildPfad');

    // ✅ FIX 1: Nur externe Pfade als Quelle erlauben.
    // Verhindert dass ein bereits intern kopiertes Bild
    // (z.B. /home/.../images/1006_name-7.jpg) als Quelle
    // für einen neuen Artikel verwendet wird.
    final String? quellPfad = _bildPfad != null && _isExternalPath(_bildPfad!)
        ? _bildPfad
        : null;

    _logger.d('quellPfad (nach Filter): $quellPfad');

    String? localImagePath;
    if (_bildBytes != null || quellPfad != null) {
      localImagePath = await platform.copyImageToLocalDirectory(
        bildBytes: _bildBytes,
        bildPfad: quellPfad,
        artikelId: artikelId,
        artikelName: _nameCtrl.text.trim(),
      );

      if (localImagePath != null) {
        await _db.updateBildPfad(artikelId, localImagePath);
        _logger.d('localImagePath gespeichert: $localImagePath');
      }
    }

    if (localImagePath != null || _bildBytes != null) {
      unawaited(_uploadImageToPocketBase(
        artikel: artikel,
        bildBytes: _bildBytes,
        bildDateiname: _bildDateiname,
        localImagePath: localImagePath,
      ),);
    }

    // ✅ FIX 2: Bild-State zurücksetzen BEVOR Navigator.pop()
    // Verhindert dass _bildPfad in einem Folge-Aufruf noch
    // auf die alte Datei zeigt.
    _resetBildState();

    if (mounted) {
      setState(() => _hasUnsavedChanges = false);
      Navigator.of(context).pop(artikel.copyWith(
        id: artikelId,
        bildPfad: localImagePath ?? '',
        uuid: artikel.uuid,
      ),);
    }
  }

  Future<void> _uploadImageToPocketBase({
    required Artikel artikel,
    Uint8List? bildBytes,
    String? bildDateiname,
    String? localImagePath,
  }) async {
    try {
      final pb = _pbService.client;

      final filter = 'uuid = "${artikel.uuid}"';
      final list = await pb.collection('artikel').getList(filter: filter);
      if (list.items.isEmpty) return;

      final recordId = list.items.first.id;

      final Uint8List bytes;
      final String filename;

      if (bildBytes != null) {
        bytes = bildBytes;
        filename = bildDateiname ?? 'bild.jpg';
      } else if (localImagePath != null) {
        bytes = await platform.readFileBytes(localImagePath);
        filename = platform.getBasename(localImagePath);
      } else {
        return;
      }

      await pb.collection('artikel').update(
        recordId,
        files: [
          http.MultipartFile.fromBytes('bild', bytes, filename: filename),
        ],
      );

      await _db.markSynced(artikel.uuid, recordId);
      _logger.i('Bild zu PocketBase hochgeladen: $filename');
    } catch (e, st) {
      _logger.e(
        'PocketBase Bild-Upload fehlgeschlagen:',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleCancel();
      },
      child: Scaffold(
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bitte Name eingeben'
                      : null,
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
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bitte Ort eingeben'
                      : null,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: spacing),
                TextFormField(
                  controller: _fachCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fach',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bitte Fach eingeben'
                      : null,
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

                // Bild-Auswahl
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _pickImageFile,
                      icon: const ImageFileIcon(),
                      label: const Text('Bilddatei wählen'),
                    ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
      ),
    );
  }
}