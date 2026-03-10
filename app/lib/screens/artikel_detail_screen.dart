// lib/screens/artikel_detail_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import '../models/artikel_model.dart';
import '../services/artikel_db_service.dart';
import '../services/pocketbase_service.dart';
import '../services/app_log_service.dart';
import '../services/image_picker.dart';
import 'package:http/http.dart' as http;



// Conditional imports für dart:io
import 'detail_screen_io.dart'
    if (dart.library.html) 'detail_screen_stub.dart' as platform;
import '../services/pdf_service_stub.dart'
    if (dart.library.io) '../services/pdf_service.dart';
import '_dokumente_button_stub.dart'
    if (dart.library.io) '_dokumente_button.dart';

class ArtikelDetailScreen extends StatefulWidget {
  final Artikel artikel;

  const ArtikelDetailScreen({super.key, required this.artikel});

  @override
  State<ArtikelDetailScreen> createState() => _ArtikelDetailScreenState();
}

class _ArtikelDetailScreenState extends State<ArtikelDetailScreen> {
  late TextEditingController _beschreibungController;
  late TextEditingController _ortController;
  late TextEditingController _fachController;
  late int _menge;
  bool _isEditing = false;
  bool _hasChanged = false;

  String? _bildPfad;
  Uint8List? _bildBytes;
  String? _remoteBildUrl; // PocketBase Bild-URL für Web

  @override
  void initState() {
    super.initState();
    _beschreibungController = TextEditingController(text: widget.artikel.beschreibung)
      ..addListener(_onChanged);
    _ortController = TextEditingController(text: widget.artikel.ort)
      ..addListener(_onChanged);
    _fachController = TextEditingController(text: widget.artikel.fach)
      ..addListener(_onChanged);
    _menge = widget.artikel.menge;
    _bildPfad = widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    // Im Web: Bild-URL von PocketBase laden
    if (kIsWeb) {
      _loadRemoteBildUrl();
    }
  }

  /// Lädt die Bild-URL aus PocketBase für die Web-Anzeige
  Future<void> _loadRemoteBildUrl() async {
    try {
      final pb = PocketBaseService().client;
      final filter = 'uuid = "${widget.artikel.uuid}"';
      final list = await pb.collection('artikel').getList(filter: filter);

      if (list.items.isNotEmpty) {
        final record = list.items.first;
        final bildField = record.data['bild'];
        if (bildField != null && bildField.toString().isNotEmpty) {
          final url = pb.files.getUrl(record, bildField.toString()).toString();
          setState(() => _remoteBildUrl = url);
        }
      }
    } catch (e) {
      debugPrint('[Detail] Bild-URL laden fehlgeschlagen: $e');
    }
  }

  void _onChanged() {
    if (_isEditing) {
      setState(() => _hasChanged = true);
    }
  }

  @override
  void dispose() {
    _beschreibungController.dispose();
    _ortController.dispose();
    _fachController.dispose();
    super.dispose();
  }

  // ==================== BILD AUSWAHL ====================

  Future<void> _pickImageFile() async {
    final picked = await ImagePickerService.pickImageFile(context);
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _hasChanged = true;
    });
  }

  Future<void> _pickImageCamera() async {
    if (kIsWeb) return;
    final picked = await ImagePickerService.pickImageCamera(context);
    if (picked.pfad == null && picked.bytes == null) return;
    setState(() {
      _bildPfad = picked.pfad;
      _bildBytes = picked.bytes;
      _hasChanged = true;
    });
  }

  // ==================== SPEICHERN ====================

  Future<void> _speichern() async {
    if (kIsWeb) {
      await _speichernWeb();
    } else {
      await _speichernMobile();
    }
  }

  /// Web: Direkt in PocketBase speichern
  Future<void> _speichernWeb() async {
    try {
      final pb = PocketBaseService().client;
      final filter = 'uuid = "${widget.artikel.uuid}"';
      final list = await pb.collection('artikel').getList(filter: filter);

      if (list.items.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Artikel nicht in PocketBase gefunden')),
          );
        }
        return;
      }

      final recordId = list.items.first.id;

      final body = <String, dynamic>{
        'menge': _menge,
        'ort': _ortController.text,
        'fach': _fachController.text,
        'beschreibung': _beschreibungController.text,
        'aktualisiertAm': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final List<http.MultipartFile> files = [];
      if (_bildBytes != null) {
        files.add(http.MultipartFile.fromBytes(
          'bild',
          _bildBytes!,
          filename: 'bild_${widget.artikel.uuid}.jpg',
        ));
      }

      await pb.collection('artikel').update(recordId, body: body, files: files);

      if (!mounted) return;
      final gespeicherterArtikel = widget.artikel.copyWith(
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        aktualisiertAm: DateTime.now(),
      );

      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _bildBytes = null;
      });

      // Bild-URL neu laden
      _loadRemoteBildUrl();

      Navigator.pop(context, gespeicherterArtikel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  /// Mobile/Desktop: Lokal speichern + PocketBase Sync
  Future<void> _speichernMobile() async {
    final artikelId = widget.artikel.id;
    if (artikelId == null) return;

    final hasNewImage =
        _bildBytes != null || (_bildPfad != null && _bildPfad != widget.artikel.bildPfad);

    String? localImagePath =
        widget.artikel.bildPfad.isNotEmpty ? widget.artikel.bildPfad : null;

    // Neues Bild lokal speichern
    if (hasNewImage) {
      localImagePath = await platform.persistSelectedImage(
        bildBytes: _bildBytes,
        bildPfad: _bildPfad,
        artikelId: artikelId,
        artikelName: widget.artikel.name,
      );

      if (localImagePath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild konnte nicht gespeichert werden')),
        );
        return;
      }
    }

    final artikelMitAenderungen = widget.artikel.copyWith(
      menge: _menge,
      ort: _ortController.text,
      fach: _fachController.text,
      beschreibung: _beschreibungController.text,
      bildPfad: localImagePath ?? '',
      aktualisiertAm: DateTime.now(),
    );

    try {
      await ArtikelDbService().updateArtikel(artikelMitAenderungen);

      // Bild zu PocketBase hochladen (im Hintergrund)
      if (hasNewImage) {
        _uploadImageToPocketBase(
          uuid: widget.artikel.uuid,
          localImagePath: localImagePath,
          bildBytes: _bildBytes,
        );
      }

      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _hasChanged = false;
        _bildBytes = null;
        _bildPfad = artikelMitAenderungen.bildPfad.isNotEmpty
            ? artikelMitAenderungen.bildPfad
            : null;
      });

      Navigator.pop(context, artikelMitAenderungen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  /// Bild im Hintergrund zu PocketBase hochladen
  Future<void> _uploadImageToPocketBase({
    required String uuid,
    String? localImagePath,
    Uint8List? bildBytes,
  }) async {
    try {
      final pb = PocketBaseService().client;
      final filter = 'uuid = "$uuid"';
      final list = await pb.collection('artikel').getList(filter: filter);
      if (list.items.isEmpty) return;

      final recordId = list.items.first.id;

      Uint8List bytes;
      String filename;

      if (bildBytes != null) {
        bytes = bildBytes;
        filename = 'bild_$uuid.jpg';
      } else if (localImagePath != null) {
        bytes = await platform.readFileBytes(localImagePath);
        filename = p.basename(localImagePath);
      } else {
        return;
      }

      await pb.collection('artikel').update(
        recordId,
        files: [http.MultipartFile.fromBytes('bild', bytes, filename: filename)],
      );

      debugPrint('[Upload] Bild zu PocketBase hochgeladen: $filename');
    } catch (e) {
      debugPrint('[Upload] PocketBase Bild-Upload fehlgeschlagen: $e');
    }
  }

  // ==================== LÖSCHEN ====================

  Future<void> _loeschen() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Artikel löschen?'),
        content: Text('Möchtest du "${widget.artikel.name}" wirklich löschen?'),
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

    if (confirm != true) return;

    try {
      if (kIsWeb) {
        // Web: In PocketBase löschen
        final pb = PocketBaseService().client;
        final filter = 'uuid = "${widget.artikel.uuid}"';
        final list = await pb.collection('artikel').getList(filter: filter);
        if (list.items.isNotEmpty) {
          await pb.collection('artikel').delete(list.items.first.id);
        }
      } else {
        // Mobile: Soft-Delete lokal
        await ArtikelDbService().deleteArtikel(widget.artikel);
      }

      if (!mounted) return;
      Navigator.pop(context, null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
        );
      }
    }
  }

  // ==================== PDF ====================

  Future<void> _generateArtikelDetailPdf() async {
    if (kIsWeb) {
      // PDF-Export im Web – TODO: Kann später mit printing-Package implementiert werden
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF-Export ist im Web noch nicht verfügbar')),
        );
      }
      return;
    }

    try {
      await AppLogService().log('PDF-Export gestartet für Artikel: ${widget.artikel.name}');
      final pdfService = PdfService();

      final aktuellerArtikel = widget.artikel.copyWith(
        menge: _menge,
        ort: _ortController.text,
        fach: _fachController.text,
        beschreibung: _beschreibungController.text,
        bildPfad: _bildPfad ?? widget.artikel.bildPfad,
        aktualisiertAm: DateTime.now(),
      );

      final pdfFile = await pdfService.generateArtikelDetailPdf(aktuellerArtikel);

      if (pdfFile != null) {
        await AppLogService().log('Artikel-PDF erstellt: ${pdfFile.path}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF erstellt!\nPfad: ${pdfFile.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Öffnen',
              onPressed: () async {
                final success = await PdfService.openPdf(pdfFile.path);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF konnte nicht geöffnet werden')),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e, stack) {
      await AppLogService().logError('Fehler beim PDF-Export: $e', stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim PDF-Export: $e')),
        );
      }
    }
  }

  // ==================== MENGEN-STEUERUNG ====================

  void _mengeErhoehen() {
    if (_isEditing) setState(() { _menge++; _hasChanged = true; });
  }

  void _mengeVerringern() {
    if (_isEditing && _menge > 0) setState(() { _menge--; _hasChanged = true; });
  }

  void _enableEdit() {
    setState(() { _isEditing = true; _hasChanged = false; });
  }

  // ==================== BILD VOLLBILD ====================

  void _zeigeBildVollbild() {
    Widget bildWidget;

    if (_bildBytes != null) {
      bildWidget = Image.memory(_bildBytes!, fit: BoxFit.contain);
    } else if (kIsWeb && _remoteBildUrl != null) {
      bildWidget = Image.network(_remoteBildUrl!, fit: BoxFit.contain);
    } else if (!kIsWeb && _bildPfad != null) {
      bildWidget = platform.buildFileImage(_bildPfad!, fit: BoxFit.contain);
    } else {
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: InteractiveViewer(child: bildWidget),
        ),
      ),
    );
  }

  // ==================== BILD WIDGET ====================

  Widget _buildBildAnzeige() {
    // 1. Neue Bytes ausgewählt (noch nicht gespeichert)
    if (_bildBytes != null) {
      return GestureDetector(
        onTap: _zeigeBildVollbild,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            _bildBytes!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // 2. Web: Bild von PocketBase
    if (kIsWeb) {
      if (_remoteBildUrl != null) {
        return GestureDetector(
          onTap: _zeigeBildVollbild,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _remoteBildUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            ),
          ),
        );
      }
      return _buildPlaceholder();
    }

    // 3. Mobile: Lokales Bild
    if (_bildPfad != null && platform.fileExists(_bildPfad!)) {
      return GestureDetector(
        onTap: _zeigeBildVollbild,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: platform.buildFileImage(
            _bildPfad!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final artikel = widget.artikel;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.artikel.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generateArtikelDetailPdf,
            tooltip: 'Artikel als PDF exportieren',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _loeschen,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ort
            TextField(
              controller: _ortController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Ort',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.grey[100],
                labelStyle: const TextStyle(color: Colors.black),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 12),

            // Fach
            TextField(
              controller: _fachController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Fach',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.grey[100],
                labelStyle: const TextStyle(color: Colors.black),
              ),
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 20),

            // Menge
            Row(
              children: [
                Text('Menge: $_menge'),
                IconButton(icon: const Icon(Icons.add), onPressed: _mengeErhoehen),
                IconButton(icon: const Icon(Icons.remove), onPressed: _mengeVerringern),
                Text(
                  'Art.-Nr.: ${artikel.id ?? "-"}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Beschreibung
            TextField(
              controller: _beschreibungController,
              enabled: _isEditing,
              decoration: InputDecoration(
                labelText: 'Beschreibung',
                filled: true,
                fillColor: _isEditing ? Colors.white : Colors.grey[100],
                labelStyle: const TextStyle(color: Colors.black),
              ),
              style: const TextStyle(color: Colors.black),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Bild-Buttons
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isEditing ? _pickImageFile : null,
                  icon: const Icon(Icons.image),
                  label: const Text('Bild wählen'),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isEditing ? _pickImageCamera : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Dokumente Button
            DokumenteButton(artikelId: artikel.id),
            const SizedBox(height: 20),

            // Bild-Anzeige (plattformübergreifend)
            _buildBildAnzeige(),

            const SizedBox(height: 20),

            // Speichern/Bearbeiten Button
            ElevatedButton(
              onPressed: !_isEditing
                  ? _enableEdit
                  : (_hasChanged ? _speichern : null),
              child: Text(!_isEditing
                  ? 'Ändern'
                  : (_hasChanged ? 'Speichern' : 'Speichern (inaktiv)')),
            ),
          ],
        ),
      ),
    );
  }
}
